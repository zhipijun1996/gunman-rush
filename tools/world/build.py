"""Compile owned world inputs; never write an authored scene or imported source."""
from pathlib import Path
import hashlib
import json
import math
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from compile_contracts import compile_contracts, write_json
from spatial import navigation_geometry


def validate_player(data):
    focus = data.get('focus_heal', {})
    for key in ('cost', 'heal', 'charge_seconds'):
        value = focus.get(key)
        if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
            raise ValueError('Invalid focus heal ' + key)
    for key, limit in [('keyboard_key', 2**32), ('gamepad_button', 128)]:
        value = focus.get(key)
        if type(value) is not int or not 0 <= value < limit:
            raise ValueError('Invalid focus heal ' + key)

    light = data.get('carry_light', {})
    for key in ('radius', 'energy'):
        value = light.get(key)
        if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
            raise ValueError('Invalid carry light ' + key)
    if not re.fullmatch(r'[0-9a-fA-F]{6}', str(light.get('color', ''))):
        raise ValueError('Invalid carry light color')
    offset = light.get('offset')
    if not isinstance(offset, list) or len(offset) != 2 or any(type(v) not in (int, float) or not math.isfinite(v) for v in offset):
        raise ValueError('Invalid carry light offset')


def validate_cameras(construction, settings):
    profiles = {'bounded_follow','horizontal_follow','vertical_follow','fixed_arena'}
    if set(settings.get('templates', {})) != profiles:
        raise ValueError('Camera must define exactly four templates')
    for key in ('zoom','horizontal_seconds','vertical_seconds','zone_seconds','look_delay_seconds','look_seconds','trend_confirm_seconds','fall_seconds'):
        if type(settings.get(key)) not in (float,int) or not math.isfinite(settings[key]) or settings[key] <= 0:
            raise ValueError('Invalid camera parameter '+key)
    if not 0 <= settings['fall_exit_speed'] < settings['fall_enter_speed']:
        raise ValueError('Camera fall hysteresis must be ordered')
    def rect(value):
        return isinstance(value,list) and len(value)==4 and all(type(v) in (float,int) and math.isfinite(v) for v in value) and value[2]>0 and value[3]>0
    for room in construction['rooms']:
        camera=room['camera']; ids=set()
        if camera.get('profile') not in profiles or camera.get('transition')!='occluded':
            raise ValueError('Invalid camera room template/scene handoff: '+room['room_id'])
        for zone in camera.get('zones',[]):
            if not zone.get('id') or zone['id'] in ids or zone.get('profile') not in profiles or not rect(zone.get('trigger')) or not rect(zone.get('display')):
                raise ValueError('Invalid camera zone: '+room['room_id'])
            ids.add(zone['id'])
            if 'zoom' in zone and (type(zone['zoom']) not in (int,float) or not math.isfinite(zone['zoom']) or zone['zoom']<=0):
                raise ValueError('Invalid explicit camera zoom')
            for mask in zone.get('conceal',[]):
                if not rect(mask): raise ValueError('Invalid camera concealment')
        for link in camera.get('links',[]):
            if link.get('a') not in ids or link.get('b') not in ids or link['a']==link['b'] or link.get('axis') not in ('x','y') or not rect(link.get('band')) or not rect(link.get('display')):
                raise ValueError('Invalid camera connection: '+room['room_id'])


def validate_services(data, implemented, npcs):
    def whole(value, minimum=0):
        return type(value) is int and value >= minimum
    if data.get('schema') != 1 or not whole(data.get('capacity'),1):
        raise ValueError('Invalid service capacity/schema')
    for key in ('enemy_gold','boss_gold'):
        if not whole(data.get(key)): raise ValueError('Invalid income: '+key)
    ids=set()
    for row in data.get('items',[]):
        if not isinstance(row.get('id'),str) or not row['id'] or row['id'] in ids:
            raise ValueError('Invalid/duplicate service item ID')
        ids.add(row['id'])
        for key in ('price','load','max_level','upgrade_price','repair_price'):
            if not whole(row.get(key),1): raise ValueError('Invalid service item '+key)
        if row.get('effect') not in ('lamp','filter','health','heal'):
            raise ValueError('Unsupported service item effect')
        if row['effect']=='health' and (not whole(row.get('health_per_level'),1) or not row.get('catalog_id')):
            raise ValueError('Missing health item binding')
        if row['effect']=='heal' and (not whole(row.get('heal_per_level'),1) or not whole(row.get('uses_per_cycle'),1)):
            raise ValueError('Missing cycle use policy')
    pickup_ids=set()
    for pickup in data.get('pickups',[]):
        if not pickup.get('id') or pickup['id'] in pickup_ids or pickup.get('room_id') not in implemented:
            raise ValueError('Invalid pickup identity/room')
        if not whole(pickup.get('quantity'),1) or not isinstance(pickup.get('point'),list) or len(pickup['point'])!=2:
            raise ValueError('Invalid pickup quantity/placement')
        pickup_ids.add(pickup['id'])
    quest=data.get('quest',{})
    if quest.get('npc_id') not in {r['id'] for r in npcs} or not whole(quest.get('quantity'),1) or not whole(quest.get('gold')):
        raise ValueError('Invalid quest NPC/material/reward')


