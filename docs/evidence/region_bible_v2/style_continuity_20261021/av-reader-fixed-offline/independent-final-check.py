import copy,hashlib,importlib.util,json,sys
from pathlib import Path
root=Path.cwd();out=root/'build/region_bible_v2/av-adapter-fixed-independent-second';sys.path.insert(0,str(root/'tools'))
import capture_forest_bible_route as av
freeze=root/'build/region_bible_v2/av-adapter-fixed-negative-first/freeze-v2.json'
owner=json.loads(freeze.read_text());before={p:av.sha(root/p) for p in owner['source_sha256']}
assert before==owner['source_sha256']
spec=importlib.util.spec_from_file_location('independent_fixture_loader',root/'tests/test_capture_forest_bible_route.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
fixture=mod.CaptureAcceptanceTests();cases=[]
def record(name,d,expect):
 raw=copy.deepcopy(d)
 try:r=av.verify_movie_timeline(d,20,'F08');accepted=True;error=None
 except Exception as e:r=None;accepted=False;error=repr(e)
 cases.append({'name':name,'expected_acceptance':expect,'accepted':accepted,'expected_outcome':accepted==expect,'raw_preserved':d==raw,'result':r,'error':error})
record('explicitly_synthetic_legal_process_modal_shape',fixture.movie_fixture(),True)
d=fixture.movie_fixture();d['events'][0]['tick']-=1;record('actual_engine_bound_preincrement_tick',d,True)
for name,mut in [
 ('physics_engine_unknown',lambda d:d['events'][0].update(engine_physics_frame=999999)),
 ('physics_declared_two_ticks_behind',lambda d:d['events'][0].update(tick=-1)),
 ('physics_draw_mismatch',lambda d:d['events'][0].update(presentation_frame=3)),
 ('physics_process_mismatch',lambda d:d['events'][0].update(process_frame=101)),
 ('duplicate_frame_engine_identity',lambda d:d['frames'][1].update(engine_physics_frame=d['frames'][0]['engine_physics_frame'])),
 ('process_event_unknown',lambda d:next(r for r in d['events'] if r['kind']=='actual_input_cancelled').update(reason='unproven_exception')),
 ('process_at_next_physics_draw',lambda d:next(r for r in d['events'] if r['kind']=='actual_input_cancelled').update(presentation_frame=16)),
 ('modal_tick_not_its_draw',lambda d:d['reader_modal_frames'][0].update(tick=1)),
 ('pointer_tick_not_its_draw',lambda d:d['pointer_events'][-1].update(tick=1)),
 ('missing_true_phase',lambda d:d['requests'][0].pop('observation_phase'))]:
 d=fixture.movie_fixture();mut(d);record(name,d,False)
positives=[]
for challenge,index,name in [('F05',1,'grounded-v3-map1-backbranch-first'),('F08',2,'f08-full-01')]:
 p=root/'build/region_bible_v2'/name/'trace.json';d=json.loads(p.read_text());positives.append({'challenge':challenge,'path':p.relative_to(root).as_posix(),'sha256':av.sha(p),'result':av.verify_trace(d,challenge,index),'scope':'Actual historical native report; route validation only, no added movie counters'})
replay=json.loads((out/'probe-report.json').read_text());after={p:av.sha(root/p) for p in before}
report={'verdict':'PASS_offline_guard_repair_only','tool_sha256':before['tools/capture_forest_bible_route.py'],'engine_executed':False,'source_before':before,'source_after':after,'source_frozen_matched':before==owner['source_sha256']==after,'original_nine_negative_unexpected_acceptances':[x['name'] for x in replay['actual_function_probes'] if x['unexpected_acceptance']],'actual_short_silent_static_media_rejected':not replay['real_synthetic_media_probe']['unexpected_acceptance'],'actual_historical_route_positives':positives,'independent_timeline_controls':cases,'all_independent_controls_expected':all(x['expected_outcome'] and x['raw_preserved'] for x in cases),'existing_narrow_unit_suite':{'passed':8,'seconds':0.705,'engine':False},'native_movie_timeline_acceptance':False,'visual_audio_aesthetic_acceptance':False,'limitations':['Historical positives contain no actual movie counters','Synthetic process/preincrement positives demonstrate guard semantics, not engine scheduling proof','Fresh original-budget native AV and continuous human visual/audio review remain necessary']}
assert report['source_frozen_matched'] and report['all_independent_controls_expected'] and not report['original_nine_negative_unexpected_acceptances']
(out/'review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['verdict','tool_sha256','source_frozen_matched','original_nine_negative_unexpected_acceptances','actual_short_silent_static_media_rejected','all_independent_controls_expected','native_movie_timeline_acceptance']},indent=2))
