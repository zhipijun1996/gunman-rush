import copy,hashlib,json,subprocess,sys
from pathlib import Path
root=Path.cwd();out=root/'build/region_bible_v2/av-adapter-independent-review-first'
source=root/'tools/capture_forest_bible_route.py';raw=source.read_bytes();(out/'adapter-reviewed.py.source.txt').write_bytes(raw)
sys.path.insert(0,str(root/'tools'))
ns={'__file__':str(source),'__name__':'independent_av_adapter_probe'}
exec(compile(raw,str(source),'exec'),ns)
base=json.loads((root/'build/region_bible_v2/grounded-v3-map1-backbranch-first/trace.json').read_text())
results=[]
def probe(name,data,call,expected):
 try:
  result=call(data);accepted=True;error=None
 except Exception as exc:
  accepted=False;result=None;error=type(exc).__name__+': '+str(exc)
 results.append({'name':name,'scope':'actual reviewed function on explicitly synthetic mutated report; not native gameplay','expected_acceptance':expected,'accepted':accepted,'unexpected_acceptance':accepted and not expected,'result':result,'error':error})
probe('actual_existing_safe_report',base,lambda d:ns['verify_trace'](d,'F05',1),True)
d=copy.deepcopy(base);d['frames'][0]['health']=0
probe('zero_health_sample',d,lambda d:ns['verify_trace'](d,'F05',1),False)
d=copy.deepcopy(base);d['events'].append({'kind':'committed_damage','target':'player','amount':2,'tick':d['frames'][0]['tick']})
probe('committed_player_damage_present',d,lambda d:ns['verify_trace'](d,'F05',1),False)
d=copy.deepcopy(base);d['frames'][-1]['actor_epoch']=999
probe('actor_respawn_epoch_changed',d,lambda d:ns['verify_trace'](d,'F05',1),False)
d=copy.deepcopy(base);d['frames'][-1]['stage_epoch']=999
probe('stage_epoch_changed',d,lambda d:ns['verify_trace'](d,'F05',1),False)
d=copy.deepcopy(base);d['frames']=d['frames'][:1]
probe('truncated_to_one_physical_sample_with_complete_header',d,lambda d:ns['verify_trace'](d,'F05',1),False)
d=copy.deepcopy(base);d['final']['position']=[99999,99999];d['claimed']={};d['opened']={}
probe('missing_actual_camp_claim_and_shortcut',d,lambda d:ns['verify_trace'](d,'F05',1),False)
for dname,remove in [('constant_draw_counter_all_events_kept',False),('constant_counter_all_accepted_events_deleted',True)]:
 d=copy.deepcopy(base)
 for group in ['frames','events']:
  for row in d[group]:row['presentation_frame']=0
 if remove:d['events']=[]
 probe(dname,d,lambda d:{'trace':ns['verify_trace'](d,'F05',1),'keyframes':ns['keyframes'](d,12,'F05')},False)
p=root/'build/region_bible_v2/f08-full-01/trace.json'
if p.exists():
 d=json.loads(p.read_text());d['core_evidence']={'not_an_actual_item_receipt':True}
 probe('F08_core_receipt_replaced_with_nonempty_garbage',d,lambda d:ns['verify_trace'](d,'F08',2),False)
fixture=out/'SYNTHETIC-NOT-GAME-static-short-silent-audio.avi'
cmd=['ffmpeg','-nostdin','-v','error','-f','lavfi','-i','color=c=black:s=1280x720:r=60:d=0.2','-f','lavfi','-i','anullsrc=r=48000:cl=stereo:d=0.001','-map','0:v:0','-map','1:a:0','-c:v','mjpeg','-q:v','10','-threads','1','-c:a','pcm_s16le',str(fixture)]
r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=30)
(out/'synthetic-media-generation.log').write_text(r.stderr)
media={'scope':'Explicit synthetic non-game constant-black video with only1ms all-zero audio; never production AV','argv':cmd,'exit_code':r.returncode}
if r.returncode==0:
 try:
  media['adapter_result']=ns['media_probe'](fixture,out);media['unexpected_acceptance']=True
 except Exception as e:media.update(unexpected_acceptance=False,error=repr(e))
 report={'reviewed_source':source.relative_to(root).as_posix(),'reviewed_sha256':hashlib.sha256(raw).hexdigest(),'source_still_identical_after_probe':source.read_bytes()==raw,'engine_executed':False,'production_source_modified':False,'actual_function_probes':results,'real_synthetic_media_probe':media}
(out/'probe-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'reviewed_sha256':report['reviewed_sha256'],'source_still_identical':report['source_still_identical_after_probe'],'unexpectedly_accepted':[r['name'] for r in results if r['unexpected_acceptance']],'synthetic_static_short_silent_audio_accepted':media.get('unexpected_acceptance')},ensure_ascii=False))
