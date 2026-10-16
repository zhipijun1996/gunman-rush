"""Independent offline audit of original native matrix; never executes Godot."""
import collections, hashlib, json, math, subprocess, sys, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
PACKAGE=ROOT/'docs/evidence/region_production_v3/final_multiseed_80'
sha=lambda b:hashlib.sha256(b).hexdigest()
summary=json.loads((PACKAGE/'summary.json').read_text())
archive=PACKAGE/'original_captures_receipts_and_logs.zip'
issues=[];rows=[];projections={};negative=[];positive=[]
sys.path.insert(0,str(ROOT/'tools'))
import level_formal
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    cases=summary['cases']
    expected={(('level-design-v2-baseline'+(f'/{i:02d}' if i else '')),m,s) for i in range(10) for m in (1,2) for s in ('fast','growth','deep','return')}
    identities=[(c['seed'],c['map_index'],c['strategy']) for c in cases]
    assert len(identities)==80 and len(set(identities))==80 and set(identities)==expected
    for c in cases:
        name=c['capture'];rp=name.replace('capture.json','capture.invocation.json');lp=name.replace('capture.json','capture.log')
        raw=z.read(name);receipt_raw=z.read(rp);lograw=z.read(lp)
        d=json.loads(raw);r=json.loads(receipt_raw)
        assert sha(raw)==c['capture_sha256']==r['capture_sha256']
        assert sha(receipt_raw)==c['receipt_sha256'] and sha(lograw)==c['log_sha256']==r['log_sha256']
        assert r['source_before']==r['source_after']==r['source_files'] and r['status']=='accepted' and r['exit_code']==0
        projections.setdefault(r['source_commit'],r['source_files'])
        assert projections[r['source_commit']]==r['source_files']
        # Original producer artifacts still exist; consume them under their exact
        # archived source projection, not the later mutable working checkout.
        assert (ROOT/name).read_bytes()==raw and (ROOT/lp).read_bytes()==lograw
        errs=level_formal.validate_capture(ROOT/name,d,r,ROOT/lp,current_sources=r['source_files'])
        assert not errs,(name,errs)
        fs=d['frames'];assert len(fs)==c['frames']==d['tick_count']
        assert [f['tick'] for f in fs]==list(range(1,len(fs)+1))
        assert all(math.isfinite(f['health']) and math.isfinite(f['shot_energy']) for f in fs)
        event_key=lambda e:json.dumps(e,sort_keys=True,separators=(',',':'))
        assert collections.Counter(map(event_key,d['events']))==collections.Counter(event_key(e) for f in fs for e in f['accepted_events'])
        assert all(e['tick']==f['tick'] for f in fs for e in f['accepted_events'])
        cap=d['initial_capability'];fin=d['final_capability']
        assert cap['equipped_weapon']['id']=='pulse_gun' and cap['equipped_weapon']['tier']==1
        assert cap['equipment_capacity']['status']=='single_current_weapon' and cap['effective_max_jumps']==1
        assert set(cap['granted_actions'])=={'jump','shot_recoil'}
        assert fin['equipped_weapon']['id']=='pulse_gun' and fin['effective_max_jumps']==1
        row={'identity':list((c['seed'],c['map_index'],c['strategy'])),'capture':name,'frames':len(fs),'event_count':len(d['events']),
             'source_commit':r['source_commit'],'source_count':len(r['source_files']),'outcome':d['outcome'],
             'min_health':min(f['health'] for f in fs),'final_health':fs[-1]['health'],'min_energy':min(f['shot_energy'] for f in fs),
             'final_position':fs[-1]['position'],'native_receipt_consumer_errors':errs,'contiguous_ticks':True,'complete_recorded_event_mirror':True}
        assert row['outcome']==c['outcome'] and d['route_reached']==c['route_reached']
        if d['outcome']=='route_policy_failed':
            diag=d['driver_diagnostics'][-1];target=diag['message'].split()[-1]
            enemies=[e for e in d['final_runtime']['enemies'] if e['id']==target]
            module=target.split('/window/')[-1].split('/')[0]
            row.update(diagnostics=d['driver_diagnostics'],last_frame={k:v for k,v in fs[-1].items() if k!='runtime'},
                       target_final_runtime=enemies,manifest_nodes=[n for n in d['manifest']['nodes'] if n['id']==module],
                       recent_target_observations=[x for x in d['policy_observations'] if x.get('enemy')==target][-10:],
                       failed_edge=d['edges'][-1],target_damage=[e for e in d['events'] if e.get('source','').startswith(target)])
            assert not d['route_reached'] and d['edges'][-1].get('aborted') and not d['edges'][-1]['reached']
            negative.append(row)
        elif d['outcome']=='route_target_reached':
            assert d['route_reached'] and d['edges'][-1]['reached']
            positive.append(row)
        else:raise AssertionError('Unexpected outcome')
        rows.append(row)
    alternatives=[]
    for name in z.namelist():
        if '/final_policy_alternative_' not in name or not name.endswith('/capture.json'):continue
        d=json.loads(z.read(name));r=json.loads(z.read(name.replace('capture.json','capture.invocation.json')))
        assert sha(z.read(name))==r['capture_sha256'] and r['source_before']==r['source_after']
        alternatives.append({'capture':name,'seed':d['root_seed'],'outcome':d['outcome'],'frames':d['tick_count'],
            'final_health':d['frames'][-1]['health'],'diagnostics':d['driver_diagnostics'],
            'damage_events':[e for e in d['events'] if e['kind']=='damage_committed'],
            'edges':d['edges'],'source_commit':r['source_commit']})
    disklog=z.read('build/region_production_v3/final_native/multiseed_80.log').decode()
    assert 'No space left on device' in disklog
