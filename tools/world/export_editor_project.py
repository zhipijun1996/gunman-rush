"""The game's authoritative schema-3 world export, shared by web and native editors."""
from pathlib import Path
import argparse,copy,hashlib,json,subprocess
from preview_catalog import preview_catalog
from forest_review import build as forest_blueprint
from spatial_layout import apply as apply_spatial_layout
ROOT=Path(__file__).resolve().parents[2]
def load(path):return json.loads(path.read_text())
def sha(value):return hashlib.sha256(json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def export(root=ROOT, spatial_draft=False):
    source=root/'config/world';world=load(source/'world.json');construction=load(source/'construction.json');contracts=load(root/'build/world/contracts.json');runtime=load(root/'build/world/runtime.json');catalog=load(root/'build/editor/catalog.json')
    p={'schema':3,'id':'gunman-rush-world','revision':0,'source':{'repository':'zhipijun1996/gunman-rush','commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'content_version':runtime['content_version'],'protocol':3,'motion_hash':sha(runtime['player']),'catalog_hash':sha(catalog)},'rooms':{},'connections':{},'rewards':{},'npcs':{},'catalog':catalog,'management':{},'locks':[],'metadata':{'name':'失序之钟 · 世界工坊','start':{'room':world['start_room'],'section':world.get('start_section','main')},'initial_tokens':world.get('initial_tokens',[])}}
    preview=preview_catalog(root)
    p['planning']={'source':'config/world/world.json','coordinate_frame':'macro_topology_not_world_units','regions':[{k:copy.deepcopy(r[k]) for k in ['id','code','name','pos','color','play'] if k in r} for r in world['regions']],'rooms':{r['id']:{'position':r.get('map_centre'),'region':r['region']} for r in world['rooms']},'blueprints':{'F':{'source':'game/world/regions/F/room_design.json','design':forest_blueprint(root,preview=preview)}}}
    p['runtime_defaults']={k:copy.deepcopy(runtime[k]) for k in ['player','demo_services','ui_texts','npcs','runtime_rules','collection_rules','gear_milestones','traveler_story','start'] if k in runtime}
    maps={r['id']:r for r in preview['map_rooms']};cs={r['room_id']:r for r in construction['rooms']};rs={r['room_id']:r for r in contracts['rooms']};main_component=maps[world['start_room']]['map_component']
    for r in world['rooms']:
        rid=r['id'];c=cs[rid];rt=rs[rid];mapped=maps.get(rid);doc_path=source/'rooms'/f'{rid}.json';doc=load(root/'build/editor/rooms'/f'{rid}.json') if doc_path.exists() else None
        bounds=rt['world_geometry']['bounds_world_units'];origin=mapped['origin'] if mapped else c.get('world_origin',[0,0])
        room={'id':rid,'region':r['region'],'name':r['name'],'purpose':r['purpose'],'role':r['primary_role'],'rest':bool(r.get('rest_point')),'origin':origin,'layer':mapped['map_component'] if mapped and mapped['map_component']!=main_component else c.get('space_layer','world'),'bounds':bounds,'spaces':c.get('space_rects',[bounds]),'sections':{s['id']:{**copy.deepcopy(s),'known':True} for s in r.get('sections',[{'id':'main','name':'主体'}])},'routes':{route['id']:{**copy.deepcopy(route),'from':route['from_section'],'to':route['to_section'],'known':True} for route in r.get('internal_routes',[])},'ports':{},'entities':copy.deepcopy(doc['entities']) if doc else {},'root':copy.deepcopy(doc['root']) if doc else {'definition_id':'room.standard','definition_version':1,'component':'FixedWorldRoom','properties':{}},'implemented':bool(c.get('implemented')),'authored':doc is not None,'layout_status':'calibrated' if mapped else 'planned','camera':c['camera'],'source_scene':c['scene_ref']}
        room['spatial_source']={'kind':'calibrated' if mapped else 'explicit' if 'world_origin' in c else 'unplaced','path':'config/world/construction.json','units':'world_units'}
        raw_doors={d['id']:d for d in c['doors']}
        for door in rt['doors']:
            raw=raw_doors.get(door['id'],door)
            room['ports'][door['id']]={'id':door['id'],'section':door.get('section','main'),'position':raw['position_candidate']['local_world_units'],'direction':door['direction'],'landing':raw.get('landing_contract',door['landing_contract']),'target_room':door['target_room'],'target_port':door['target_door_id'],'connection':door['edge_id'],'front_door':bool(door.get('front_door'))}
        p['rooms'][rid]=room;p['management'][rid]={'development':'developed' if doc else 'unbuilt','provenance':'主游戏静态房间，未据此推定初审' if doc else '世界规划'}
    for c in world['connections']:
        a,b=p['rooms'][c['a']],p['rooms'][c['b']];ap=next(port for port in a['ports'].values() if port['connection']==c['id']);bp=next(port for port in b['ports'].values() if port['connection']==c['id'])
        p['connections'][c['id']]={**copy.deepcopy(c),'a':{'room':a['id'],'port':ap['id']},'b':{'room':b['id'],'port':bp['id']},'requires':c.get('effective_door_requires',c.get('requires',[[]])),'direction':c.get('direction','both') if c.get('direction') in ['a_to_b','b_to_a'] else 'both','known':True,'front_door':ap['front_door'] or bp['front_door']}
    for room in p['rooms'].values():
        for section in room['sections'].values():
            volume=next((v for v in room['root']['properties'].get('section_volumes',[]) if v['id']==section['id']),None)
            if volume:section.setdefault('bounds',volume['bounds'])
            doors=[d for d in room['ports'].values() if d['section']==section['id']]
            section.setdefault('point',doors[0]['position'] if doors else [room['bounds'][0]+room['bounds'][2]/2,room['bounds'][1]+room['bounds'][3]/2])
    design=load(source/'collection_design.json');actions={a['id']:a for a in world['actions']}
    for reward in design['acquisition_contracts']:
        key=reward['reward_id'];action=next((a for a in actions.values() if a.get('reward_id')==key or a['id']=='pickup_'+key),None);action_id=action['id'] if action else 'pickup_'+key
        host=next((e['id'] for e in p['rooms'][reward['room_id']]['entities'].values() if e['properties'].get('action_id',e['properties'].get('parameters',{}).get('reward_action'))==action_id),None)
        p['rewards'][key]={**copy.deepcopy(reward),'id':key,'room':reward['room_id'],'section':reward.get('section_id','main'),'type':action.get('type') if action else reward.get('category','collectible'),'action_id':action_id,'host':host,'physical':host is not None,'quantity':(action or {}).get('quantity',next(iter(action['inventory_grants'].values())) if action and len(action.get('inventory_grants',{}))==1 else 1),'requires':reward.get('requires',[[]])}
    clock_ids={c['action_id'] for c in world['clock_repairs']}
    for action in actions.values():
        key=action.get('reward_id',action['id'])
        if action.get('type')!='ability' and action['id'] not in clock_ids or key in p['rewards']:continue
        room=p['rooms'][action['room_id']];host=next((e['id'] for e in room['entities'].values() if e['properties'].get('action_id',e['properties'].get('parameters',{}).get('reward_action'))==action['id']),None);extra={}
        p['rewards'][key]={'id':key,'action_id':action['id'],'room':room['id'],'section':action.get('section_id','main'),'type':action['type'],'quantity':1,'requires':action.get('requires',[[]]),'host':host,'physical':host is not None,'unique':True,'goal':True,**extra}
    for n in world['npcs']:
        host=next((e['id'] for e in p['rooms'][n['room_id']]['entities'].values() if e['component']=='WorldNpc' and e['properties'].get('npc_id')==n['id']),None);p['npcs'][n['id']]={**copy.deepcopy(n),'host':host}
    if spatial_draft:apply_spatial_layout(p,root)
    if spatial_draft:
        from spatial_adjustments import world_for_draft
        world=world_for_draft(root,world)
        draft_actions={a['id']:a for a in world['actions']}
        for reward in p['rewards'].values():
            action=draft_actions.get(reward['action_id'])
            if action:
                reward.update(room=action['room_id'],section=action.get('section_id','main'),requires=copy.deepcopy(action.get('requires',[[]])))
                room=p['rooms'][reward['room']]
                host=next((e['id'] for e in room['entities'].values() if e['properties'].get('action_id',e['properties'].get('parameters',{}).get('reward_action'))==action['id']),None)
                reward.update(host=host,physical=host is not None)
        for npc in p['npcs'].values():
            if npc.get('host') not in p['rooms'][npc['room_id']]['entities']:npc['host']=None
    p['catalog']['actions']=copy.deepcopy(world['actions']);p['catalog']['behavior_source']=p['source']['commit'];p['source']['document_hash']=sha(p['rooms'])
    native=root/'build/editor-native/manifest.json'
    if native.exists():
        meta=load(native)
        if meta['content_version']==runtime['content_version']:p['source']['behavior_hash']=meta.get('behavior_hash');p['native_runtime']=meta
    return p

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=ROOT/'build/editor/project.json');parser.add_argument('--spatial-draft',action='store_true',help='Export the explicit world layout proposal for review, not runtime geometry');a=parser.parse_args();project=export(spatial_draft=a.spatial_draft);a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(project,ensure_ascii=False,separators=(',',':'))+'\n');print(json.dumps({'rooms':len(project['rooms']),'connections':len(project['connections']),'rewards_and_goals':len(project['rewards']),'authored':sum(r['authored'] for r in project['rooms'].values()),'output':str(a.output)},ensure_ascii=False))
if __name__=='__main__':main()
