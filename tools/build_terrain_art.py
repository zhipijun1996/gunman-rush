#!/usr/bin/env python3
"""Deterministic plains vector art; stdlib only, no gameplay changes."""
from pathlib import Path
import json, random, hashlib
ROOT=Path(__file__).resolve().parents[1]
records=[]
DEFS='''<defs><linearGradient id="rock" x2=".2" y2="1"><stop stop-color="#72776a"/><stop offset=".5" stop-color="#4b514a"/><stop offset="1" stop-color="#313a36"/></linearGradient><linearGradient id="grass" x2="0" y2="1"><stop stop-color="#d7cc73"/><stop offset=".35" stop-color="#8f9f4f"/><stop offset="1" stop-color="#4f653a"/></linearGradient><linearGradient id="metal" x2="0" y2="1"><stop stop-color="#958467"/><stop offset=".5" stop-color="#494539"/><stop offset="1" stop-color="#302f28"/></linearGradient></defs>'''
def save(group,name,w,h,body,anchor,**meta):
 p=ROOT/'assets'/group/'plains'/f'{name}.svg'
 data=f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{DEFS}{body}</svg>\n'
 p.write_text(data)
 records.append(dict(id=f'plains_{name}',path=str(p.relative_to(ROOT)),size_px=[w,h],logical_size=[w/2,h/2],anchor_px=anchor,render_scale=.5,collision=meta.pop('collision','defined_by_gameplay_geometry'),sha256=hashlib.sha256(data.encode()).hexdigest(),**meta))
def rock(seed):
 r=random.Random(seed); s='<path d="M0 16H128V128H0Z" fill="#50594d"/>'
 # Guaranteed border field: features strictly inset; four edges stay identical.
 for row in range(3):
  for col in range(3):
   x=5+col*40;y=22+row*33; c=r.choice(['#697063','#5c665a','#788073','#49544c'])
   s+=f'<path d="M{x+5} {y}l27 2 5 10-4 17-27-1-4-12Z" fill="{c}" stroke="#303b34" stroke-width="2"/><path d="M{x+6} {y+3}l23 1" stroke="#a2a58d" opacity=".45" stroke-width="2"/>'
 return s
for variant in range(3):
 for cap in ['middle','left','right','isolated']:
  s=rock(20+variant)
  s+='<path d="M0 16H128V24Q112 30 96 24T64 24T32 24T0 24Z" fill="#314a32"/><path d="M0 16H128V20Q112 25 96 20T64 20T32 20T0 20Z" fill="url(#grass)"/><path d="M0 16H128" stroke="#dbd28a" stroke-width="2"/>'
  r=random.Random(variant+32)
  for i in range(16):
   x=8+i*7;s+=f'<path d="M{x} 17l-3 -{r.randint(3,7)} 5 3 2 -5 1 7" fill="#a2af59"/>'
  # One-pixel connector guards ensure identical raster edges under SVG antialiasing.
  for edge_x in [0,127]:
   s+=f'<path d="M{edge_x} 16h1v1h-1Z" fill="#dbd28a"/><path d="M{edge_x} 17h1v3h-1Z" fill="#8f9f4f"/><path d="M{edge_x} 20h1v4h-1Z" fill="#314a32"/><path d="M{edge_x} 24h1v7h-1Z" fill="#50594d"/>'
  # Edge caps shade inside tile, never extend the connector edge.
  if cap in ['left','isolated']:s+='<path d="M1 25V127" stroke="#283a31" stroke-width="3"/>'
  if cap in ['right','isolated']:s+='<path d="M127 25V127" stroke="#283a31" stroke-width="3"/>'
  save('terrain',f'grass_{cap}_{variant+1}',128,128,s,[0,16],kind='terrain',connectors={'top_surface_y':16,'left':'grass_16' if cap in ['middle','right'] else 'open','right':'grass_16' if cap in ['middle','left'] else 'open','bottom':'rock_fill'},repeat={'horizontal':cap=='middle','vertical':False},exclusion_zones=[{'rect':[0,0,128,24],'purpose':'no_foreground_decoration_on_landing_edge'}])
