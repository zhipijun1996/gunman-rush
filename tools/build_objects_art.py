#!/usr/bin/env python3
"""AI-authored deterministic vector art, not raster image generation/editing."""
import json, math
from pathlib import Path
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
INK='#242b29'; STEEL='#535b56'; LIGHT='#a1a79a'; BRASS='#b99145'; CYAN='#79eff5'; AMBER='#ffcf6b'
records=[]
def path(d,fill='none',stroke=INK,width=3): return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>'
def circle(x,y,r,fill,stroke=INK,width=3): return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'
def rect(x,y,w,h,fill,stroke=INK,width=3,rx=4): return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'
def diamond(x,y,r,c):return path(f'M{x} {y-r} L{x+r} {y} L{x} {y+r} L{x-r} {y} Z','none',c,4)+path(f'M{x} {y-r/2} L{x+r/2} {y} L{x} {y+r/2} L{x-r/2} {y} Z','none',c,2)
def chevron(x,y,r,c):return path(f'M{x-r} {y} L{x} {y-r} L{x+r} {y} M{x-r} {y+r*.6} L{x} {y-r*.4} L{x+r} {y+r*.6}','none',c,5)
def save(group,name,w,h,body,role,anchor=None,safe=4,extra=None):
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n'
    dest=ROOT/'assets'/group/(name+'.svg');dest.write_text(svg);ET.fromstring(svg)
    rec={'id':name,'path':str(dest.relative_to(ROOT)),'width':w,'height':h,'anchor_px':anchor or [w/2,h/2],'role':role,'safe_margin_px':safe,'alpha':True,'provenance':'AI-authored SVG via tools/build_objects_art.py; original mechanical plains interpretation'}
    if extra:rec.update(extra)
    records.append(rec)
# Circular hazard: all points inside radius 60; centered pivot.
points=[]
for i in range(64):
    a=i*math.tau/64-math.pi/2;r=60 if i%4==0 else 51 if i%4==3 else 55
    points.append(f'{64+math.cos(a)*r:.3f},{64+math.sin(a)*r:.3f}')
saw=f'<polygon points="{" ".join(points)}" fill="{LIGHT}" stroke="{INK}" stroke-width="3"/>'+circle(64,64,47,STEEL)+circle(64,64,35,INK,BRASS,2)
for i in range(8):
    a=i*math.tau/8;saw+=circle(round(64+math.cos(a)*39,2),round(64+math.sin(a)*39,2),3,BRASS,INK,1)
saw+=circle(64,64,17,BRASS)+circle(64,64,10,STEEL,LIGHT,2)+circle(64,64,4,INK)
save('objects','saw_wheel',128,128,saw,'hazard',[64,64],2,{'collision_hint':{'shape':'circle','center_px':[64,64],'radius_px':60},'mirror_allowed':True})
platform=rect(4,5,248,22,STEEL)+path('M8 9 L247 9','none',LIGHT,2)+rect(15,29,226,10,BRASS)+circle(42,44,14,STEEL,BRASS)+circle(214,44,14,STEEL,BRASS)
for x in range(20,245,32):platform+=circle(x,17,3,BRASS,INK,1)
save('objects','moving_platform',256,64,platform,'standable_surface',[128,5],3,{'standable_top_y':5,'mirror_allowed':True})
for active in (False,True):
    c=AMBER if active else STEEL
    save('objects','trigger_plate_'+('active' if active else 'inactive'),96,32,rect(5,15,86,12,INK)+rect(13,7 if not active else 13,70,10,c,BRASS,2),'trigger',[48,27])
for opened in (False,True):
    b=rect(6,5,20,182,STEEL)+rect(70,5,20,182,STEEL)+rect(9,5,78,16,BRASS)
    for y in range(29,181,24):
        b+=rect(10,y,12,9,BRASS,INK,1)+rect(74,y,12,9,BRASS,INK,1)
    if not opened:
        for x in (31,45,59):b+=rect(x,22,6,160,STEEL,INK,2,1)
        b+=rect(25,86,46,10,BRASS)
    save('objects','gate_'+('open' if opened else 'closed'),96,192,b,'mechanism_gate',[48,188])
for typ,color,shape in [('shot',CYAN,diamond),('jump',AMBER,chevron)]:
    for active in (False,True):
        c=color if active else '#606e6b'
        b=circle(48,48,37,'none',c,1)+shape(48,46,25,c)
        if active:
            for x,y in [(14,24),(77,18),(78,74)]:b+=circle(x,y,2,c,'none',0)
        save('objects',typ+'_recharge_'+('active' if active else 'inactive'),96,96,b,typ+'_recharge',[48,48],8)
    save('ui',typ+'_resource',48,48,shape(24,23,16,color),typ+'_resource_icon',[24,24],5)
for active in (False,True):
    c=AMBER if active else LIGHT
    b=rect(15,85,66,8,STEEL)+rect(25,76,46,10,BRASS)+rect(35,43,26,35,STEEL)+path('M22 43 L29 24 L67 24 L74 43 Z',STEEL)+circle(48,29,11,INK,c,2)+diamond(48,29,7,c)+path('M48 17 L48 8','none',c,3)
    if active:b+=path('M29 18 Q48 -3 67 18','none',AMBER,2)
    save('objects','checkpoint_'+('active' if active else 'inactive'),96,96,b,'checkpoint',[48,93],3)
