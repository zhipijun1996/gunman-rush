"""Explicit, reviewed-room draft changes; never mutate the runtime catalog."""
import copy,json

def connections(root,world):
    """Candidate topology is explicit; formal runtime contracts remain unchanged."""
    manifest=json.loads((root/'config/world/spatial_layout.json').read_text())
    removed=manifest.get('connection_removals',{})
    rows=[copy.deepcopy(e) for e in world['connections'] if e['id'] not in removed]
    rows += copy.deepcopy(manifest.get('additional_connections',[]))
    lookup={r['id']:r for r in rows}
    for cid,change in manifest.get('connection_adjustments',{}).items():
        edge=lookup[cid]
        for key in ['a','b','a_section','b_section','requires']:
            if key in change:edge[key]=copy.deepcopy(change[key])
        if 'requires' in change:
            edge['effective_door_requires']=copy.deepcopy(change['requires'])
            edge['condition_text']='物理门条件：'+' / '.join('+'.join(g) or '基础通行' for g in change['requires'])
        edge['external']=edge['a'][0]!=edge['b'][0]
        if not edge['external']:edge['kind']='internal'
        for key in ['polyline','manual_polyline','passage_polygons','length_map_units']:
            edge.pop(key,None)
        edge['geometry_status']='世界初稿门对；按候选房形和端口共同校准'
    return rows


def world_for_draft(root,world):
    """Move an entrance's ability section with its doorway, never bypass it."""
    manifest=json.loads((root/'config/world/spatial_layout.json').read_text())
    result=copy.deepcopy(world)
    result['rooms']+=copy.deepcopy(manifest.get('additional_rooms',[]))
    rooms={r['id']:r for r in result['rooms']}
    for rid,change in manifest.get('room_identity_adjustments',{}).items():rooms[rid].update(copy.deepcopy(change))
    original={e['id']:e for e in world['connections']}
    result['connections']=connections(root,world)
    for cid,change in manifest.get('connection_adjustments',{}).items():
        edge=original[cid]
        for side in ('a','b'):
            if side not in change or change[side]==edge[side]:continue
            section=edge.get(side+'_section','main')
            if section=='main' or side+'_section' in change:continue
            old,new=rooms[edge[side]],rooms[change[side]]
            members=[r for r in old['internal_routes'] if section in (r['from_section'],r['to_section'])]
            assert all({r['from_section'],r['to_section']}<={section,'main'} for r in members),f'Complex entrance migration: {cid}'
            for entry in old['sections']:
                if entry['id']==section:new['sections'].append(copy.deepcopy(entry))
            old['sections']=[s for s in old['sections'] if s['id']!=section]
            old['internal_routes']=[r for r in old['internal_routes'] if r not in members]
            for route in members:
                route=copy.deepcopy(route)
                for key in ('id','reverse_route_id'):
                    if key in route:route[key]=route[key].replace(old['id'],new['id'])
                if 'map_marker' in route:route['map_marker']['room_id']=new['id']
                new['internal_routes'].append(route)
            for action in result['actions']:
                if action.get('room_id')==old['id'] and action.get('section_id')==section:action['room_id']=new['id']
    for cid in manifest.get('connection_removals',{}):
        edge=original[cid]
        for side in ('a','b'):
            section=edge.get(side+'_section','main');room=rooms[edge[side]]
            if section=='main':continue
            room['sections']=[s for s in room['sections'] if s['id']!=section]
            room['internal_routes']=[r for r in room['internal_routes'] if section not in (r['from_section'],r['to_section'])]
    actions={a['id']:a for a in result['actions']}
    for aid,change in manifest.get('action_adjustments',{}).items():actions[aid].update(copy.deepcopy(change))
    return result

