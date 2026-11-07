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


def navigation_geometry(rooms, anchor):
    """Preserve actual room scale; survey links connect physical door endpoints."""
    if rooms and all(r['world_geometry'].get('map_origin') is not None for r in rooms.values()):
        # A survey chart: authored rooms retain their true scale, while explicit
        # drawn links express transitions. The macro illustration is not collision.
        result={}
        for key, row in rooms.items():
            x,y=row['world_geometry']['map_origin']; _,_,w,h=row['world_geometry']['bounds_world_units']
            for i,a in enumerate(row['doors']):
                for b in row['doors'][i+1:]:
                    if a['direction']==b['direction'] and math.dist(a['position_candidate']['local_world_units'],b['position_candidate']['local_world_units'])<192:
                        raise ValueError('Crowded physical exits: '+key)
            result[key]={'origin':[x,y],'polygon':[[x,y],[x+w,y],[x+w,y+h],[x,y+h]],'map_centre':[x+w/2,y+h/2],'projection':'survey_with_explicit_connections'}
        for a,first in result.items():
            for b,second in result.items():
                if a>=b:continue
                x,y=first['origin'];xx,yy=second['origin'];w,h=rooms[a]['world_geometry']['bounds_world_units'][2:];ww,hh=rooms[b]['world_geometry']['bounds_world_units'][2:]
                if min(x+w,xx+ww)>max(x,xx) and min(y+h,yy+hh)>max(y,yy):raise ValueError('Room map envelopes overlap: '+a+'/'+b)
        reachable={anchor};pending=[anchor]
        while pending:
            for door in rooms[pending.pop()]['doors']:
                target=door['target_room']
                if target in rooms and target not in reachable:reachable.add(target);pending.append(target)
        if reachable!=set(rooms):raise ValueError('Implemented rooms need a connected authored map')
        return result
    origins = {anchor: (0.0, 0.0)}
    pending = [anchor]
    while pending:
        source = pending.pop(0)
        row = rooms[source]
        exposed = [d for d in row['doors'] if d['target_room'] in rooms]
        for i, first in enumerate(exposed):
            for second in exposed[i+1:]:
                if first['direction'] == second['direction']:
                    a, b = first['position_candidate']['local_world_units'], second['position_candidate']['local_world_units']
                    if sum((a[n]-b[n])**2 for n in (0,1)) < 192**2:
                        raise ValueError('Crowded physical exits: '+source)
        for door in exposed:
            target = door['target_room']
            paired = next(d for d in rooms[target]['doors'] if d['id'] == door['target_door_id'])
            a, b = door['position_candidate']['local_world_units'], paired['position_candidate']['local_world_units']
            proposed = tuple(origins[source][n] + a[n] - b[n] for n in (0,1))
            if target in origins:
                if any(abs(proposed[n]-origins[target][n]) > .01 for n in (0,1)):
                    raise ValueError('Room map seam conflicts: '+door['id'])
            else:
                origins[target] = proposed
                pending.append(target)
    if len(origins) != len(rooms):
        raise ValueError('Implemented rooms need a connected authored map')
    result = {}
    for key, origin in origins.items():
        _, _, w, h = rooms[key]['world_geometry']['bounds_world_units']
        x, y = origin
        result[key] = {'polygon': [[x,y],[x+w,y],[x+w,y+h],[x,y+h]], 'map_centre':[x+w/2,y+h/2], 'origin':[x,y]}
    for a, first in result.items():
        for b, second in result.items():
            if a >= b: continue
            x1,y1=first['origin']; x2,y2=second['origin']
            _,_,w1,h1=rooms[a]['world_geometry']['bounds_world_units']; _,_,w2,h2=rooms[b]['world_geometry']['bounds_world_units']
            if min(x1+w1,x2+w2)>max(x1,x2)+.01 and min(y1+h1,y2+h2)>max(y1,y2)+.01:
                raise ValueError('Room map envelopes overlap: '+a+'/'+b)
    return result


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
    layouts = navigation_geometry({r['room_id']:r for r in contracts['rooms'] if r['room_id'] in implemented}, contracts['initial_state']['room'])
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
