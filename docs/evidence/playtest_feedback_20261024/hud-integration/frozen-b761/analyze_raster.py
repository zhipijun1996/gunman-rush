from pathlib import Path
import hashlib,io,json,math,zipfile
import numpy as np
from PIL import Image
BASE=Path('build/verification/hud-review-independent/final-b7610b8a');folder=BASE/'raster';probe=json.loads((folder/'probe.json').read_text());obs={x['label']:x for x in probe['observations']}
def image(label):return np.array(Image.open(folder/(label+'.png')).convert('RGB'))
def mask(label,off):return np.any(image(label)!=image(off),axis=2)
def fill(bounds):
 x,y,w,h=bounds;field=np.zeros((720,1280),bool);field[max(0,math.floor(y)):min(720,math.ceil(y+h)),max(0,math.floor(x)):min(1280,math.ceil(x+w))]=True;return field
analyses=[];masks={}
for label,off in [('before-quiet','without-status'),('after-quiet','without-status'),('after-notice','without-status-notice')]:
 ink=mask(label,off);masks[label]=ink;declared=np.zeros(ink.shape,bool);raw=np.zeros(ink.shape,bool)
 for row in obs[label]['widgets']:
  bounds=list(row['bounds']);raw|=fill(bounds)
  if row['notice']:bounds[2]=min(bounds[2],(row['native_text_width']+6)*row['global_scale'][0])
  if row['type']=='Label':
   grow=2*row['global_scale'][0];bounds=[bounds[0]-grow,bounds[1]-grow,bounds[2]+2*grow,bounds[3]+2*grow]
  declared|=fill(bounds)
 analyses.append({'label':label,'ink_pixels':int(ink.sum()),'outside_raw_leaf_bounds':int((ink&~raw).sum()),'outside_final_observer_bounds':int((ink&~declared).sum()),'status_anchor':obs[label]['rows_bounds'][:2],'resonance_bounds':obs[label]['resonance_bounds']})
 assert not (ink&~declared).any(),label+' actual ink escaped final observer bounds'
z=zipfile.ZipFile('/tmp/pr108-serial-failure.zip');a=zipfile.ZipFile(io.BytesIO(z.read(next(n for n in z.namelist() if n.endswith('plains-redesign-scene/large-json.zip')))))
p=json.loads(a.read(next(n for n in a.namelist() if n.endswith('positive-shard-1.json'))));case=next(c for c in p['cases'] if c.get('scene_case_index')==2);critical=[]
for frame in case['visual_frames']:
 if 2160<=frame['tick']<=2220:
  rect=next(t['screen'] for t in frame['targets'] if t['id']=='enemy/12');roi=fill(rect)
  row={'recorded_tick':frame['tick'],'recorded_enemy_screen_bounds':rect,'before_ink_pixels':int((masks['before-quiet']&roi).sum()),'after_quiet_ink_pixels':int((masks['after-quiet']&roi).sum()),'after_notice_ink_pixels':int((masks['after-notice']&roi).sum())};critical.append(row)
  assert row['after_quiet_ink_pixels']==row['after_notice_ink_pixels']==0
assert any(x['before_ink_pixels']>0 for x in critical)
assert obs['before-quiet']['rows_bounds'][:2]==obs['after-quiet']['rows_bounds'][:2]==[24,18]
report={'status':'passed','scope':'Actual production HUD ink raster. Runtime restores original two EXPAND_FILL properties for controlled before; isolated real Godot viewport bound to a real formal controller. Recorded old enemy rectangles are sampling windows, not an identical-seed live route reenactment. No gameplay/device/performance acceptance inferred.','renderer':'Godot 4.7.2 GL Compatibility / Mesa llvmpipe','raster_cases':analyses,'recorded_critical_windows':critical,'notice_native_font_width':next(w['native_text_width'] for w in obs['after-notice']['widgets'] if w['notice']),'actual_viewed_pngs':['before-quiet.png','after-quiet.png','after-notice.png'],'original_files':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [folder/'probe.json',*[folder/(label+'.png') for label in obs]]},'source_hashes':probe['sources'],'strict_log_path':str(BASE/'raster.log')}
(BASE/'raster-analysis.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'status':report['status'],'raster_cases':analyses,'notice_native_font_width':report['notice_native_font_width'],'critical_after_all_zero':True},ensure_ascii=False))
