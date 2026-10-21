"""Independent style-continuity revalidation with explicit sources only."""
import argparse
import ast
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT=Path(__file__).resolve().parents[4]
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();folder=args.output.resolve();folder.mkdir(exist_ok=False)
    style_path='docs/creative_direction/bibles/style-continuity-20261021.json'
    style=json.loads((ROOT/style_path).read_bytes())
    skills=['region-creative-director','region-generator','art-director','visual-director','game-quality-gate','animation-vfx']
    sources=['tools/production_loop.py','tools/region_creative_direction.py','tools/level_region_context.py',
             'tools/level_design.py','tools/visual_director.py','tools/harness/profiles.json',
             'tests/test_region_bible.py','tests/test_level_design_routing.py','tests/test_level_region_context.py',
             'tests/test_production_loop.py','docs/creative_direction/bibles/registry.json',
             'docs/creative_direction/bibles/user-request.json',style_path,
             'docs/creative_direction/bibles/style-continuity-rebind-v1.json',
             'docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md',
             'docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md',
             'docs/creative_direction/windchime_plains.json','docs/creative_direction/thorn_forest.json',
             'docs/creative_direction/archive/creative-v4/windchime_plains.json',
             'docs/creative_direction/archive/creative-v4/thorn_forest.json','AGENTS.md','docs/creative_direction/README.md',
             *['.agents/skills/'+name+'/SKILL.md' for name in skills],
             *[row['path'] for row in style['runtime_reference']['references']]]
    sources=list(dict.fromkeys(sources));before={name:sha(ROOT/name) for name in sources}
    commands=[['python3','tests/test_region_bible.py'],['python3','tests/test_level_design_routing.py'],
              ['python3','tests/test_level_region_context.py'],
              ['python3','-m','unittest','test_production_loop.CreativeLoopTests.test_host_lease_binds_direction_hash_separately_from_skills',
               'test_production_loop.CreativeLoopTests.test_direction_change_inside_worker_cannot_receive_acceptance'],
              ['python3',str(Path(__file__).with_name('probe_style_guards.py')),'--output',str(folder/'independent-probes.json')],
              ['python3',str(Path(__file__).parents[1]/'independent-review/probe_workflow_gates_expanded.py'),
               '--output',str(folder/'prior-rework-probes.json')]]
    def execute(pair):
        index,command=pair;start=time.monotonic();env=dict(os.environ);env['PYTHONPATH']='tools:tests'
        process=subprocess.run(command,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=45)
        log=folder/('%02d.log'%index);log.write_bytes(process.stdout)
        counts=re.findall(rb'Ran (\d+) tests?',process.stdout)
        return {'command':command,'exit_code':process.returncode,'seconds':time.monotonic()-start,
                'test_count':int(counts[-1]) if counts else None,'log':log.name,'sha256':sha(log)}
    with ThreadPoolExecutor(max_workers=5) as pool:checks=list(pool.map(execute,enumerate(commands,1)))
    old=json.loads(subprocess.check_output(['git','show','HEAD:tools/harness/profiles.json'],cwd=ROOT,text=True))
    new=json.loads((ROOT/'tools/harness/profiles.json').read_bytes())
    contracts={'old_count':len(old['checks']),'new_count':len(new['checks']),
               'changed_or_missing_old_checks':[name for name,data in old['checks'].items() if new['checks'].get(name)!=data],
               'removed_old_memberships':{name:sorted(set(rows)-set(new['profiles'].get(name,[])))
                                          for name,rows in old['profiles'].items() if set(rows)-set(new['profiles'].get(name,[]))}}
    old_loop=ast.parse(subprocess.check_output(['git','show','HEAD:tools/production_loop.py'],cwd=ROOT,text=True))
    new_loop=ast.parse((ROOT/'tools/production_loop.py').read_text())
    protected=['snapshot','check_task_quality','validate_restored_budget','validate_restored_completion',
               '_verify_invocation','visual_capture_admission','resolved_check_contracts']
    functions=lambda tree:{node.name:ast.dump(node,include_attributes=False) for node in tree.body if isinstance(node,(ast.FunctionDef,ast.AsyncFunctionDef))}
    oa,na=functions(old_loop),functions(new_loop)
    protected_result={name:oa[name]==na[name] for name in protected}
    original=[]
    evidence=json.loads((ROOT/'docs/creative_direction/bibles/user-request.json').read_bytes())
    for row in evidence['attachments']:
        canonical=ROOT/'docs/creative_direction/bibles'/Path(row['staged_path']).name
        staged=ROOT/row['staged_path'];original_path=Path(row['original_attachment_path'])
        original.append({'path':str(canonical.relative_to(ROOT)),'sha256':sha(canonical),
                         'canonical_matches_original_evidence':sha(canonical)==row['sha256'] and canonical.stat().st_size==row['bytes'],
                         'staged_bytes_equal':staged.read_bytes()==canonical.read_bytes(),
                         'attachment_available':original_path.is_file(),
                         'attachment_bytes_equal':original_path.read_bytes()==canonical.read_bytes() if original_path.is_file() else None})
    impact=json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-rebind-v1.json').read_bytes())
    impact_result=[]
    for row in impact['bindings']:
        results={}
        for kind in ('old_direction','new_direction'):
            binding=row[kind];path=ROOT/binding['path'];data=json.loads(path.read_bytes())
            results[kind]=sha(path)==binding['sha256'] and data['version']==binding['version'] and data['region_bible']==binding['region_bible']
        impact_result.append({'region_id':row['region_id'],**results})
    after={name:sha(ROOT/name) for name in sources};changed=[name for name in sources if before[name]!=after[name]]
    passed=(all(c['exit_code']==0 for c in checks) and not changed and not contracts['changed_or_missing_old_checks']
            and not contracts['removed_old_memberships'] and all(protected_result.values())
            and all(r['canonical_matches_original_evidence'] and r['staged_bytes_equal'] and r['attachment_bytes_equal'] is not False for r in original)
            and all(r['old_direction'] and r['new_direction'] for r in impact_result))
    report={'reviewer':'/root/forest_discoveries_impl','scope':'Source-bound workflow/input-controller validation only; no engine, repository snapshot or actual pixels',
            'checks':checks,'source_before':before,'source_after':after,'changed_sources':changed,
            'original_bible_bytes':original,'impact_bindings':impact_result,'old_harness_contracts':contracts,
            'protected_original_loop_functions':protected_result,'passed':passed,'runner_sha256':sha(__file__)}
    save(folder/'report.json',report)
    print(json.dumps({'passed':passed,'commands':len(checks),'unit_tests':sum(c['test_count'] or 0 for c in checks),
                      'reviewed_sources':len(sources),'changed_sources':changed}))
    return 0 if passed else 1

if __name__=='__main__':raise SystemExit(main())
