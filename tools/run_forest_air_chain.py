"""New continuous-air golden; existing Motor, resource reader and strict log policy."""
import argparse, copy, fcntl, hashlib, importlib.util, json, math, os, pathlib, re, subprocess, time
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('directional_reader',ROOT/'tools/run_forest_directional_golden.py')
BASE=importlib.util.module_from_spec(spec);spec.loader.exec_module(BASE)
NEW_KEYS={'action_program','scene_language','chain_contract'}
def validate(data,layout,variant):
    errors=[]
    def require(condition,label):
        if not condition and label not in errors:errors.append(label)
    frames=data.get('frames',[]);events=data.get('events',[]);m=data.get('manifest',{})
    require(data.get('audio_released') is True,'audio_not_released')
    require(data.get('manual_motor_step') is False and data.get('midroute_injection') is False,'privileged_motion')
    require(data.get('failure')=='','native_failure')
    require(m.get('id')==layout and m.get('version')==({'hollow_spiral':'forest-vertical-chain-golden-v1','thorn_mouth':'forest-thorn-mouth-chain-v1'}.get(layout,'forest-air-chain-golden-v1')),'wrong_factory')
    require(len(frames)>24 and all(f.get('tick')==i+1 and f.get('motor_steps')==1 for i,f in enumerate(frames)),'noncontinuous_motor')
    if not frames:return errors+['frames_missing']
    tuning,h=BASE._runtime_numbers()
    errors.extend(BASE._resource_errors(frames,events,tuning))
    require(all(isinstance(f.get('health'),(int,float)) and f['health']==frames[0]['health'] for f in frames),'unexpected_health_change')
    require(all(BASE._distance(a['position'],b['position'])<=max(h['pull_speed'],tuning['shot_burst_speed'])/tuning['physics_hz']+.3 for a,b in zip(frames,frames[1:])),'unexplained_displacement')
    if layout in ['bridge_five','hollow_spiral','thorn_mouth','recoil_hook_recoil']:
        source_spec=importlib.util.spec_from_file_location('chain_factory_reader',ROOT/'tools/run_forest_depth_region.py')
        factory_reader=importlib.util.module_from_spec(source_spec);source_spec.loader.exec_module(factory_reader)
        require(m==factory_reader._air_chain_authoritative_factory(layout),'bridge_manifest_not_authoritative_factory')
    if layout=='arch_four':
        old=BASE._factory_manifest();geometry={k:v for k,v in m.items() if k not in NEW_KEYS and k not in {'id','version'}}
        require(geometry=={k:v for k,v in old.items() if k not in {'id','version'}},'arch_geometry_changed')
        if variant in ['intended','noH','onlyR','naivejump']:
            olddata=copy.deepcopy(data);olddata['manifest']=old;olddata['layout']='arch'
            errors.extend(BASE.validate(olddata))
    if variant in ['intended','skipLastH','skipLowerH']:
        require((data.get('reached') is True and data.get('returned') is True and not data.get('danger_contacts')) or (variant=='skipLastH' and data.get('reached') is False and data.get('recovered') is True),'intended_or_probe_not_complete_clean')
        program=m.get('action_program',[])
        if variant=='skipLastH':program=program[:-1]
        if variant=='skipLowerH':program=[{'action':'R','direction':[0,1]}]+program[1:]
        desired=[x['action'] for x in program]
        departure=next((e['tick'] for e in events if e['kind']=='jumped'),None)
        arrival=next((f['tick'] for f in frames if f.get('crown_support') and departure and f['tick']>departure),None)
        require(departure is not None and (arrival is not None or variant=='skipLastH'),'missing_real_departure_arrival')
        if departure and arrival:
            air=[f for f in frames if departure<=f['tick']<arrival]
            require(bool(air) and not any(f['grounded'] for f in air),'intermediate_landing_breaks_chain')
            actual=[('H' if e['kind']=='hook_contact_kick' else 'R') for e in events if departure<=e['tick']<arrival and e['kind'] in ['hook_contact_kick','shot_fired']]
            require(actual==desired,'accepted_airborne_action_program_differs')
            require([e.get('target') for e in events if departure<=e['tick']<arrival and e['kind']=='hook_contact_kick']==[a['anchor'] for a in program if a['action']=='H'],'accepted_H_targets_not_exact_program')
            casts=[e for e in events if departure<=e['tick']<arrival and e['kind']=='hook_cast']
            contacts=[e for e in events if departure<=e['tick']<arrival and e['kind']=='hook_contact_kick']
            kicks=[e for e in events if departure<=e['tick']<arrival and e['kind']=='hook_kick']
            require(len(casts)==len(contacts)==len(kicks)==desired.count('H'),'H_not_full_contact_restore')
            anchors={x['id']:x['position'] for x in m.get('hook_anchors',[])}
            by={f['tick']:f for f in frames}
            expected_targets=[a['anchor'] for a in program if a['action']=='H']
            for i,(cast,contact,kick) in enumerate(zip(casts,contacts,kicks)):
                require(cast['tick']<contact['tick']<kick['tick'],'H_state_order')
                target=expected_targets[i] if i<len(expected_targets) else None
                require(contact.get('target')==target and kick.get('target')==target,'per_step_H_target_not_expected_anchor')
                until=casts[i+1]['tick'] if i+1<len(casts) else arrival
                group=[e for e in events if cast['tick']<=e['tick']<until]
                chain=[]
                for state in ['hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick','free']:
                    matching=[e for e in group if e['kind']==state]
                    require(len(matching)==1,'per_step_H_state_missing_or_duplicate/'+state)
                    if len(matching)==1:chain.append(matching[0])
                if len(chain)==6:
                    require([e['tick'] for e in chain]==sorted(set(e['tick'] for e in chain)),'per_step_H_six_states_order')
                    require(all(e.get('target')==target for e in chain[2:]),'per_step_H_pull_contact_kick_free_target')
                    for a,b,state in zip(chain,chain[1:],['hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick']):
                        require(all(by.get(t,{}).get('hook_state')==state for t in range(a['tick'],b['tick'])),'per_step_H_live_state_interval')
                require(contact.get('target') in anchors,'unknown_anchor')
                if contact.get('target') in anchors:require(BASE._xy(contact.get('hook_tip')) and BASE._distance(contact['position'],contact['hook_tip'])<=h['stop']+.1,'body_not_at_anchor_contact')
                require(by[kick['tick']]['hook_used'] is False,'contact_did_not_restore_H')
                if i:require(cast['tick']>kicks[i-1]['tick'] and by[cast['tick']-1]['hook_used'] is False,'next_H_without_real_restore')
            last=[f for f in frames if arrival<=f['tick']<arrival+12]
            require(len(last)==12 and all(f['grounded'] and f.get('crown_support') for f in last),'exit_not_stable')
        if variant=='skipLastH':
            require(len(frames)>=12 and all(BASE._support(f,next(p for p in m['platforms'] if p['id']=='entry')) for f in frames[-12:]),'skipLastH_actual_final_entry12')
            require([e.get('target') for e in events if e['kind']=='hook_contact_kick']==[a['anchor'] for a in program if a['action']=='H'],'skipLastH_actual_H_prefix')
    else:
        require(data.get('reached') is False and data.get('recovered') is True,'ablation_not_failed_and_recovered')
        if layout=='bridge_five':
            supports={p['id']:p for p in m['platforms']}
            require(len(frames)>=12 and all(BASE._support(f,supports['entry']) and f.get('entry_support') is True for f in frames[-12:]),'bridge_negative_recovery_not_actual_entry_fullsupport12')
            count=0;reached_physically=False
            for f in frames:
                count=count+1 if BASE._support(f,supports['crown']) else 0
                if count>=12:reached_physically=True
            require(not reached_physically,'bridge_ablation_actually_reached_receiver')
            if variant=='noH':require(not any(e['kind']=='hook_contact_kick' for e in events),'bridge_noH_actual_contact')
            if variant=='skipR':
                recovery=next((e['tick'] for e in events if e['kind']=='phase' and e.get('to')=='recover_walk'),frames[-1]['tick']+1)
                require(not any(e['kind']=='shot_fired' and e['tick']<recovery for e in events),'bridge_skipR_used_crossing_R')
            if variant in ['onlyR','naivejump']:
                recovery=next((e['tick'] for e in events if e['kind']=='phase' and e.get('to')=='recover_walk'),frames[-1]['tick']+1)
                shots=[e for e in events if e['kind']=='shot_fired' and e['tick']<recovery]
                require(len(shots)==(2 if variant=='onlyR' else 0),'bridge_ordinary_actual_shot_count')
                require(not any(e['kind'].startswith('hook_') for e in events),'bridge_ordinary_actual_H')
    if layout=='hollow_spiral':
        solids=[p['rect'] for p in m.get('platforms',[]) if not p.get('one_way')]
        for f in frames:
            x,y=f['position'];body=[x-12,y-18,24,36]
            require(not any(min(body[0]+body[2],r[0]+r[2])-max(body[0],r[0])>.2 and min(body[1]+body[3],r[1]+r[3])-max(body[1],r[1])>.2 for r in solids),'vertical_real_body_inside_solid')
        if variant=='onlyR':
            shots=[e for e in events if e.get('kind')=='shot_fired']
            require(len(shots)==2 and all(e.get('direction')==[0,1] for e in shots),'vertical_strong_control_two_upward_bursts')
            require(not any(e.get('kind','').startswith('hook_') for e in events),'vertical_strong_control_no_H')
        if variant=='skipR':require(not any(e.get('kind')=='shot_fired' for e in events),'vertical_R_ablation_fired')
        if variant=='skipLastH':require(data.get('reached') is False and data.get('recovered') is True,'vertical_last_H_must_fail_cleanly')
    return list(dict.fromkeys(errors))
