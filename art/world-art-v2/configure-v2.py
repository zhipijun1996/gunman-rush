#!/usr/bin/env python3
"""Build the v2 room recipes from the preserved v1 study, never cumulatively offset."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
data = json.loads((ROOT / 'references/study-v1.json').read_text())
specs = {r['id']: r for r in json.loads((ROOT / 'v2-regional-specs.json').read_text())}
data['schema'] = 'clock-world-art-library-v2'
data['title'] = '失序之钟 · 16 区域 47 邻接与平台景深'
data['hero']['x'], data['hero']['y'] = 126, 288
cells = {(x, y) for y in range(9, 14) for x in range(-2, 8)}
cells |= {(x, y) for y in range(8, 14) for x in range(11, 22)}
cells -= {(15, 9), (16, 9)}
cells |= {(8, 7), (9, 7)}
data['terrainGrid'] = {'tile': 32, 'origin': [0, 0], 'cells': [list(c) for c in sorted(cells, key=lambda c:(c[1],c[0]))]}
data['terrain'] = [dict(x=-64,y=288,w=320,h=160),dict(x=352,y=256,w=352,h=192)]
data['motion']['cameraAmplitude'] = 32
data['artDirection'] = 'Underworld细像素家族 v2；16区完整47邻接、区域构件、平台近景与定向局部光'
data['qualityContract']['terrainCoverage'] = '16 regions × 47 normalized blob adjacency states in separate native32 atlases'
data['qualityContract']['terrain47'] = '47 normalized 8-neighbor states per region; native tile 32x32; isolated/concave/thin forms verified separately'
data['qualityContract']['foregroundV2'] = 'independent complete low silhouettes, close to platform height; rooted attached props remain world speed 1; floating near clumps use world-space platform band and local hero reveal'
for r in data['regions']:
    rid=r['id']; spec=specs[rid]
    r['artStatus']='v2_expansion_preserving_approved_underworld_materials'
    if rid in ('windchime_plains','thorn_forest'):
        r['background'] = rid+'_v2'
    for obj in r['instances']:
        if obj.get('hazard'):
            obj['x']=304
            continue
        if obj['y'] < 330:
            obj['y'] -= 2 if obj['x'] < 300 else 10
    # The old light-emitting landmarks remain, with their source position offsets.
    for light in r['lighting']['lights']:
        if light.get('visible') and light['y'] > 100 and light['y'] < 330:
            light['y'] -= 2 if light['x'] < 300 else 10
    # Exchange only the non-luminous small rock; other practical lights remain supported.
    r['instances']=[o for o in r['instances'] if o['id']!='rock']
    small=spec['props'][2]
    r['instances'].append(dict(id='v2-region-detail-left',asset=rid+'_v2_'+small[0],x=40,y=288,group='detail',newInV2=True))
    right=spec['props'][3]
    r['instances'].append(dict(id='v2-region-detail-right',asset=rid+'_v2_'+right[0],x=390,y=256,group='detail',newInV2=True))
    r['assetExpansion']={'newProps':[rid+'_v2_'+p[0] for p in spec['props']], 'displayedProps':[rid+'_v2_'+small[0],rid+'_v2_'+right[0]], 'scope':'visual environmental dressing, no new gameplay mechanics'}
    band={'type':'platform_band','above':72,'below':72,'edgeFade':8,'heroReveal':{'radiusX':30,'radiusY':48,'minAlpha':0.15}}
    r['layers']=[
      dict(id='mid-left-v2',asset=rid+'_mid_v2',kind='mid',x=92,y=310,parallax=0.45,opacity=0.62,tint=[0.62,0.68,0.72]),
      dict(id='mid-right-v2',asset=rid+'_mid_v2',kind='mid',x=559,y=294,parallax=0.62,opacity=0.46,tint=[0.56,0.62,0.68]),
      dict(id='near-left-v2',asset=rid+'_near_v2',kind='near',x=155,y=312,parallax=1.08,opacity=0.95,tint=[0.46,0.52,0.59],mask={**copy.deepcopy(band),'surfaceY':288}),
      dict(id='near-right-v2',asset=rid+'_near_v2',kind='near',x=540,y=284,parallax=1.12,opacity=0.91,tint=[0.48,0.53,0.60],mask={**copy.deepcopy(band),'surfaceY':256}),
    ]
    if 'hazardDemo' in r:
        r['hazardDemo']['bounds']=[277,333,54,27]
data['releaseNotes']={
 'backgrounds':'New Windchime Plains and Thorn Forest plates; previous plates retained as explicit variants.',
 'terrain':'All 16 regions use a separate 47-mask atlas manifest; legacy nine-slice remains for compatibility.',
 'depth':'32 redrawn mid/near independent sprites with natural ends; near clumps use a local mask, not full-screen framing.',
 'newProps':'64 new regional props are delivered; two per region are placed in this density-controlled sample.',
 'sampleScope':'Art assembly and adjacency/depth behavior sample; hazard art and visual props do not add damage or other gameplay logic.'
}
(ROOT/'study.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'regions':len(data['regions']),'terrainCells':len(cells),'newProps':64,'newDepthSprites':32,'newBackgrounds':2},ensure_ascii=False))
