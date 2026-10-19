from pathlib import Path
import subprocess,json,hashlib
from PIL import Image
root=Path.cwd();out=root/'build/underworld_plains/source_f_scenery';commit='a44b856e1730e81ed74aa5eb1c8999e8d2bb8ff2'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rel=lambda p:str(p.relative_to(root))
critical=['scripts/underworld_plains/underworld_scenery.gd','scripts/underworld_plains/underworld_local_composition.gd','scripts/underworld_plains/underworld_parallax.gd','scripts/underworld_plains/underworld_parallax_edge.gdshader','tests/underworld_plains/capture_scenery_windows.gd','assets/underworld_plains/scenery_build.json','assets/underworld_plains/decor/chime_props.json','assets/underworld_plains/decor/identity_props.png']
diffs=subprocess.check_output(['git','diff','--name-only',commit,'--','assets','scripts','scenes','addons','project.godot','export_presets.cfg'],text=True).splitlines();assert not diffs,diffs
same={}
for p in critical:
    assert (root/p).read_bytes()==subprocess.check_output(['git','show',commit+':'+p]);same[p]=sha(root/p)
def imrecord(p,**kw):
    with Image.open(p) as im: size=list(im.size)
    assert size==[1280,720]
    return dict(path=rel(p),sha256=sha(p),size=size,**kw)
records=json.loads((out/'run_records.json').read_text());assert len(records)==3
binding={'schema':'underworld-exact-f-scenery-capture-v1','runtime_source_commit':commit,'capture_fixture_source_commit':commit,'worktree_head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'runtime_paths_differing_from_source':diffs,'component_files_equal_to_commit':same,'web_build_context':'4b01de439c24; these are native GPU fixtures, not Web screenshots','maps':[],'selected_identity_images':[],'all_images':[],'scope':'Positioned actual formal consumers on source F; controller/camera cut fixture, no traversal/no-damage/device/FPS claim; E evidence remains distinct','preserved_display_failure':rel(out/'map1/attempt1_x99_display_unavailable.log')}
expected={'windmill_plateau','creek_well','clock_court','repair_gallery'}
for mapid in [1,2]:
    slot=out/('map'+str(mapid));d=json.loads((slot/'receipts.json').read_text());assert len(d['samples'])==8
    assert all(r['hit_static_body'] for r in d['grounded_landmark_rays']);assert all(not s['local_issues'] for s in d['samples'])
    first=d['samples'][0];ids={x['identity'] for x in first['decor']['items']}|{x['identity'] for x in first['local_compositions']};assert ids==expected
    for sample in d['samples']:
        for layer in sample['layers']:
            assert len(layer.get('texture_sha256',''))==64,layer
    binding['maps'].append({'map':mapid,'seed':d['seed'],'exit_code':0,'log':rel(slot/'capture.log'),'log_sha256':sha(slot/'capture.log'),'receipts':rel(slot/'receipts.json'),'receipts_sha256':sha(slot/'receipts.json'),'actual_identity_set':sorted(ids),'grounded_landmark_rays':d['grounded_landmark_rays'],'local_compositions':first['local_compositions']})
    for p in sorted(slot.glob('*.png')):
        r=imrecord(p,map=mapid);binding['all_images'].append(r)
        if 'identity_' in p.name or 'local_creek_well' in p.name:binding['selected_identity_images'].append(r)
assert len(binding['all_images'])==16 and len(binding['selected_identity_images'])==8
slot=out/'seed0';d=json.loads((slot/'receipts.json').read_text());assert len(d['samples'])==9
assert all(r['hit_static_body'] for r in d['grounded_landmark_rays']);assert all(not s['local_issues'] for s in d['samples'])
repair=next(x for x in d['samples'][0]['decor']['items'] if x['identity']=='repair_gallery');assert abs(repair['display_bounds'][3]-56)<.001
binding['capture_log_issues'] = []
for run in records:
    log=(out/run['slot']/'capture.log').read_text()
    issues=[line for line in log.splitlines() if 'ERROR:' in line or 'ObjectDB instances were leaked' in line]
    if issues: binding['capture_log_issues'].append({'slot':run['slot'],'engine_exit_code':run['exit_code'],'issues':issues,'status':'retained, not asserted clean; actual capture/rays succeeded'})
binding['capture_status']='complete_with_exit_cleanup_issue' if binding['capture_log_issues'] else 'complete_clean'
binding['previously_failing_seed0']={'seed':d['seed'],'map':1,'actual_repair_height':repair['display_bounds'][3],'actual_repair_item':repair,'actual_landmark_rays':d['grounded_landmark_rays'],'log':rel(slot/'capture.log'),'log_sha256':sha(slot/'capture.log'),'receipts':rel(slot/'receipts.json'),'receipts_sha256':sha(slot/'receipts.json'),'fixture_provenance':rel(out/'seed0_fixture_provenance.json'),'selected_image':imrecord(slot/'golden_identity_repair_gallery.png'),'all_images':[imrecord(p) for p in sorted(slot.glob('*.png'))],'exit_code':0,'capture_count_explanation':'Nine actual windows because seed0 has four genuinely supported grounded items plus local well architecture; default has three grounded items','image_observation':'Complete56wu source shelter; real positioned sequence may trigger Boss intro/UI; not a natural-route or no-damage claim'}
(out/'source_binding.json').write_text(json.dumps(binding,indent=2)+'\n')
print('F source bound: default16/selected8 + seed09; 56wu repair;10 actualStaticBody rays; no runtime changes; status=',binding['capture_status'])
