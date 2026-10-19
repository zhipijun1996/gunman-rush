from pathlib import Path
import json,re,hashlib
R=Path('/workspace/gunman-rush-design');O=R/'build/forest_depth/snapshots/level_capability01/build/capability_boundary';s=(O/'case.gd').read_text();s=s.replace('var SNAPSHOT: Script = load("res://tools/level_capability_snapshot.gd")','var SNAPSHOT: Script\nvar lifecycle_ok := false')
a=s.index('\tvar motor =');b=s.index('\tactor.set_physics_process(false)')
s=s[:a]+'''\tvar app=load("res://scripts/demo/demo_app.gd").new()
	app.meta_persistence_enabled=false
	get_tree().root.add_child(app)
	if not app.start_plains("level-capability-default"):
		push_error("CAPABILITY APP: normal default start refused")
		app.free()
		return
	await get_tree().process_frame
	var motor=app.player
	var actor=app.controller
'''+s[b:]
s=s.replace('\tvar build = load("res://scripts/builds/build_state.gd").new()\n\tbuild.configure(actor)','\tvar build = app.build\n\tSNAPSHOT=load("res://tools/level_capability_snapshot.gd")')
s=s.replace('\tmotor.free()\n\tawait get_tree().process_frame', '''\tvar app_ref: WeakRef=weakref(app)
	var motor_ref: WeakRef=weakref(motor)
	var controller_ref: WeakRef=weakref(actor)
	var drained: bool=await load("res://tests/audio_teardown.gd").drain_world(app)
	app.free()
	app=null
	motor=null
	actor=null
	build=null
	await get_tree().process_frame
	lifecycle_ok=drained and app_ref.get_ref()==null and motor_ref.get_ref()==null and controller_ref.get_ref()==null
	print("CAPABILITY APP LIFECYCLE ",JSON.stringify({"audio_drained":drained,"app_released":app_ref.get_ref()==null,"motor_released":motor_ref.get_ref()==null,"controller_released":controller_ref.get_ref()==null,"normal_default_entry":true}))''')
(O/'app_case.gd').write_text(s);entry=(O/'entry.gd').read_text().replace('/case.gd','/app_case.gd').replace('case.failures!=0 or case.assertions!=41','case.failures!=0 or case.assertions!=41 or not case.lifecycle_ok');(O/'app_entry.gd').write_text(entry)
original=(O/'case.gd').read_text();assert re.findall(r'verify\((.*)',s)==re.findall(r'verify\((.*)',original)
D=R/'build/forest_depth/level_capability/app_candidate01';D.mkdir(exist_ok=True);(D/'preparation.json').write_text(json.dumps({'scope':'Actual DemoApp normal default Plains entry + actual build; all original41 assertion expression lines/order retained under the already-recorded runtime type-lookup normalization','candidate_sha256':hashlib.sha256(s.encode()).hexdigest(),'source_original_sha256':hashlib.sha256(original.encode()).hexdigest()},indent=2)+'\n')
s=(R/'build/forest_depth/level_capability/candidate01/run.py').read_text().replace("O=ROOT/'build/forest_depth/level_capability/candidate01'","O=ROOT/'build/forest_depth/level_capability/app_candidate01'").replace('build/capability_boundary/entry.gd','build/capability_boundary/app_entry.gd');(D/'run.py').write_text(s)
