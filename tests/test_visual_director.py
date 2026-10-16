"""Synthetic fault injection for evidence admission; NEVER actual Motor/image quality proof."""
from __future__ import annotations
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import visual_director as vd


class VisualDirectorTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='unit-visual-director-',dir=vd.ROOT/'build');self.addCleanup(self.tmp.cleanup)
        self.folder=Path(self.tmp.name)
        self.source={k:'a'*64 for k in vd.level_formal.source_files()}
        self.source['tests/observer_fixture.gd']='b'*64
        self.source['assets/fixture-bitmap.png']='e'*64
        self.request=dict(source_commit='c'*40,root_seed='SYNTHETIC-NOT-MOTOR',map_index=2,strategy='growth',phase_wait_ticks=0,max_ticks=60,encounter_policy='kill_from_bank_v1')
        runtime={'res://'+k:v for k,v in vd.formal_source_projection(self.source).items() if k=='project.godot' or k.startswith(('scripts/','scenes/','resources/','config/','shaders/','assets/'))}
        basis={'schema_version':1,'encounter_policy':'kill_from_bank_v1','reward_policy':'two_actual_medium_and_camp_v1',
               'driver_sources':{'res://'+k:self.source[k] for k in vd.level_formal.driver_source_paths()},
               'core_invariants':{'res://'+k:self.source[k] for k in vd.level_formal.core_source_paths()}}
        self.data=dict(**self.request,schema_version=1,artifact_kind='formal_level_capture',capture_contract_version=3,
            frames=[{'tick':1,'position':[0,0],'runtime':{'camera':{'screen_center':[0,0],'zoom':[1.6,1.6]}}}],edges=[{'id':'fixture'}],tick_count=1,
            capture_errors=[],screenshots=[],outcome='route_policy_failed',route_reached=False,
            manifest={'manifest_hash':'d'*64},manifest_hash='d'*64,formal_run_manifest_initial={'seed':'SYNTHETIC'},
            initial_capability={'fixture_not_runtime':True},initial_scenery_inventory=[{'path':'/fixture','descendants':[]}],
            engine='4.7.2-stable (official)',resource_receipts=[],policy_observations=[],policy_basis=basis,runtime_source_hashes=runtime,
            capture_source_hashes={'res://'+k:self.source[k] for k in ('tools/level_formal_capture.gd','tests/level_formal_trace.gd','scripts/art/plains_region_scenery.gd')})
        self.data['captured_scope']={k:True for k in ('enemies_instantiated','enemy_attacks_enabled','enemy_contacts_enabled','production_rewards_enabled','production_camera_enabled')}
        self.data['captured_scope'].update({k:False for k in ('controller_manual_step','actor_teleport_by_driver','resource_injection','enemy_disable')})
        self.log='Godot Engine v4.7.2.stable.official.abc123\nLEVEL FORMAL CAPTURE: 1 frames, 1 edges, outcome=route_policy_failed, capture_errors=0\n'
        self.native=self.folder/'capture.json';vd.write(self.native,self.data)
        self.logpath=self.folder/'capture.log';self.logpath.write_text(self.log)
        self.movie=self.folder/'gameplay.mp4';self.movie.write_bytes(b'SYNTHETIC UNIT MEDIA, NOT A REAL MOVIE')
        self.png=self.folder/'frame.png';Image.new('RGB',(1280,720),'gray').save(self.png)
        command=vd.level_formal.command_for(self.request,self.native,frame_dir='',visible=True)
        command[2:2]=['--rendering-method','gl_compatibility','--write-movie',str(self.movie.with_suffix('.avi'))]
        self.log+='Done recording movie at path: '+str(self.movie.with_suffix('.avi'))+'\n'
        self.logpath.write_text(self.log)
        self.report=dict(schema_version=1,artifact_kind='actual_formal_visual_capture',status='captured',errors=[],request=self.request,
             source_before=self.source,source_after=copy.deepcopy(self.source),command=command,
             environment={'LP_NUM_THREADS':'1','LIBGL_ALWAYS_SOFTWARE':'1'},
             capture_process={'status':'passed','exit_code':0},native_capture=vd.artifact(self.native),native_log=vd.artifact(self.logpath),
             movie=vd.artifact(self.movie),video_frames=[dict(**vd.artifact(self.png),video_frame_index_zero_based=0,video_time_seconds=0)],
             media={'streams':[{'codec_type':'video','width':1280,'height':720,'avg_frame_rate':'60/1','nb_frames':'2'},
                               {'codec_type':'audio','sample_rate':'48000','channels':2}]},outcome=self.data['outcome'],route_reached=False,tick_count=1)
        self.receipt=self.folder/'visual_capture.json';vd.write(self.receipt,self.report)

    def save(self):
        vd.write(self.native,self.data);self.report['native_capture']=vd.artifact(self.native);vd.write(self.receipt,self.report)

    def test_positive_integrity_fixture_retains_failed_route(self):
        report,data=vd.load_capture(self.receipt)
        self.assertEqual(data['outcome'],'route_policy_failed')
        self.assertIs(report['route_reached'],False)
        self.assertEqual(vd.inspect_capture(self.receipt)['status'],'review_required')

    def test_relocated_movie_command_requires_bound_original_native_completion(self):
        report=copy.deepcopy(self.report)
        index=report['command'].index('--write-movie')+1
        original='/workspace/original-capture/'+str(self.movie.with_suffix('.avi').relative_to(vd.ROOT))
        report['command'][index]=original
        log=self.log.replace(str(self.movie.with_suffix('.avi')),original)
        self.logpath.write_text(log);report['native_log']=vd.artifact(self.logpath)
        vd.write(self.receipt,report)
        self.assertEqual(vd.load_capture(self.receipt)[1]['tick_count'],1)
        self.assertEqual(vd.producer_command_origin(report,self.native,log)['producer_root'],'/workspace/original-capture')
        # Rewriting the archive command back to current ROOT must also contradict the original native destination.
        rewritten=copy.deepcopy(report);rewritten['command'][index]=str(self.movie.with_suffix('.avi'))
        with self.assertRaisesRegex(ValueError,'matching native completion'):
            vd.producer_command_origin(rewritten,self.native,log)
        # Synthetic fault injection only, never evidence of a real MovieWriter run.
        for mutation in ('no_log','wrong_log','duplicate_log','relative','other_tail','other_arg','wrong_root','noncanonical'):
            with self.subTest(mutation=mutation):
                bad=copy.deepcopy(report);badlog=log
                if mutation=='no_log':badlog=self.log
                elif mutation=='wrong_log':badlog=self.log+'Done recording movie at path: /elsewhere/gameplay.avi\n'
                elif mutation=='duplicate_log':badlog=log+log
                elif mutation=='relative':bad['command'][index]=original.lstrip('/')
                elif mutation=='other_tail':bad['command'][index]=original.replace('gameplay.avi','other.avi')
                elif mutation=='other_arg':bad['command'][-1]+='-changed'
                elif mutation=='wrong_root':bad['producer_root']='/workspace/unrelated'
                elif mutation=='noncanonical':bad['command'][index]=original.replace('/build/','/extra/../build/')
                with self.assertRaises(ValueError):vd.producer_command_origin(bad,self.native,badlog)

    def test_middle_far_is_a_real_environment_role_not_an_unknown_layer(self):
        observation=self.observation();observation['nodes'][0]['layer']='middle_far'
        self.assertEqual(vd.composition_candidates(observation,self.report['native_capture']['sha256'],self.source),[])
        observation['nodes'][0]['layer']='invented_layer'
        with self.assertRaisesRegex(ValueError,'Unknown layer role'):
            vd.composition_candidates(observation,self.report['native_capture']['sha256'],self.source)

    def test_caller_cannot_self_attest_adapter_validation(self):
        for adaptation in (None,{}):
            report=copy.deepcopy(self.report)
            if adaptation is not None:report['adaptation']=adaptation
            report['adaptation_validation']={'adapter_identity':'archived_bytes_verified'}
            vd.write(self.receipt,report)
            self.assertNotIn('adaptation_validation',vd.load_capture(self.receipt)[0])
            self.assertIsNone(vd.inspect_capture(self.receipt)['adaptation_validation'])

    def test_v2_adaptation_binds_archive_errors_origin_and_original_raw(self):
        # Explicit synthetic adapter-consumer unit test; no engine/media execution.
        raw=self.observation();raw.pop('capture_sha256');raw['artifact_kind']='actual_scene_composition_measurements'
        raw['samples']=[{'observer_frame':0,'camera':{'position':[0,0]},'nodes':copy.deepcopy(raw['nodes'])}]
        rawpath=self.folder/'composition_raw.json';vd.write(rawpath,raw)
        self.report['composition_capture']={'requested':True,'raw_path':vd.relative(rawpath)}
        self.report['command']=vd.native_command(self.report,self.native,self.movie.with_suffix('.avi'))
        original=copy.deepcopy(self.report);original.update(status='failed',errors=['actual synthetic adapter error'])
        oldpath=self.folder/'failed_adapter.json';vd.write(oldpath,original)
        adapter=self.folder/'adapter_source.py';adapter.write_text('# Synthetic archived adapter fixture\n')
        observed=self.folder/'composition_observation.json';vd.bind_composition(rawpath,self.native,self.source,observed)
        report=copy.deepcopy(self.report)
        report.update(composition_observation=vd.artifact(observed),composition_observation_status='measured',
            adaptation={'kind':'postprocessing_only_no_engine_rerun','contract_version':2,'original_receipt':vd.artifact(oldpath),
                'original_status':'failed','original_errors':original['errors'],'adapter':vd.artifact(adapter),
                'producer_origin':vd.producer_command_origin(original,self.native,self.log),
                'original_composition_raw':vd.artifact(rawpath)})
        vd.write(self.receipt,report)
        self.assertEqual(vd.load_capture(self.receipt)[0]['adaptation_validation']['adapter_identity'],'archived_bytes_verified')
        for mutation in ('adapter_absent','adapter_wrong','errors','origin','raw_absent','raw_hash','observation_absent','version'):
            with self.subTest(mutation=mutation):
                bad=copy.deepcopy(report);a=bad['adaptation']
                if mutation=='adapter_absent':a.pop('adapter')
                elif mutation=='adapter_wrong':a['adapter']=vd.artifact(vd.ROOT/'tools/quality.py')
                elif mutation=='errors':a['original_errors']=[]
                elif mutation=='origin':a['producer_origin']={'kind':'forged'}
                elif mutation=='raw_absent':a.pop('original_composition_raw')
                elif mutation=='raw_hash':a['original_composition_raw']['sha256']='0'*64
                elif mutation=='observation_absent':bad.pop('composition_observation')
                elif mutation=='version':a['contract_version']=999
                vd.write(self.receipt,bad)
                with self.assertRaises(ValueError):vd.load_capture(self.receipt)
        legacy=copy.deepcopy(report);legacy['adaptation'].pop('contract_version');legacy['adaptation'].pop('adapter')
        vd.write(self.receipt,legacy)
        self.assertEqual(vd.inspect_capture(self.receipt)['adaptation_validation']['adapter_identity'],'unverified')
        self.assertEqual(vd.compare_captures(self.receipt,self.receipt)['adaptation_validation']['after']['adapter_identity'],'unverified')

    def test_drift_failed_process_empty_bad_hash_and_fake_kind_rejected(self):
        for mutation in ('drift','exit','empty','hash','kind','scope','command','version'):
            with self.subTest(mutation=mutation):
                report=copy.deepcopy(self.report);data=copy.deepcopy(self.data)
                if mutation=='drift':report['source_after']={}
                elif mutation=='exit':report['capture_process']['exit_code']=1
                elif mutation=='empty':data['frames']=[]
                elif mutation=='hash':report['movie']['sha256']='0'*64
                elif mutation=='kind':data['artifact_kind']='concept_art'
                elif mutation=='scope':data['captured_scope']['enemy_disable']=True
                elif mutation=='command':report['command']+=['--frame-dir=fake']
                elif mutation=='version':data.pop('capture_contract_version')
                vd.write(self.native,data);report['native_capture']=vd.artifact(self.native);vd.write(self.receipt,report)
                with self.assertRaises(ValueError):vd.load_capture(self.receipt)
        self.save()

    def test_full_bitmap_guard_is_separate_from_original_formal_projection(self):
        # Original GDScript observer never lists PNG: keep that contract while retaining bitmap provenance.
        self.assertNotIn('assets/fixture-bitmap.png',vd.formal_source_projection(self.source))
        self.assertIn('scripts/art/plains_region_scenery.gd',vd.formal_source_projection(self.source))
        self.assertEqual(vd.validate_native(self.data,self.report,self.log),[])
        self.report['source_after']['assets/fixture-bitmap.png']='f'*64
        self.assertIn('source drift/incomplete inventory',vd.validate_native(self.data,self.report,self.log))
        self.report['source_after']=copy.deepcopy(self.source)
        self.data['runtime_source_hashes'].pop('res://scripts/art/plains_region_scenery.gd')
        self.assertIn('incomplete/changed independently observed runtime source inventory',vd.validate_native(self.data,self.report,self.log))

    def test_finalize_cannot_rescue_failed_engine_or_rewrite_old_receipt(self):
        original=copy.deepcopy(self.report);original['status']='failed';original['capture_process']['exit_code']=1
        path=self.folder/'failed_native.json';vd.write(path,original);digest=vd.file_hash(path)
        with self.assertRaisesRegex(ValueError,'failed/timed-out native'):
            vd.finalize_existing(path,self.folder/'finalize')
        self.assertEqual(vd.file_hash(path),digest)
        self.assertFalse((self.folder/'finalize').exists())

    def test_foreign_concept_or_empty_review_cannot_be_game_pixel_review(self):
        review={'reviewer':'fixture-reviewer','scope':'observed_actual_game_pixels','observed_frames':[self.report['video_frames'][0]],'verdict':'REJECT','findings':['Synthetic unit finding']}
        self.assertEqual(vd.validate_review(review,self.report)['verdict'],'REJECT')
        for fields in ({'observed_frames':[]},{'scope':'metadata_only'},{'reviewer':''}):
            bad={**review,**fields}
            with self.assertRaises(ValueError):vd.validate_review(bad,self.report)
        concept=self.folder/'concept.png';Image.new('RGB',(1280,720)).save(concept)
        review['observed_frames']=[dict(**vd.artifact(concept),video_frame_index_zero_based=0)]
        with self.assertRaises(ValueError):vd.validate_review(review,self.report)

    def test_video_frame_is_not_tick_and_wrong_frame_time_rejected(self):
        self.report['video_frames'][0]['video_time_seconds']=1
        vd.write(self.receipt,self.report)
        with self.assertRaises(ValueError):vd.load_capture(self.receipt)

    def observation(self):
        return {'artifact_kind':'actual_scene_composition_observation','capture_sha256':self.report['native_capture']['sha256'],
                'observer':{'path':'tests/observer_fixture.gd','sha256':'b'*64},
                'nodes':[{'node_path':'/wall','world_bounds':[0,0,100,100],'layer':'middle','semantic':'rooted_architecture','attachment_node_path':'/base'},
                         {'node_path':'/base','world_bounds':[0,90,100,20],'layer':'far','semantic':'stone'}],
                'protected_world_bounds':[{'id':'landing','bounds':[20,20,30,20]}]}

    def test_composition_good_and_injected_semantic_root_overlap_candidates(self):
        observation=self.observation()
        self.assertEqual(vd.composition_candidates(observation,self.report['native_capture']['sha256'],self.source),[])
        observation['nodes'][0].update(layer='near',attachment_node_path='',spatial_use='cliff_wall',asset_family={'intended_use':'small_rock_prop'})
        codes={i['code'] for i in vd.composition_candidates(observation,self.report['native_capture']['sha256'],self.source)}
        self.assertTrue({'unobserved_attachment','asset_use_mismatch','foreground_protected_bounds_overlap'}<=codes)
        # Candidate detection is geometric/contractual, never opaque pixel or beauty proof.
        for item in vd.composition_candidates(observation,self.report['native_capture']['sha256'],self.source):
            self.assertNotIn('score',item)
        for bad in ({**observation,'capture_sha256':'0'*64},{**observation,'nodes':[]},{**observation,'observer':{'path':'not-captured','sha256':'b'*64}}):
            with self.assertRaises(ValueError):vd.composition_candidates(bad,self.report['native_capture']['sha256'],self.source)
        observation['nodes'][0]['world_bounds']=[0,0,float('nan'),20]
        with self.assertRaises(ValueError):vd.composition_candidates(observation,self.report['native_capture']['sha256'],self.source)

    def test_actual_raw_binding_roundtrip_rejects_changed_measurements_and_design_json(self):
        # Explicit synthetic measurement fixture; this test is not actual runtime proof.
        raw=self.observation();raw.pop('capture_sha256')
        raw['artifact_kind']='actual_scene_composition_measurements'
        raw['samples']=[{'observer_frame':0,'camera':{'position':[0,0]},'nodes':copy.deepcopy(raw['nodes'])}]
        path=self.folder/'composition_raw.json';vd.write(path,raw)
        output=self.folder/'composition_observation.json'
        bound=vd.bind_composition(path,self.native,self.source,output)
        self.assertEqual(vd.validate_composition_binding(bound,self.report['native_capture']['sha256'],self.source),bound)
        self.report['composition_observation']=vd.artifact(output);self.report['composition_observation_status']='measured';vd.write(self.receipt,self.report)
        diagnostic=vd.inspect_capture(self.receipt)
        self.assertEqual(diagnostic['findings'],[])
        bad=copy.deepcopy(bound);bad['nodes'][0]['world_bounds'][0]+=20
        with self.assertRaisesRegex(ValueError,'changed actual measurements'):
            vd.validate_composition_binding(bad,self.report['native_capture']['sha256'],self.source)
        raw['artifact_kind']='scene_composition_design_intent';vd.write(path,raw)
        with self.assertRaises(ValueError):vd.bind_composition(path,self.native,self.source,self.folder/'fake.json')
        with self.assertRaises(ValueError):vd.load_capture(self.receipt)

    def test_explicit_observer_arg_only_and_old_capture_without_observer_still_valid(self):
        original=vd.native_command(self.report,self.native,self.movie.with_suffix('.avi'))
        self.assertNotIn('--visual-composition-output', ' '.join(original))
        observed=copy.deepcopy(self.report)
        observed['composition_capture']={'requested':True,'raw_path':vd.relative(self.folder/'composition_raw.json')}
        command=vd.native_command(observed,self.native,self.movie.with_suffix('.avi'))
        self.assertEqual(command[:-1],original)
        self.assertEqual(command[-1],'--visual-composition-output=res://'+vd.relative(self.folder/'composition_raw.json'))
        observed['composition_capture']['raw_path']='build/unrelated/stale.json'
        with self.assertRaises(ValueError):vd.native_command(observed,self.native,self.movie.with_suffix('.avi'))
        self.assertEqual(vd.load_capture(self.receipt)[1]['outcome'],'route_policy_failed')

    def test_capture_script_is_allowlisted_and_binds_native_observer_bytes(self):
        # Synthetic integrity test only, not actual spatial/gameplay evidence.
        script = 'tools/spatial_golden_capture.gd'
        extension = {script: 'f' * 64, 'tests/spatial_golden_trace.gd': 'e' * 64}
        self.request['capture_script'] = script
        self.report['capture_extension'] = {'script': script, 'sources': extension}
        self.source.update(extension)
        self.report['source_after'] = copy.deepcopy(self.source)
        self.data['capture_extension_sources'] = {'res://' + p: h for p, h in extension.items()}
        command = vd.native_command(self.report, self.native, self.movie.with_suffix('.avi'))
        self.assertEqual(command[command.index('--script') + 1], script)
        self.assertEqual(vd.validate_native(self.data, self.report, self.log), [])
        for mutation in ('native_missing', 'native_changed', 'guard_missing', 'extension_missing', 'unsupported'):
            with self.subTest(mutation=mutation):
                data, report = copy.deepcopy(self.data), copy.deepcopy(self.report)
                if mutation == 'native_missing': data.pop('capture_extension_sources')
                elif mutation == 'native_changed': data['capture_extension_sources']['res://' + script] = '0' * 64
                elif mutation == 'guard_missing': report['source_before'].pop(script)
                elif mutation == 'extension_missing': report.pop('capture_extension')
                elif mutation == 'unsupported': report['request']['capture_script'] = '../unrelated.gd'
                self.assertTrue(vd.validate_native(data, report, self.log))
        for bad in ('../unrelated.gd', '/tmp/arbitrary.gd', 'tools/level_formal_capture.gd'):
            bad_report = copy.deepcopy(self.report); bad_report['request']['capture_script'] = bad
            with self.assertRaisesRegex(ValueError, 'Unsupported capture script'):
                vd.native_command(bad_report, self.native, self.movie.with_suffix('.avi'))
            with self.assertRaisesRegex(ValueError, 'Unsupported capture script'):
                vd.capture_extension_sources(bad)

    def test_visual_sample_treatment_is_allowlisted_and_binds_observed_catalog(self):
        self.request['capture_script'] = 'tools/spatial_golden_capture.gd'
        self.request['visual_sample'] = vd.VISUAL_SAMPLE_CATALOG
        self.request['visual_layout'] = 'open-meadow'
        self.data['visual_layout_treatment'] = 'open-meadow'
        command = vd.native_command(self.report, self.native, self.movie.with_suffix('.avi'))
        self.assertIn('--visual-sample=' + vd.VISUAL_SAMPLE_CATALOG, command)
        self.assertIn('--visual-layout=open-meadow', command)
        report = copy.deepcopy(self.report)
        report['request']['visual_layout'] = ''
        with self.assertRaisesRegex(ValueError, 'requires explicit open-meadow'):
            vd.native_command(report, self.native, self.movie.with_suffix('.avi'))
        for unsafe in ('res://scripts/arbitrary.gd', '../candidate.json', '/tmp/candidate.json'):
            report = copy.deepcopy(self.report)
            report['request']['visual_sample'] = unsafe
            with self.subTest(unsafe=unsafe), self.assertRaisesRegex(ValueError, 'Unsupported explicit visual sample'):
                vd.native_command(report, self.native, self.movie.with_suffix('.avi'))
        # Isolate actual catalog binding from the already-tested extension closure.
        self.request.pop('capture_script')
        path = vd.VISUAL_SAMPLE_CATALOG.removeprefix('res://')
        self.source[path] = 'f' * 64
        self.data['visual_sample_treatment'] = {'catalog_path': vd.VISUAL_SAMPLE_CATALOG, 'catalog_sha256': 'f' * 64}
        relevant = lambda data, report: [e for e in vd.validate_native(data, report, self.log) if 'explicit visual sample' in e]
        self.assertEqual(relevant(self.data, self.report), [])
        for mutation in ('missing', 'wrong_path', 'wrong_hash', 'unguarded_catalog', 'wrong_type'):
            data, report = copy.deepcopy(self.data), copy.deepcopy(self.report)
            if mutation == 'missing': data.pop('visual_sample_treatment')
            elif mutation == 'wrong_path': data['visual_sample_treatment']['catalog_path'] = ''
            elif mutation == 'wrong_hash': data['visual_sample_treatment']['catalog_sha256'] = '0' * 64
            elif mutation == 'unguarded_catalog': report['source_before'].pop(path)
            elif mutation == 'wrong_type': report['request']['visual_sample'] = 1
            with self.subTest(mutation=mutation): self.assertTrue(relevant(data, report))

    def test_compare_requires_same_conditions_core_and_manifest(self):
        good=vd.compare_captures(self.receipt,self.receipt)
        self.assertEqual(good['status'],'comparable_for_review');self.assertEqual(good['route_outcomes']['after'],'route_policy_failed')
        changed=copy.deepcopy(self.report);changed['request']=dict(self.request,root_seed='different')
        other=self.folder/'other.json';vd.write(other,changed)
        with self.assertRaises(ValueError):vd.compare_captures(self.receipt,other)
        # Independently valid per-side evidence may differ in geometry: compare still refuses.
        newdata=copy.deepcopy(self.data);newdata['manifest']['different_generated_geometry']=True
        newpath=self.folder/'after_capture.json';vd.write(newpath,newdata)
        changed=copy.deepcopy(self.report);changed['native_capture']=vd.artifact(newpath)
        changed['command']=vd.level_formal.command_for(self.request,newpath,frame_dir='',visible=True)
        changed['command'][2:2]=['--rendering-method','gl_compatibility','--write-movie',str(self.movie.with_suffix('.avi'))]
        vd.write(other,changed)
        with self.assertRaisesRegex(ValueError,'generated route input'):vd.compare_captures(self.receipt,other)

    def test_route_is_real_original_production_loop_input_not_worker_success(self):
        # Registration and policy are real; this test does not dispatch workers.
        mission=vd.route('优化风铃平原钟庭美术','unit-visual','docs/quality/records/unit-visual-golden.json',['docs/','scripts/art/','assets/'])
        self.assertEqual(mission['scope'],'offline_production_plan_not_executed')
        self.assertTrue(any('rejected unrelated mother does not block' in item for item in mission['constraints']))
        self.assertEqual(mission['tasks'][1]['required_gates'],['G0','G1'])
        self.assertIn('art-art',mission['tasks'][1]['checks'])
        self.assertIn('visual-director-space',mission['tasks'][1]['checks'])
        forest=vd.route('制作荆棘森林黄金场景美术','forest-visual','docs/quality/records/forest-visual.json',['scripts/art/'],phase='golden')
        self.assertNotIn('visual-director-space',forest['tasks'][0]['checks'])
        focused=vd.route('优化风铃平原黄金场景','existing-task-id','docs/quality/records/existing-task-id.json',['scripts/art/'],phase='golden')
        self.assertEqual(len(focused['tasks']),1);self.assertEqual(focused['tasks'][0]['id'],'existing-task-id')
        with self.assertRaises(ValueError):vd.route('request','../bad','record.json',['assets/'])

    def test_alpha_noise_is_not_proven_visible_halo_and_old_contract_stays_frozen(self):
        from PIL import Image
        image=Image.new('RGBA',(12,12),(0,0,0,0))
        image.putpixel((0,0),(255,255,255,1));image.putpixel((5,5),(100,100,100,255))
        alpha=image.getchannel('A')
        strict=alpha.point(lambda a:255 if a>0 else 0).getbbox()
        visible=alpha.point(lambda a:255 if a>=2 else 0).getbbox()
        self.assertEqual(strict,(0,0,6,6));self.assertEqual(visible,(5,5,6,6))
        # Neither computation evaluates filtered actual Godot pixels or licenses changing a frozen >0 check.
        self.assertNotEqual(strict,visible)

    def test_capture_refuses_overwrite_and_unbounded_requests_without_engine(self):
        with self.assertRaises(ValueError):vd.capture('fixture',1,'fast',self.folder)
        with self.assertRaises(ValueError):vd.capture('fixture',1,'fast',self.folder/'new',max_ticks=0)

if __name__=='__main__':unittest.main()
