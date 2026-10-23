"""Expanded native ecology verifier; fixture scopes remain explicit."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import time
import run_root_bell_formal as legacy
from run_root_bell_formal import require, sha
ROOT=legacy.ROOT
REQUIRED=legacy.REQUIRED|{'low_resource_input_depletion','alive_full_connection_return','paused_warning_freeze','inactive_target_cancel_fixture'}

def inactive_ticks(data):
    cases=[c for c in data['root_bell_cases'] if c['id']=='inactive_target_cancel_fixture']
    require(len(cases)==1, 'Missing uniquely scoped inactive counterfactual')
    case=cases[0]
    frames=data['frames'][case['start_tick']-1:case['end_tick']]
    inactive=[f['tick'] for f in frames if f['root_bell']['active'] is False]
    require(len(inactive)==3 and inactive==list(range(inactive[0],inactive[0]+3)), 'Inactive fixture must contain exact three native ticks')
    require(all(data['frames'][t-1]['root_bell']['state']=='recovery' for t in inactive),'Inactive warning did not cancel')
    require(not any(e['kind']=='root_pulse' and e['tick'] in inactive for e in data['events']),'Inactive target pulse committed')
    return set(inactive)

def validate(data):
    require(data.get('artifact_kind')=='formal_level_capture' and data.get('capture_contract_version')==3,'Not original formal consumer')
    require(data.get('outcome')=='route_target_reached' and data.get('route_reached') is True and data.get('capture_errors')==[] and data.get('driver_diagnostics')==[],'Actual formal route/cases failed')
    require(data.get('root_bell_admission_scope','').startswith(('explicit encounter-v3 pilot','default admitted encounter-v3')),'Missing honest pilot/default admission scope')
    scope=data['captured_scope']
    require(all(scope.get(k) is True for k in ('enemies_instantiated','enemy_attacks_enabled','enemy_contacts_enabled','production_rewards_enabled','production_camera_enabled')),'Formal consumers disabled')
    require(all(scope.get(k) is False for k in ('controller_manual_step','actor_teleport_by_driver','resource_injection','enemy_disable')),'Formal runtime bypass')
    require(data['seed']==data['root_seed']+'/plains/map_2' and data['map_index']==2,'Campaign actual seed mismatch')
    require(data['manifest']['version']=='plains-region-v12-root-bell-spaces','Enabled content lacks explicit version')
    admission=data['manifest']['root_bell_admission'];identity=data['root_bell_identity']
    require(admission['replaced']==1 and admission['id']==identity and admission['version']=='root-bell-encounter-v3','Wrong actual admission')
    floor=admission['physical_facts']['floor_xywh'];home=admission['physical_facts']['home']
    require(floor[2]>=560 and admission['physical_facts']['reasons']==[],'Physical admission invalid')
    free_policy=legacy.current_free_profile(data)
    frames=data['frames'];require(len(frames)==data['tick_count'] and len(frames)>100,'Missing true native trace')
    for i,frame in enumerate(frames):
        require(frame['tick']==i+1 and frame['root_bell'].get('id')==identity,'Missing/gapped actual root frame')
        require(frame['root_bell']['position']==home,'Rooted body moved')
        if i:
            require(frame['controller_tick']>frames[i-1]['controller_tick'],'Native controller clock did not advance')
            previous=frames[i-1]['root_bell'];current=frame['root_bell']
            if current['state'] in ('telegraph','attack') and previous['state'] in ('telegraph','attack'):
                require(current['goal']==previous['goal'],'Fixed ground mark followed player')
    cases=data['root_bell_cases'];ids=[c['id'] for c in cases]
    require(len(ids)==len(set(ids)) and set(ids)==REQUIRED and all(c['passed'] is True for c in cases),'Incomplete/duplicate essential formal cases')
    expected_order=['formal_approach']+[f'{kind}_phase_{phase}' for phase in (0,30,60) for kind in ('walk_mark_escape','jump_forward','jump_return')]+['low_resource_input_depletion','alive_full_connection_return','paused_warning_freeze','inactive_target_cancel_fixture','real_projectile_interrupt_0','real_projectile_interrupt_1','real_projectile_death','dead_walk_through_and_return','full_connection_and_gear_return']
    require(ids==expected_order,'Formal case chronology/phase matrix differs from actual protocol')
    require(cases[0]['start_tick']==1 and cases[-1]['end_tick']==len(frames),'Formal approach/terminal trace incomplete')
    for a,b in zip(cases,cases[1:]):require(a['end_tick']+1==b['start_tick'],'Missing continuous formal case interval')
    events=data['events'];root_events=[e for e in events if e['kind']=='root_pulse'];require(root_events,'No actual pulse')
    for event in root_events:
        frame=frames[event['tick']-1]['root_bell'];require(frame['state']=='attack' and frame['goal']==event['point'] and event['event_id'].endswith(':root_pulse:'+str(frame['serial'])),'Pulse/state/serial cause mismatch')
    for case in cases:
        observed=frames[case['start_tick']-1:case['end_tick']];require(len(observed)>=2,'Empty native case')
        require(abs(observed[-1]['position'][0]-case['position'][0])<.01,'Case endpoint differs from trace')
        if case['id'].startswith(('walk_mark_escape','jump_')):
            require(all(f['health']==observed[0]['health'] and f['root_bell']['hp']==3 for f in observed),'Nonkill case has HP damage')
            require(observed[-1]['grounded'] and abs(observed[-1]['position'][1]+18-floor[1])<.2,'No actual supported endpoint')
            require(all(floor[0]+12<=f['position'][0]<=floor[0]+floor[2]-12 for f in observed),'Pilot left supported lane')
        if '_phase_' in case['id']:
            require(case.get('phase_wait')==int(case['id'].rsplit('_',1)[1]),'Declared phase does not match exact case identity')
        if case['id'].startswith('jump_'):
            direction=1 if 'forward' in case['id'] else -1
            require(case['direction']==direction and direction*(observed[-1]['position'][0]-observed[0]['position'][0])>250,'Missing physical directed traversal')
            require(any(e['kind']=='jump_accepted' and case['start_tick']<=e['tick']<=case['end_tick'] for e in events),'No real accepted jump')
            require(any(not f['grounded'] and abs(f['position'][0]-home[0])<30 and f['position'][1]+18<home[1]-20 for f in observed),'Jump lacks actual live-body vertical clearance')
        if case['id'].startswith('walk_mark_escape'):
            delay=case['phase_wait'];require(case['phase_ready_tick']==case['start_tick']-1+delay and all(f['axis']==0 and f['input_requests']==[] for f in observed[:delay]),'Phase wait lacks actual idle native samples')
            pulses=[e for e in root_events if case['start_tick']<=e['tick']<=case['end_tick']]
            require(pulses and any(f['root_bell']['state']=='telegraph' for f in observed),'Walk escape erased warning/pulse')
            require(abs(observed[-1]['position'][0]-pulses[0]['point'][0])>40,'Walk ended inside fixed pulse')
        if case['id'].startswith('real_projectile'):
            damage=[e for e in events if e['kind']=='damage_committed' and e.get('target')==identity and case['start_tick']<=e['tick']<=case['end_tick']]
            shots=[e for e in events if e['kind']=='shot_accepted' and case['start_tick']<=e['tick']<=case['end_tick']]
            require(len(damage)==1 and len(shots)==1 and shots[0]['tick']<damage[0]['tick'],'No actual projectile→committed HP chain')
            hit=damage[0];tick=hit['tick'];require(frames[tick-2]['root_bell']['hp']-frames[tick-1]['root_bell']['hp']==hit['amount'],'HP delta not actual committed hit')
            require(hit['event_id'].endswith(':'+str(shots[0]['shot_id'])),'Hit not bound to accepted projectile identity')
            if free_policy:
                require(not any(case['start_tick']<=r['tick']<=case['end_tick'] and not r.get('continuous',False) for r in data['resource_receipts']),'Free projectile fabricated a weapon-energy receipt')
            else:
                require(any(r.get('amount_applied',0)<0 and r.get('operation')=='consume' and case['start_tick']<=r['tick']<=hit['tick'] for r in data['resource_receipts']),'Shot lacks actual resource spend receipt')
            require(any(f['root_bell']['state']=='telegraph' for f in observed),'No warning before shot')
            if 'interrupt' in case['id']:
                require(any(e['kind']=='root_interrupted' and e['tick']==hit['tick'] for e in events) and frames[hit['tick']-1]['root_bell']['state']=='recovery','No true HP interruption/recovery')
            else:require(hit['lethal'] and observed[-1]['root_bell']['terminal'],'No real terminal death')
    dead_case=next(c for c in cases if c['id']=='dead_walk_through_and_return')
    last=frames[dead_case['start_tick']-1:dead_case['end_tick']];require(all(f['root_bell']['terminal'] and f['health']==last[0]['health'] for f in last),'Dead actor still damages')
    require(any(f['position'][0]>home[0]+200 for f in last) and last[-1]['position'][0]<home[0]-200,'No real dead through-and-return')
    edge=admission['physical_facts']['edge'];steps=[e for e in data['edges'] if e['id']==edge]
    require(len(steps)==2 and [e['forward'] for e in steps]==[True,False] and all(e['reached'] for e in steps),'Missing full original edge out/gear return')

    # Full live outward destination AND reverse neighboring-module ports. A local
    # body jump or author-passed flag cannot stand in for this proof.
    live=next(c for c in cases if c['id']=='alive_full_connection_return')
    fs=frames[live['start_tick']-1:live['end_tick']]
    require(all(f['health']==fs[0]['health'] and f['root_bell']['hp']==3 and not f['root_bell']['terminal'] for f in fs),'Live continuous return took damage or killed target')
    require(not any(e['kind']=='shot_accepted' and live['start_tick']<=e['tick']<=live['end_tick'] for e in events),'Low-resource live route depended on firing')
    edge_def=next(e for e in data['manifest']['connections'] if e['id']==edge)
    areas={a['id']:a for a in data['manifest']['areas']}
    far=areas[edge_def['b']]['position'];near=areas[edge_def['a']]['position']
    def at(f,p):return legacy._near(f['position'],p,13) and f['grounded'] and f['collisions']
    far_ticks=[i for i,f in enumerate(fs) if at(f,far)]
    require(far_ticks,'Live route never reached far supported area')
    turn=far_ticks[0]
    near_ticks=[i for i,f in enumerate(fs) if i>turn and at(f,near)]
    require(near_ticks,'Live route never returned through neighboring mechanism to near area')
    for index in edge_def['modules']:
        node=data['manifest']['nodes'][index]
        text=(ROOT/('resources/generation/modules/'+node['module_id']+'.tres')).read_text()
        ports=[]
        for name in ('Entry','Exit'):
            section=re.search(r'\[sub_resource[^\n]*id="'+name+r'"\](.*?)(?=\n\[)',text,re.S)
            p=legacy._vec(section.group(1),'position');ports.append([p[0]+node['offset'][0],p[1]+node['offset'][1]])
        last=turn
        for p in ports[::-1]:
            hits=[i for i,f in enumerate(fs) if i>last and at(f,p)]
            require(hits,'Live return omitted actual reverse module port');last=hits[0]
        require(last<near_ticks[-1], 'Live reverse ports did not precede supported near destination')
    depletion=next(c for c in cases if c['id']=='low_resource_input_depletion')
    df=frames[depletion['start_tick']-1:depletion['end_tick']]
    if free_policy:
        require(depletion['profile']=='air_focus_v2' and depletion['end_tick']+1==live['start_tick'] and df[-1]['shot_energy']<data['initial_capability']['tuning']['focus_rearm_stamina'],'Live crossing lacks actual low incoming time energy')
        require(any(e['kind']=='jump_accepted' and depletion['start_tick']<=e['tick']<=depletion['end_tick'] for e in events),'Time depletion lacks actual Router jump')
        require(not any(e['kind']=='shot_accepted' and depletion['start_tick']<=e['tick']<=depletion['end_tick'] for e in events),'Current time depletion used shooting')
        spent=[r for r in data['resource_receipts'] if depletion['start_tick']<=r['tick']<=depletion['end_tick'] and r['operation']=='consume']
        require(spent and all(r['continuous'] is True and r['amount_applied']<0 and r['aim_engaged'] is True and r['grounded_before'] is False for r in spent),'Time depletion lacks real airborne focus changed results')
    else:
        require(depletion['end_tick']+1==live['start_tick'] and df[-1]['shot_energy']<data['initial_capability']['shot_energy']['shot_energy_cost'],'Live crossing lacked actual low incoming energy')
        spent=[r for r in data['resource_receipts'] if depletion['start_tick']<=r['tick']<=depletion['end_tick'] and r['operation']=='consume']
        require(spent and all(r['amount_applied']<0 for r in spent),'Resource depletion lacks real formal shot debits')
        require(not any(e['kind']=='energy_recovered' and depletion['start_tick']<=e['tick']<=depletion['end_tick'] for e in events),'Depletion used enemy grants')
    legacy.strict_semantics(data, inactive_ticks=inactive_ticks(data))
    return {'cases':len(cases),'frames':len(frames),'root_pulses':len(root_events),'scope':'One actual formal map2 pilot; not full campaign/player/device/visual admission'}


def tamper(data):
    mutations=[]
    for name in sorted(REQUIRED):
        bad=copy.deepcopy(data);bad['root_bell_cases']=[c for c in bad['root_bell_cases'] if c['id']!=name];mutations.append(('erase_case/'+name,bad))
    for kind in ('shot_accepted','damage_committed','root_pulse','root_interrupted','jump_accepted'):
        bad=copy.deepcopy(data);bad['events']=[e for e in bad['events'] if e['kind']!=kind];mutations.append(('erase_event/'+kind,bad))
    bad=copy.deepcopy(data);bad['resource_receipts']=[];mutations.append(('erase_resource_chain',bad))
    bad=copy.deepcopy(data);c=next(c for c in bad['root_bell_cases'] if c['id']=='alive_full_connection_return');bad['frames'][c['start_tick']]['root_bell']['hp']=0;mutations.append(('kill_during_live_route',bad))
    bad=copy.deepcopy(data);c=next(c for c in bad['root_bell_cases'] if c['id']=='low_resource_input_depletion');bad['frames'][c['end_tick']-1]['shot_energy']=100;mutations.append(('forge_low_resource',bad))
    if legacy.current_free_profile(data):
        bad=copy.deepcopy(data)
        for container in [bad['events']]+[f['accepted_events'] for f in bad['frames']]:
            for e in container:
                if e['kind']=='shot_accepted':e.update(packet_id=999,session_id=999,resource_epoch=999)
        mutations.append(('coherent_foreign_projectile_lifetime',bad))
        bad=copy.deepcopy(data);bad['initial_capability']['shot_energy'].pop('definition_path');mutations.append(('erase_current_profile_authority',bad))
        bad=copy.deepcopy(data)
        for r in bad['resource_receipts']:
            if r['operation']=='consume':r['aim_engaged']=False
        mutations.append(('erase_actual_focus_input',bad))
        bad=copy.deepcopy(data);bad['events']=[e for e in bad['events'] if e['kind']!='time_energy_changed'];mutations.append(('erase_time_energy_events',bad))
    refused=[]
    for label,bad in mutations:
        try:validate(bad)
        except (ValueError,KeyError,IndexError,TypeError,StopIteration):refused.append(label)
        else:raise ValueError('Accepted native ecology erasure '+label)
    return refused


def native_runtime_failed(exit_code, log):
    return exit_code != 0 or bool(re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR:|ObjectDB instances? (?:was|were) leaked", log))


def godot_lock_path(root=ROOT):
    """Use the caller's actual checkout, with an explicit shared-host override."""
    path = Path(os.environ.get("GUNMAN_GODOT_LOCK", str(Path(root).parent / "toolchains/godot-verification.lock")))
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def xvfb_binary(root=ROOT):
    candidate = Path(os.environ.get("GUNMAN_TOOLCHAIN_ROOT", str(Path(root).parent / "toolchains"))) / "xvfb/usr/bin/Xvfb"
    binary = shutil.which("Xvfb") or (str(candidate) if candidate.is_file() else None)
    require(binary is not None, "Xvfb is required for real rendered ecology capture")
    return binary