def apply(root,project):
    manifest=json.loads((root/'config/world/spatial_layout.json').read_text())
    changed=set()
    world=json.loads((root/'config/world/world.json').read_text())
    draft=world_for_draft(root,world)
    for row in manifest.get('additional_rooms',[]):
        rid=row['id']
        template=copy.deepcopy(next(r for r in project['rooms'].values() if r['region']==row['region'] and not r['implemented']))
        template.update(id=rid,name=row['name'],purpose=row['purpose'],role=row['primary_role'],rest=False,entities={},ports={},sections={},routes={},implemented=False,authored=False,source_scene='',layout_status='draft',origin=[0,0],camera={'profile':'bounded_follow','transition':'occluded','zones':[],'links':[]})
        template['root']={'definition_id':'room.standard','definition_version':1,'component':'FixedWorldRoom','properties':{}}
        project['rooms'][rid]=template
        project['management'][rid]={'development':'unbuilt','provenance':'世界空间候选新增房，尚未施工'}
        project['planning']['rooms'][rid]={'position':None,'region':row['region']}
    for rid,change in manifest.get('room_identity_adjustments',{}).items():project['rooms'][rid].update(copy.deepcopy(change))
    originals={r['id']:r for r in world['rooms']}
    for row in draft['rooms']:
        prior=originals.get(row['id'])
        if prior and all(row[k]==prior[k] for k in ('sections','internal_routes')):continue
        room=project['rooms'][row['id']]
        room['sections']={s['id']:{**room['sections'].get(s['id'],{}),**copy.deepcopy(s),'known':True} for s in row['sections']}
        room['routes']={r['id']:{**copy.deepcopy(r),'from':r['from_section'],'to':r['to_section'],'known':True} for r in row['internal_routes']}
    for cid in manifest.get('connection_removals',{}):
        edge=project['connections'].pop(cid)
        for side in ('a','b'):
            ep=edge[side];project['rooms'][ep['room']]['ports'].pop(ep['port'])
    for row in manifest.get('additional_connections',[]):
        edge={**copy.deepcopy(row),'known':True,'front_door':False}
        for side,other in [('a','b'),('b','a')]:
            rid=row[side];pid=row['id']+':'+rid
            project['rooms'][rid]['ports'][pid]={'id':pid,'section':row.get(side+'_section','main'),'connection':row['id'],'target_room':row[other],'target_port':row['id']+':'+row[other],'position':[0,0],'direction':'right' if side=='a' else 'left','front_door':False,'landing_status':'requires_room_construction'}
            edge[side]={'room':rid,'port':pid}
        project['connections'][row['id']]=edge
    canonical={e['id']:e for e in draft['connections']}
    for cid,change in manifest.get('connection_adjustments',{}).items():
        edge=project['connections'][cid]
        moved={}
        for side in ['a','b']:
            if side in change:
                ep=edge[side]
                moved[side]=project['rooms'][ep['room']]['ports'].pop(ep['port'])
        for side,port in moved.items():
            new_room=project['rooms'][change[side]]
            port['id']=cid+':'+new_room['id'];port['section']=canonical[cid].get(side+'_section','main')
            new_room['ports'][port['id']]=port;edge[side]={'room':new_room['id'],'port':port['id']}
            changed.add(new_room['id'])
        for side,other in [('a','b'),('b','a')]:
            ep=edge[side];back=edge[other];port=project['rooms'][ep['room']]['ports'][ep['port']]
            port.update(target_room=back['room'],target_port=back['port'])
            if side+'_section' in change:port['section']=change[side+'_section']
        for key in ['a_section','b_section','requires','effective_door_requires','condition_text','external']:
            if key in canonical[cid]:edge[key]=copy.deepcopy(canonical[cid][key])
        for key in ['polyline','manual_polyline','passage_polygons','length_map_units']:edge.pop(key,None)
        edge['geometry_status']='世界初稿门对；按候选房形和端口共同校准'
    for rid in changed:
        r=project['rooms'][rid];r['layout_status']='draft'
        r['spatial_source']={'kind':'spatial_draft','path':'config/world/spatial_layout.json','units':'world_units','status':'calibration_required'}


def review_route_plans(root):
    """Current candidate journeys reuse the canonical goals with explicit edits."""
    plans=json.loads((root/'config/world/routes.json').read_text())['routes']
    edits=json.loads((root/'config/world/spatial_layout.json').read_text()).get('route_review',{})
    for plan in plans:
        for target in plan['targets']:
            if not isinstance(target,dict):continue
            for rule in edits.get('visit_replacements',[]):
                if all(target.get(k)==v for k,v in rule['match'].items()):
                    target.update(copy.deepcopy(rule['replace']))
        for rule in edits.get('before_targets',[]):
            if rule['route']==plan['id']:
                index=plan['targets'].index(rule['target'])
                plan['targets'][index:index]=rule['insert']
    return plans
