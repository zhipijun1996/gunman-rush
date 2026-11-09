#!/usr/bin/env python3
"""Write the current regional asset recipes; contact sheets are emitted by the bakers."""
import json
from pathlib import Path
P=Path(__file__).resolve().parent
s=json.loads((P/'study.json').read_text())
m=json.loads((P/'assets/pixel/manifest.json').read_text())
a=json.loads((P/'assets/terrain47/manifest.json').read_text())
regions=[]
for r in s['regions']:
    rid=r['id']
    keys=sorted({o['asset'] for o in r['instances']+r['layers']} | set(r.get('assetExpansion',{}).get('newProps',[])))
    regions.append({
      'id':rid,'name':r['name'],'status':'authored_v2_candidate_preserving_approved_material_family',
      'background':r['background'],'terrain47':a['regions'][rid],
      'legacyTerrain':m['terrains'][rid], 'assets':keys,
      'newProps':r.get('assetExpansion',{}).get('newProps',[]),
      'instances':r['instances'],'layers':r['layers'],
      'lighting':r['lighting'],'particles':r['particles'],
      'preview':'previews/'+rid+'-lit.png','hazardStatus':'visual_only_no_damage_logic'
    })
(P/'region-catalog.json').write_text(json.dumps({'schema':'clock-world-art-catalog-v2','worldUnitsPerPixel':1,'terrainCell':32,'heroBodyHeight':44,'regions':regions},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'regions':len(regions),'catalog':'region-catalog.json'},ensure_ascii=False))
