import os,sys,importlib.util,json,subprocess
from pathlib import Path
repo=Path('/workspace/gunman-rush');s=importlib.util.spec_from_file_location('uidcase',repo/'tests/test_forest_uid_preservation.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
actual=os.geteuid();result={'scope':'Actual kernel namespace identity and temporary chmod filesystem checks; no mocks/native/AI','pid':os.getpid(),'euid':actual,'uid_map':Path('/proc/self/uid_map').read_text(),'gid_map':Path('/proc/self/gid_map').read_text(),'proc_uid_gid':[s for s in Path('/proc/self/status').read_text().splitlines() if s.startswith(('Uid:','Gid:'))],'cases':{},'refusals':[]}
for name in ['denied_reference','readable_reference','readable_unreferenced']:
 value=m.run_actual_case(name);assert value['euid']==actual and actual!=0;result['cases'][name]=value
for expected in [0,actual+1]:
 p=subprocess.run([sys.executable,'-c',m.PROBE,str(repo),'denied_reference',str(expected)],capture_output=True,text=True,timeout=5);assert p.returncode!=0;result['refusals'].append({'explicit_expected':expected,'actual_identity':actual,'exit_code':p.returncode,'stderr':p.stderr})
assert result['cases']['denied_reference']['actual_directory_permission_denied']
assert result['cases']['denied_reference']['uid_preserved'] and result['cases']['denied_reference']['preserved_original_bytes']
assert result['cases']['readable_unreferenced']['archive_matches_original'] and not result['cases']['readable_unreferenced']['uid_preserved']
print(json.dumps(result,indent=2))
