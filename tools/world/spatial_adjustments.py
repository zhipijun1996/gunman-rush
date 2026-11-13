"""Explicit, reviewed-room draft changes; never mutate the runtime catalog."""
import copy,json
from spatial import room_space

def designs(root):
    manifest=json.loads((root/'config/world/spatial_layout.json').read_text())
    result={}
    for rid,row in manifest.get('room_adjustments',{}).items():
        spaces=row['spaces'];x=min(b[0] for b in spaces);y=min(b[1] for b in spaces)
        w=max(b[0]+b[2] for b in spaces)-x;h=max(b[1]+b[3] for b in spaces)-y
        shape=room_space([[a-x,b-y,c,d] for a,b,c,d in spaces],[w,h])
        result[rid]={**row,'origin':[x,y],'bounds':[0,0,w,h],'outline':[[a+x,b+y] for a,b in shape['outline']]}
    return result

def preview(root,catalog):
    catalog=copy.deepcopy(catalog)
    changes=designs(root)
    for row in catalog['map_rooms']:
        if row['id'] in changes:
            d=changes[row['id']];row['polygon']=d['outline']
    return catalog

def apply(root,project):
    from forest_review import rectangles
    manifest=json.loads((root/'config/world/spatial_layout.json').read_text())
    changed=set()
    for rid,d in designs(root).items():
        r=project['rooms'][rid];old=r['origin'];x,y=d['origin']
        # Unchanged ports keep their world anchor when the room origin moves.
        for p in r['ports'].values():p['position']=[p['position'][i]+old[i]-d['origin'][i] for i in (0,1)]
        r.update(origin=d['origin'],bounds=d['bounds'],spaces=[[a-x,b-y,c,e] for a,b,c,e in rectangles(d['outline'])],purpose=d['purpose'],review_label=[d['label'][0]-x,d['label'][1]-y])
        for section in r['sections'].values():section['point']=r['review_label'][:]
        for p in r['ports'].values():
            if p['section'].startswith('entry:'):r['sections'][p['section']]['point']=p['position'][:]
        r['design_contract']={'stage':'地图候选，正式控制器未验证','play':d['play'],'failure':'门口先给稳定岸；具体落点随灰盒校准。','exploration':'连接、奖励与能力资格保持。'}
        changed.add(rid)
    for cid,change in manifest.get('port_adjustments',{}).items():
        edge=project['connections'][cid]
        for side in ['a','b']:
            ep=edge[side];rid=ep['room']
            if 'room' in change and change['room']!=rid:continue
            r=project['rooms'][rid];p=r['ports'][ep['port']]
            p.update(position=[change['point'][i]-r['origin'][i] for i in (0,1)],direction=change.get('direction') or change['directions'][rid],landing_status='requires_room_construction')
            if p['section'].startswith('entry:'):r['sections'][p['section']]['point']=p['position'][:]
            changed.add(rid)
        if 'room' not in change:edge['spatial_draft']={'kind':'shared_seam','path':[change['point'],change['point']],'length':0}
    for rid in changed:
        r=project['rooms'][rid];r['layout_status']='draft'
        r['spatial_source']={'kind':'spatial_draft','path':'config/world/spatial_layout.json','units':'world_units','status':'calibration_required'}