# One fixed suite on the existing native runner, never recursive CLI/lock calls.
SUITE_CASES = (('arch_four', 'intended'), ('hook_hook', 'intended'),
               ('recoil_hook', 'intended'), ('bridge_five', 'intended'),
               ('bridge_five', 'noH'), ('bridge_five', 'skipR'),
               ('bridge_five', 'onlyR'), ('bridge_five', 'naivejump'),
               ('bridge_five', 'skipLastH'),
               ('hollow_spiral','intended'), ('hollow_spiral','onlyR'),
               ('hollow_spiral','naivejump'), ('hollow_spiral','noH'),
               ('hollow_spiral','skipR'), ('hollow_spiral','skipLastH'),
               ('hollow_spiral','skipLowerH'), ('thorn_mouth','intended'),
               ('recoil_hook_recoil','intended'))


def suite_case_errors(data, layout, variant):
    errors = validate(data, layout, variant)
    if (layout, variant) == ('bridge_five', 'skipLastH'):
        if data.get('reached') is not False or data.get('recovered') is not True:
            errors.append('suite_last_H_ablation_must_fail_and_recover')
        events = data.get('events', [])
        recovery = next((e['tick'] for e in events if e.get('kind') == 'phase'
                         and e.get('to') == 'recover_walk'), math.inf)
        actions = [('H' if e.get('kind') == 'hook_contact_kick' else 'R')
                   for e in events if e.get('tick', math.inf) < recovery
                   and e.get('kind') in ('hook_contact_kick', 'shot_fired')]
        prefix = data.get('manifest', {}).get('action_program', [])[:-1]
        if actions != [action['action'] for action in prefix]:
            errors.append('suite_last_H_ablation_actual_prefix_not_complete')
    return list(dict.fromkeys(errors))


