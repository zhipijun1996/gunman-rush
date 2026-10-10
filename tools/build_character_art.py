"""Generate original deterministic courier vector production parts; no raster editing."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/characters/courier'
OUT.mkdir(parents=True,exist_ok=True)
parts={
'body':(96,96,'''<path fill="#b9ac87" d="M35 45L62 44 70 74 50 83 28 76Z"/><path fill="#f1e6c9" d="M35 43L61 43 66 66 49 61 31 73 25 69Z"/><path fill="#675a46" d="M40 59L57 60 58 80 38 80Z"/><path fill="#b69551" d="M37 64L60 66 59 71 36 69Z"/><circle cx="50" cy="68" r="4" fill="#e9c36a"/><path fill="#f5eedb" d="M28 37Q23 14 46 9Q67 8 73 28L63 51 46 48 31 58Z"/><path stroke="#c6baa0" fill="none" d="M31 34Q35 21 46 15M32 50L43 44"/><path fill="#292d2c" d="M46 25Q65 18 69 30L62 45 48 43Z"/><ellipse cx="61" cy="33" rx="10" ry="12" fill="#bc9250"/><ellipse cx="62" cy="33" rx="6" ry="8" fill="#2b6971"/><path stroke="#b9f2e1" stroke-width="2" fill="none" d="M62 27L59 34 62 37"/><path fill="#a74536" d="M32 48Q44 45 50 49L48 54 34 56Z"/>'''),
'scarf':(64,32,'''<path fill="#a94435" d="M61 13Q43 20 29 7Q18 2 3 10L13 15 4 23Q22 15 33 23Q49 25 61 18Z"/><path stroke="#d66e4e" fill="none" d="M12 11Q24 8 37 18L56 17"/>'''),
'leg':(24,40,'''<path fill="#6c5739" d="M8 3L17 3 17 14 14 26 18 32 16 37 4 37 2 33 7 27 5 15Z"/><circle cx="12" cy="14" r="5" fill="#c39c51"/><circle cx="12" cy="14" r="2" fill="#4c4538"/><path stroke="#d1b473" fill="none" d="M12 20L11 27"/><path fill="#292e2d" d="M4 31L15 30 19 35 17 38 3 38Z"/>'''),
'weapon_arm':(80,32,'''<path fill="#73604a" d="M4 11L22 13 33 9 38 15 24 22 4 20Z"/><circle cx="7" cy="16" r="6" fill="#b49150"/><path fill="#513e2b" d="M35 11L48 11 47 25 41 27 39 17Z"/><path fill="#b78d47" d="M33 6L59 6 61 9 75 9 75 15 57 15 53 19 34 18Z"/><path stroke="#ead18d" fill="none" d="M39 9L59 9M62 11L73 11"/><path fill="#292c2b" d="M75 9L78 9 78 15 75 15Z"/>''')}
assets=[]
for name,(w,h,shapes) in parts.items():
 p=OUT/f'{name}.svg'
 p.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><g stroke="#363a33" stroke-width="2" stroke-linejoin="round" stroke-linecap="round">{shapes}</g></svg>')
 assets.append({'id':f'courier_{name}','path':str(p.relative_to(ROOT)),'width':w,'height':h,'transparent':True,'usage':'production_layer'})
(OUT/'manifest_fragment.json').write_text(json.dumps({'schema_version':1,'character_id':'courier','source_master':'assets/characters/courier/source/master.png','scene':'assets/characters/courier/courier_visual.tscn','script':'assets/characters/courier/courier_visual.gd','feet_anchor':[48,112],'display_height_px':104,'aim_pivot':[52,61],'states':['idle','run','jump','fall','recoil','death'],'assets':assets},indent=2))
(OUT/'source/provenance.json').write_text(json.dumps({'source':'image_gen','generated_file':'/workspace/generated_images/exec-d255dbf9-4190-4c87-bd86-11684fd012f9.png','reference':'/workspace/generated_images/exec-b229b4a0-ec16-4180-905b-14954d71d657.png','prompt':'Single original ivory linen hood mechanical courier; brass monocular cyan lens; red scarf; bronze articulated legs; recoil pistol. Transparent full body side facing right neutral standing. Painterly 2D hand ink, warm brass charcoal shadows, readable at 72px. Reference approved plains screenshot. No scenery UI text or existing franchise.','production_method':'AI authored deterministic original SVG layers; generated PNG remains untouched visual master','limitation':'vector runtime simplifies painterly concept; visually review in game before final art signoff'},indent=2))
print('Generated',len(assets),'SVG production layers')
