"""Actual imported Python verifier against actual JSON plus explicitly mutated copies; no worker/native execution."""
import copy,hashlib,importlib.util,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'tools'))
import run_root_bell_formal as subject
O=Path(__file__).resolve().parent
P=ROOT/'build/region_production_v3/root_bell_run_replay_fix/audit_03.json'
if not P.exists():P=O/'audit_03.actual.json'
actual=json.loads(P.read_text());result={'scope':'Actual Python receipt verification; all mutations synthetic copies of real actual audit JSON, no additional native runs or mocked workers','source_sha256':hashlib.sha256((ROOT/'tools/run_root_bell_formal.py').read_bytes()).hexdigest(),'audit_path':str(P),'audit_sha256':hashlib.sha256(P.read_bytes()).hexdigest(),'actual_result':subject.validate_admission_audit(actual),'mutations':[]}
mutations=[]
for key in ['rows','failures','physical_negatives','legacy_live_loader_compatibility','run_manifest_replay']:
 mutations.append(('delete_'+key,lambda v,k=key:v.pop(k)))
for key in ['passed','failures','cases','negatives']:
 mutations.append(('delete_replay_'+key,lambda v,k=key:v['run_manifest_replay'].pop(k)))
for i in range(5):
 mutations.extend([(f'case_{i}_delete',lambda v,j=i:v['run_manifest_replay']['cases'].pop(j)),(f'case_{i}_false',lambda v,j=i:v['run_manifest_replay']['cases'][j].__setitem__('passed',False)),(f'case_{i}_duplicate',lambda v,j=i:v['run_manifest_replay']['cases'].__setitem__(j,copy.deepcopy(v['run_manifest_replay']['cases'][(j+1)%5])))])
for i in range(9):
 mutations.extend([(f'negative_{i}_delete',lambda v,j=i:v['run_manifest_replay']['negatives'].pop(j)),(f'negative_{i}_false',lambda v,j=i:v['run_manifest_replay']['negatives'][j].__setitem__('refused',False)),(f'negative_{i}_duplicate',lambda v,j=i:v['run_manifest_replay']['negatives'].__setitem__(j,copy.deepcopy(v['run_manifest_replay']['negatives'][(j+1)%9])))])
mutations.extend([('duplicate_map',lambda v:v['rows'].__setitem__(0,copy.deepcopy(v['rows'][1]))),('legacy_byte_false',lambda v:v['rows'][0].__setitem__('legacy_default_byte_equal',False)),('replay_pass_false',lambda v:v['run_manifest_replay'].__setitem__('passed',False)),('loader_pass_false',lambda v:v['legacy_live_loader_compatibility'].__setitem__('passed',False)),('duplicate_physical',lambda v:v['physical_negatives']['refused'].__setitem__(1,copy.deepcopy(v['physical_negatives']['refused'][0]))),('erase_physical_reasons',lambda v:v['physical_negatives'].__setitem__('refused',[{} for _ in range(10)])),('row_default_gate_false',lambda v:v['rows'][0].__setitem__('default_gate',False)),('row_ineligible_replaced_negative',lambda v:v['rows'][0]['candidate'].__setitem__('replaced',-1)),('loader_unequal_hash',lambda v:v['legacy_live_loader_compatibility'].__setitem__('actual_new_loader_hash','wrong'))])
for label,edit in mutations:
 value=copy.deepcopy(actual);edit(value)
 try:subject.validate_admission_audit(value);result['mutations'].append({'label':label,'refused':False})
 except Exception as e:result['mutations'].append({'label':label,'refused':True,'exception':type(e).__name__,'reason':str(e)})
label=sys.argv[1] if len(sys.argv)>1 else 'probe';(O/(label+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'source_sha256':result['source_sha256'],'actual_pass':True,'mutations':len(result['mutations']),'refused':sum(v['refused'] for v in result['mutations']),'unexpected_accept':[v['label'] for v in result['mutations'] if not v['refused']]}))
