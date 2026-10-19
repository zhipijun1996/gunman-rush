from pathlib import Path
import subprocess,os,json,hashlib,shutil,time
root=Path.cwd(); out=root/'build/underworld_plains/source_f_scenery'
commit='a44b856e1730e81ed74aa5eb1c8999e8d2bb8ff2'
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==commit
fixture=root/'tests/underworld_plains/capture_scenery_windows.gd'
assert fixture.read_bytes()==subprocess.check_output(['git','show',commit+':'+str(fixture.relative_to(root))])
seedfixture=out/'capture_seed0.gd'; src=fixture.read_text();assert src.count('level-design-v2-baseline/08')==2
seedfixture.write_text(src.replace('level-design-v2-baseline/08','underworld-formal/0'))
hashfile=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'seed0_fixture_provenance.json').write_text(json.dumps({'schema':'underworld-seed0-art-fixture-provenance-v1','runtime_source_commit':commit,'fixture_parent_commit':commit,'fixture_parent_path':str(fixture.relative_to(root)),'fixture_parent_sha256':hashfile(fixture),'build_only_fixture':str(seedfixture.relative_to(root)),'fixture_sha256':hashfile(seedfixture),'transformation':'Replace exactly two literal level-design-v2-baseline/08 seeds with underworld-formal/0; no other fixture, gameplay, physics or layout changes','scope':'Positioned art inspection, runtime F; seed-only modified fixture is not claimed byte-identical to committed default fixture'},indent=2)+'\n')
runrecords=[]
for slot,mapid,driver in [('map1',1,fixture),('map2',2,fixture),('seed0',1,seedfixture)]:
    dst=out/slot;dst.mkdir(exist_ok=True)
    cmd=['bash','tools/godot.sh','--path','.','--rendering-method','gl_compatibility','--audio-driver','Dummy','--script',str(driver.relative_to(root))]
    if mapid==2:cmd+=['--','--scenery-map=2']
    env=dict(os.environ,DISPLAY=':98',LIBGL_ALWAYS_SOFTWARE='1')
    start=time.time()
    with (dst/'capture.log').open('w') as log:
        p=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=env,timeout=90)
    assert p.returncode==0,(slot,p.returncode)
    receipt=root/('build/underworld_plains/scenery_'+('map2_' if mapid==2 else '')+'golden_receipts.json')
    assert receipt.stat().st_mtime>=start
    data=json.loads(receipt.read_text());assert len(data['samples'])==(9 if slot=='seed0' else 8)
    assert all(r['hit_static_body'] for r in data['grounded_landmark_rays'])
    for sample in data['samples']:
        assert not sample['local_issues'],sample['local_issues']
        im=root/sample['image'].removeprefix('res://');assert im.stat().st_mtime>=start
        shutil.copy2(im,dst/im.name)
    shutil.copy2(receipt,dst/'receipts.json')
    runrecords.append({'slot':slot,'argv':cmd,'exit_code':p.returncode,'elapsed_seconds':time.time()-start,'samples':len(data['samples']),'actual_rays':len(data['grounded_landmark_rays'])})
    (out/'run_records.json').write_text(json.dumps(runrecords,indent=2)+'\n')
    print(slot,'captured',len(data['samples']),'elapsed',runrecords[-1]['elapsed_seconds'],flush=True)
print('GPU CAPTURE COMPLETE',flush=True)