def suite_complete(report):
    rows = report.get('runs', [])
    return (report.get('import', {}).get('status') == 'passed'
            and report.get('source_stable') is True
            and [(r.get('layout'), r.get('variant')) for r in rows] == list(SUITE_CASES)
            and all(r.get('status') == 'passed' and r.get('source_stable') is True
                    for r in rows))


def run_suite(args):
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    before = BASE.inventory()
    report = {'scope': 'fixed_local_real_Motor_18case_suite_not_formal_region_or_fun_acceptance',
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'source_before': before, 'requested_cases': [list(case) for case in SUITE_CASES],
              'runs': [], 'status': 'running'}
    def save():
        (out / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    def digest(files):
        return hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    started = time.monotonic()
    save()
    lock_path = ROOT / 'build/verification/engine.lock'
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with lock_path.open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            import_log = out / 'import.log'
            argv = ['bash', 'tools/godot.sh', '--headless', '--path', '.', '--editor', '--quit']
            imported = {'argv': argv, 'timeout_seconds': 90, 'status': 'running'}
            report['import'] = imported
            save()
            import_started = time.monotonic()
            try:
                with import_log.open('w') as stream:
                    result = subprocess.run(argv, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                                            timeout=90, env={**os.environ, 'LP_NUM_THREADS': '1'})
                text = import_log.read_text(errors='replace')
                after_import = BASE.inventory()
                imported.update(exit_code=result.returncode,
                                source_stable=after_import == before,
                                source_after_sha256=digest(after_import),
                                status='passed' if result.returncode == 0
                                and not BASE.ERRORS.search(text) and after_import == before else 'failed')
            except subprocess.TimeoutExpired:
                imported['status'] = 'timeout'
            finally:
                imported['seconds'] = time.monotonic() - import_started
                if import_log.is_file(): imported['log_sha256'] = hashlib.sha256(import_log.read_bytes()).hexdigest()
                save()
            if imported['status'] == 'passed':
                for index, (layout, variant) in enumerate(SUITE_CASES):
                    folder = out / f'{index:02d}-{layout}-{variant}'
                    folder.mkdir()
                    capture = folder / 'capture.json'
                    log = folder / 'native.log'
                    argv = ['bash', 'tools/godot.sh', '--headless', '--fixed-fps', '60', '--path', '.',
                            '--script', 'tests/forest_air_chain_runner.gd', '--', '--layout=' + layout,
                            '--launch-delay=' + str(args.launch_delay), '--variant=' + variant,
                            '--output=' + str(capture)]
                    case_started = time.monotonic()
                    case_before = BASE.inventory()
                    row = {'layout': layout, 'variant': variant, 'argv': argv,
                           'timeout_seconds': 45, 'status': 'failed',
                           'source_before_sha256': digest(case_before)}
                    report['runs'].append(row)
                    save()
                    try:
                        if case_before != before:
                            raise ValueError('Suite source changed before native case')
                        with log.open('w') as stream:
                            result = subprocess.run(argv, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                                                    timeout=45, env={**os.environ, 'LP_NUM_THREADS': '1'})
                        data = json.loads(capture.read_text()) if capture.is_file() else {}
                        errors = suite_case_errors(data, layout, variant) if data else ['capture_absent']
                        text = log.read_text(errors='replace')
                        ok = (result.returncode == 0 and not BASE.ERRORS.search(text) and not errors
                              and bool(re.search(r'^FOREST AIR CHAIN: .*passed=true', text, re.M)))
                        row.update(exit_code=result.returncode, validation_errors=errors,
                                   status='passed' if ok else 'failed')
                    except subprocess.TimeoutExpired:
                        row['status'] = 'timeout'
                    except (OSError, ValueError, TypeError, KeyError, IndexError, StopIteration) as error:
                        row['error'] = type(error).__name__ + ': ' + str(error)
                    finally:
                        case_after = BASE.inventory()
                        row.update(seconds=time.monotonic() - case_started,
                                   source_after_sha256=digest(case_after),
                                   source_stable=case_before == case_after == before)
                        if not row['source_stable']: row['status'] = 'failed'
                        for path, key in ((log, 'log_sha256'), (capture, 'capture_sha256')):
                            if path.is_file(): row[key] = hashlib.sha256(path.read_bytes()).hexdigest()
                        save()
                        print(json.dumps(row), flush=True)
                    if row['status'] != 'passed': break
    except (OSError, ValueError, TypeError, KeyError, IndexError, StopIteration) as error:
        report['error'] = type(error).__name__ + ': ' + str(error)
    finally:
        report['source_after'] = BASE.inventory()
        report['source_stable'] = report['source_after'] == before
        report['seconds'] = time.monotonic() - started
        report['status'] = 'passed' if suite_complete(report) else 'failed'
        save()
    print(f"FOREST AIR CHAIN SUITE: {report['status']} / {len(report['runs'])} cases")
    return 0 if report['status'] == 'passed' else 1

def main():
    p=argparse.ArgumentParser();p.add_argument('--launch-delay',type=int,choices=[1,2,3,4,5],default=1);p.add_argument('--output-dir',type=pathlib.Path,required=True);p.add_argument('--layout',choices=['arch_four','hook_hook','recoil_hook','bridge_five','hollow_spiral','thorn_mouth','recoil_hook_recoil'],default='arch_four');p.add_argument('--variant',choices=['intended','noH','skipR','onlyR','naivejump','skipLastH','skipLowerH','all'],default='intended');p.add_argument('--suite',action='store_true',help='Fixed eighteen cases on one import; no formal region admission');a=p.parse_args()
    if a.suite:
        if a.layout!='arch_four' or a.variant!='intended' or a.launch_delay!=1:
            p.error('--suite has fixed layout/variant/launch-delay inputs')
        return run_suite(a)
    out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    report={'scope':'local_real_Motor_golden_not_formal_region_or_fun_acceptance','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_before':BASE.inventory(),'runs':[],'status':'running'}
    def save():(out/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    save();variants=(['intended','noH','skipR','onlyR','naivejump']+(['skipLastH'] if a.layout in ['bridge_five','hollow_spiral'] else [])) if a.variant=='all' else [a.variant]
    with (ROOT/'build/verification/engine.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        for variant in variants:
            capture=out/(variant+'.json');log=out/(variant+'.log')
            argv=['bash','tools/godot.sh','--headless','--fixed-fps','60','--path','.','--script','tests/forest_air_chain_runner.gd','--','--layout='+a.layout,'--launch-delay='+str(a.launch_delay),'--variant='+variant,'--output='+str(capture)]
            started=time.monotonic();row={'variant':variant,'argv':argv}
            try:
                with log.open('w') as stream:r=subprocess.run(argv,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=45,env={**os.environ,'LP_NUM_THREADS':'1'})
                data=json.loads(capture.read_text()) if capture.exists() else {};errors=validate(data,a.layout,variant) if data else ['capture_absent']
                text=log.read_text(errors='replace');ok=r.returncode==0 and not BASE.ERRORS.search(text) and not errors and bool(re.search(r'^FOREST AIR CHAIN: .*passed=true',text,re.M))
                row.update(exit_code=r.returncode,validation_errors=errors,status='passed' if ok else 'failed',seconds=time.monotonic()-started,log_sha256=hashlib.sha256(log.read_bytes()).hexdigest())
            except subprocess.TimeoutExpired:row.update(status='timeout',seconds=time.monotonic()-started)
            report['runs'].append(row);save();print(json.dumps(row),flush=True)
            if row['status']!='passed':break
    report['source_after']=BASE.inventory();report['source_stable']=report['source_after']==report['source_before'];report['status']='passed' if len(report['runs'])==len(variants) and all(r['status']=='passed' for r in report['runs']) and report['source_stable'] else 'failed';save();print('FOREST AIR CHAIN GOLDEN:',report['status'],out)
    return 0 if report['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