def source_files():
    result=legacy.visual_director.sources()
    for name in ('tools/run_root_bell_formal.py','tools/test_root_bell_runtime_paths.py','tools/run_root_bell_spaces.py','tools/level_design_analysis.py','tests/test_level_design_analysis.py','tools/run_root_bell_ecology.py','tools/root_bell_ecology_capture.gd','tests/root_bell_ecology_trace.gd','tests/root_bell_spaces_runner.gd'):
        result[name]=sha(ROOT/name)
    return result

def main():
    import fcntl
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seed',default='plains-redesign-8')
    parser.add_argument('--default',action='store_true')
    parser.add_argument('--movie',action='store_true')
    parser.add_argument('--output-dir',default='build/production_repair/ecology/formal_'+str(time.time_ns()))
    parser.add_argument('--validate-capture',help='Explicit existing native validation only; no native execution')
    args=parser.parse_args()
    folder=(ROOT/args.output_dir).resolve()
    require(folder.is_relative_to(ROOT/'build/production_repair/ecology') and not folder.exists(),'Use a NEW ecology build directory; originals immutable')
    folder.mkdir(parents=True)
    report={'status':'failed','scope':'real formal current DemoApp; 17 Router movement/combat cases plus one production pause callback and separately labeled inactive target lifecycle fixture; no commercial/player/device acceptance','source_before':source_files(),'started_at_unix':time.time(),'native_reexecuted':not bool(args.validate_capture),'movie_reexecuted':args.movie}
    display=None
    try:
        if args.validate_capture:
            require(not args.movie,'Existing capture validation cannot claim a new movie')
            data=json.loads((ROOT/args.validate_capture).read_text());report['original_capture']=args.validate_capture
        else:
            env=os.environ.copy();env.update(LP_NUM_THREADS='1',LIBGL_ALWAYS_SOFTWARE='1')
            command=['bash','tools/godot.sh']+([] if args.movie else ['--headless'])+['--fixed-fps','60','--path','.','--script','tools/root_bell_ecology_capture.gd','--','--source-commit='+subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'--seed='+args.seed,'--map-index=2','--strategy=fast','--encounter-policy=kill_from_bank_v1','--max-ticks=18000','--output=res://'+str((folder/'capture.json').relative_to(ROOT))]
            if args.default:command.append('--root-bell-default')
            if args.movie:
                display=subprocess.Popen([xvfb_binary(ROOT),'-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=(folder/'display.log').open('wb'))
                with selectors.DefaultSelector() as ready:
                    ready.register(display.stdout,selectors.EVENT_READ);require(ready.select(20),'Xvfb readiness timeout')
                    number=display.stdout.readline().decode().strip();require(number.isdigit(),'Invalid display');env['DISPLAY']=':'+number
                command[2:2]=['--rendering-method','gl_compatibility','--audio-driver','Dummy','--write-movie',str(folder/'gameplay.avi')]
                command.append('--capture-visible')
            report['command']=command
            wait=time.monotonic()
            with godot_lock_path(ROOT).open('a') as lock:
                fcntl.flock(lock,fcntl.LOCK_EX)
                report['engine_lock_wait_seconds']=time.monotonic()-wait
                started=time.monotonic()
                with (folder/'runtime.log').open('w') as log:
                    actual=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=900 if args.movie else 300)
                report['native_integration_seconds']=time.monotonic()-started
            report['exit_code']=actual.returncode
            log=(folder/'runtime.log').read_text()
            require(not native_runtime_failed(actual.returncode,log),'Actual native producer failed; preserve original log')
            data=json.loads((folder/'capture.json').read_text())
        start=time.monotonic()
        report['observed']=validate(data)
        report['mutation_refusals']=tamper(data)
        report['verification_seconds']=time.monotonic()-start
        if args.movie:
            start=time.monotonic()
            with (folder/'encode.log').open('w') as log:
                subprocess.run(['ffmpeg','-n','-threads','1','-i',str(folder/'gameplay.avi'),'-c:v','libx264','-threads','1','-crf','21','-pix_fmt','yuv420p','-c:a','aac',str(folder/'gameplay.mp4')],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
            report['encoding_seconds']=time.monotonic()-start
            media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(folder/'gameplay.mp4')],timeout=30))
            video=next(s for s in media['streams'] if s['codec_type']=='video');audio=next(s for s in media['streams'] if s['codec_type']=='audio')
            require((video['width'],video['height'],video['avg_frame_rate'],int(audio['sample_rate']),audio['channels'])==(1280,720,'60/1',48000,2),'Actual movie dimensions/audio differ')
            require(int(video['nb_frames'])>=data['tick_count'],'Movie lost actual native frames')
            report['movie_sha256']=sha(folder/'gameplay.mp4');report['media_probe']=media
            # A derived successful encode can replace its lossless transport; it
            # never removes failed runs, capture, native log or source receipt.
            (folder/'gameplay.avi').unlink()
        report['source_after']=source_files()
        require(report['source_before']==report['source_after'],'Source drift during actual proof; rerun after source freeze')
        report['status']='passed'
        print('ROOT BELL ECOLOGY:',json.dumps(report['observed']))
        return 0
    except Exception as error:
        report['error']=type(error).__name__+': '+str(error)
        raise
    finally:
        if display is not None:display.terminate();display.wait(timeout=10);display.stdout.close()
        report['ended_at_unix']=time.time();report['usage']={'tokens':'not_exposed','price':'not_exposed'}
        (folder/'report.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':raise SystemExit(main())
