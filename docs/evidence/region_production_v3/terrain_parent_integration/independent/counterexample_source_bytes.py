"""Read-only reconstruction and media consistency checks; no engine or art verdict."""
from pathlib import Path
import hashlib,json,subprocess,sys,time
from PIL import Image
ROOT=Path('/workspace/gunman-v3-scenes')
def sha(data): return hashlib.sha256(data).hexdigest()
def read(path): return (ROOT/path).read_bytes()
def load(path): return json.loads(read(path))
checks=[]
def check(name,condition,detail=None):
 checks.append({'name':name,'passed':bool(condition),'detail':detail})
def blob(commit,path): return subprocess.check_output(['git','show',f'{commit}:{path}'],cwd=ROOT)
def resolve_old(item):
 if 'restore_delta' in item:return read(item['restore_delta'])
 return blob(item['restore_git_commit'],item['path'])

_original_read=read
def read(path):
 data=_original_read(path)
 return data+b'\nINDEPENDENT_SIMULATED_CORRUPTION' if str(path)=='scripts/art/plains_terrain_family_sampler.gd' else data

start=time.monotonic()
base='docs/evidence/region_production_v3/terrain_family_01/'
manifest_path='build/region_production_v3/scene/terrain_integration_manifest.json'
manifest=load(manifest_path)
check('original_integration_manifest_SHA',sha(read(manifest_path))=='946efe9b5eaacf95c22aecb055a7c8b84a76c971ecfdafd8a7a9648a52be09bb')
for group,count in [('runtime_files',10),('docs_files',120)]:
 items=manifest[group];bad=[i['path'] for i in items if sha(read(i['path']))!=i['sha256']]
 check('frozen_'+group,len(items)==count and not bad,{'count':len(items),'drift':bad})
closure=load(base+'closure/portable_source_closure.json');old=load(closure['prior_verified_source_closure']);oldfiles={i['path']:i for i in old['files']}
restored={};drift=[];badrestore=[];kinds={}
for item in closure['files']:
 p=item['path']; r=item['restore'];kind=r['kind'];kinds[kind]=kinds.get(kind,0)+1
 if kind=='prior_verified_978_closure':data=resolve_old(oldfiles[p])
 elif kind=='git_blob':data=blob(r['commit'],r['path'])
 elif kind=='exact_delta':data=read(r['path'])
 else:raise ValueError(kind)
 restored[p]=sha(data)
 if restored[p]!=item['sha256']:badrestore.append(p)
 if sha(read(p))!=item['sha256']:drift.append(p)
check('999_Git_and_exact_delta_restoration',len(restored)==999 and not badrestore,{'count':len(restored),'kinds':kinds,'errors':badrestore})
check('999_current_source_freeze',not drift,{'drift':drift})
for item in closure['controls']:check('supplemental_control:'+item['path'],sha(read(item['path']))==item['sha256']==sha(read(item['restore'])))
imports=[('assets/region_production_v3/spaces/limestone_bank_section_v1/source.png.import','098189d40f8d5a2ac22ec9c3e45ec4242ce74c1f0bbfc7d097c7a4c39e3dcade'),('assets/region_production_v3/spaces/suspended_mechanical_baffle_v1/source.png.import','9f0c048019a9c32690991dcc787284926c1b7e4bf0eacb9dc557f57bceded0e8')]
for p,h in imports:check('immutable_import_dependency:'+p,sha(read(p))==h==sha(blob('2a585124f2c94ed41f3f8df06642b275f0ac96be',p)),{'sha256':h,'restore_commit':'2a585124f2c94ed41f3f8df06642b275f0ac96be','write_performed':False})
state=load('build/verification/v3-terrain-family/state.json')
check('original_controller_remains_blocked_calls1',state['status']=='blocked' and state['calls']==1 and state['error']=='Worker modified paths outside task contract; no automatic rollback',{'status':state['status'],'calls':state['calls'],'error':state['error']})
for folder,positive,negative in [('final_20map',418,46),('final_static',45,42)]:
 report=load(base+folder+'/report.json');runs=report['runs']
 check(folder+'_native_report',report['status']=='passed' and report['source_stable'] and report['source_before']==report['source_after'],{'status':report['status'],'source_stable':report['source_stable']})
 for run in runs:
  name=Path(run['log']).name;data=read(base+folder+'/'+name);text=data.decode()
  check(folder+'/'+name+'_original_log_SHA',sha(data)==run['log_sha256'])
  check(folder+'/'+name+'_counts_and_exit',run['assertions']==(negative if run['negative'] else positive) and run['failures']==(1 if run['negative'] else 0) and run['exit_code']==(1 if run['negative'] else 0),{'assertions':run['assertions'],'failures':run['failures'],'exit_code':run['exit_code']})
  check(folder+'/'+name+'_clean_engine_log','ERROR:' not in text and 'Parse Error:' not in text)
