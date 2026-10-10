#!/usr/bin/env python3
"""Generate AI-authored vector parallax delivery assets. No raster image editing."""
import json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/backgrounds/plains'
W,H=1920,1080

def svg(body,defs=''):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}"><defs>{defs}</defs>{body}</svg>\n'

def ridge(base,a,b,fill,phase=0):
    points=[]
    for x in range(0,W+1,12):
        y=base+a*math.cos(2*math.pi*x/W+phase)+b*math.sin(6*math.pi*x/W)
        points.append(f'{x},{y:.3f}')
    return f'<path d="M {" L ".join(points)} L {W},{H} L 0,{H} Z" fill="{fill}"/>'

OUT.mkdir(parents=True,exist_ok=True)
sky_defs='<linearGradient id="sky" x2="0" y2="1"><stop stop-color="#759db7"/><stop offset=".58" stop-color="#bdced0"/><stop offset="1" stop-color="#e1ddba"/></linearGradient>'
cloud=''
# Soft long shapes with wrapped copies guarantee horizontal repetition.
for cx,cy,s in [(160,180,1),(760,110,.8),(1450,260,1.2)]:
    for offset in [-W,0,W]:
        cloud+=f'<g transform="translate({cx+offset} {cy}) scale({s})" fill="#eef0df" opacity=".28"><ellipse rx="230" ry="31"/><ellipse cx="-62" cy="-18" rx="92" ry="42"/><ellipse cx="65" cy="-13" rx="110" ry="35"/></g>'
files={'plains_sky.svg':svg('<rect width="1920" height="1080" fill="url(#sky)"/>'+cloud,sky_defs)}
files['plains_far_hills.svg']=svg(ridge(560,70,24,'#9bb2b1')+ridge(660,60,31,'#88a3a0',1)+ridge(756,40,22,'#7d9990',2))
files['plains_meadow.svg']=svg(ridge(850,48,22,'#8d9f7a',.4)+ridge(968,30,16,'#7c9069',1.7)+ridge(1030,12,8,'#71875f',2))
ruins=''
for x,y,scale in [(365,858,.8),(1120,900,.65),(1510,935,.5)]:
    ruins+=f'<g transform="translate({x} {y}) scale({scale})" fill="#83958a" stroke="#a2ae97" stroke-width="3" opacity=".48"><path d="M -20,0 L -14,-116 L 8,-125 L 21,0 Z"/><path d="M -26,-116 L 16,-125 L 18,-139 L 4,-139 L 4,-133 L -6,-130 L -6,-140 L -22,-135 Z"/><path d="M 0,-104 L -66,-153 L -75,-142 L -8,-94 L 44,-33 L 54,-43 Z"/><path d="M -2,-101 L 49,-165 L 61,-157 L 8,-94 L -42,-35 L -53,-43 Z"/><circle cy="-101" r="9" fill="#b0b8a0"/></g>'
ruins+='<g fill="#899a8c" opacity=".42"><path fill-rule="evenodd" d="M 650,945 L 650,816 Q 719,735 788,816 L 788,945 L 762,945 L 762,831 Q 719,782 676,831 L 676,945 Z"/><path d="M 642,816 L 660,802 L 675,809 L 668,832 L 645,830 Z M 759,796 L 777,784 L 793,806 L 786,830 L 768,823 Z"/><path d="M 1730,970 L 1733,847 L 1754,840 L 1757,970 Z M 1800,978 L 1804,885 L 1825,881 L 1830,978 Z"/></g>'
files['plains_distant_ruins.svg']=svg(ruins)
for name,content in files.items():
    (OUT/name).write_text(content)
ratios=[.04,.12,.22,.28]
manifest={'schema_version':1,'biome':'plains','canvas':[W,H],'layers':[]}
for i,(name,_) in enumerate(files.items()):
    manifest['layers'].append({'id':name.removesuffix('.svg'),'path':f'assets/backgrounds/plains/{name}','size':[W,H],'scroll_scale':[ratios[i],0.0],'repeat_size':[W,0],'collision':False,'z_index':-40+i,'anchor':[0,0],'alpha':i!=0,'generation':'ai_authored_vector_script','gameplay_random_stream':False})
(OUT/'manifest_fragment.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Wrote {len(files)} SVG layers and manifest fragment')
