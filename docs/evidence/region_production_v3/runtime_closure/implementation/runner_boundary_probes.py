"""Synthetic subprocess boundary probes only; not native or real verifier execution."""
import sys,json,time,subprocess,types
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,'tools')
import run_root_bell_tests as r
root=r.BASE/'runtime_closure_boundary'/str(time.time_ns());root.mkdir(parents=True)
results={}
for case in ('nonzero','missing_marker','missing_report','failed_report','omitted_refusals','wrong_verifier','timeout'):
    r.OUT=r.reserve_output(root/case)
    def fake(command,**kwargs):
        if case=='timeout':raise subprocess.TimeoutExpired(command,90)
        folder=r.ROOT/command[-1];folder.mkdir()
        data={'status':'passed','scope':'Actual Python main negatives with explicitly synthetic transport, NO NATIVE/MOVIE execution','original27_refusals':list(range(27)),'coherent_fullmain_refusals':{str(i):{'refused':True} for i in range(9)},'current_verifier_sha256':r.sha(r.ROOT/'tools/run_root_bell_formal.py'),'current_test_sha256':r.sha(r.ROOT/'tools/test_root_bell_formal_verifier.py')}
        if case=='failed_report':data['status']='failed'
        if case=='omitted_refusals':data['coherent_fullmain_refusals'].pop('8')
        if case=='wrong_verifier':data['current_verifier_sha256']='0'*64
        if case!='missing_report':(folder/'report.json').write_text(json.dumps(data))
        return types.SimpleNamespace(returncode=1 if case=='nonzero' else 0,stdout='old stale SUCCESS' if case=='missing_marker' else 'STRICT FORMAL PYTHON: original27 + coherent full-main 9 refusals; no native\n',stderr='')
    try:
        with patch.object(r.subprocess,'run',side_effect=fake):r.strict_formal_python_checks()
    except (ValueError,subprocess.TimeoutExpired) as e:results[case]={'rejected':True,'reason':str(e)}
    else:raise AssertionError('Boundary accepted '+case)
report={'scope':__doc__,'rejections':results,'status':'passed','native_reexecuted':False}
Path('build/region_production_v3/runtime_closure/runner_boundary_probes.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