# Reconstruct every declared source member from actual Git blobs, including when
# current files no longer equal this historical capture version. Hash each blob
# once, across six commits; none of the working files is modified.
requests=[];commit_entries={}
for commit,projection in projections.items():
    tree={}
    for item in subprocess.check_output(['git','ls-tree','-r','-z',commit],cwd=ROOT).split(b'\0'):
        if item:
            meta,path=item.split(b'\t');tree[path.decode()]=meta.decode().split()[2]
    commit_entries[commit]=[(n,tree[n],h) for n,h in projection.items()]
    requests.extend(obj for n,obj,h in commit_entries[commit])
objects=list(dict.fromkeys(requests))
p=subprocess.run(['git','cat-file','--batch'],input=('\n'.join(objects)+'\n').encode(),cwd=ROOT,capture_output=True,check=True)
pos=0;actual={}
for obj in objects:
    end=p.stdout.index(b'\n',pos);header=p.stdout[pos:end].split();size=int(header[-1]);pos=end+1
    data=p.stdout[pos:pos+size];pos+=size+1;assert header[0].decode()==obj and header[1]==b'blob'
    actual[obj]=sha(data)
projection_checks=[]
for commit,entries in commit_entries.items():
    mismatches=[n for n,obj,want in entries if actual[obj]!=want]
    assert not mismatches,(commit,mismatches)
    projection_checks.append({'commit':commit,'count':len(entries),'all_actual_git_blob_sha256_match':True,
                              'projection_sha256':sha(json.dumps(projections[commit],sort_keys=True,separators=(',',':')).encode())})
assert len(negative)==9 and len(positive)==71 and len(alternatives)==2
result={'kind':'independent_existing_native_matrix_audit','reviewer':'/root/v3_ecology_admission',
        'scope':'Original historical source projection; no fresh Godot/latest-source/visual/device/user approval',
        'archive_sha256':sha(archive.read_bytes()),'summary_sha256':sha((PACKAGE/'summary.json').read_bytes()),
        'unique_case_count':len(rows),'native_targets':len(positive),'native_policy_failures':len(negative),
        'actual_outcome_counts':dict(collections.Counter(r['outcome'] for r in rows)),
        'all80_receipts_hashes_contiguous_frames_and_recorded_event_mirrors_verified':True,
        'source_projections':projection_checks,'all_source_projection_dicts_equal':all(v==next(iter(projections.values())) for v in projections.values()),
        'source_scope_limit':'798 declared runtime/JSON/script members, not1072 whole movie/art texture closure; does not authenticate unobserved pixels.',
        'original_diskfull_failure_preserved':True,'original_reused':summary['validated_original_reuse'],'new_native':summary['new_native_executions'],
        'negative_cases':negative,'positive_case_metrics':positive,'actual_two_failed_alternatives':alternatives,
        'validator_sha256':sha((ROOT/'tools/level_formal.py').read_bytes()),
        'event_scope_limit':'Exact mirror proves complete recording against this producer event stream, not every possible uninstrumented game event or every player strategy.'}
(OUT/'audit_results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('Independent matrix:80 unique;71 targets;9 policy failures;2 alternative failures;6 Git projections verified. No native execution.')
