import sys,json,copy,hashlib,gzip
from pathlib import Path
R=Path.cwd();O=R/'build/plains_redesign/review_encounter_r2';sys.path.insert(0,str(R/'tools'))
import level_experience as e,level_formal as f
results=[]
def reject(name,c,o,mutate):
 c,o=copy.deepcopy((c,o));mutate(c,o)
 try:e.validate_cache_claim(c,o)
 except (ValueError,KeyError,TypeError) as error:results.append(dict(case=name,rejected=True,reason=str(error)))
 else:results.append(dict(case=name,rejected=False));raise AssertionError('accepted '+name)
def sync(o):
 for key in ['coins','health','meta']:o['after'][key]=copy.deepcopy(o['transaction']['after'][key])
 o['wallet_receipts']=copy.deepcopy(o['transaction']['after']['wallet_grants'])
actual=[]
for resource,path in [('coin','recovery.json'),('heart','recovery_heart.json'),('note','recovery_note.json')]:
 c=json.loads((O/path).read_text())['cases'][0];o=next(x for x in c['policy_observations'] if x.get('kind')=='actual_cache_claim');e.validate_cache_claim(c,o)
 tx=o['transaction'];event=tx['receipt_prefix']+'/'+o['chest']+'/resource';ledger={'coin':'wallet_grants','heart':'health_receipts','note':'meta_receipts'}[resource]
 actual.append(dict(resource=resource,output=o['claim_output'],before=o['before'],after=o['after'],event_id=event,receipt=tx['after'][ledger][event],returns=c['recovery_count'],frames=len(c['frames'])))
 reject(resource+'_missing_offer',c,o,lambda c,o:o['transaction'].pop('offer'))
 reject(resource+'_duplicate_candidate',c,o,lambda c,o:o['transaction']['offer']['candidates'].append(copy.deepcopy(o['transaction']['offer']['candidates'][0])))
 reject(resource+'_invalid_selected',c,o,lambda c,o:next(x for x in o['transaction']['offer']['candidates'] if x['id']==o['choice']).update(valid=False))
 reject(resource+'_wrong_final_stage',c,o,lambda c,o:next(s for s in c['formal_run_manifest_final']['stages'] if s['stage_index']==c['map_index']).update(stage_index=99))
 reject(resource+'_wrong_transaction_stage',c,o,lambda c,o:o['transaction'].update(stage_index=99))
 reject(resource+'_wrong_runprefix',c,o,lambda c,o:o['transaction'].update(receipt_prefix='other_run'))
 reject(resource+'_reused_receipt',c,o,lambda c,o:o['transaction']['before'][ledger].update({event:copy.deepcopy(o['transaction']['after'][ledger][event])}))
 def duplicate(c,o):
  o['transaction']['after'][ledger]['other_run/'+o['chest']+'/resource']=copy.deepcopy(o['transaction']['after'][ledger][event])
  if resource=='coin':o['transaction']['after']['coins']+=o['claim_output']['amount']
  elif resource=='note':
   for key in ['notes','meta_currency']:o['transaction']['after']['meta'][key]+=o['claim_output']['amount']
   o['transaction']['after']['meta']['profile_revision']+=1
  sync(o)
 reject(resource+'_duplicate_samecache_receipt',c,o,duplicate)
 def missingeffect(c,o):
  key={'coin':'coins','heart':'health','note':'meta'}[resource];o['transaction']['after'][key]=copy.deepcopy(o['transaction']['before'][key]);sync(o)
 reject(resource+'_missing_net_effect',c,o,missingeffect)
 def crossresource(c,o):
  o['transaction']['after']['wallet_grants']['other_run/'+o['chest']+'/resource']=3;o['transaction']['after']['coins']+=3;sync(o)
 # coin own ledger duplicate and other resource crossledger both must reject.
 reject(resource+'_crossresource_or_run_duplicate',c,o,crossresource)
 # Adjacent legal concurrent service transactions in same snapshot window.
 cc,oo=copy.deepcopy((c,o));oo['transaction']['after']['wallet_grants']['independent_other_chest/resource']=3;oo['transaction']['after']['coins']+=3;sync(oo);e.validate_cache_claim(cc,oo);results.append(dict(case=resource+'_legal_concurrent_wallet',accepted=True))
 if resource=='heart':
  for key,value in [('status',1),('epoch',999),('requested_amount',99),('amount_applied',2),('current',4)]:reject('heart_'+key,c,o,lambda c,o,key=key,value=value:o['transaction']['after'][ledger][event].update({key:value}))
  assert o['before']['health']==4 and o['after']['health']==5 and o['claim_output']['amount']==2 and tx['after'][ledger][event]['amount_applied']==1
 if resource=='note':
  for key,value in [('amount',999),('kind','upgrade')]:reject('note_'+key,c,o,lambda c,o,key=key,value=value:o['transaction']['after'][ledger][event].update({key:value}))
  reject('note_missing_revision',c,o,lambda c,o:(o['transaction']['after']['meta'].update(profile_revision=o['transaction']['before']['meta']['profile_revision']),sync(o)))
  cc,oo=copy.deepcopy((c,o));oo['transaction']['after']['meta_receipts']['other_note']={'kind':'notes','amount':2}
  for key in ['notes','meta_currency']:oo['transaction']['after']['meta'][key]+=2
  oo['transaction']['after']['meta']['profile_revision']+=1;sync(oo);e.validate_cache_claim(cc,oo);results.append(dict(case='note_legal_concurrent_note',accepted=True))
