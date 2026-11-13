"""Compile hand-authored neighboring-region drafts into shared physical spaces.

Identity and eligibility are always read from world.json. This does not install
candidate geometry into construction or mutate the playable room documents.
"""
import copy,json
from pathlib import Path
from forest_review import rectangles,overlap,build as forest_build
from spatial import room_space
from preview_catalog import preview_catalog
ROOT=Path(__file__).resolve().parents[2]

def compile_plan(root=ROOT,validate=True,cluster="underground",_cache=None):
    cache={} if _cache is None else _cache
    if cluster in cache:
        result=copy.deepcopy(cache[cluster])
        if validate:assert not result['issues'],'\n'.join(result['issues'])
        return result
    plan=json.loads((root/f'config/world/spatial_clusters/{cluster}.json').read_text())
    world=json.loads((root/'config/world/world.json').read_text())
    from spatial_adjustments import world_for_draft
    world=world_for_draft(root,world)
    identities={r['id']:r for r in world['rooms']};edges={e['id']:e for e in world['connections']}
    rooms={r['room_id']:r for r in plan['rooms']};expected={r for r in identities if r[0] in plan['regions']}
    assert set(rooms)==expected,'Missing/extra regional rooms'
    internal={e['id'] for e in edges.values() if e['a'] in rooms and e['b'] in rooms}
    transition_ids={t['id'] for t in [*plan['transitions'],*plan.get('pending_connections',[])]}
    assert internal=={e['id'] for e in plan['connections']}|{cid for cid in transition_ids if edges[cid]['a'] in rooms and edges[cid]['b'] in rooms},'Missing/extra internal edges'
    external={e['id'] for e in edges.values() if (e['a'] in rooms)!=(e['b'] in rooms)}
    assert external=={e['id'] for e in plan['external_ports']+plan['attachments']}|{cid for cid in transition_ids if (edges[cid]['a'] in rooms)!=(edges[cid]['b'] in rooms)},'Missing/extra outside ports'
    assert plan['geometry_schema']==2, 'Room outlines must own complete geometry'
    rects={rid:rectangles(r['outline']) for rid,r in rooms.items()}
    for c in plan['connections']:
        e=edges[c['id']];c.update(a=e['a'],b=e['b'],requires=e.get('requires',[[]]))
    issues=[]
    for rid,r in rooms.items():
        own=rects[rid];x=min(a[0] for a in own);y=min(a[1] for a in own);xx=max(a[0]+a[2] for a in own);yy=max(a[1]+a[3] for a in own)
        try:
            shape=room_space([[a-x,b-y,c,d] for a,b,c,d in own],[xx-x,yy-y]);r['outline']=[[a+x,b+y] for a,b in shape['outline']]
        except ValueError as e:issues.append(f'{rid}: {e}')
        r['bounds']=[x,y,xx-x,yy-y]
        source=identities[rid];r.update(name=source['name'],rewards=source['reward_ids'],rest=source['rest_point'],rift=source.get('rift_machine',False),neighbors=[])
        r['stage']='；'.join(dict.fromkeys(' / '.join('+'.join(g) or '基础' for g in i['requires']) for i in source['internal_routes'] if not i['id'].endswith(':return'))) or '基础通路；门锁沿世界资格'
        r['gates']=[{k:copy.deepcopy(i[k]) for k in ['id','from_section','to_section','requires']} for i in source['internal_routes'] if not i['id'].endswith(':return')]
        r['bosses']=[b['working_name'] for b in world['boss_plan']['bosses'] if b['physical_room']==rid]
        r['actions']=[{k:copy.deepcopy(a[k]) for k in ['id','type','grants','section_id'] if k in a} for a in world['actions'] if a.get('room_id')==rid and (a.get('type')=='ability' or a['id'].startswith(('repair_','get_lamp','get_filter','open_SC','open_s03')))]
        for e in edges.values():
            if rid in [e['a'],e['b']]:r['neighbors'].append({'id':e['id'],'room':e['b'] if e['a']==rid else e['a'],'condition':e.get('condition_text','基础通行')})
    preview=preview_catalog(root);forest=forest_build(root,preview)
    fixed={r['room_id']:rectangles(r['outline']) for r in forest['rooms']}
    fixed.update({r['id']:rectangles(r['polygon']) for r in preview['map_rooms'] if r['id'][0] not in {*plan['regions'],'F','M','S','T','Z','V'}})
    manifest=json.loads((root/'config/world/spatial_layout.json').read_text())
    for source in manifest['cluster_sources']:
        previous=Path(source).stem
        if previous==cluster:break
        fixed.update({r['room_id']:rectangles(r['outline']) for r in compile_plan(root,cluster=previous,_cache=cache)['rooms']})
    def extent(rs):
        x=min(r[0] for r in rs);y=min(r[1] for r in rs)
        return [x,y,max(r[0]+r[2] for r in rs)-x,max(r[1]+r[3] for r in rs)-y]
    items=list(rects.items())
    for i,(rid,rs) in enumerate(items):
        for other,ss in [*items[i+1:],*fixed.items()]:
            if not overlap(extent(rs),extent(ss)):continue
            pairs=[(a,b) for a in rs for b in ss if overlap(a,b)]
            if pairs:issues.append(f'Overlap {rid} / {other}: {pairs[0]}')
    for route in plan['routes']:
        for a,b in zip(route['rooms'],route['rooms'][1:]):
            assert any({e['a'],e['b']}=={a,b} for e in edges.values()),f'Invalid route {a} {b}'
    for p in plan['external_ports']:
        e=edges[p['id']];p['target']=e['b'] if e['a']==p['room'] else e['a'];p['region_name']=next(r['name'] for r in world['regions'] if r['code']==p['target'][0])
    # A coordinate match alone is insufficient: both ports must touch the
    # intended boundary and outside reservations must have approach space.
    def boundary(poly,point):
        x,y=point
        return any((a[0]==b[0]==x and min(a[1],b[1])<=y<=max(a[1],b[1])) or (a[1]==b[1]==y and min(a[0],b[0])<=x<=max(a[0],b[0])) for a,b in zip(poly,poly[1:]+poly[:1]))
    for c in plan['connections']:
        for rid in [c['a'],c['b']]:
            if not boundary(rooms[rid]['outline'],c['seam']):issues.append(f"Seam not on boundary: {c['id']} / {rid}")
    for p in plan['external_ports']:
        if not boundary(rooms[p['room']]['outline'],p['point']):issues.append(f"Outside port not on boundary: {p['id']}")
        if p['target'][0] in 'PF':continue
        x,y=p['point'];probe={'up':[x-96,y-384,192,384],'down':[x-96,y,192,384],'left':[x-384,y-96,384,192],'right':[x,y-96,384,192]}[p['direction']]
        for rid,rs in [*rects.items(),*fixed.items()]:
            if rid not in (p['room'],p['target']) and any(overlap(probe,r) for r in rs):issues.append(f"Blocked outside approach: {p['id']} / {rid}")
    for c in plan['attachments']:
        if not boundary(rooms[c['room']]['outline'],c['path'][0]):issues.append(f"Anchor not on boundary: {c['id']}")
    plan['issues']=issues
    if validate:assert not issues,'\n'.join(issues)
    cache[cluster]=copy.deepcopy(plan)
    return plan

if __name__=='__main__':
    p=compile_plan(validate=False)
    print('\n'.join(p['issues']) or f"{len(p['rooms'])} rooms; geometry passed")