for v in range(3):
 save('terrain',f'rock_fill_{v+1}',128,128,rock(v+20).replace('M0 16H128','M0 0H128'),[0,0],kind='terrain',connectors=dict(left='rock_fill',right='rock_fill',top='rock_fill',bottom='rock_fill'),repeat=dict(horizontal=True,vertical=True),exclusion_zones=[])
for side in ['left','right']:
 s=rock(24)+f'<path d="M{2 if side=="left" else 126} 0V128" stroke="#26392f" stroke-width="4"/>'
 save('terrain',f'rock_edge_{side}',128,128,s,[0,0],kind='terrain',connectors={'inner':'rock_fill','outer':'open'},repeat={'vertical':True},exclusion_zones=[])
for side in ['left','right']:
 s=rock(25);s+='<path d="M0 16H128V22H0Z" fill="url(#grass)"/>'
 save('terrain',f'inner_corner_{side}',128,128,s,[0,16],kind='terrain',connectors={'top':'grass_16','bottom':'rock_fill'},repeat={'horizontal':False},exclusion_zones=[])
for cap in ['left','middle','right']:
 s='<path d="M0 16H128V31L113 36H15L0 31Z" fill="url(#metal)" stroke="#252e29" stroke-width="2"/><path d="M0 16H128V22H0Z" fill="url(#grass)"/><path d="M0 16H128" stroke="#d6ce8c" stroke-width="2"/>'
 for x in [14,48,80,114]:s+=f'<circle cx="{x}" cy="28" r="3" fill="#b19c64" stroke="#34392e"/>'
 save('terrain',f'thin_platform_{cap}',128,48,s,[0,16],kind='one_way_platform_skin',connectors={'left':'thin_16','right':'thin_16'},repeat={'horizontal':cap=='middle'},exclusion_zones=[{'rect':[0,0,128,20],'purpose':'landing_surface_clear'}])
props={
 'grass_tuft_1':(64,48,'<path d="M9 46L5 20l16 20L19 7l13 33L43 9l-3 32 17-20-8 25Z" fill="#738849"/><path d="M25 44L22 15M37 44L43 16" stroke="#c3c47b" stroke-width="2"/>'),
 'grass_tuft_2':(80,48,'<path d="M5 46L13 27l7 15L27 12l8 28L48 6l-3 33 19-21-7 24 18-9-8 13Z" fill="#8f9b4e"/>'),
 'flowers_white':(64,64,''), 'flowers_gold':(64,64,''),
 'stone_small':(64,48,'<path d="M8 45L5 31 22 17 43 21 58 37 54 45Z" fill="url(#rock)" stroke="#39453b" stroke-width="2"/><path d="M8 31l17-10 17 3-12 11Z" fill="#959c86"/>'),
 'stone_cluster':(96,64,'<path d="M5 59L10 38 35 29l18 11-6 19Z" fill="url(#rock)"/><path d="M43 59L48 24 65 13l21 16 7 30Z" fill="url(#rock)" stroke="#364238" stroke-width="2"/><path d="M50 25l16-9 17 14-23 4Z" fill="#8d9581"/>'),
 'ruined_pillar':(96,192,'<path d="M20 184L22 49 31 25 57 20l17 27 2 137Z" fill="url(#rock)" stroke="#303d34" stroke-width="3"/><path d="M25 52H73M24 91H74M23 132H74" stroke="#344339" stroke-width="3"/><path d="M35 30L39 175M62 32L60 174" stroke="#94977d" opacity=".4" stroke-width="3"/><path d="M13 181H85V191H13Z" fill="#545f50"/><path d="M23 49l13-11 12 5 13-18" fill="none" stroke="#283d31" stroke-width="3"/><path d="M16 184l4-18 10 15 10-10 6 14" fill="#829647"/>'),
 'brass_ruin_ring':(96,96,'<circle cx="48" cy="48" r="35" fill="url(#metal)" stroke="#b19a60" stroke-width="4"/><circle cx="48" cy="48" r="24" fill="none" stroke="#2b342b" stroke-width="9"/><circle cx="48" cy="48" r="7" fill="#9b834d"/>'),
 'hanging_vines':(64,128,'<path d="M13 0q-10 35 6 65t-4 56M43 0q17 29-3 59t7 48" fill="none" stroke="#566c39" stroke-width="4"/>'),
 'windmill_distant':(160,240,'<path d="M56 229L64 92 93 92l13 137Z" fill="#6f806a"/><path d="M55 96L80 74l27 22Z" fill="#667664"/><g transform="translate(80 95) rotate(25)" fill="#8d997d" stroke="#5c705d" stroke-width="3"><path d="M-7-83H7V83H-7Z"/><path d="M-72-7H72V7H-72Z"/></g><circle cx="80" cy="95" r="9" fill="#627561"/>')}