(O/'native_economy_summary.json').write_text(json.dumps(actual,indent=2));(O/'claim_neighbors.json').write_text(json.dumps(results,indent=2));print('CLAIM neighbors',len(results),'bad rejected',sum(x.get('rejected',False) for x in results))
# Revalidate original fresh 8 captures/invocations and old v2 reports without recapture.
fresh=json.loads((R/'build/verification/plains-encounter/run_j8vy1m2q/receipt.json').read_text());pairs=[];caps=[]
for side,paths in fresh['paired_cases'].items():
 for p in paths:
  path=R/p;c=json.loads(path.read_text());receipt=json.loads(path.with_suffix('.invocation.json').read_text());assert not f.validate_capture(path,c,receipt,path.with_suffix('.log'),current_sources=receipt['source_files']);e.validate_capture(c);caps.append(c)
  assert not f.validate_policy_basis(c,receipt['source_files'])
  initial=c['initial_capability'];final=c['final_capability'];diff=[k for k in initial if initial[k]!=final.get(k)]
  assert set(diff)<= {'shot_energy','combat_energy','position','scope'}
  for field in ['shot_energy','combat_energy']:
   assert {k:v for k,v in initial[field].items() if k not in ['current','_delay']}=={k:v for k,v in final[field].items() if k not in ['current','_delay']}
  pairs.append(dict(path=p,side=side,route_reached=c['route_reached'],outcome=c['outcome'],frames=len(c['frames']),initial_final_changed_keys=diff,driver_count=len(c['policy_basis']['driver_sources']),core_count=len(c['policy_basis']['core_invariants'])))
for a,b in zip(caps[:4],caps[4:]):assert a['policy_basis']==b['policy_basis']
# Every precise closure dependency and key core omission/change rejected by invocation basis.
c=caps[4];p=R/fresh['paired_cases']['after'][0];s=json.loads(p.with_suffix('.invocation.json').read_text())['source_files'];source_neighbors=[]
for field in ['driver_sources','core_invariants']:
 for key in c['policy_basis'][field]:
  if field=='core_invariants' and not any(x in key for x in ['motor','input','stamina','shoot','recoil','build']):continue
  for action in ['remove','change']:
   bad=copy.deepcopy(c)
   if action=='remove':bad['policy_basis'][field].pop(key)
   else:bad['policy_basis'][field][key]='0'*64
   assert f.validate_policy_basis(bad,s);source_neighbors.append(dict(field=field,key=key,action=action,rejected=True))
bad=copy.deepcopy(c);bad['runtime_source_hashes'].pop(next(iter(bad['runtime_source_hashes'])));assert f.validate_policy_basis(bad,s)
for version in [0,4,999,'3']:
 bad=copy.deepcopy(c);bad['capture_contract_version']=version
 try:e.validate_capture(bad)
 except ValueError:pass
 else:raise AssertionError('unknown version accepted')
oldindex=json.loads((R/'docs/evidence/plains_redesign/encounter/index.json').read_text());reports=[]
for row in oldindex['entries']:
 if '/run_ypk8st18/' in row['original_path'] and row['original_path'].endswith(('before_report.json','after_report.json')):
  report=json.loads(gzip.decompress((R/row['portable_path']).read_bytes()));e.validate_report(report);reports.append(dict(path=row['original_path'],fingerprint=report['fingerprint'],raw_sha256=row['raw_sha256']))
(O/'paired_and_sources.json').write_text(json.dumps(dict(pairs=pairs,source_neighbors=source_neighbors,old_reports=reports,unknown_versions_rejected=[0,4,999,'3']),indent=2));print('PAIRS',len(pairs),'SOURCEneighbors',len(source_neighbors),'OLDREPORTS',len(reports))
