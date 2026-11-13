"""Export complete region chambers for calibration; never invent world placement."""
import copy,json
from pathlib import Path
from forest_review import build,rectangles
from preview_catalog import preview_catalog

def apply(project,root):
    source=Path(root)/'config/world/spatial_layout.json'
    if not source.exists():return
    manifest=json.loads(source.read_text())
    assert manifest['scope_regions']==['F']
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
    project['metadata']['spatial_draft']={'source':str(source.relative_to(root)),'status':manifest['status'],'regions':['F'],'limits':manifest['review_limits']}
