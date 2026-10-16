import os,json
from pathlib import Path
r=Path('/workspace/gunman-rush');archive=r/'build/region_production_v3/ci_uid_portability/test_forest_uid_preservation.py.before';g={'__file__':str(r/'tests/test_forest_uid_preservation.py'),'__name__':'independent_old_uid_replay'};exec(compile(archive.read_bytes(),g['__file__'],'exec'),g);results=[]
for case in ['denied_reference','readable_reference','readable_unreferenced']:
 try:g['run_actual_case'](case)
 except AssertionError as e:results.append({'case':case,'refused':True,'reason':str(e)});assert 'requires actual unprivileged euid1000' in str(e)
 else:raise AssertionError('Old hard-UID assertion unexpectedly passed')
assert os.geteuid()==1001;print(json.dumps({'scope':'New independent replay of exact archived old source under actual kernel UID1001, not a historical CI run','euid':os.geteuid(),'uid_map':Path('/proc/self/uid_map').read_text(),'results':results},indent=2))
