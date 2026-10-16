"""Additional actual verifier receipt mutations; not native or worker execution."""
import copy,hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4];O=Path(__file__).resolve().parent;sys.path.insert(0,str(ROOT/'tools'))
import run_root_bell_formal as subject
actual=json.loads((O/'audit_03.actual.json').read_text());subject.validate_admission_audit(actual);changes=[]
for field in ['passed','old_hash','actual_new_loader_hash','old_version','actual_version','old_actor_count','actual_actor_count','actual_root_count']:
 changes.append(('loader_delete_'+field,lambda v,k=field:v['legacy_live_loader_compatibility'].pop(k)))
for field,value in [('old_actor_count',0),('actual_actor_count',0),('actual_actor_count',22),('actual_actor_count',True),('actual_actor_count','21'),('actual_root_count',1),('actual_root_count',False),('old_version','plains-region-v11-root-bell-v2'),('actual_version','plains-region-v11-root-bell-v2'),('old_hash','not-a-sha')]:
 changes.append(('loader_'+field+'_'+repr(value),lambda v,k=field,w=value:v['legacy_live_loader_compatibility'].__setitem__(k,w)))
for i in range(10):
 changes.extend([(f'physical_{i}_empty_reasons',lambda v,j=i:v['physical_negatives']['refused'][j].__setitem__('reasons',[])),(f'physical_{i}_missing_reasons',lambda v,j=i:v['physical_negatives']['refused'][j].pop('reasons')),(f'physical_{i}_false_reason',lambda v,j=i:v['physical_negatives']['refused'][j].__setitem__('reasons',[False])),(f'physical_{i}_empty_string_reason',lambda v,j=i:v['physical_negatives']['refused'][j].__setitem__('reasons',[' ']))])
for field,value in [('replaced',True),('replaced',False),('replaced',1.0),('replaced','0'),('replaced',2),('replaced',None),('status','one_candidate'),('version','root-bell-encounter-v1')]:
 changes.append(('row_candidate_'+field+'_'+repr(value),lambda v,k=field,w=value:v['rows'][0]['candidate'].__setitem__(k,w)))
for field,value in [('default_gate',0),('actual_seed','wrong'),('content_version','plains-region-v10'),('legacy_hash','wrong'),('map_index',True),('map_index',1.0)]:
 changes.append(('row_'+field+'_'+repr(value),lambda v,k=field,w=value:v['rows'][0].__setitem__(k,w)))
for field in ['candidate','default_gate','actual_seed','content_version','legacy_hash','root_seed','map_index']:
 changes.append(('row_delete_'+field,lambda v,k=field:v['rows'][0].pop(k)))
results=[]
for label,edit in changes:
 data=copy.deepcopy(actual);edit(data)
 try:subject.validate_admission_audit(data);results.append({'label':label,'refused':False})
 except Exception as e:results.append({'label':label,'refused':True,'exception':type(e).__name__,'reason':str(e)})
name=sys.argv[1] if len(sys.argv)>1 else 'extra';result={'scope':'Synthetic receipt mutations of actual native audit03 JSON; actual imported verifier only, no native run','source_sha256':hashlib.sha256((ROOT/'tools/run_root_bell_formal.py').read_bytes()).hexdigest(),'mutations':results};(O/(name+'.json')).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'source_sha256':result['source_sha256'],'total':len(results),'refused':sum(x['refused'] for x in results),'unexpected_accept':[x['label'] for x in results if not x['refused']]}))
