"""Read-only audit of downloaded ORIGINAL CI lane ZIPs; never runs a check."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys,zipfile,tempfile
R=Path('/workspace/gunman-rush');sys.path.insert(0,str(R/'tools'));import harness
p=argparse.ArgumentParser();p.add_argument('--folder',type=Path,required=True);p.add_argument('--commit',required=True);p.add_argument('--parallel-sha',required=True);p.add_argument('--serial-sha',required=True);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
assert not args.output.exists(), 'Refuse an existing audit output; use a fresh run-specific path'
assert (R/'tools/harness.py').read_bytes()==subprocess.check_output(['git','show',args.commit+':tools/harness.py'],cwd=R), 'Verifier library differs from frozen CI source'
assert (R/'tools/harness/profiles.json').read_bytes()==subprocess.check_output(['git','show',args.commit+':tools/harness/profiles.json'],cwd=R), 'Verifier manifest differs from frozen CI source'
manifest=json.loads(subprocess.check_output(['git','show',args.commit+':tools/harness/profiles.json'],cwd=R));ids=harness.resolve_checks(manifest,['full']);result={'scope':'Original full167 lane evidence/source integrity, not gameplay execution or subjective/device acceptance','commit':args.commit,'assertions':0,'failures':[]};tokens=set();reports={};report_paths={};allchecks={}
def ck(ok,label):
 result['assertions']+=1
 if not ok:result['failures'].append(label)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest_sha=hashlib.sha256(subprocess.check_output(['git','show',args.commit+':tools/harness/profiles.json'],cwd=R)).hexdigest()
for lane,wantsha in [('parallel',args.parallel_sha),('serial',args.serial_sha)]:
 archive=args.folder/('phase-'+lane+'.zip');ck(sha(archive)==wantsha,lane+' actual GitHub API ZIP digest')
 z=zipfile.ZipFile(archive);assert len(z.namelist())==len(set(z.namelist())), 'Duplicate ZIP members';safe=all(not Path(n).is_absolute() and '..' not in Path(n).parts and ((i.external_attr >> 16) & 0o170000) != 0o120000 for i in z.infolist() for n in [i.filename]);ck(safe,lane+' bounded archive paths and no linked entries');assert safe;out=Path(tempfile.mkdtemp(prefix=lane+'-',dir=args.folder));z.extractall(out)
 rp=list(out.rglob('report.json'));ck(len(rp)==1,lane+' one original report');d=json.loads(rp[0].read_text());reports[lane]=d;report_paths[lane]=rp[0];base=rp[0].parent
 ck(d['schema_version']==1 and d['profiles']==['full'] and d['requested_checks']==ids and not d['changed_paths'],lane+' exact original full selected scope')
 ck(d['status']=='passed' and d['partial'] is True and d['approval_scope']=='partial' and d['release'] is True and d['jobs']==1 and d['targeted_checks'] is False,lane+' real fresh partial-lane declaration')
 ck(d['manifest_sha256']==manifest_sha and d['commit']==args.commit,lane+' exact frozen source and manifest')
 ck(d['source_files']==d['source_files_after'] and d['toolchain']==d['toolchain_after'],lane+' source/toolchain stability')
 ck([c['id'] for c in d['checks']]==harness.lane_checks(manifest,ids,lane),lane+' exact physical ownership and order')
 for c in d['checks']:
  name=c['id'];expected=manifest['checks'][name];allchecks[name]=c
  ck(c['argv']==expected['argv'] and c['timeout_seconds']==expected['timeout_seconds'] and c['success_pattern']==expected['success_pattern'],name+' original argv/budget/marker')
  ck(c.get('reused') is False and c['status']=='passed' and type(c['exit_code']) is int and c['exit_code']==0 and c.get('failure_reason') is None,name+' actual fresh pass')
  ck(c['input_digest']==harness.input_digest(expected,sorted(d['source_files']),d['toolchain'],snapshot=d['source_files']),name+' dependency digest')
  token=c['check_token'];ck(isinstance(token,str) and re.fullmatch('[0-9a-f]{32}',token) and token not in tokens,name+' unique actual check token');tokens.add(token)
  assert c['log']==name+'.log', 'Unexpected log basename';raw=(base/c['log']).read_bytes();text=raw.decode(errors='replace');ck(hashlib.sha256(raw).hexdigest()==c['log_sha256'] and re.search(expected['success_pattern'],text,re.MULTILINE) is not None,name+' original log digest and completion')
  ck(re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script|ObjectDB.*leaked|resources? still in use at exit',text) is None,name+' no strict engine/lifecycle errors')
a,b=reports['parallel'],reports['serial'];metadata={k:a[k] for k in ['working_files','commit','git_status','diff','untracked']};original_merged=harness.verify_lane_reports(manifest,['full'],list(report_paths.values()),metadata,a['source_files']);ck(len(original_merged['checks'])==167,'frozen original Harness verifier accepts complete two-lane receipts');ck(a['source_files']==b['source_files'] and a['toolchain']==b['toolchain'],'same prepared source and toolchain across two physical lanes');ck(set(allchecks)==set(ids) and len(allchecks)==167 and len(tokens)==167,'all167 unique/fresh checks with no omission');prepared=a.get('working_files',{});ck(all(n.startswith('resources/foundry/') and n.endswith('.json') for n in prepared),'prepared modifications remain only existing Foundry JSON');ck(not a.get('untracked'),'no untracked prepared phase sources')
ck(all(a['source_files'].get(n)==v for n,v in prepared.items()),'every declared prepared working-file digest matches shared source inventory')
# These are exact task production bytes; docs/media evidence may be later.
prefixes=('scripts/','scenes/','resources/','config/','assets/','shaders/');paths=subprocess.check_output(['git','diff','--name-only','2ac54f9f15fd6c174e7e91ed4ffafa3cf50ab3c8',args.commit],cwd=R,text=True).splitlines();changed=[n for n in paths if n.startswith(prefixes) or n in ['project.godot','export_presets.cfg']];mismatch=[]
for name in changed:
 raw=subprocess.check_output(['git','show',args.commit+':'+name],cwd=R);actual=hashlib.sha256(raw).hexdigest()
 if a['source_files'].get(name)!=actual:mismatch.append(name)
ck(not mismatch,'every current task production byte matches exact Git source and both CI inventories')
result.update(phase_counts={k:len(v['checks']) for k,v in reports.items()},fresh=len(allchecks),reused=0,stable_source_items=len(a['source_files']),prepared_modified_paths=sorted(prepared),task_production_compared=changed,task_production_mismatches=mismatch,phase_report_sha={k:sha(report_paths[k]) for k in reports},limits=['Lane receipts are partial separately; official affected job must still validate complete prepared input closure and merge.','No device, listening, user or subjective visual approval.'])
args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k not in ['prepared_modified_paths','task_production_compared']},ensure_ascii=False,indent=2));raise SystemExit(bool(result['failures']))