b=rect(11,146,74,10,STEEL)+rect(21,50,54,94,BRASS)+path('M21 50 Q48 8 75 50',BRASS)+rect(30,56,36,84,INK,AMBER,2)+circle(48,60,12,'none',AMBER,2)+path('M48 47 L48 77 M37 60 L59 60','none',AMBER,2)+path('M40 112 L48 103 L56 112 M48 103 L48 130','none',AMBER,3)
save('objects','end_marker',96,160,b,'level_exit',[48,156],4)
# Mobile controls preserve their design size; hit areas belong to input layer.
base=circle(64,64,59,'#242b29',LIGHT,3)
move=base+circle(64,64,24,'#68716a',LIGHT,2)
for d in ['M58 22 L64 15 L70 22 Z','M58 106 L64 113 L70 106 Z','M22 58 L15 64 L22 70 Z','M106 58 L113 64 L106 70 Z']:move+=path(d,LIGHT,'none',0)
save('ui','control_move',128,128,move,'mobile_movement_control',safe=3)
save('ui','control_aim',128,128,base+circle(64,64,22,'none',LIGHT,3)+circle(64,64,4,LIGHT,'none',0)+path('M64 25 L64 48 M64 80 L64 103 M25 64 L48 64 M80 64 L103 64','none',LIGHT,3),'mobile_aim_control',safe=3)
save('ui','control_jump',128,128,base+chevron(64,61,23,LIGHT),'mobile_jump_control',safe=3)
for name,b in [('pause',rect(21,16,7,32,LIGHT,'none',0,1)+rect(36,16,7,32,LIGHT,'none',0,1)),('restart',path('M46 24 A19 19 0 1 0 49 40','none',LIGHT,4)+path('M35 23 L47 23 L47 11','none',LIGHT,4))]:save('ui',name,64,64,circle(32,32,28,INK,LIGHT,2)+b,'menu_control',safe=3)
save('ui','selection_panel',320,192,rect(5,5,310,182,INK,BRASS,3,12)+rect(12,12,296,168,'none',STEEL,1,9),'scalable_panel',[160,96],4,{'nine_slice_margin_px':[20,20,20,20]})
save('ui','selection_card',160,192,rect(5,5,150,182,INK,LIGHT,2,10)+rect(12,12,136,168,'none',STEEL,1,7)+diamond(80,55,23,CYAN),'ability_selection_card',[80,96],4,{'resize_policy':'preserve_aspect','text_safe_rect_px':[20,90,120,75]})
for name,col in [('bar_track',INK),('bar_shot',CYAN),('bar_jump',AMBER),('bar_health','#df8973')]:save('ui',name,128,16,rect(2,2,124,12,col,LIGHT if name=='bar_track' else 'none',1,5),'resource_bar',[0,8],1,{'nine_slice_margin_px':[7,3,7,3]})
# VFX contain no gameplay timing/collision. Blend defaults are documented.
save('vfx','muzzle_flash',96,64,path('M8 32 L38 22 L27 8 L56 23 L85 32 L55 41 L29 57 L38 41 Z',AMBER,'none',0)+path('M8 32 L42 27 L70 32 L42 37 Z','#fff1c4','none',0),'shot_flash',[8,32],6)
save('vfx','projectile',64,24,path('M4 12 L46 6 L58 12 L46 18 Z',AMBER,'none',0)+path('M27 12 L52 9 L58 12 L52 15 Z','#fff8dd','none',0),'player_projectile',[52,12],4)
save('vfx','recoil_streak',96,48,path('M8 24 Q47 9 86 24 M20 34 Q46 26 69 34','none','#fff0cb',3),'recoil_feedback',[86,24],5)
save('vfx','landing_dust',128,64,path('M6 54 Q8 37 26 42 Q21 23 39 29 Q42 15 55 28 Q65 18 73 32 Q88 22 94 39 Q118 32 122 54 Z','#c7be99','none',0),'landing_dust',[64,54],5)
for name,c in [('recharge_shot',CYAN),('recharge_jump',AMBER),('checkpoint_ring',AMBER)]:save('vfx',name,96,96,circle(48,48,32,'none',c,3)+circle(48,48,22,'none',c,1),'event_ring',[48,48],12)
save('vfx','death_shard',32,48,path('M17 5 L26 27 L13 43 L6 22 Z',LIGHT,INK,1),'death_particle',[16,24],4)
save('vfx','spark',32,32,path('M16 3 L19 12 L29 16 L19 19 L16 29 L13 19 L3 16 L13 12 Z','#fff0c3','none',0),'spark_particle',[16,16],3)
fragment=ROOT/'assets/objects/manifest_fragment.json'
if fragment.exists():
    generated_ids={r['id'] for r in records}
    records.extend(r for r in json.loads(fragment.read_text()).get('assets',[]) if r['id'] not in generated_ids)
fragment.write_text(json.dumps({'schema_version':1,'pack':'plains_objects_ui_vfx','assets':records},ensure_ascii=False,indent=2)+'\n')
print('Wrote and XML-validated 35 SVG assets; preserved additional manifest candidates')
