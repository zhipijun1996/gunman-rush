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
        room.update(origin=[x,y],bounds=[0,0,w,h],spaces=[[a-x,b-y,c,d] for a,b,c,d in rectangles(design['outline'])],layout_status='draft')
        room['spatial_source']={'kind':'spatial_draft','path':manifest['source'],'units':'world_units','status':'calibration_required'}
        room['review_label']=[design['label'][0]-x,design['label'][1]-y]
        room['purpose']=design['purpose']
        room['design_contract']={k:design[k] for k in ['stage','play','failure','exploration']}
        for section in room['sections'].values():section['point']=copy.deepcopy(room['review_label'])
    for c in plan['connections']:
        edge=project['connections'][c['id']];seam=c['seam']
        path=c['path'];horizontal=any(a[1]==b[1]==seam[1] and min(a[0],b[0])<=seam[0]<=max(a[0],b[0]) for a,b in zip(path,path[1:]))
        # The segment through the seam defines its normals, not the room centre.
        seg=next((a,b) for a,b in zip(path,path[1:]) if min(a[0],b[0])<=seam[0]<=max(a[0],b[0]) and min(a[1],b[1])<=seam[1]<=max(a[1],b[1]))
        direction=('right' if seg[1][0]>seg[0][0] else 'left') if horizontal else ('down' if seg[1][1]>seg[0][1] else 'up')
        opposite={'left':'right','right':'left','up':'down','down':'up'}
        for side in ['a','b']:
            ep=edge[side];room=project['rooms'][ep['room']];port=room['ports'][ep['port']]
            port.update(position=[seam[i]-room['origin'][i] for i in (0,1)],direction=direction if side=='a' else opposite[direction],landing_status='requires_room_construction')
        edge['spatial_draft']={'kind':'shared_seam','path':[seam,seam],'route_within_rooms':c['path'],'width':c['width'],'length':0}
    for port in plan['external_ports']:
        room=project['rooms'][port['room']];ep=next(v for v in room['ports'].values() if v['connection']==port['id'])
        ep.update(position=[port['point'][i]-room['origin'][i] for i in (0,1)],direction=port['direction'],landing_status='requires_room_construction')
    from regional_review import compile_plan
    for cluster_source in manifest.get('cluster_sources',[]):
        apply_cluster(project, compile_plan(Path(root),cluster=Path(cluster_source).stem), cluster_source)
    project['metadata']['spatial_draft']={'source':str(source.relative_to(root)),'status':manifest['status'],'regions':manifest['scope_regions'],'limits':manifest['review_limits']}


def apply_cluster(project,plan,source):
    """Install only candidate coordinates; gameplay documents remain unchanged."""
    for design in plan['rooms']:
        room=project['rooms'][design['room_id']];x,y,w,h=design['bounds']
        room.update(origin=[x,y],bounds=[0,0,w,h],spaces=[[a-x,b-y,c,d] for a,b,c,d in rectangles(design['outline'])],layout_status='draft')
        room['spatial_source']={'kind':'spatial_draft','path':source,'units':'world_units','status':'calibration_required'}
        room['review_label']=[design['label'][0]-x,design['label'][1]-y]
        room['purpose']=design['purpose']
        room['design_contract']={k:design[k] for k in ['stage','play','failure','exploration']}
        for section in room['sections'].values():section['point']=copy.deepcopy(room['review_label'])
    opposite={'left':'right','right':'left','up':'down','down':'up'}
    def port(rid,cid,point,direction):
        r=project['rooms'][rid];p=next(p for p in r['ports'].values() if p['connection']==cid)
        p.update(position=[point[i]-r['origin'][i] for i in (0,1)],direction=direction,landing_status='requires_room_construction')
        if p['section'].startswith('entry:'):r['sections'][p['section']]['point']=p['position'][:]
    for c in plan['connections']:
        seam=c['seam'];a,b=next((a,b) for a,b in zip(c['path'],c['path'][1:]) if min(a[0],b[0])<=seam[0]<=max(a[0],b[0]) and min(a[1],b[1])<=seam[1]<=max(a[1],b[1]))
        direction=('right' if b[0]>a[0] else 'left') if a[1]==b[1] else ('down' if b[1]>a[1] else 'up')
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
    project['planning']['blueprints'][''.join(plan['regions'])]={'source':source,'design':plan}