for name,(w,h,s) in props.items():
 if name.startswith('flowers'):
  for x,y in [(12,28),(30,16),(48,34)]:
   s+=f'<path d="M{x} 62V{y}" stroke="#738443" stroke-width="2"/>'
   for dx,dy in [(-4,0),(4,0),(0,-4),(0,4)]:s+=f'<circle cx="{x+dx}" cy="{y+dy}" r="4" fill="{"#eee6bb" if name.endswith("white") else "#d9b853"}"/>'
   s+=f'<circle cx="{x}" cy="{y}" r="2" fill="#9e7b3d"/>'
 if name=='hanging_vines':
  for x,y in [(13,14),(10,35),(19,57),(20,80),(42,22),(45,45),(36,67),(39,91)]:s+=f'<path d="M{x} {y}q-14-4-9 8q10 4 9-8Z" fill="#84914b"/>'
 save('props',name,w,h,s,[w/2,0 if name=='hanging_vines' else h],kind='decoration',collision='none',allowed_zones=['background'] if name=='windmill_distant' else ['decoration_safe'],repeat={'horizontal':False,'vertical':False},placement={'minimum_spacing_logical':24,'avoid_gameplay_clearance':True,'mirror_safe':name not in ['windmill_distant','ruined_pillar']},exclusion_zones=[])
# Preserve separately generated raster supplements on vector regeneration.
existing_meta=ROOT/'assets/terrain/plains/metadata.json'
if existing_meta.exists():
 for supplemental in json.loads(existing_meta.read_text()).get('assets',[]):
  if not supplemental['path'].endswith('.svg'):
   records.append(supplemental)
manifest={'schema_version':1,'biome':'plains','style':'muted hand-painted-inspired vector; grass, stone and restrained brass','grid':{'logical_cell':64,'art_cell_px':128,'pixels_per_logical_unit':2,'surface_offset_px':16},'provenance':{'method':'AI-authored deterministic procedural SVG','generator':'tools/build_terrain_art.py','reference':'approved plains concept exec-b229b4a0-ec16-4180-905b-14954d71d657.png','seed_policy':'fixed per asset; no model-generated raster incorporated','license':'project-authored original artwork'},'assets':records}
(ROOT/'assets/terrain/plains/metadata.json').write_text(json.dumps(manifest,indent=2)+'\n')
fragment={'assets':[{**a,'width':a['size_px'][0],'height':a['size_px'][1],'anchors':{'origin':a['anchor_px']}} for a in records]}
(ROOT/'assets/terrain/plains/manifest_fragment.json').write_text(json.dumps(fragment,indent=2)+'\n')
# Portable browser contact sheet with genuine external SVG assets.
html='<html lang="zh"><meta charset="utf-8"><title>Plains terrain contact sheet</title><style>body{background:#263931;color:#ede8ca;font:14px sans-serif}.grid{display:flex;flex-wrap:wrap;gap:14px}.item{width:180px;height:270px;border:1px solid #74816a;padding:10px}.item img{max-width:160px;max-height:220px;image-rendering:auto}.seam{display:flex;gap:0}.seam img{width:128px;height:128px}</style><h1>Plains terrain and props</h1><p>2 art pixels = 1 logical unit. Grass surface y = 16 art px.</p><h2>Seam strip</h2><div class="seam">'
for n in ['grass_left_1','grass_middle_1','grass_middle_2','grass_middle_3','grass_right_1']:html+=f'<img src="{n}.svg">'
html+='</div><h2>Individual assets</h2><div class="grid">'
for a in records:html+=f'<div class="item"><div>{a["id"]}</div><img src="../../../{a["path"]}"></div>'
html+='</div></html>'
(ROOT/'assets/terrain/plains/contact_sheet.html').write_text(html)
print(f'Built {len(records)} SVG assets and metadata')
