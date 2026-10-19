from pathlib import Path
import yaml,json,hashlib,tempfile,subprocess,os,shutil,re
R=Path('/workspace/gunman-rush-design');D=Path(__file__).resolve().parent;old=(D/'environment.before.yml.txt').read_text();new=(R/'.github/workflows/environment.yml').read_text()
start='      - name: Collect the unique original phase report';end='      - uses: actions/upload-artifact@v4'
a=old.index(start);b=old.index(end,a);c=new.index(start);d=new.index(end,c);assert new[:c]+old[a:b]+new[d:]==old
job=yaml.safe_load(new)['jobs']['core_checks'];collector=next(s['run'] for s in job['steps'] if s.get('name')=='Collect the unique original phase report and check stdout logs');code=collector.split("python3 - <<'PYCODE'\n",1)[1].rsplit('\nPYCODE',1)[0];compile(code,'actual-inline-collector','exec')
rows=[]
labels=['valid','missing_report','two_reports','missing_log','escape_log','report_symlink','report_directory_symlink','harness_ancestor_symlink','log_symlink','log_parent_symlink','proof_parent_symlink','report_not_regular','repo_via_alias']
for label in labels:
 with tempfile.TemporaryDirectory(prefix='ci-lanes02-') as temp:
  base=Path(temp);root=base/'repo';root.mkdir();folder=root/'build/verification/harness/run';folder.mkdir(parents=True)
  log='../outside.log' if label=='escape_log' else 'nested/first.log' if label=='log_parent_symlink' else 'first.log'
  (folder/'report.json').write_text(json.dumps({'checks':[{'log':log}]}));(folder/'first.log').write_bytes(b'PASS: original stdout\n')
  if label=='missing_report':(folder/'report.json').unlink()
  elif label=='two_reports':other=folder.parent/'other';other.mkdir();(other/'report.json').write_text('{}')
  elif label=='missing_log':(folder/'first.log').unlink()
  elif label=='report_symlink':
   actual=root/'build/original-report.json';shutil.move(folder/'report.json',actual);(folder/'report.json').symlink_to(actual)
  elif label=='report_directory_symlink':
   actual=root/'build/actual-run';shutil.move(folder,actual);folder.symlink_to(actual,target_is_directory=True)
  elif label=='harness_ancestor_symlink':
   actual=root/'build/actual-harness';harness=folder.parent;shutil.move(harness,actual);harness.symlink_to(actual,target_is_directory=True)
  elif label=='log_symlink':
   actual=root/'build/original.log';shutil.move(folder/'first.log',actual);(folder/'first.log').symlink_to(actual)
  elif label=='log_parent_symlink':
   actual=folder/'actual-logs';actual.mkdir();shutil.move(folder/'first.log',actual/'first.log');(folder/'nested').symlink_to(actual,target_is_directory=True)
  elif label=='proof_parent_symlink':
   actual=root/'build/actual-proof';actual.mkdir();(root/'build/verification/ci-lane-proof').symlink_to(actual,target_is_directory=True)
  elif label=='report_not_regular':(folder/'report.json').unlink();(folder/'report.json').mkdir()
  cwd=root
  if label=='repo_via_alias':cwd=base/'repo-alias';cwd.symlink_to(root,target_is_directory=True)
  env=os.environ.copy();env['HARNESS_LANE']='parallel';run=subprocess.run(['python3','-c',code],cwd=cwd,env=env,capture_output=True,text=True);accepted=label in {'valid','repo_via_alias'};assert (run.returncode==0)==accepted,(label,run.stderr)
  if accepted:
   proof=root/'build/verification/ci-lane-proof/parallel';assert (proof/'report.json').read_bytes()==(folder/'report.json').read_bytes();assert (proof/'first.log').read_bytes()==(folder/'first.log').read_bytes()
  rows.append({'case':label,'accepted':run.returncode==0,'expected_accepted':accepted,'exit_code':run.returncode,'diagnostic':run.stderr.strip()})
# All previously audited lane/commands/caps/interface source outside collector is identical.
manifest=json.loads((R/'tools/harness/profiles.json').read_text());ids=list(dict.fromkeys(sum((manifest['profiles'][p] for p in ['gameplay','art']),[])));serial=[i for i in ids if manifest['checks'][i].get('serial')];parallel=[i for i in ids if not manifest['checks'][i].get('serial')];assert len(ids)==85 and len(serial)==18 and len(parallel)==67
result={'scope':'Real inline-collector filesystem tests only; no native/CI/commit/push','before_workflow_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_workflow_sha256':hashlib.sha256(new.encode()).hexdigest(),'only_original_inline_collector_changed':True,'root_anchor':'Canonical repository cwd; inspect each lexical descendant with is_symlink before lstat, never inspect system ancestors','profile_counts':{'total':85,'parallel':67,'serial':18},'all_existing_other_workflow_bytes_unchanged':True,'cases':rows};(D/'result.json').write_text(json.dumps(result,indent=2)+'\n');(D/'environment.after.yml.txt').write_text(new)
print(json.dumps({'cases':len(rows),'expected_accept':2,'expected_reject':len(rows)-2,'collector_only':True}))
