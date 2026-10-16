from pathlib import Path
import os,sys,json,importlib.util,subprocess
root=Path.cwd();spec=importlib.util.spec_from_file_location('actual_uid_tests',root/'tests/test_forest_uid_preservation.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
result={'kind':'actual_kernel_unprivileged_identity_and_permissions_not_mock','parent_pid':os.getpid(),'parent_euid':os.geteuid(),'uid_map':Path('/proc/self/uid_map').read_text(),'cases':[m.run_actual_case(case) for case in ['denied_reference','readable_reference','readable_unreferenced']]}
for expected in [0,1000 if os.geteuid()!=1000 else 1001]:
 p=subprocess.run([sys.executable,'-c',m.PROBE,str(root),'denied_reference',str(expected)],capture_output=True,text=True)
 result.setdefault('explicit_identity_refusals',[]).append({'expected_uid':expected,'actual_parent_euid':os.geteuid(),'exit_code':p.returncode,'stderr':p.stderr})
 assert p.returncode!=0
assert result['cases'][0]['actual_directory_permission_denied'] is True
assert all(x['euid']==os.geteuid() and x['euid']!=0 for x in result['cases'])
print(json.dumps(result,indent=2))
