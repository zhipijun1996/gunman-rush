import json,gzip,hashlib,subprocess,collections
from pathlib import Path
S='9fdf7fad08550ea0da46b59ef7126fa721571f28'
out=Path('build/forest_depth/independent/final-experience-v7')
def read(p):
 p=Path(p);return json.loads(gzip.decompress(p.read_bytes()) if p.suffix=='.gz' else p.read_bytes())
def sha(b):return hashlib.sha256(b).hexdigest()
def invdiff(p):
 d=read(p);inv=d['source_files'];diff=[];missing=[]
 for f,h in inv.items():
  r=subprocess.run(['git','show',S+':'+f],capture_output=True)
  if r.returncode:missing.append(f)
  elif sha(r.stdout)!=h:diff.append(f)
 return {'inventory':p,'count':len(inv),'different':diff,'missing':missing}
paths={'growth':'build/forest_depth/snapshots/region_v7_movie01/build/forest_depth/region/v7-growth-movie01/00-map2-growth/capture.json','guardian':'docs/evidence/forest_depth_v2/guardian_label_delta03/capture.json.gz','queen_H':'docs/evidence/forest_depth_v2/queen36/movies/adaptive_H/capture.json.gz','queen_edge':'docs/evidence/forest_depth_v2/queen36/movies/edge/capture.json.gz'}
r={'reviewed_commit':S,'inventory_differences':{},'raw_summary':{}}
for k,p in {'exploration':'build/forest_depth/snapshots/region_v7_movie01/build/snapshot-receipt.json','guardian':'docs/evidence/forest_depth_v2/guardian_label_delta03/full-source-after.json','queen':'docs/evidence/forest_depth_v2/queen36/inventories/actual-main-snapshot-receipt.json.gz'}.items():r['inventory_differences'][k]=invdiff(p)
for k,p in paths.items():
 d=read(p);fs=d.get('frames',[]);r['raw_summary'][k]={'path':p,'sha256':sha(Path(p).read_bytes()),'top_keys':list(d),'frames':len(fs),'first_keys':list(fs[0]) if fs else []}
 if k=='growth':
  enemyids={e['id'] for f in fs for e in f['enemies']};r['growth']={'choices':d['manifest']['choices'],'completed_legs':d['completed_legs'],'health_min':min(f['health'] for f in fs),'health_final':fs[-1]['health'],'motor_steps':dict(collections.Counter(f['motor_steps'] for f in fs)),'enemies':{eid:{'states':dict(collections.Counter(e['state'] for f in fs for e in f['enemies'] if e['id']==eid)),'health_values':sorted({e['health'] for f in fs for e in f['enemies'] if e['id']==eid})} for eid in sorted(enemyids)},'hook_requests':[x for x in d['requests'] if x.get('kind')=='grapple'],'shot_requests':[x for x in d['requests'] if x.get('kind')=='shoot_release']}
selected=['scripts/generation/thorn_forest_region_v2.gd','scripts/generation/forest_hollow_trunk_geometry.gd','scripts/bosses/rootbell_guardian_v2.gd','scripts/bosses/guardian_root_bell_v2.gd','scripts/bosses/thorn_queen_v2.gd','scripts/bosses/thorn_queen_weave_band.gd','scripts/bosses/thorn_queen_weave_knot.gd','scripts/bosses/forest_boss_duel_presentation_v2.gd','scripts/enemies/forest_thread_spider_behavior.gd','scripts/enemies/forest_lantern_behavior.gd','scripts/enemies/forest_seed_sentry_behavior.gd','config/player_tuning.json']
r['selected_git_blobs']={}
for f in selected:
 p=subprocess.run(['git','show',S+':'+f],capture_output=True)
 if p.returncode==0:r['selected_git_blobs'][f]={'sha256':sha(p.stdout),'working_byte_equal':Path(f).read_bytes()==p.stdout}
(out/'audit.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps({'inventory_differences':r['inventory_differences'],'growth':r['growth']},indent=2))
