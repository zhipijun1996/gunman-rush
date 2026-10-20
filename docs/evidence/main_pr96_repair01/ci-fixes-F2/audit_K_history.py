from pathlib import Path
import sys,json,hashlib,zipfile,importlib.util,copy
sys.path.insert(0,str(Path.cwd()/'tools'));import run_root_bell_tests as v
O=Path('build/forest_revision04/fix-F2-review');P=Path('build/forest_revision04/ci-final-H/root-bell-fix');H=Path('docs/evidence/region_production_v3/enemy')
def sha(b):return hashlib.sha256(b).hexdigest()
zp=H/'round2/round1_exact_sources.zip';assert sha(zp.read_bytes())=='59972c71bfb38680c51ac3bed5269b11ea55243c4c82b9c08d64bcfd30359f80'
with zipfile.ZipFile(zp) as z:
 assert len(z.namelist())==15 and set(z.namelist())==set(v.SOURCES)|{'source_manifest.json'}
 source=json.loads(z.read('source_manifest.json'))['source_sha256']
 for p,h in source.items():assert sha(z.read(p))==h
cap=(H/'g1_capture.json').read_bytes();report=json.loads((H/'g1_report.json').read_text());runtime=(H/'g1_runtime.log').read_bytes()
assert sha(cap)=='eebefac37b559336edbcd74770bff74e0c512725bf02b0cbb71384a15342903d'
stats=v.validate_evidence(cap,report,runtime,source,report['source_commit'],historical_no_stun=True)
content=v.tamper_checks(json.loads(cap),historical_no_stun=True);receipt=v.provenance_tamper_checks(cap,report,runtime,source,report['source_commit'],historical_no_stun=True)
assert len(content)==41 and len(receipt)==9
try:v.validate_evidence(cap,report,runtime,source,report['source_commit'])
except ValueError as e:default_refusal=str(e)
else:raise AssertionError('old artifact implicitly accepted as current')
a=json.loads((O/'K_independent_pure_audit.json').read_text());assert set(content)<=set(a['root_bell']['content_refusals_reexecuted']);assert set(receipt)<=set(a['root_bell']['receipt_refusals_reexecuted'])
spec=importlib.util.spec_from_file_location('candidate02',P/'candidate02-validator-reconstructed-exact.py');old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old);old.ROOT=Path.cwd()
assert sha((P/'candidate02-validator-reconstructed-exact.py').read_bytes())=='d2dc38a77f2c23537ecfe3aa02ca35e4f418dbc949c179700459a48b93a56de2'
d=json.loads(Path('build/root_bell/fix_H_damage_stun02/native165/capture.json').read_text());c=next(c for c in d['cases'] if c['id']=='solid_occlusion_negative')
for f in c['frames']:f['damage_stun_remaining']=1e-6;f['time']=c['frames'][0]['time']
old.validate_capture(d)
try:v.validate_capture(d)
except ValueError as e:epsilon_refusal=str(e)
else:raise AssertionError('final accepts counterexample')
r={'status':'PASS','historical_capture_sha256':sha(cap),'historical14_source_bytes_verified':True,'historical_stats':stats,'historical_content_refusals':content,'historical_receipt_refusals':receipt,'all_old_refusals_retained_in_current':True,'current_default_historical_refusal':default_refusal,'epsilon_actual02_counterexample':{'old_reconstructed_source_exact_execution_sha':True,'old_candidate_accepted':True,'final_rejected':True,'reason':epsilon_refusal},'no_native_reexecution':True}
(O/'K_independent_history_audit.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'status':'PASS','historical': [len(content),len(receipt)],'epsilon_old_accept_final_reject':True}))
