#!/usr/bin/env python3
"""Read-only focused contract checks for comparison_variants; no Site/Game writes."""
from pathlib import Path
import importlib.util,json,hashlib,copy,datetime,sys
GAME=Path('/workspace/gunman-rush'); HELPER=Path('/tmp/add_plains_revision_catalog.py')
TRACE=GAME/'build/plains_revision_01/comparison-03/trace.json';MOVIE=GAME/'build/plains_revision_01/comparison-03/review.mp4';REPORT=MOVIE.parent/'report.json'
OUTPUT=Path('/tmp/plains_comparison_safeclip_regression_report.json')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before={str(p):sha(p) for p in [HELPER,TRACE,MOVIE,REPORT]}
spec=importlib.util.spec_from_file_location('plains_catalog_reviewed',HELPER);helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
trace=json.loads(TRACE.read_text()); report=json.loads(REPORT.read_text()); commit=report['source']['commit']; info=helper.probe(MOVIE)
assert report['source_stable'] is True and report['mp4_sha256']==sha(MOVIE) and report['trace_sha256']==sha(TRACE)
# Existing pure formatter contract, with authentic local media identity. URLs are
# echoed only; this focused call does not claim remote media publication.
identity={**info,'game_commit':commit,'media_id':'plains-revision-comparison-'+sha(MOVIE)[:12],'media_sha256':sha(MOVIE),'source_video_url':MOVIE.as_uri(),'video_url':'/media/plains-revision-comparison-'+sha(MOVIE)[:12]}
checks=[]
def check(ok,label,details=None):
 checks.append({'name':label,'passed':bool(ok),**({'details':details} if details is not None else {})})
 if not ok:print('FAIL',label,file=sys.stderr)
variants,posters,proofs=helper.comparison_variants(copy.deepcopy(trace),identity,commit)
check(len(variants)==len(posters)==len(proofs)==6,'actual trace yields six comparison-only variants')
check(all(len(v['actions'])==1 and v['actions'][0]['id']=='scale_comparison' for _,v in variants),'no combat action is manufactured')
for index,page in enumerate(trace['pages']):
 rows=[r for r in trace['frames'] if r['page']==page['page']]; v=variants[index][1]; proof=proofs[index]
 start=page['start_movie_process_frame'];end=page['end_movie_process_frame'];frames=[r['movie_process_frame'] for r in rows]
 check(v['in']==start/60 and v['out']==end/60 and v['actions'][0]['start']==start/60 and v['actions'][0]['end']==end/60,'page%d original declared clip/action bounds preserved'%page['page'])
 check(posters[index]['frame']==start,'page%d poster is first actual playable frame'%page['page'])
 check(proof['observed_frames']==len(rows)==300 and proof['actual_first_observation_frame']==frames[0] and proof['movie_end_process_frame']==frames[-1] and proof['combat_evidence'] is False,'page%d proof retains full continuous original observations'%page['page'])
 check(proof['excluded_before_declared_playback']==([9] if index==0 else []),'page%d only the actual initial frame9 is disclosed excluded'%page['page'])
check(proofs[0]['actual_first_observation_frame']==9 and proofs[0]['movie_start_process_frame']==10 and proofs[0]['movie_end_process_frame']==308 and posters[0]['frame']==10,'initial300 observations9..308 become declared safe299-frame interval10..308, not shifted trace')

def reject(label,mutate):
 changed=copy.deepcopy(trace);mutate(changed)
 try:helper.comparison_variants(changed,identity,commit)
 except ValueError as exc:check(True,label,str(exc))
 except Exception as exc:check(False,label,'Unexpected exception: '+repr(exc))
 else:check(False,label,'Tampered contract was accepted')

def set_page(d,index,field,value):d['pages'][index][field]=value

def page_rows(d,index):return [r for r in d['frames'] if r['page']==index]

def remove_inner(d,adjust):
 row=page_rows(d,0)[100];d['frames'].remove(row)
 if adjust:d['pages'][0]['observed_frames']-=1

def duplicate(d,adjust):
 rows=page_rows(d,0);at=d['frames'].index(rows[100]);d['frames'].insert(at,copy.deepcopy(rows[100]))
 if adjust:d['pages'][0]['observed_frames']+=1

def reordered(d):
 rows=page_rows(d,0);a=d['frames'].index(rows[100]);b=d['frames'].index(rows[101]);d['frames'][a],d['frames'][b]=d['frames'][b],d['frames'][a]

def nonfirst_leading(d):
 first=page_rows(d,1)[0];row=copy.deepcopy(first);row['movie_process_frame']-=1;d['frames'].insert(d['frames'].index(first),row);d['pages'][1]['observed_frames']+=1

reject('initial page more than one leading frame rejected',lambda d:set_page(d,0,'start_movie_process_frame',11))
reject('noninitial page one leading frame rejected',lambda d:set_page(d,1,'start_movie_process_frame',310))
reject('noninitial explicit extra leading row rejected',nonfirst_leading)
reject('missing interior row with original count rejected',lambda d:remove_inner(d,False))
reject('missing interior row with adjusted count rejected',lambda d:remove_inner(d,True))
reject('duplicate interior row with original count rejected',lambda d:duplicate(d,False))
reject('duplicate interior row with adjusted count rejected',lambda d:duplicate(d,True))
reject('reordered rows rejected',reordered)
reject('tail observation later than declared end rejected',lambda d:set_page(d,0,'end_movie_process_frame',307))
reject('declared end later than actual last observation rejected',lambda d:set_page(d,0,'end_movie_process_frame',309))
reject('initial declared start before first observed frame rejected',lambda d:set_page(d,0,'start_movie_process_frame',8))
reject('fractional observation frame rejected',lambda d:page_rows(d,0)[100].update(movie_process_frame=109.5))
reject('invalid observed count rejected',lambda d:set_page(d,0,'observed_frames',299))
reject('false source stable rejected',lambda d:d.update(source_stable=False))
reject('source_after drift rejected',lambda d:d.update(source_after={'changed':True}))
reject('dirty game head rejected',lambda d:(d['git_before'].update(status=' M changed'),d['git_after'].update(status=' M changed')))
reject('manifest changed rejected',lambda d:d.update(original_manifest_unchanged=False))
reject('sample AI disclosure false rejected',lambda d:d['pages'][0]['revised'].update(comparison_AI_disabled=False))
check(before=={str(p):sha(p) for p in [HELPER,TRACE,MOVIE,REPORT]},'helper, original trace, original MP4 and report bytes remain unchanged by regression')
result={'scope':'Focused direct comparison_variants function regression. Actual final source trace/movie identity; no Godot, Site write, browser, publication, DB or whole catalog approval. Local file URI is formatting input only, not a public URL assertion.','reviewer':'/root/revision_evidence_prepare','created_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'helper_sha256':before[str(HELPER)],'trace':str(TRACE),'trace_sha256':before[str(TRACE)],'movie':str(MOVIE),'movie_sha256':before[str(MOVIE)],'game_commit':commit,'checks':checks,'check_count':len(checks),'failures':sum(not c['passed'] for c in checks),'actual_comparison_proofs':proofs,'posters':posters}
OUTPUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'checks':result['check_count'],'failures':result['failures'],'output':str(OUTPUT)}))
raise SystemExit(bool(result['failures']))
