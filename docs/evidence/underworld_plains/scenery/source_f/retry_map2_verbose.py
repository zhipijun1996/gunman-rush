from pathlib import Path
import subprocess,json,hashlib,time,os,shutil
from PIL import Image
root=Path.cwd();base=root/'build/underworld_plains/source_f_scenery';out=base/'map2_verbose_retry';out.mkdir(exist_ok=True)
commit='a44b856e1730e81ed74aa5eb1c8999e8d2bb8ff2'; fixture='tests/underworld_plains/capture_scenery_windows.gd'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert (root/fixture).read_bytes()==subprocess.check_output(['git','show',commit+':'+fixture])
diff=subprocess.check_output(['git','diff','--name-only',commit,'--','assets','scripts','scenes','addons','project.godot','export_presets.cfg'],text=True).splitlines();assert not diff,diff
original_binding_sha=sha(base/'source_binding.json')
cmd=['bash','tools/godot.sh','--path','.','--rendering-method','gl_compatibility','--audio-driver','Dummy','--verbose','--script',fixture,'--','--scenery-map=2']
start=time.time()
with (out/'capture.log').open('w') as log:
    p=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,DISPLAY=':98',LIBGL_ALWAYS_SOFTWARE='1'),timeout=90)
rpath=root/'build/underworld_plains/scenery_map2_golden_receipts.json';assert rpath.stat().st_mtime>=start
r=json.loads(rpath.read_text());assert len(r['samples'])==8
images=[]
for sample in r['samples']:
    path=root/sample['image'].removeprefix('res://');assert path.stat().st_mtime>=start
    target=out/path.name;shutil.copy2(path,target)
    with Image.open(target) as im:size=list(im.size)
    assert size==[1280,720]
    images.append({'path':str(target.relative_to(root)),'sha256':sha(target),'size':size})
shutil.copy2(rpath,out/'receipts.json')
assert all(x['hit_static_body'] for x in r['grounded_landmark_rays'])
assert all(not s['local_issues'] for s in r['samples'])
log=(out/'capture.log').read_text();issues=[s for s in log.splitlines() if 'ERROR:' in s or 'ObjectDB instances were leaked' in s]
assert sha(base/'source_binding.json')==original_binding_sha
binding={'schema':'underworld-exact-f-map2-verbose-retry-v1','runtime_source_commit':commit,'fixture_source_commit':commit,'fixture_path':fixture,'fixture_sha256':sha(root/fixture),'runtime_diff':diff,'original_preserved_binding':str((base/'source_binding.json').relative_to(root)),'original_preserved_binding_sha256':original_binding_sha,'purpose':'One exact original fixture retry with --verbose to diagnose original4ObjectDB/2resource exit warning; original warning evidence unchanged','argv':cmd,'engine_exit_code':p.returncode,'elapsed_seconds':time.time()-start,'log':str((out/'capture.log').relative_to(root)),'log_sha256':sha(out/'capture.log'),'receipts':str((out/'receipts.json').relative_to(root)),'receipts_sha256':sha(out/'receipts.json'),'images':images,'grounded_landmark_rays':r['grounded_landmark_rays'],'log_issues':issues,'status':'clean' if not issues and p.returncode==0 else 'exit_cleanup_issue_retained','scope':'Positioned real formal consumer art inspection; not traversal/no-damage/FPS claim'}
(out/'retry_binding.json').write_text(json.dumps(binding,indent=2)+'\n')
print(json.dumps({'status':binding['status'],'exit':p.returncode,'issues':issues,'elapsed':binding['elapsed_seconds']},indent=2))
