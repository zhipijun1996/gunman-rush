from pathlib import Path
import shutil,json,os,sys,concurrent.futures
r=Path('/workspace/gunman-rush');b=r/'build/plains_redesign/reward_entry';p=b/'candidate_b_return';p.mkdir(exist_ok=True)
for folder in ['scripts','scenes','resources','config','tools','tests','shaders','.godot']:
 if (r/folder).exists():shutil.copytree(r/folder,p/folder,dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(r/'project.godot',p/'project.godot')
if not (p/'assets').exists():(p/'assets').symlink_to(r/'assets',target_is_directory=True)
gen=p/'scripts/generation/plains_region_generator.gd';s=gen.read_text();s=s.replace('''		# Authored ascent: reserve first jump/receiver; same guard watches the wide outside bank.
		var trial_entrance: bool=m.connections.any(func(e: Dictionary):return e.kind=="challenge" and e.a==a.id)
		if trial_entrance:p=_point(a.position)+(Vector2(-130,-65) if aerial else Vector2(-130,0))''','''		# The approach and known upper return bank share an observation/recoil
		# role. Reserve the right-hand receiver/retreat band from generic bodies.
		if _trial_observation_bank(m,a):p=_point(a.position)+(Vector2(-130,-65) if aerial else Vector2(-130,0))''')
pos=s.index('func _deep_loop(');s=s[:pos]+'''func _trial_observation_bank(m:Dictionary,a:Dictionary) -> bool:
	for edge:Dictionary in m.connections:
		if edge.kind=="challenge" and edge.a==a.id:return true
		if edge.kind!="drop" or not edge.has("return_polyline"):continue
		# Real generated evacuation points, not fixed column/Seed coordinates.
		for point:Array in edge.return_polyline.slice(1):
			if _point(point).distance_to(_point(a.position))<1.0:return true
	return false

'''+s[pos:];gen.write_text(s)
sys.path.insert(0,str(p/'tools'));import level_formal as f
os.environ['GUNMAN_TOOLCHAIN_ROOT']='/workspace/toolchains'
def run(case):
 name,seed,policy=case;output=p/'build/candidate_b'/name/'capture.json';result=f.capture_one(seed,1,'return',output,max_ticks=18000,encounter_policy=policy);print(name,json.dumps(result),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(run,[('canonical_kill','level-design-v2-baseline','kill_from_bank_v1'),('canonical_bypass','level-design-v2-baseline','bait_then_bypass_v1'),('worst_return_charger','two-map-corpus/2','kill_from_bank_v1')]))
