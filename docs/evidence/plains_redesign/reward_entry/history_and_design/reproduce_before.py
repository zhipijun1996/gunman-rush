import shutil,tarfile,sys,json,os,concurrent.futures
from pathlib import Path
r=Path('/workspace/gunman-rush');b=r/'build/plains_redesign/reward_entry';p=b/'before_reproduction';a=b/'candidate_a';p.mkdir(exist_ok=True)
for folder in ['scripts','scenes','resources','config','tools','tests','shaders','.godot']:
 if (a/folder).exists():shutil.copytree(a/folder,p/folder,dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(a/'project.godot',p/'project.godot')
if not (p/'assets').exists():(p/'assets').symlink_to(r/'assets',target_is_directory=True)
with tarfile.open(b/'baseline_source.tar.gz') as tar:(p/'scripts/generation/plains_region_generator.gd').write_bytes(tar.extractfile('scripts/generation/plains_region_generator.gd').read())
sys.path.insert(0,str(p/'tools'));import level_formal as f
os.environ['GUNMAN_TOOLCHAIN_ROOT']='/workspace/toolchains'
def run(policy):
 result=f.capture_one('level-design-v2-baseline',1,'return',p/'build/before'/policy/'capture.json',max_ticks=15000,encounter_policy=policy);print(json.dumps(result),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:list(ex.map(run,['kill_from_bank_v1','bait_then_bypass_v1']))
