"""Run actual V12 spatial admission/version audit; reject native exit diagnostics."""
import argparse
import copy
import fcntl
import json
from pathlib import Path
import re
import subprocess
import time
from run_root_bell_ecology import ROOT, require, sha, source_files, godot_lock_path, native_runtime_failed


def validate(data):
    require(data.get('phase')=='all' and data.get('failures')==[],'Incomplete or failed actual native audit')
    rows=data.get('rows',[])
    expected={(prefix+str(i),m) for prefix in ('v3-root-bell-pilot-','plains-redesign-') for i in range(10) for m in (1,2)}
    require(len(rows)==40 and {(r.get('root_seed'),r.get('map_index')) for r in rows}==expected,'Missing/duplicate actual maps')
    qualified=[]
    for row in rows:
        require(type(row['map_index']) is int and row['map_index'] in (1,2),'Invalid map index type')
        require(re.fullmatch('[0-9a-f]{64}',row.get('legacy_v11_hash','')) and re.fullmatch('[0-9a-f]{64}',row.get('v12_hash','')),'Missing real versioned Manifest hashes')
        admission=row['admission'];n=admission.get('replaced')
        require(type(n) is int and n in (0,1) and type(row['enemy_count']) is int and row['enemy_count']>0,'Invalid replacement or enemy budget')
        require(admission['version']=='root-bell-encounter-v3' and admission['status']==('one_candidate' if n else 'no_physically_qualified_lane'),'Admission contradiction')
        if n:
            facts=admission['physical_facts'];qualified.append(facts['space_class'])
            require(row['map_index']==2 and facts['reasons']==[],'Unproved intro or physically refused class admitted')
            require((facts['space_class'],facts['recipe'],facts['floor_xywh'][2]) in [('double_gear_wide_bank','double_gear',620),('recovery_bridge_tight_bank','rescue_bank',560)],'Unreviewed physical class')
            require(facts['joint_space']['visual_keep_clear_xywh'][2]==facts['floor_xywh'][2]-80,'Joint scene contract lost negative space')
    require(sorted(qualified)==['double_gear_wide_bank','recovery_bridge_tight_bank'],'Unexpected coverage, not a probability target')
    negatives=data.get('physical_negatives',[])
    names={'width559','width561','wrong_recipe','one_way','non_bidirectional','own_ceiling','adjacent_danger','camp_endpoint','hazard_on_bank','removed_guard'}
    require(len(negatives)==10 and {x.get('mutation') for x in negatives}==names and all(x.get('refused') is True for x in negatives),'Missing/false physical rejection')
    saved=data.get('saved_map_compatibility',[])
    versions={'legacy_v10':'plains-region-v10','v2':'plains-region-v11-root-bell-v2','v3':'plains-region-v12-root-bell-spaces'}
    require(len(saved)==2 and {x.get('mode') for x in saved}=={'legacy_v10','v2'},'Missing actual historical loader compatibility')
    for row in saved:
        require(row['passed'] is True and row['old_version']==row['actual_version']==versions[row['mode']] and row['old_hash']==row['actual_hash'] and row['old_actors']==row['actual_actors']>0,'Historical hash/actors/version changed')
    replay=data.get('run_manifest_replay',[])
    require(len(replay)==3 and {x.get('mode') for x in replay}==set(versions),'Missing actual three-version replay')
    require(all(x.get('passed') is True and x.get('wrong_version_refused') is True and x.get('version')==versions[x['mode']] for x in replay),'Actual versioned RunManifest replay failed')
    return {'maps':40,'v11_root_maps':1,'v12_root_maps':2,'intro_root_maps':0,'physical_refusals':10,'saved_version_replays':2,'run_manifest_versions':3,'scope':data['scope']}


def mutations(data):
    def dropped(key):
        value=copy.deepcopy(data);value.pop(key);return value
    candidates=[('drop/'+key,dropped(key)) for key in ('physical_negatives','saved_map_compatibility','run_manifest_replay')]
    bad=copy.deepcopy(data);bad['rows'][0]['admission']['replaced']=True;candidates.append(('boolean_replacement',bad))
    bad=copy.deepcopy(data);bad['saved_map_compatibility'][0]['actual_hash']='different';candidates.append(('lost_old_hash',bad))
    bad=copy.deepcopy(data);bad['run_manifest_replay'][-1]['wrong_version_refused']=False;candidates.append(('version_false_accept',bad))
    refused=[]
    for label,bad in candidates:
        try:validate(bad)
        except (ValueError,KeyError,TypeError,IndexError):refused.append(label)
        else:raise ValueError('Audit receipt mutation accepted '+label)
    return refused


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output-dir',default='build/production_repair/ecology/spaces_'+str(time.time_ns()));args=parser.parse_args()
    folder=(ROOT/args.output_dir).resolve();require(folder.is_relative_to(ROOT/'build/production_repair/ecology') and not folder.exists(),'Use a new bounded ecology output directory')
    folder.mkdir(parents=True)
    before=source_files();report={'status':'failed','source_before':before,'started_at_unix':time.time(),'scope':'actual native spatial/version audit; not input-only traversal, pixels, device or player acceptance'}
    try:
        command=['bash','tools/godot.sh','--headless','--fixed-fps','60','--path','.','--script','tests/root_bell_spaces_runner.gd','--','--output=res://'+str((folder/'audit.json').relative_to(ROOT))]
        report['command']=command;waiting=time.monotonic()
        with godot_lock_path(ROOT).open('a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX);report['engine_lock_wait_seconds']=time.monotonic()-waiting
            started=time.monotonic()
            with (folder/'runtime.log').open('w') as log:actual=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=240)
            report['native_verification_seconds']=time.monotonic()-started
        report['exit_code']=actual.returncode;log=(folder/'runtime.log').read_text()
        require(not native_runtime_failed(actual.returncode,log),'Actual audit process failed or leaked resources; preserve diagnostics')
        report['observed']=validate(json.loads((folder/'audit.json').read_text()));report['mutation_refusals']=mutations(json.loads((folder/'audit.json').read_text()))
        report['source_after']=source_files();require(before==report['source_after'],'Source drift during actual audit')
        report['status']='passed';print('ROOT BELL SPACES VERIFIED:',json.dumps(report['observed']));return 0
    except Exception as error:report['error']=type(error).__name__+': '+str(error);raise
    finally:
        report['ended_at_unix']=time.time();report['usage']={'tokens':'not_exposed','price':'not_exposed'}
        (folder/'report.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':raise SystemExit(main())
