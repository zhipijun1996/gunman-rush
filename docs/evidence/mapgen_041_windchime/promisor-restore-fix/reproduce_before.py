import importlib.util,sys,subprocess,json,os,hashlib
from pathlib import Path
REPO=Path('/tmp/gunman-rush-mapgen-041');sys.path.insert(0,str(REPO/'tools'))
s=importlib.util.spec_from_file_location('ci_inputs_fixture',REPO/'tests/test_cloud_inputs.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
c=m.CloudInputBundleTests();c.setUp()
try:
 c.package();c.git(c.source,'config','uploadpack.allowFilter','true');c.git(c.source,'config','uploadpack.allowAnySHA1InWant','true')
 root=c.base/'promisor';subprocess.run(['git','clone','-q','--no-local','--filter=blob:none','--no-checkout',c.source.as_uri(),str(root)],check=True)
 c.git(root,'sparse-checkout','init','--no-cone');subprocess.run(['git','-C',str(root),'sparse-checkout','set','--no-cone','--stdin'],input='/*\n!/docs/evidence/**\n',text=True,capture_output=True,check=True);c.git(root,'checkout','-q','HEAD')
 (root/'build').mkdir();(root/'build/plan.json').write_bytes(c.plan_path.read_bytes())
 blobs=[c.git(root,'rev-parse','HEAD:'+p) for p in [c.proof,c.executable]]
 print('MISSING_BEFORE',m.inputs.blob_sizes(root,blobs),flush=True)
 c.git(root,'remote','set-url','origin',(c.base/'unavailable-remote').as_uri())
 before=m.inputs.repository_state(root,'HEAD');index_path=Path(c.git(root,'rev-parse','--git-path','index'));index_path=index_path if index_path.is_absolute() else root/index_path;index_before=index_path.read_bytes()
 result=m.inputs.restore_bundle(root,[],['full'],'HEAD',root/'build/plan.json',c.run_id,c.bundle)
 print('RESTORED',result['status'],result['restored_files'],flush=True);print('MISSING_AFTER',m.inputs.blob_sizes(root,blobs),flush=True)
 trace=c.base/'git-trace.txt';env=os.environ|{'GIT_TRACE':str(trace)}
 r=subprocess.run(['git','-C',str(root),'diff','--name-only','-z','HEAD'],capture_output=True,timeout=10,env=env)
 print('DIFF',r.returncode,repr(r.stdout),r.stderr.decode(),flush=True);print('TRACE',trace.read_text(),flush=True)
 (Path(__file__).parent/'before-result.json').write_text(json.dumps({'blobs':blobs,'diff_rc':r.returncode,'stdout':r.stdout.decode(),'stderr':r.stderr.decode(),'trace':trace.read_text(),'restore_status':result['status'],'index_bytes_changed_by_restore':index_path.read_bytes()!=index_before},indent=2))
finally:c.doCleanups()