def local_returns(source, implemented):
    """Compile stable IDs from the latest acquisition design, never from receipts."""
    result=[]
    for row in json.loads((source/'collection_design.json').read_text())['acquisition_contracts']:
        flag=row.get('return_access_contract',{}).get('local_return_state_id')
        if row['room_id'] not in implemented or not flag: continue
        result.append({'id':flag,'room_id':row['room_id'],'section_id':row['section_id'],
                       'type':'local_return','requires':[[]],'grants':[flag],
                       'repeat':False,'persistent':True,'interaction_required':True,
                       'description':'返程折梯已放下','source_ref':'ACQ_'+row['reward_id']})
    return result


def build(root=ROOT):
    root = Path(root)
    source = root / 'config/world'
    world = json.loads((source/'world.json').read_text())
    contracts, report = compile_contracts(source/'world.json', source/'construction.json', root/'build/world/no-route-samples')
    if not report['passed']:
        raise ValueError(report['issues'])
    construction = json.loads((source/'construction.json').read_text())
    implemented = {r['room_id'] for r in construction['rooms'] if r.get('implemented')}
    scene_refs = {r['room_id']:r['scene_ref'] for r in construction['rooms']}
    for room in contracts['rooms']:
        room['scene_ref_status'] = 'implemented_graybox' if room['room_id'] in implemented else 'planned_new_scene_path; not already implemented'
        for door in room['doors']:
            door['target_scene'] = scene_refs[door['target_room']]
            door['target_implemented'] = door['target_room'] in implemented
    # Calibrated construction phases share one physical region even while the
    # internal scenes are being rebuilt in connected batches. Validate every
    # adopted footprint; expose only completed scenes to the runtime loader.
    laid_out = implemented | {r['room_id'] for r in construction['rooms'] if r.get('layout_revision')}
    layouts = navigation_geometry({r['room_id']:r for r in contracts['rooms'] if r['room_id'] in laid_out}, contracts['initial_state']['room'])
    sources = {n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in ['world.json','construction.json','collections.json','player.json','demo_services.json','ui_texts.json','collection_design.json']}
    scene_sources = {r['scene_ref']:hashlib.sha256((root/r['scene_ref'].removeprefix('res://')).read_bytes()).hexdigest() for r in construction['rooms'] if r['room_id'] in implemented and (root/r['scene_ref'].removeprefix('res://')).is_file()}
    bundle = {'schema':1,'sources':sources,
              'start':contracts['initial_state'], 'actions':world['actions']+local_returns(source,implemented), 'scene_sources':scene_sources,
              'player':json.loads((source/'player.json').read_text()),
              'collection_rules':json.loads((source/'collections.json').read_text())['trial_defaults'],
              'gear_milestones':['pickup_'+r['reward_id'] for r in json.loads((source/'collection_design.json').read_text())['acquisition_contracts'] if r['source_channel']=='gear_delivery'],
              'demo_services':json.loads((source/'demo_services.json').read_text()),
              'ui_texts':json.loads((source/'ui_texts.json').read_text()),
              'npcs':[r for r in world['npcs'] if r['room_id'] in implemented], 'traveler_story':world.get('traveler_story',{}),
              'map_rooms':[{**{k:r[k] for k in ['id','name','region']}, **layouts[r['id']]} for r in world['rooms'] if r['id'] in implemented], 'runtime_rules':world['runtime_rules'],
              'rooms':{r['room_id']:r for r in contracts['rooms'] if r['room_id'] in implemented}}
    validate_player(bundle['player'])
    validate_cameras(construction,bundle['player']['camera'])
    # Unbuilt-room placements remain authored in the source, but must not be
    # advertised as available in a staged construction playtest.
    bundle['demo_services']['pickups'] = [p for p in bundle['demo_services']['pickups'] if p['room_id'] in implemented]
    validate_services(bundle['demo_services'],implemented,bundle['npcs'])
    texts=bundle['ui_texts'].get('strings')
    if not isinstance(texts,dict) or any(not isinstance(v,str) or not v for v in texts.values()):
        raise ValueError('Invalid UI text catalog')
    for script in (root/'game/presentation/ui/world').glob('*.gd'):
        for text_id in re.findall(r'WorldText\.text\("([^"\n]+)"\)',script.read_text()):
            if text_id not in texts: raise ValueError('Missing UI text: '+text_id)
    for room in bundle['rooms'].values():
        if not (root / room['scene_ref'].removeprefix('res://')).is_file():
            raise ValueError('Implemented scene missing: '+room['scene_ref'])
    # Bind the compiled semantics too: a compiler fix can change runtime data
    # without changing any authored input or scene bytes.
    bundle['content_version'] = hashlib.sha256(json.dumps(bundle,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    write_json(root/'build/world/contracts.json', contracts)
    write_json(root/'build/world/runtime.json', bundle)
    return contracts, bundle

if __name__ == '__main__':
    contracts, bundle = build()
    print(f'WORLD BUILD: {len(contracts["rooms"])} contracts, {len(bundle["rooms"])} implemented rooms, {bundle["content_version"][:12]}')
