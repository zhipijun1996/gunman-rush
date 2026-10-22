"""Independent bounded source/input probes; no engine or repository snapshot."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools'))
import production_loop as loop
import region_creative_direction as creative
import level_design


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('Preserve original review evidence; use a new output path')
    rows = []
    def case(label, condition, **details):
        rows.append(dict(case=label, passed=bool(condition), **details))

    reg = creative.load_bible_registry()
    authority = creative.supplemental_authority({}, 'thorn_forest')
    refs = authority['content']['runtime_reference']['references']
    style_ref = {key: authority[key] for key in ('path', 'sha256')}
    reference_inputs = [{key: row[key] for key in ('path','sha256')} for row in refs]
    original_expected = {
        'windchime_plains':'02c9dd3299d12c91a426cf40b2a5885e526b51f467b955539b4b5ff99e1aca35',
        'thorn_forest':'a7bad8323af64a7be0577132e5d988a6e1b781d9e1ac1639d37f9d65935194e3',
    }
    for region, expected in original_expected.items():
        bible, ref = creative.bind_region_bible(region)
        task = {'id':'REVIEW','goal':'Inspect regional source','region_id':region,'region_bible':ref,
                'skills':['gameplay-reviewer'],'checks':['docs'],'read_only':True}
        source_inputs = loop.bound_source_inputs(task)
        with tempfile.TemporaryDirectory() as output:
            prompt, *_ = loop.prepare_call(task, {'objective':'Inspect region'}, 'implement', Path(output), '{}', check_contracts={'checks':[]})
        case('valid_original_'+region,
             sha(ROOT/ref['path']) == expected and bible['music_status']=='deferred_user_supplied'
             and (ROOT/ref['path']).read_text() in prompt
             and all(item in source_inputs for item in [style_ref,*reference_inputs])
             and authority['content']['source']['additional_quote'] in prompt,
             original_sha256=sha(ROOT/ref['path']), source_input_count=len(source_inputs))
        for mutation in ('omit','forge'):
            changed = copy.deepcopy(task)
            if mutation == 'omit':
                for key in creative.SUPPLEMENT_FIELDS: changed['region_bible'].pop(key)
            else: changed['region_bible']['supplemental_authority_sha256']='0'*64
            error = ''
            try: loop.region_bible_input(changed)
            except ValueError as exc: error=str(exc)
            case('handwritten_'+mutation+'_supplement_'+region, bool(error), error=error)

    missing = [row['region_id'] for row in reg['regions'] if row['current_bible'] is None]
    case('fourteen_missing_bibles',len(missing)==14,region_ids=missing)
    for region in missing:
        mission = level_design.route_request('create '+region)
        task = mission['tasks'][0]
        inputs = loop.bound_source_inputs(task)
        with tempfile.TemporaryDirectory() as output:
            prompt, *_ = loop.prepare_call(task,mission,'implement',Path(output),'{}',check_contracts={'checks':[]})
        valid = (task.get('shared_style_authority')==style_ref and task['required_gates']==['G0']
                 and task.get('preproduction_only') is True and task.get('completion')=='stage'
                 and all(p.startswith('docs/') for p in task['allowed_paths'])
                 and all(item in inputs for item in [style_ref,*reference_inputs])
                 and authority['content']['source']['quote'] in prompt
                 and authority['content']['source']['additional_quote'] in prompt)
        changed=copy.deepcopy(task);changed.pop('shared_style_authority')
        omitted_error=''
        try: loop.region_bible_input(changed)
        except ValueError as exc: omitted_error=str(exc)
        changed=copy.deepcopy(task);changed['allowed_paths'].append('scripts/generation/'+region+'_region.gd')
        escape_error=''
        try: loop.region_bible_input(changed)
        except ValueError as exc: escape_error=str(exc)
        case('future_proposed_'+region, valid and bool(omitted_error) and bool(escape_error),
             source_input_count=len(inputs),omitted_error=omitted_error,production_escape_error=escape_error)

    for path in ['scripts/player/player_motor.gd','scripts/player/traversal_ability.gd',
                 'scripts/run/demo_lifetime.gd','config/player_tuning.json','docs/controls_contract.md']:
        task={'goal':'Correct shared behavior','allowed_paths':[path]}
        with patch.object(creative,'supplemental_authority',side_effect=AssertionError('Unrelated task loaded art authority')):
            case('unrelated_shared_'+path,loop.region_bible_input(task) is None and loop.shared_style_input(task) is None)

    names = ['docs/world_regions.json',creative.BIBLE_REGISTRY,
             'docs/creative_direction/bibles/user-request.json',
             'docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md',
             'docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md',
             '.agents/skills/gameplay-reviewer/SKILL.md',authority['path'],*[r['path'] for r in refs]]
    with tempfile.TemporaryDirectory() as output:
        fixture=Path(output)
        for name in names:
            target=fixture/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
        _,ref=creative.bind_region_bible('thorn_forest',fixture)
        task={'id':'REVIEW','goal':'Inspect regional source','region_id':'thorn_forest','region_bible':ref,
              'skills':['gameplay-reviewer'],'checks':['docs'],'read_only':True}
        m={'schema_version':1,'objective':'制作荆棘森林','max_calls':2,'max_rounds':1,'call_timeout_seconds':10,'tasks':[task]}
        future=level_design.route_request('create firefly_marsh')
        future_task=future['tasks'][0]
        # Each changed input independently reaches the actual controller preflight,
        # resume entry and before/after-worker guard; snapshot is forbidden except
        # for an explicit synthetic empty model during the post-worker unit probe.
        changing=[authority['path'],*[r['path'] for r in refs if r['role'] in
                    {'material_shader','tileset','atlas','source_pixels','tile_build','player_style_reference'}]]
        for index,name in enumerate(changing):
            source=fixture/name;raw=source.read_bytes()
            for kind,selected in [('production',m),('proposed',future)]:
                source.write_bytes(raw+b'\nreview drift\n')
                folder=fixture/('fresh-'+kind+'-'+str(index));error=''
                with patch.object(loop,'ROOT',fixture),patch.object(loop,'snapshot',side_effect=AssertionError('No repository snapshot')),patch.object(loop,'native_import_preflight',side_effect=AssertionError('No engine')):
                    state=loop.run(selected,folder,lambda *a: (_ for _ in ()).throw(AssertionError('No worker')))
                case('before_call_'+kind+'_'+name,state.get('calls')==0 and state.get('region_bible_blocked') is True,calls=state.get('calls'))
                checkpoint=folder/'state.json';prior=checkpoint.read_bytes()
                with patch.object(loop,'ROOT',fixture),patch.object(loop,'snapshot',side_effect=AssertionError('No repository snapshot')),patch.object(loop,'native_import_preflight',side_effect=AssertionError('No engine')):
                    try:loop.run(selected,folder,lambda *a: (_ for _ in ()).throw(AssertionError('No worker')))
                    except ValueError as exc:error=str(exc)
                case('resume_'+kind+'_'+name,error.startswith('Restored Bible source/binding changed') and checkpoint.read_bytes()==prior,error=error,checkpoint_preserved=checkpoint.read_bytes()==prior)
                source.write_bytes(raw)
            for kind,selected_task,selected_m in [('production',task,m),('proposed',future_task,future)]:
                attempt=fixture/('worker-'+kind+'-'+str(index))/'1';attempt.mkdir(parents=True)
                state={'calls':0};state_path=attempt.parent/'state.json';called=[];error=''
                def worker(*args):
                    called.append(True);source.write_bytes(raw+b'\nworker drift\n')
                    return {'status':'ready_for_review','summary':'synthetic test','findings':[]}
                with patch.object(loop,'ROOT',fixture),patch.object(loop,'snapshot',return_value={'synthetic_bounded_fixture':True}):
                    try:loop._call_with_retries(selected_task,selected_m,'implement',attempt,'{}',state,state_path,worker)
                    except ValueError as exc:error=str(exc)
                case('during_worker_'+kind+'_'+name,len(called)==1 and state['calls']==1 and bool(error),calls=state['calls'],error=error)
                source.write_bytes(raw)
                creative.validate_bible_binding(ref,root=fixture)

    result={'reviewer':'/root/forest_discoveries_impl','scope':'Independent source/input-controller checks; no engine/full repository snapshot/visual or content acceptance',
            'cases':rows,'passed':all(row['passed'] for row in rows),'runner_sha256':sha(Path(__file__))}
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'passed':result['passed'],'cases':len(rows),'failed':[r['case'] for r in rows if not r['passed']]}))
    return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
