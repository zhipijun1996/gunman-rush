"""Prepare/validate schema-2 editor changes; explicit --apply writes reviewed files.

Stable-ID three-way merges preserve unrelated main changes. Room documents and
world/construction/collection owners are updated together, never generated as
another independently editable world. Does not commit, merge or publish.
"""
from pathlib import Path
import argparse,copy,hashlib,json,re,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
from build import build

MISSING=object()
def read(path):return json.loads(Path(path).read_text())
def write(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
def merge(base,draft,current,path):
    if draft==base:return copy.deepcopy(current) if current is not MISSING else MISSING
    if current==base or current==draft:return copy.deepcopy(draft) if draft is not MISSING else MISSING
    if all(isinstance(v,dict) for v in [base,draft,current]):
        out={}
        for key in base.keys()|draft.keys()|current.keys():
            value=merge(base.get(key,MISSING),draft.get(key,MISSING),current.get(key,MISSING),path+'/'+key)
            if value is not MISSING:out[key]=value
        return out
    raise ValueError('Concurrent design conflict: '+path)

def scope_for(package):
    before,after=package['base'],package['project'];scope=set(package['selected_rooms']);changed=True
    while changed:
        changed=False
        for name in ['connections','rewards','npcs']:
            for key in before.get(name,{}).keys()|after.get(name,{}).keys():
                old,new=before.get(name,{}).get(key),after.get(name,{}).get(key)
                if old==new:continue
                owners=set()
                for value in [old,new]:
                    if not value:continue
                    if name=='connections':owners.update([value['a']['room'],value['b']['room']])
                    else:owners.add(value.get('room',value.get('room_id')))
                if scope&owners and not owners<=scope:scope|=owners;changed=True
    return scope

def sections(rows):return {k:{key:value for key,value in r.items() if key!='known'} for k,r in rows.items()}
def routes(rows):
    out={}
    for key,r in rows.items():
        value={k:v for k,v in r.items() if k not in ['from','to','known','bidirectional','reverse_requires']};value.update(id=key,from_section=r.get('from',r.get('from_section')),to_section=r.get('to',r.get('to_section')),kind=r.get('kind','environment_traversal'))
        out[key]=value
        if r.get('bidirectional'):
            rev=copy.deepcopy(value);rev.update(id=key+':return',from_section=value['to_section'],to_section=value['from_section'],requires=r.get('reverse_requires',r.get('requires',[[]])));out[rev['id']]=rev
    return out

def prepare(root,package,output):
    if package.get('schema')!=2 or package.get('project',{}).get('schema')!=2:raise ValueError('Expected schema-2 change package')
    base,project=package['base'],package['project']
    commit=package.get('source',{}).get('commit','')
    if not re.fullmatch('[a-f0-9]{40}',commit):raise ValueError('Missing game baseline commit')
    if package.get('source',{}).get('repository')!='zhipijun1996/gunman-rush':raise ValueError('Change package belongs to a different game')
    output.mkdir(parents=True,exist_ok=True)
    if any(output.iterdir()):raise ValueError('Output must be empty; keep previous receipts')
    source=root/'config/world';stage=output/'candidate';shutil.copytree(source,stage/'config/world')
    world,construction,design=[read(source/name) for name in ['world.json','construction.json','collection_design.json']]
    room_rows={r['id']:r for r in world['rooms']};build_rows={r['room_id']:r for r in construction['rooms']};connection_rows={r['id']:r for r in world['connections']};pair_rows={r['edge_id']:r for r in construction['door_pairs']}
    scope=scope_for(package);changed=set();new_documents=[]
    for rid in scope:
        old=base['rooms'].get(rid);new=project['rooms'].get(rid)
        if new is None:
            if old is not None:
                if any(a.get('room_id')==rid for a in world['actions']) or any(n.get('room_id')==rid for n in world['npcs']) or build_rows[rid].get('implemented'):
                    raise ValueError('Room deletion requires relocating actions, NPCs and playable/save references first: '+rid)
                world['rooms']=[r for r in world['rooms'] if r['id']!=rid];construction['rooms']=[r for r in construction['rooms'] if r['room_id']!=rid];room_rows.pop(rid,None);build_rows.pop(rid,None)
            continue
        if not re.fullmatch(r'[A-Z]-R[A-Za-z0-9_-]+',rid):raise ValueError('Room ID is not cross-platform safe: '+rid)
        if rid not in room_rows:
            x,y=new['origin'];w,h=new['bounds'][2:];polygon=[[x/8,y/8],[(x+w)/8,y/8],[(x+w)/8,(y+h)/8],[x/8,(y+h)/8]]
            row={'id':rid,'region':new['region'],'name':new['name'],'purpose':new['purpose'],'primary_role':new.get('role','exploration'),'polygon':polygon,'map_centre':[(x+w/2)/8,(y+h/2)/8],'sections':[],'internal_routes':[],'rest_point':False,'rift_machine':False,'npc_ids':[],'reward_ids':[],'clock_actions':[],'challenge_anchors':[],'shortcut_controls':[]};room_rows[rid]=row;world['rooms'].append(row)
            c={'shape_class':'authored_union','rationale':'编辑器新房灰盒；门台和实际动作须另验','room_id':rid,'scene_ref':f'res://game/world/regions/{new["region"]}/rooms/{rid}.tscn','implemented':False,'doors':[],'entry_spawns':[],'extent':new['bounds'][2:],'space_rects':new['spaces'],'camera':new['camera'],'world_origin':new['origin'],'space_layer':new.get('layer','world')};build_rows[rid]=c;construction['rooms'].append(c)
        row,c=room_rows[rid],build_rows[rid];old=old or {}
        for field,key in [('name','name'),('purpose','purpose'),('region','region'),('role','primary_role'),('rest','rest_point')]:
            if field in new and new[field]!=old.get(field):row[key]=merge(old.get(field,MISSING),new[field],row.get(key,MISSING),f'/rooms/{rid}/{field}')
        for field,normalize in [('sections',sections),('routes',routes)]:
            if new.get(field)!=old.get(field):
                key='sections' if field=='sections' else 'internal_routes';prior={r['id']:r for r in row[key]};value=merge(normalize(old.get(field,{})),normalize(new.get(field,{})),prior,f'/rooms/{rid}/{field}');row[key]=list(value.values())
        for field,key in [('spaces','space_rects'),('camera','camera')]:
            if new.get(field)!=old.get(field):c[key]=merge(old.get(field,MISSING),new[field],c.get(key,old.get(field,MISSING)),f'/rooms/{rid}/{field}')
        if new.get('bounds')!=old.get('bounds'):c['extent']=merge(old.get('bounds',new['bounds'])[2:],new['bounds'][2:],c['extent'],f'/rooms/{rid}/bounds')
        if new.get('origin')!=old.get('origin'):c['world_origin']=merge(old.get('origin',MISSING),new['origin'],c.get('world_origin',old.get('origin',MISSING)),f'/rooms/{rid}/origin')
        if new.get('layer')!=old.get('layer'):c['space_layer']=merge(old.get('layer','world'),new['layer'],c.get('space_layer',old.get('layer','world')),f'/rooms/{rid}/layer')
        doc_path=source/'rooms'/f'{rid}.json'
        if (new['root']!=old.get('root') or new['entities']!=old.get('entities')) and (new.get('authored') or new['entities']):
            original={'schema':2,'room_id':rid,'root':old.get('root',{}),'entities':old.get('entities',{})};draft={'schema':2,'room_id':rid,'root':new['root'],'entities':new['entities']};current=read(doc_path) if doc_path.exists() else original
            document=merge(original,draft,current,'/documents/'+rid);target=stage/'config/world/rooms'/f'{rid}.json';write(target,document);changed.add(target.relative_to(stage).as_posix());new_documents.append(target)
            scene=Path(c['scene_ref'].removeprefix('res://'));script='res://game/world/regions/V/starbridge_trial_room.gd' if new['root']['component']=='StarbridgeTrialRoom' else 'res://game/world/levels/fixed_world_room.gd'
            wrapper=f'[gd_scene format=3]\n\n[ext_resource type="Script" path="{script}" id="1"]\n\n[node name="{rid}" type="Node2D"]\nscript = ExtResource("1")\ndocument_ref = "res://config/world/rooms/{rid}.json"\n';(stage/scene).parent.mkdir(parents=True,exist_ok=True);(stage/scene).write_text(wrapper)
            if not (root/scene).exists() or (root/scene).read_text()!=wrapper:changed.add(scene.as_posix())
        old_ports=old.get('ports',{});existing={d['id']:d for d in c['doors']}
        for pid,port in new['ports'].items():
            if port==old_ports.get(pid):continue
            raw=copy.deepcopy(existing.get(pid,{}));prior=old_ports.get(pid,{})
            position=merge(prior.get('position',MISSING),port['position'],raw.get('position_candidate',{}).get('local_world_units',MISSING),f'/rooms/{rid}/ports/{pid}/position')
            raw['id']=pid;raw['edge_id']=merge(prior.get('connection',MISSING),port['connection'],raw.get('edge_id',MISSING),f'/rooms/{rid}/ports/{pid}/connection');raw['position_candidate']={**raw.get('position_candidate',{}),'local_world_units':position,'normalized_uv':[(position[0]-new['bounds'][0])/new['bounds'][2],(position[1]-new['bounds'][1])/new['bounds'][3]],'opening_candidate_world_units':raw.get('position_candidate',{}).get('opening_candidate_world_units',[64,96])}
            if port.get('landing'):raw['landing_contract']=merge(prior.get('landing',MISSING),port['landing'],raw.get('landing_contract',MISSING),f'/rooms/{rid}/ports/{pid}/landing')
            elif not raw.get('landing_contract'):
                x,y=port['position'];dx,dy={'left':(64,-18),'right':(-64,-18),'up':(0,128),'down':(-96,-64)}[port['direction']];raw['landing_contract']={'id':'landing:'+pid,'section':port['section'],'incoming_mode':'walk_into_grounded_landing','safe_standing_position_world_units':[x+dx,y+dy],'entry_position_world_units':[x+dx,y+dy],'platform_is_real_collision':False,'needs_support_validation':True}
            landing=raw['landing_contract'];stand=landing['safe_standing_position_world_units'];landing.setdefault('platform_candidate_rect_world_units',[max(0,min(new['bounds'][2]-128,stand[0]-64)),stand[1]+18,128,32])
            existing[pid]=raw
        c['doors']=[existing[pid] for pid in new['ports'] if pid in existing]
        c['entry_spawns']=[{'id':'spawn:'+d['id'],'entry_door':d['id'],'section':d['landing_contract'].get('section','main'),'position_candidate_world_units':d['landing_contract']['entry_position_world_units'],'eventual_standing_position_world_units':d['landing_contract']['safe_standing_position_world_units'],'landing_contract_ref':'landing:'+d['id'],'fake_grounded_reset_forbidden':True} for d in c['doors']]
    for cid in base['connections'].keys()|project['connections'].keys():
        old,new=base['connections'].get(cid),project['connections'].get(cid)
        owners={v[k]['room'] for v in [old,new] if v for k in ['a','b']}
        directions_changed=bool(new) and any(project['rooms'][v['room']]['ports'][v['port']].get('direction')!=base['rooms'].get(v['room'],{}).get('ports',{}).get(v['port'],{}).get('direction') for v in [new['a'],new['b']])
        if not owners&scope or old==new and not directions_changed:continue
        if not new:
            connection_rows.pop(cid,None);pair_rows.pop(cid,None);continue
        value=copy.deepcopy(connection_rows.get(cid,{'kind':'editor_door_pair','geometry_status':'authored construction ports'}));draft_value={**value,'id':cid,'a':new['a']['room'],'b':new['b']['room'],'a_section':project['rooms'][new['a']['room']]['ports'][new['a']['port']]['section'],'b_section':project['rooms'][new['b']['room']]['ports'][new['b']['port']]['section'],'requires':new.get('requires',[[]]),'effective_door_requires':new.get('requires',[[]]),'direction':new.get('direction','both'),'door_ids':{new['a']['room']:new['a']['port'],new['b']['room']:new['b']['port']}}
        for field in ['a','b','direction','requires']:
            if old:
                prior=old[field]['room'] if field in ['a','b'] else old.get(field,'both' if field=='direction' else [[]]);current=value.get('effective_door_requires',value.get('requires',[[]])) if field=='requires' else value.get(field,'both' if field=='direction' else MISSING)
                # Export normalizes non-directional descriptive strings to both.
                if field=='direction' and current not in ['a_to_b','b_to_a']:current='both'
                draft_value[field]=merge(prior,draft_value[field],current,'/connections/'+cid+'/'+field)
        draft_value['effective_door_requires']=draft_value['requires'];connection_rows[cid]=draft_value
        pair=copy.deepcopy(pair_rows.get(cid,{'spatial_exception':None}));side_map={}
        for end in [new['a'],new['b']]:
            prior=base['rooms'].get(end['room'],{}).get('ports',{}).get(end['port'],{}).get('direction',MISSING)
            side_map[end['room']]=merge(prior,project['rooms'][end['room']]['ports'][end['port']]['direction'],pair.get('construction_sides',{}).get(end['room'],MISSING),'/connections/'+cid+'/sides/'+end['room'])
        pair.update(edge_id=cid,construction_sides=side_map,old_sides=side_map,normalization_required=False,connector_owner_rooms=[]);pair['front_door']=bool(new.get('front_door'));pair_rows[cid]=pair
    world['connections']=list(connection_rows.values());construction['door_pairs']=list(pair_rows.values())
    actions={a['id']:a for a in world['actions']};acquisitions={a['reward_id']:a for a in design['acquisition_contracts']}
    for key,new in project['rewards'].items():
        old=base['rewards'].get(key)
        if old==new or not {new['room'],old['room'] if old else new['room']}&scope:continue
        action=actions.get(new['action_id']) or new.get('action')
        if not action:raise ValueError('Reward definition missing: '+key)
        if old and new['action_id']!=old['action_id']:raise ValueError('Permanent reward receipt identity is immutable: '+key)
        action=copy.deepcopy(action)
        for field,target,default in [('room','room_id',MISSING),('section','section_id','main'),('requires','requires',[[]])]:
            action[target]=merge((old or {}).get(field,default),new.get(field,default),action.get(target,default),'/rewards/'+key+'/'+field)
        actions[action['id']]=action
        if new.get('type')!=(old or {}).get('type') and new.get('type')!=action.get('type'):
            if new.get('goal') or action.get('type') in ['ability','equipment'] or new['type'] in ['ability','equipment']:raise ValueError('Unique reward type cannot be converted: '+key)
            template=next((a for a in actions.values() if a.get('type')==new['type'] and a.get('inventory_grants')),None)
            if not template:raise ValueError('Unregistered reward type: '+new['type'])
            action.update(type=new['type'],inventory_grants=copy.deepcopy(template['inventory_grants']))
        quantity=int(new.get('quantity',1))
        if quantity!=int((old or {}).get('quantity',1)) or old is None:
            if len(action.get('inventory_grants',{}))!=1:raise ValueError('Reward is not a single stackable inventory type: '+key)
            action['inventory_grants']={k:quantity for k in action['inventory_grants']}
            action['quantity']=quantity
        if key in acquisitions:
            acquisitions[key].update(room_id=new['room'],section_id=new.get('section','main'),requires=new.get('requires',[[]]),category=new['type'])
            for field in ['challenge','approach_cue','approach_route','return_path','failure_return','primary_experience']:
                if field in new:acquisitions[key][field]=new[field]
        elif not new.get('goal'):
            record={**new,'reward_id':key,'room_id':new['room'],'section_id':new.get('section','main'),'source_channel':'map','category':new['type'],'canonical_source_ref':f'collectibles.editor_sources[id={key}]','status':'editor_graybox_pending_experience_review'};world['collectibles'].setdefault('editor_sources',[]).append(copy.deepcopy(record));acquisitions[key]=record
        def relocate(v):
            if isinstance(v,dict):
                if v.get('reward_id',v.get('id'))==key and 'room_id' in v:
                    v.update(room_id=new['room'],physical_room=new['room'],section_id=new.get('section','main'),region=room_rows[new['room']]['region'])
                for child in v.values():relocate(child)
            elif isinstance(v,list):
                for child in v:relocate(child)
        for name in ['collectibles','important_markers','weapon_major_rewards','clock_repairs']:relocate(world.get(name,{}))
        if old and old['room']!=new['room'] and old['room'] in room_rows:room_rows[old['room']]['reward_ids']=[r for r in room_rows[old['room']].get('reward_ids',[]) if r!=key]
        if key not in room_rows[new['room']].get('reward_ids',[]):room_rows[new['room']].setdefault('reward_ids',[]).append(key)
    world['actions']=list(actions.values());design['acquisition_contracts']=list(acquisitions.values())
    for key,old in base['rewards'].items():
        if key not in project['rewards'] and old['room'] in scope:raise ValueError('Permanent reward removal requires an explicit receipt retirement migration: '+key)
    for key,npc in project.get('npcs',{}).items():
        old=base.get('npcs',{}).get(key)
        if npc==old or npc['room_id'] not in scope and (not old or old['room_id'] not in scope):continue
        current=next((n for n in world['npcs'] if n['id']==key),None)
        merged=merge({k:v for k,v in (old or {}).items() if k!='host'},{k:v for k,v in npc.items() if k!='host'},current or {},'/npcs/'+key)
        if current:current.clear();current.update(merged)
        else:world['npcs'].append(merged)
    for key,npc in base.get('npcs',{}).items():
        if key not in project.get('npcs',{}) and npc['room_id'] in scope:raise ValueError('NPC retirement requires relocating its services and story references first: '+key)
    for row in world['actions']:
        npc=next((n for n in world['npcs'] if n['id']==row.get('service_npc')),None)
        if npc:row.update(room_id=npc['room_id'],section_id=npc.get('section_id','main'))
    for key in ['rooms','room_connections','connections','npcs','sections','internal_directed_routes']:
        value={'rooms':len(world['rooms']),'room_connections':len(world['connections']),'connections':len(world['connections']),'npcs':len(world['npcs']),'sections':sum(len(r.get('sections',[])) for r in world['rooms']),'internal_directed_routes':sum(len(r.get('internal_routes',[])) for r in world['rooms'])}[key]
        world.setdefault('counts',{})[key]=value
    for name,value in [('world.json',world),('construction.json',construction),('collection_design.json',design)]:
        if value!=read(source/name):write(stage/'config/world'/name,value);changed.add('config/world/'+name)
    collections=read(source/'collections.json');collections['canonical_reference']['sha256']=digest(stage/'config/world/world.json')
    if collections!=read(source/'collections.json'):write(stage/'config/world/collections.json',collections);changed.add('config/world/collections.json')
    for r in construction['rooms']:
        relative=Path(r['scene_ref'].removeprefix('res://'))
        if (root/relative).exists() and not (stage/relative).exists():(stage/relative).parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(root/relative,stage/relative)
    ui=root/'game/presentation/ui/world'
    if ui.exists():shutil.copytree(ui,stage/'game/presentation/ui/world')
    _,runtime=build(stage)
    result={'schema':2,'status':'prepared','source_commit':commit,'revision':project['revision'],'rooms':sorted(scope),'content_version':runtime['content_version'],'actual_controller_playtest':False,'changes':[{'path':name,'sha256':digest(stage/name),'previous_sha256':digest(root/name)} for name in sorted(changed)],'candidate':str(stage)}
    write(output/'receipt.json',result);return result

def publish(root,receipt):
    stage=Path(receipt['candidate']);backups={}
    for change in receipt['changes']:
        if digest(root/change['path'])!=change['previous_sha256'] or digest(stage/change['path'])!=change['sha256']:raise ValueError('Source changed after preparation: '+change['path'])
    try:
        for change in receipt['changes']:
            target=root/change['path'];backups[target]=target.read_bytes() if target.exists() else None;target.parent.mkdir(parents=True,exist_ok=True);temporary=target.with_name(target.name+'.editor-tmp');temporary.write_bytes((stage/change['path']).read_bytes());temporary.replace(target)
        _,runtime=build(root)
        if runtime['content_version']!=receipt['content_version']:raise ValueError('Published source differs from prepared candidate')
    except BaseException:
        for target,data in backups.items():
            if data is None:target.unlink(missing_ok=True)
            else:target.write_bytes(data)
        build(root);raise
    receipt['status']='applied';return receipt

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('package',type=Path);p.add_argument('--output',type=Path,required=True);p.add_argument('--apply',action='store_true');a=p.parse_args();receipt=prepare(ROOT,read(a.package),a.output)
    if a.apply:receipt=publish(ROOT,receipt);write(a.output/'receipt.json',receipt)
    print(json.dumps(receipt,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
