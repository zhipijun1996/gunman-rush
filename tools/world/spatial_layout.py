"""Export complete region chambers for calibration; never invent world placement."""
import copy,json
from pathlib import Path
from forest_review import build,rectangles
from preview_catalog import preview_catalog

def apply(project,root):
    source=Path(root)/'config/world/spatial_layout.json'
    if not source.exists():return
    manifest=json.loads(source.read_text())
    from spatial_adjustments import apply as apply_adjustments
    apply_adjustments(Path(root),project)
    plan=build(root=Path(root),preview=preview_catalog(root))
    lookup={r['room_id']:r for r in plan['rooms']}
    for rid,design in lookup.items():
        room=project['rooms'][rid];x,y,w,h=design['bounds']
        room.update(layer='world',origin=[x,y],bounds=[0,0,w,h],spaces=[[a-x,b-y,c,d] for a,b,c,d in rectangles(design['outline'])],layout_status='draft')
        room['spatial_source']={'kind':'spatial_draft','path':manifest['source'],'units':'world_units','status':'calibration_required'}
        room['review_label']=[design['label'][0]-x,design['label'][1]-y]
        room['purpose']=design['purpose']
        room['design_contract']={k:design[k] for k in ['stage','play','failure','exploration','space_type'] if k in design}
        for section in room['sections'].values():section['point']=copy.deepcopy(room['review_label'])
    for c in plan['connections']:
        edge=project['connections'][c['id']];seam=c['seam']
        direction=c['direction']
        opposite={'left':'right','right':'left','up':'down','down':'up'}
        for side in ['a','b']:
            ep=edge[side];room=project['rooms'][ep['room']];port=room['ports'][ep['port']]
            port.update(position=[seam[i]-room['origin'][i] for i in (0,1)],direction=direction if side=='a' else opposite[direction],landing_status='requires_room_construction')
        edge['spatial_draft']={'kind':'shared_seam','path':[seam,seam],'route_within_rooms':c['path'],'width':c['width'],'length':0}
    for port in plan['external_ports']:
        room=project['rooms'][port['room']];ep=next(v for v in room['ports'].values() if v['connection']==port['id'])
        ep.update(position=[port['point'][i]-room['origin'][i] for i in (0,1)],direction=port['direction'],landing_status='requires_room_construction')
    from regional_review import compile_plan
    cache={}
    for cluster_source in manifest.get('cluster_sources',[]):
        apply_cluster(project, compile_plan(Path(root),cluster=Path(cluster_source).stem,_cache=cache), cluster_source)
    for rid in manifest.get('replanned_rooms', []):
        room=project['rooms'][rid]
        room.update(entities={},implemented=False,authored=False,source_scene='')
        project['management'][rid]={'development':'unbuilt','provenance':'空间与路线已重排；旧房内实例不适用于新占地，须重新灰盒施工'}
    project['metadata']['spatial_draft']={'source':str(source.relative_to(root)),'status':manifest['status'],'regions':manifest['scope_regions'],'limits':manifest['review_limits']}
    project['planning']['region_programs']=copy.deepcopy(manifest.get('region_programs',{}))
    project['planning']['world_routes']=copy.deepcopy(manifest.get('world_routes',[]))
    project['planning']['review_groups']=copy.deepcopy(manifest.get('review_groups',[]))
    project['planning']['onboarding_guidance']=copy.deepcopy(manifest.get('onboarding_guidance',{}))
    project['planning']['rope_platforms']=copy.deepcopy(manifest.get('rope_platforms',[]))


def apply_cluster(project,plan,source):
    """Install only candidate coordinates; gameplay documents remain unchanged."""
    for design in plan['rooms']:
        room=project['rooms'][design['room_id']];x,y,w,h=design['bounds']
        room.update(layer='world',origin=[x,y],bounds=[0,0,w,h],spaces=[[a-x,b-y,c,d] for a,b,c,d in rectangles(design['outline'])],layout_status='draft')
        room['spatial_source']={'kind':'spatial_draft','path':source,'units':'world_units','status':'calibration_required'}
        room['review_label']=[design['label'][0]-x,design['label'][1]-y]
        room['purpose']=design['purpose']
        room['design_contract']={k:design[k] for k in ['stage','play','failure','exploration','space_type'] if k in design}
        for section in room['sections'].values():section['point']=copy.deepcopy(room['review_label'])
    opposite={'left':'right','right':'left','up':'down','down':'up'}
    def port(rid,cid,point,direction):
        r=project['rooms'][rid];p=next(p for p in r['ports'].values() if p['connection']==cid)
        p.update(position=[point[i]-r['origin'][i] for i in (0,1)],direction=direction,landing_status='requires_room_construction')
        if p['section'].startswith('entry:'):r['sections'][p['section']]['point']=p['position'][:]
    for c in plan['connections']:
        seam=c['seam'];direction=c['direction']
        port(c['a'],c['id'],seam,direction);port(c['b'],c['id'],seam,opposite[direction])
        project['connections'][c['id']]['spatial_draft']={'kind':'shared_seam','path':[seam,seam],'route_within_rooms':c['path'],'width':c['width'],'length':0}
    for c in plan['attachments']:
        edge=project['connections'][c['id']];other=edge['b']['room'] if edge['a']['room']==c['room'] else edge['a']['room'];r=project['rooms'][other];p=next(p for p in r['ports'].values() if p['connection']==c['id'])
        seam=[p['position'][i]+r['origin'][i] for i in (0,1)]
        assert seam==c['path'][0],f"Anchor drift: {c['id']}"
        port(c['room'],c['id'],seam,opposite[p['direction']]);edge['spatial_draft']={'kind':'shared_seam','path':[seam,seam],'route_within_rooms':c['path'],'width':c['width'],'length':0}
    for p in plan['external_ports']:port(p['room'],p['id'],p['point'],p['direction'])
    for t in plan['transitions']:
        edge=project['connections'][t['id']];edge['front_door']=True
        edge['spatial_draft']={'kind':t.get('kind','well_lift'),'description':t['description'],'endpoints':copy.deepcopy([t['a'],t['b']])}
        for side in ['a','b']:
            rid=t[side]['room'];r=project['rooms'][rid];p=next(p for p in r['ports'].values() if p['connection']==t['id'])
            p.update(position=[t[side]['point'][i]-r['origin'][i] for i in (0,1)],front_door=True,landing_status='requires_room_construction')
    for pending in plan.get('pending_connections',[]):
        edge=project['connections'][pending['id']]
        edge['spatial_draft']={'kind':'unresolved','reason':pending['reason'],'endpoints':[pending['a'],pending['b']]}
        for side in ['a','b']:
            endpoint=pending[side];r=project['rooms'][endpoint['room']]
            p=next(p for p in r['ports'].values() if p['connection']==pending['id'])
            p.update(position=[endpoint['point'][i]-r['origin'][i] for i in (0,1)],landing_status='unresolved')
    project['planning']['blueprints'][''.join(plan['regions'])]={'source':source,'design':plan}
