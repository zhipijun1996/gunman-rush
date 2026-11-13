"""Apply the reviewed-world spatial draft to editor data, never runtime geometry."""
import copy,json
from pathlib import Path

def apply(project,root):
    path=Path(root)/'config/world/spatial_layout.json'
    if not path.exists():return
    layout=json.loads(path.read_text())
    assert set(layout['rooms'])==set(project['rooms']), 'Spatial draft room identities differ'
    assert set(layout['connections'])==set(project['connections']), 'Spatial draft connections differ'
    for rid,design in layout['rooms'].items():
        room=project['rooms'][rid]
        if design['status']=='authored_anchor':continue
        for key in ['origin','bounds','spaces','layer']:room[key]=copy.deepcopy(design[key])
        room['layout_status']='draft'
        room['spatial_source']={'kind':'spatial_draft','path':'config/world/spatial_layout.json','units':'world_units','status':'awaiting_review'}
        for pid,port in design['ports'].items():
            room['ports'][pid].update(copy.deepcopy(port))
            # Proposed doors have no verified landing; runtime retains its source.
            room['ports'][pid]['landing_status']='requires_room_construction'
        if not room['authored']:
            largest=max(room['spaces'],key=lambda b:b[2]*b[3])
            for section in room['sections'].values():section['point']=[largest[0]+largest[2]/2,largest[1]+largest[3]/2]
    for cid,c in layout['connections'].items():project['connections'][cid]['spatial_draft']=copy.deepcopy(c)
    project['metadata']['spatial_draft']={'source':'config/world/spatial_layout.json','status':layout['status'],'limits':layout['review_limits']}
