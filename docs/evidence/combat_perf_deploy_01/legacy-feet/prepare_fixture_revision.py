from pathlib import Path
import json,hashlib,difflib,shutil
r=Path('/workspace/gunman-rush-refactor');o=Path(__file__).parent;v=o/'fixture-revision-02';v.mkdir(exist_ok=True);path='tests/enemy_feedback_01_tests.gd';p=r/path;before=p.read_bytes();s=before.decode();original=(o/'originals'/path).read_bytes();sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha(before)=='1d712d24f97b8ef9c60751496baf27617d8de6ec8e8484b1136fec7f824db34a'
shutil.copyfile(p,v/'before-test.gd');failure=r/'build/verification/harness/20261102T031249.244362Z/enemy-feedback-native.log';shutil.copyfile(failure,v/'before-618-3-native.log')
start=s.index('\nfunc original_contact_bottom(')
custom='''
class ContactPixels extends Texture2D:
	# Real CPU pixel source: headless Dummy's ImageTexture.update is a no-op.
	var pixels: Image
	func _get_image() -> Image: return pixels
	func _get_width() -> int: return pixels.get_width()
	func _get_height() -> int: return pixels.get_height()
'''
s=s[:start]+custom+s[start:]
s=s.replace('\tvar texture := ImageTexture.create_from_image(image)\n\tvar bounds := Rect2(-2,-13,20,28)','\tvar texture := ImageTexture.create_from_image(image)\n\tvar mutable := ContactPixels.new()\n\tmutable.pixels = image\n\tvar observed_updates: Array[Dictionary] = []\n\tvar bounds := Rect2(-2,-13,20,28)')
s=s.replace('\tfor alpha: float in [0.499,0.5,0.501,0.0]:','\tcheck(EnemyFeedback01Frames.contact_bottom(mutable,bounds) == 0.0,"custom mutable texture starts with actual transparent pixels")\n\tfor alpha: float in [0.499,0.5,0.501,0.0]:')
s=s.replace('"ImageTexture.update stays live across the actual half-alpha boundary "','"ImageTexture.update matches the original scan of actual renderer readback "')
s=s.replace('\t\tcheck(EnemyFeedback01Frames.contact_bottom(texture,bounds) == (15.0 if alpha >= 0.5 else 0.0),','\t\tvar seen_alpha := mutable.get_image().get_pixel(2,3).a\n\t\tcheck(is_equal_approx(seen_alpha,alpha),"custom mutable texture really exposes the changed RGBAF alpha "+str(alpha))\n\t\tobserved_updates.append({"input_alpha":alpha,"renderer_readback_alpha":texture.get_image().get_pixel(2,3).a,"cpu_readback_alpha":seen_alpha})\n\t\tcheck(EnemyFeedback01Frames.contact_bottom(mutable,bounds) == (15.0 if alpha >= 0.5 else 0.0),')
s=s.replace('\tmutable_atlas.atlas = texture\n','\tmutable_atlas.atlas = mutable\n').replace('"Atlas over mutable ImageTexture also starts transparent"','"Atlas over mutable CPU texture also starts transparent"').replace('"Atlas over updated ImageTexture observes new row without stale shared entry"','"Atlas over updated CPU texture observes new row without stale shared entry"')
s=s.replace('\tvar imported := EnemyFeedback01Frames.TEXTURES["legacy_diver.png"] as CompressedTexture2D\n','\tprint("CONTACT_BOTTOM_MUTABLE_READBACK "+JSON.stringify(observed_updates))\n\tvar imported := EnemyFeedback01Frames.TEXTURES["legacy_diver.png"] as CompressedTexture2D\n')
# Every pre-optimization test byte is still intact.
assert s[:s.index('\nclass ContactPixels')].replace('\tverify_contact_bottom_cache()\n','',1).encode()==original
q=v/'candidate'/path;q.parent.mkdir(parents=True,exist_ok=True);q.write_text(s)
patch=''.join(difflib.unified_diff(before.decode().splitlines(True),s.splitlines(True),fromfile='a/'+path,tofile='b/'+path));(v/'fixture-only.patch').write_text(patch)
engine=Path('/workspace/engine-diagnostics/godot-4.7.2-stable');refs=[]
for name,lo,hi in [('servers/rendering/dummy/storage/texture_storage.h',82,119),('scene/resources/image_texture.cpp',97,120),('scene/resources/texture.h',43,54)]:
 f=engine/name;raw=f.read_bytes();refs.append({'path':str(f),'sha256':sha(raw),'lines':[lo,hi],'excerpt':'\n'.join(raw.decode().splitlines()[lo-1:hi])})
report={'reason':'Dummy renderer texture_2d_update is empty, initialization duplicates pixels and get_image returns original stored image. New fixture assumed GPU update visibility. Old algorithm and new helper agreed in all oracle cases;3 hardcoded outcomes failed because actual source remained transparent.','preserved_failure':{'path':str(failure),'sha256':sha(failure.read_bytes()),'checks':618,'failures':3},'files':[{'path':path,'before_sha256':sha(before),'after_sha256':sha(s.encode())}],'delta_patch_sha256':sha(patch.encode()),'production_files_changed':False,'original_preoptimization_test_entire_body_preserved':True,'new_checks_relative_first_candidate':5,'expected_total_checks':623,'contracts':['Keep every ImageTexture.update old/new scan equality, now described as actual renderer readback.','Hard numeric threshold .499/.5/.501/0 and Atlas changed-row1.0 use same actual CPU-backed Texture2D instance with real RGBAF pixels, not production cache mocks.','Explicit get_image pixel assertions prove input reached virtual source before fixed numeric expectation.','Original all484 checks, oracle algorithm and existing test budgets unchanged.','Custom source is deliberately uncacheable production path; original immutable cache/oracle coverage remains.'],'source_evidence':refs,'native':'pending root; no engine execution by author'}
(v/'candidate.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'directory':str(v),'test_sha256':sha(s.encode()),'patch_sha256':sha(patch.encode()),'candidate_sha256':sha((v/'candidate.json').read_bytes())},indent=2))