moviebase=base+'movie_original/'
movie=load(moviebase+'visual_capture.json');native=load(moviebase+'capture.json')
check('original_movie_source_receipt',movie['source_before']==movie['source_after']==closure['native_source_before'] and movie['source_before']==restored)
for key in ['native_capture','native_log','movie']:
 item=movie[key];p=moviebase+Path(item['path']).name;check('original_movie_'+key+'_SHA',sha(read(p))==item['sha256'])
check('actual_movie_outcome',movie['status']=='captured' and movie['outcome']=='route_target_reached' and movie['tick_count']==3063 and movie['composition_observation_status']=='not_requested',{'status':movie['status'],'outcome':movie['outcome'],'ticks':movie['tick_count'],'composition':movie['composition_observation_status']})
log=read(moviebase+'capture.log').decode();check('movie_exit_ERRORS_preserved','4 resources still in use' in log and '10 ObjectDB instances were leaked at exit' in log,{'lifecycle_clean':False,'original_errors_preserved':True})
mp4=ROOT/moviebase/'gameplay.mp4'
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=width,height,avg_frame_rate,nb_read_frames','-of','json',str(mp4)]))['streams'][0]
check('actual_MP4_decoded_frames',probe=={'width':1280,'height':720,'avg_frame_rate':'60/1','nb_read_frames':'3067'},probe)
frames=movie['video_frames'];indices=[i['video_frame_index_zero_based'] for i in frames]
selection='+'.join(f'eq(n\\,{i})' for i in indices)
raw=subprocess.check_output(['ffmpeg','-v','error','-threads','1','-i',str(mp4),'-vf','select='+selection,'-fps_mode','passthrough','-pix_fmt','rgb24','-f','rawvideo','pipe:1'])
size=1280*720*3;bad=[]
for j,item in enumerate(frames):
 path=moviebase+'video_frames/'+Path(item['path']).name
 if sha(read(path))!=item['sha256'] or Image.open(ROOT/path).convert('RGB').tobytes()!=raw[j*size:(j+1)*size]:bad.append(path)
check('27_original_PNG_match_actual_MP4_pixels',len(raw)==size*len(frames) and len(frames)==27 and not bad,{'count':len(frames),'decoded_RGB_bytes':len(raw),'mismatches':bad,'scope':'Media consistency only, not independent art acceptance'})
result={'schema_version':1,'task_id':'V3-TERRAIN-BINDING-02','status':'passed' if all(c['passed'] for c in checks) else 'failed','checks':checks,'seconds':time.monotonic()-start,'engine_invoked':False,'runtime_or_old_docs_written':False,'limits':['Not an art, audio, lifecycle, device or whole-region acceptance','Old controller remains blocked/calls1','Original whole-piece G0 failures unchanged','Existing AVI auto-deleted by original success producer, its receipt SHA retained; no AVI reconstruction','Existing original receipt producer binding differs from newer ROOT strict adapter; exact original producer is in verified999 closure']}
print(json.dumps(result,ensure_ascii=False,indent=2));sys.exit(0 if result['status']=='passed' else 1)
