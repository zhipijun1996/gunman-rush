import hashlib,json,statistics
from pathlib import Path
root=Path(__file__).resolve().parent
names=['debug-profile-01','release-profile-01','debug-fixed-cache-01','debug-baseline-return-01']
docs=[];baseline_states={};sources={};checks=[]
for name in names:
 p=root/name/'report.json';d=json.loads(p.read_text());identity=d['identity']['contents'];meta=d['served_metadata']
 assert d['status']=='captured_cloud_frame_samples_no_phone_acceptance'
 assert not d['page_errors']
 assert not any('SCRIPT ERROR:' in s or 'SHADER ERROR:' in s for s in d['logs'])
 assert d['runner_sha256']=='daa1192a39ac629c619926b97498f96433d021fbbaa8998f34c548e2b67b4257'
 assert meta['source_commit']==identity['source_commit']=='5f55716a838a754a938997920ff18cb3b17452b5'
 assert meta['build_id']==identity['diagnostic_pack_sha256'][:12]
 pair_name='fixed-cache-pair-01' if 'fixed-cache' in name else 'profile-pair-01'
 pair=json.loads((root/pair_name/'pair-receipt.json').read_text())
 assert pair['measured_pack']['sha256']==identity['diagnostic_pack_sha256']
 variant=next(v for v in pair['variants'] if v['mode']==meta['engine_template'])
 assert meta==variant['metadata']
 assert meta['threads_enabled'] and meta['audio_supply']=='dedicated_thread'
 assert d['plains_region_event']['manifest_hash']=='d38685563f9fc81224e96af0eef040e3c736b50bd3bc90d83d9d27b4f0ab0a1f'
 assert not d['plains_region_event']['debug_entry']
 rows=[]
 for r in d['rows']:
  c=r['canvas'];assert c['isolated'] and c['dpr']==2.5 and c['width']==2132 and c['height']==725
  native=r['native'];summary=r['native_summary'];browser=r['browser_summary']
  assert browser['closed_on_raf'] and browser['interval_coverage_fraction']>.9
  for edge in ['initial','final']:
   state=native[edge];assert not state['tree_paused'] and state['menu']==''
   state={k:state[k] for k in ['context','player','camera','viewport','manifest','foreground']}
   baseline_states.setdefault(r['scene'],state)
   assert state==baseline_states[r['scene']],(name,r['scene'],edge,state)
  rows.append({'scene':r['scene'],'repeat':r['repeat'],**summary,'browser_coverage':browser['interval_coverage_fraction']})
 docs.append({'name':name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'rows':rows})
 checks.append({'report':name,'identity_and_conditions_equal':True})
 for scene in ['home','plains']:
  rr=[r for r in rows if r['scene']==scene]
  print(name,scene,'FPS',round(sum(r['frames'] for r in rr)*1000/sum(r['elapsed_ms'] for r in rr),3),'P95 samples',[round(r['frame_p95_ms'],3) for r in rr])
result={'checks':checks,'conditions':baseline_states,'groups':docs,'scope':'Cloud software WebGL. Matched snapshots do not establish equal world simulation time throughout windows. Inclusive method costs overlap. No phone/GPU FPS claim; sequential runs are noisy. Old vanilla boundary failures remain separate.'}
(root/'profile-comparison-audit.json').write_text(json.dumps(result,indent=2)+'\n')
