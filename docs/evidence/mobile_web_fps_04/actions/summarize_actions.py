import json,hashlib,shutil
from pathlib import Path
root=Path('build/mobile_web_fps_04/actions'); out=Path('docs/evidence/mobile_web_fps_04/actions')
labels=['baseline-run-03','candidate-run-01','baseline-run-04']; reports=[json.loads((root/n/'report.json').read_text()) for n in labels]
b,c= [json.loads((root/n/'receipt.json').read_text()) for n in ['baseline-pack-03','candidate-pack-01']]
assert b['probe_sha256']==c['probe_sha256']
assert [k for k,v in b['source_sha256'].items() if c['source_sha256'][k]!=v]==['scripts/underworld_plains/underworld_foreground.gd']
checks={}
for key in ['runner_sha256','shared_runner_sha256','viewport_css','device_scale_factor','input_plan','region_before','input_layout']:
 checks[key]=all(r[key]==reports[0][key] for r in reports)
 assert checks[key],key
for key in ['player','camera','viewport','manifest','player_health','foreground']:
 checks['initial:'+key]=all(r['native']['initial'][key]==reports[0]['native']['initial'][key] for r in reports)
 assert checks['initial:'+key],key
rows=[]
for name,r in zip(labels,reports):
 assert r['status']=='captured_entry_action_window_no_phone_acceptance'
 n=r['native'];s=r['native_summary'];assert s['accepted_cue_deltas']=={'jump':4,'shot':4,'death':0} and s['airborne_rounds']==4
 row={'name':name,'fps':s['fps'],'frames':s['frames'],'elapsed_ms':s['elapsed_ms'],'p50_ms':s['frame_p50_ms'],'p95_ms':s['frame_p95_ms'],'p99_ms':s['frame_p99_ms'],'max_ms':s['frame_max_ms'],'over_budget':s['frame_over_budget'],'process_p50_ms':s['process_p50_ms'],'physics_p50_ms':s['physics_p50_ms'],'draw_calls_mean':s['draw_calls_mean'],'objects_mean':s['objects_mean'],'primitives_mean':s['primitives_mean'],'observed_actions':s['accepted_cue_deltas'],'airborne_rounds':s['airborne_rounds'],'methods':{}}
 for k in ['scripts/underworld_plains/underworld_foreground.gd:_observe','scripts/combat/shoot_ability.gd:_emit_round','scripts/dev/player_presentation_01/weapon_feel.gd:_shot']:
  v=n['costs'][k];row['methods'][k]={'calls':v[1],'total_ms':v[0]/1000,'mean_ms':v[0]/1000/v[1],'max_ms':v[2]/1000}
 rows.append(row)
 dst=out/name;dst.mkdir(exist_ok=True)
 for f in (root/name).iterdir():
  if f.suffix in ['.json','.log'] or f.name in ['plains-entry.png','plains-after-actions.png']:shutil.copy2(f,dst/f.name)
summary={'environment':'Chromium mobile viewport on cloud SwiftShader; not phone GPU/FPS','baseline':'published1394d114df73 source5caf4d4f','candidate_foreground_sha256':c['source_sha256']['scripts/underworld_plains/underworld_foreground.gd'],'checks':checks,'rows':rows,'limitations':['Single30s window per run; tiny4shot sample; no statistical FPS uplift claim','Actions accepted and initial state identical, but CDP latency/enemy phase and intermediate trajectory are not bit-identical','Inclusive wall-method times overlap and include scheduling; not summed CPU time','No browser audio capture in timing window; separate normal export validation required','Full large Plains loaded, stationary entry actions; not deep-map combat/longduration/device validation']}
(out/'comparison.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(rows,indent=2))
