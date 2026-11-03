import importlib.util, sys, subprocess, json, os, stat, hashlib
from pathlib import Path
REPO=Path('/tmp/gunman-rush-mapgen-041'); sys.path.insert(0,str(REPO/'tools'))
s=importlib.util.spec_from_file_location('ci_inputs_fixture', REPO/'tests/test_cloud_inputs.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
c=m.CloudInputBundleTests(); c.setUp()
try:
 c.package(); root,wanted=c.promisor_consumer(); before=c.cache_git_state(root); missing=m.inputs.blob_sizes(root,wanted)
 events=[]; cache_states=[]; original_cache=m.inputs.cache_verified_git_blobs
 def checked_cache(*args, **kwargs):
  start=c.cache_git_state(root); result=original_cache(*args,**kwargs); cache_states.append((start,c.cache_git_state(root))); return result
 with m.patch.object(m.inputs,'cache_verified_git_blobs',side_effect=checked_cache):
  result=m.inputs.restore_bundle(root,[],['full'],'HEAD',root/'build/plan.json',c.run_id,c.bundle,progress=events.append)
 after=c.cache_git_state(root); checks={}
 def check(name):
  trace=c.base/(name+'.trace'); r=subprocess.run(['git','-C',str(root),'diff','--name-only','-z','HEAD'],capture_output=True,timeout=30,env=os.environ|{'GIT_TRACE':str(trace)})
  checks[name]={'returncode':r.returncode,'paths':r.stdout.decode().split(chr(0))[:-1],'stderr':r.stderr.decode(),'trace':trace.read_text()}
  assert r.returncode==0 and ' fetch ' not in trace.read_text() and 'upload-pack' not in trace.read_text()
 check('clean'); assert checks['clean']['paths']==[]
 proof=root/c.proof; original=proof.read_bytes(); proof.write_text('changed content\n'); check('content_edit'); assert checks['content_edit']['paths']==[c.proof]; proof.write_bytes(original)
 executable=root/c.executable; old_mode=executable.stat().st_mode; executable.chmod(old_mode & ~stat.S_IXUSR & ~stat.S_IXGRP & ~stat.S_IXOTH); check('mode_edit'); assert checks['mode_edit']['paths']==[c.executable]; executable.chmod(old_mode)
 proof.unlink(); check('delete'); assert checks['delete']['paths']==[c.proof]
 summary={'kind':'tiny actual file:// filtered/promisor Git fixture, no 4GB validation claim','git_version':c.git(root,'--version'),'missing_before':missing,'available_after':m.inputs.blob_sizes(root,wanted),'restore':result,'progress':events,'cache_operation_raw_index_refs_flags_unchanged':cache_states[0][0]==cache_states[0][1],'head_tree_index_entries_unchanged':before[0][:3]==after[0][:3],'refs_unchanged':before[2]==after[2],'diff_guard_timeout_seconds':30,'checks':checks}
 assert summary['cache_operation_raw_index_refs_flags_unchanged'] and summary['head_tree_index_entries_unchanged'] and summary['refs_unchanged']
 print(json.dumps(summary,indent=2)); (Path(__file__).parent/'after-result.json').write_text(json.dumps(summary,indent=2)+'\n')
finally: c.doCleanups()
