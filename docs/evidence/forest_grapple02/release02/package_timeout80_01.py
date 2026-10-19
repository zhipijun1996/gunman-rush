"""Seal only terminal timeout receipts/logs and completed-prefix hash references."""
from pathlib import Path
import json,hashlib,zipfile,re
R=Path.cwd();O=R/'build/forest_grapple02/ci_s2/release02_skeleton';S=lambda raw:hashlib.sha256(raw).hexdigest();F=R/'build/verification/harness/20261019T053645.986217Z';B=R/'build/forest_depth/region/harness-matrix/harness-4425a03c915044368d7912d3fe50a74e';outer=json.loads((F/'report.json').read_text());inner=json.loads((B/'receipt.json').read_text());check=outer['checks'][0]
assert outer['status']=='failed' and outer['targeted_checks'] and outer['release'] and check['status']=='timeout' and check['timeout_seconds']==600 and check['reused'] is False
assert inner['status']=='running' and len(inner['runs'])==59 and len(inner['requested_cases'])==80
assert all(c['status']=='passed' and c['exit_code']==0 and not c['errors'] for c in inner['runs'])
data={};rows=[]
for p in [F/'report.json',F/'forest-depth-region.log',B/'receipt.json',B/'import.log',B/'59-map1-change_mind/native.log',O/'timeout59-prefix-index01.json']:
 raw=p.read_bytes()
 if re.search(rb'[?&](?:sig|X-Amz-Signature)=|gh[pousr]_[A-Za-z0-9]{20}',raw):raise ValueError('Sensitive content: '+str(p))
 data[str(p.relative_to(R))]=raw
notes={'scope':'Whole original80 FAIL(timeout); 59 completed positives cannot approve whole corpus','HEAD_at_execution':outer['commit'],'git_status_at_execution':outer['git_status'],'whole_Harness_status':'failed','single_check_status':'timeout','original_cap_seconds':600,'check_seconds':check['duration_seconds'],'outer_wall_seconds':outer['wall_seconds'],'fresh_release':True,'reused':False,'inner_status_retained':'running; interrupted, no rewritten failed/source_stable field','completed_case_count':59,'requested_case_count':80,'completed_case_seconds':sum(c['seconds'] for c in inner['runs']),'interrupted_case_directory_index':59,'interrupted_request':inner['requested_cases'][59],'unverified_count_including_interrupted':21,'final_inner_source_stable':'not available and not invented','prefix_raw_storage':'59 original raw files remain build-only; their recorded capture/log SHA/path index is included, no large raw duplication','full89_or_new_release':'not passed','parent_content':'REVISE remains'}
data['derived/timeout80-custody01.json']=json.dumps(notes,indent=2).encode();(O/'timeout80-custody01.json').write_bytes(data['derived/timeout80-custody01.json'])
rows=[{'member':n,'sha256':S(raw),'bytes':len(raw)} for n,raw in sorted(data.items())];inside=json.dumps({'scope':notes['scope'],'members':rows},indent=2).encode();zp=O/'s2-local80-timeout-originals01.zip'
with zipfile.ZipFile(zp,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for n,raw in sorted(data.items()):z.writestr(n,raw)
 z.writestr('ARCHIVE-INVENTORY.json',inside)
with zipfile.ZipFile(zp) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(rows)+1
 for row in rows:assert S(z.read(row['member']))==row['sha256']
idx={'scope':notes['scope'],'archive_sha256':S(zp.read_bytes()),'archive_bytes':zp.stat().st_size,'archive_member_count':len(rows)+1,'members':rows,'inside_inventory_sha256':S(inside),'full_readback_verified':True,'no_completed_case_raw_copies':True};(O/'s2-local80-timeout-index01.json').write_text(json.dumps(idx,indent=2)+'\n');print(json.dumps({k:v for k,v in idx.items() if k!='members'}))
