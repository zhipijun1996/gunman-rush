extends SceneTree
## Default v10 consumer / recorded generated geometry. Motor proof excludes enemies;
## the unchanged region suites separately exercise the real fan/diver encounter.
var assertions:=0
var failures:=0
var output:=""
var broken:=false
var corpus_mode:=false
var semantic_cases: Array=[]
var semantic_negatives: Array=[]
var observations: Array=[]
var manifests: Array=[]
class RouteTrace extends "res://tests/plains_region_trace.gd":
	var frames: Array=[]
	var route_runs: Array=[]
	var accepted_shots: Array=[]
	func tick(n: int=1) -> void:
		for unused: int in n:
			await super.tick(1)
			frames.append({"tick":trace_ticks,"position":[motor.global_position.x,motor.global_position.y],"grounded":motor.is_on_floor(),"normal_velocity":[motor.normal_velocity.x,motor.normal_velocity.y],"recoil_velocity":[motor.recoil_velocity.x,motor.recoil_velocity.y],"energy":controller.actor_resources.stamina.current,"energy_capacity":controller.actor_resources.stamina.capacity,"shots":shots,"session":controller.session_id,"motor":motor.get_instance_id(),"safe":safe_trace,"continuous":continuous_trace})
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg=="--delete-receiver": broken=true
		if arg=="--corpus": corpus_mode=true
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func run() -> void:
	var g:=PlainsRegionGenerator.new()
	var tuning:=PlayerTuning.load_default()
	if corpus_mode:
		run_corpus(g,tuning)
		finish();return
	for seed_index: int in (1 if broken else 10):
		var root_seed: String="level-design-v2-baseline"+("" if seed_index==0 else "/%02d"%seed_index)
		for map_index: int in (1 if broken else 2):
			var difficulty: String="intro" if map_index==0 else "advanced"
			var seed_value:=PlainsRegionCampaign.seed_for(root_seed,map_index+1)
			var generated:=g.generate(seed_value,tuning,false,"",difficulty)
			check(generated.ok,"default generated "+seed_value)
			if not generated.ok: continue
			var m: Dictionary=generated.manifest
			manifests.append(m)
			check_semantics(g,m)
			check(m.version=="plains-region-v10" and m.fallback_id.is_empty(),"actual v10 default without fallback")
			check(m.streams.derivation_version=="plains-region-v4","existing named random derivation retained")
			check(m.merchant_id=="area_2_1" and m.route_intents.main_recovery=="area_1_1","authored short path rejoins real camp")
			var widths: Dictionary={}
			for i: int in range(1,m.topology.column_positions.size()): widths[float(m.topology.column_positions[i])-float(m.topology.column_positions[i-1])]=true
			check(widths.size()>=2,"world interval allocation has multiple real challenge clearances")
			check(g.validate(JSON.parse_string(JSON.stringify(m)),tuning),"native JSON roundtrip replay identity")
			var old: Dictionary=m.duplicate(true);old.version="plains-region-v9";old.manifest_hash=g._hash(old)
			check(not g.validate(old,tuning),"relabelled historical v9 manifest rejected")
			var changed: Dictionary=m.duplicate(true);changed.nodes[0].geometry.platforms[0][2]=1;changed.manifest_hash=g._hash(changed)
			check(not g.validate(changed,tuning),"rehashed missing supported receiver rejected")
			var edge: Dictionary={}
			for candidate: Dictionary in m.connections:
				if candidate.a=="area_0_1" and candidate.b=="area_1_1":edge=candidate
			check(not edge.is_empty() and edge.recipe==("well_arch_phrase" if map_index==0 else "remote_sequence") and edge.modules.size()==(2 if map_index==0 else 1),"default first short chain is real map-specific lesson")
			var camp_edge: Dictionary=m.connections.filter(func(e:Dictionary):return e.a=="area_1_1" and e.b=="area_2_1")[0]
			check(camp_edge.recipe not in (["well_arch_phrase","low_arch","thorn_gap","bell_pit"] if map_index==0 else ["remote_sequence","remote_bell","bell_order"]),"next main beat changes real action family rather than recipe label")
			var low_arch_nodes: Array=m.nodes.filter(func(n:Dictionary):return n.module_id=="plains_low_arch").map(func(n:Dictionary):return n.id)
			check(not m.enemies.any(func(e:Dictionary):return e.area in low_arch_nodes and e.get("pattern","")=="gear_landing_intercept"),"recessed wheel cannot silently create a guard in reserved arch headroom")
			var creek_roles: Array=m.enemies.filter(func(e:Dictionary):return e.area==m.creek_discovery.module)
			check(creek_roles.size()==1 and creek_roles[0].behavior_id=="diver","first creek crossing demonstrates one readable diver without fan stack")
			var trace:=RouteTrace.new();trace.tree=self;trace.check=check
			check(await trace.fixture(m,tuning),"default real recorded assembler fixture")
			check(await trace.tutorial(),"actual continuous tutorial reaches first choice")
			var entry_energy: float=trace.controller.actor_resources.stamina.current
			if seed_index%2==1:
				var stamina: StaminaState=trace.controller.actor_resources.stamina
				check(stamina.consume_continuous(stamina.current,stamina.epoch).accepted(),"legal zero initial energy boundary")
				entry_energy=stamina.current
				check(entry_energy==0,"zero boundary read back before phrase")
			if broken:
				var well: PlatformingModule=trace.stage.modules[int(edge.modules[0])]
				well.get_node("Platform1").free() # Remove the actual right bank collider, not a reported coordinate.
			trace.controller.shoot_ability.shot_fired.connect(func(direction:Vector2,id:int):trace.accepted_shots.append({"tick":trace.trace_ticks+1,"position":[trace.motor.global_position.x,trace.motor.global_position.y],"direction":[direction.x,direction.y],"shot_id":id,"energy":trace.controller.actor_resources.stamina.current}))
			var first_begin: int=trace.trace_ticks
			var before_shots: int=trace.shots
			var forward: bool=await trace.walk_edge(edge,true)
			check(forward,"actual first phrase reaches grounded receiver")
			var first_end: int=trace.trace_ticks
			var first_shots: Array=trace.accepted_shots.duplicate(true)
			var first_latch: ShotLatch=trace.shot_latch_encounter.for_module(trace.stage.modules[int(edge.modules[0])])
			if not broken:
				check(first_latch.is_open and first_latch.gate_shape.disabled,"first phrase actual projectile disables physical door")
				if map_index==1:
					check(first_shots.size()==2,"map2 first phrase uses exactly two accepted real projectiles")
					if first_shots.size()==2:check(first_shots[1].position[1]<first_shots[0].position[1]-80 and first_shots[1].position[0]-first_shots[0].position[0]>300,"map2 first phrase changes actual elevated sightline")
			var camp_forward:=false
			var reverse:=false
			var alternatives:=false
			var reward_return:=false
			if forward:
				camp_forward=await follow_route(trace,["area_1_1","area_2_1"],"short_technique_to_camp")
				check(camp_forward,"second concise teaching step really reaches protected camp")
				if camp_forward: reverse=await follow_route(trace,["area_2_1","area_1_1","area_0_1"],"short_technique_return")
			if not broken:
				check(reverse,"same-body complete short route returns from camp")
				var worst: bool=(seed_index==3 and map_index==0) or (seed_index==4 and map_index==1)
				if worst and reverse:
					var upper: bool=await follow_route(trace,m.route_intents.upper_discovery,"upper_discovery")
					var to_fork: bool=upper and await follow_route(trace,["area_2_1","area_1_1"],"known_shortchain_fork")
					var creek: bool=to_fork and await follow_route(trace,m.route_intents.creek_return,"creek_return")
					alternatives=upper and creek
					check(alternatives,"worst seed upper and creek alternatives really rejoin same camp")
					if alternatives:
						var approach:=true
						for step: Dictionary in trace.path_to("area_2_1","area_0_0"):
							if not await trace.walk_edge(step.edge,step.forward): approach=false;break
						var start_tick: int=trace.trace_ticks
						var high: bool=approach and await trace.deep_trial("deep_high")
						trace.route_runs.append({"name":"high_reward_return","path":["area_0_0","deep_high","area_1_1"],"start_tick":start_tick,"end_tick":trace.trace_ticks,"reached":high,"end_position":[trace.motor.global_position.x,trace.motor.global_position.y]})
						reward_return=high and await follow_route(trace,["area_1_1","area_2_1"],"reward_rejoins_camp")
						check(reward_return,"same-body worst seed reward opens real return control then rejoins camp")
						if reward_return: reverse=await follow_route(trace,["area_2_1","area_1_1","area_0_1"],"final_return")
				check(trace.safe_trace and trace.continuous_trace,"all-frame full-body sweep and no teleport")
				check(trace.shots>before_shots,"short chain actually releases shot to open gate")
			observations.append({"seed":root_seed,"map_index":map_index+1,"manifest_hash":m.manifest_hash,"entry_energy":entry_energy,"first_begin":first_begin,"first_end":first_end,"first_shots":first_shots,"first_door_open":first_latch.is_open,"forward":forward,"camp_forward":camp_forward,"reverse":reverse,"alternatives":alternatives,"reward_return":reward_return,"route_runs":trace.route_runs,"safe":trace.safe_trace,"continuous":trace.continuous_trace,"frames":trace.frames,"shots":trace.shots-before_shots,"enemy_scope":"no enemies in input-only assembler; formal live cohort and unchanged pressure suite are separate"})
			trace.world.free()
	finish()

func follow_route(trace: RouteTrace,path: Array,label: String) -> bool:
	var start_tick: int=trace.trace_ticks
	var reached:=true
	var steps: Array=[]
	for i: int in range(path.size()-1):
		var picked: Dictionary={}
		var forward:=false
		for edge: Dictionary in trace.stage.manifest.connections:
			if edge.condition!="open": continue
			if edge.a==path[i] and edge.b==path[i+1]: picked=edge;forward=true;break
			if edge.bidirectional and edge.b==path[i] and edge.a==path[i+1]: picked=edge;forward=false;break
		if picked.is_empty(): reached=false;break
		var begin: int=trace.trace_ticks
		var passed: bool=await trace.walk_edge(picked,forward)
		steps.append({"id":picked.id,"forward":forward,"source":path[i],"target":path[i+1],"start_tick":begin,"end_tick":trace.trace_ticks,"reached":passed})
		if not passed: reached=false;break
	trace.route_runs.append({"name":label,"path":path.duplicate(),"steps":steps,"start_tick":start_tick,"end_tick":trace.trace_ticks,"reached":reached,"end_position":[trace.motor.global_position.x,trace.motor.global_position.y]})
	return reached

func check_semantics(g: PlainsRegionGenerator,m: Dictionary) -> void:
	var errors: Array[String]=g.semantic_route_errors(m)
	check(errors.is_empty(),"actual complete directed initial semantic routes "+str(m.seed)+" "+str(errors))
	semantic_cases.append({"seed":m.seed,"family":m.family,"difficulty":m.difficulty,"hash":m.manifest_hash,"errors":errors,"route_intents":m.route_intents,"connections":m.connections.map(func(e: Dictionary):return {"id":e.id,"a":e.a,"b":e.b,"bidirectional":e.bidirectional,"condition":e.condition})})

func run_corpus(g: PlainsRegionGenerator,tuning: PlayerTuning) -> void:
	var inputs: Array=[]
	for family: String in PlainsRegionGenerator.FAMILIES:
		for i: int in 50: inputs.append(["corpus/%s/%s"%[family,i],family,"advanced"])
	for map_index: int in [1,2]:
		for i: int in 50: inputs.append([PlainsRegionCampaign.seed_for("two-map-corpus/%s"%i,map_index),"","intro" if map_index==1 else "advanced"])
	for i: int in 100: inputs.append(["operation-corpus/%s"%i,"","intro" if i<50 else "advanced"])
	for request: Array in inputs:
		var generated:=g.generate(request[0],tuning,false,request[1],request[2])
		check(generated.ok and generated.manifest.fallback_id.is_empty(),"original corpus generation remains actual candidate")
		if generated.ok: check_semantics(g,generated.manifest)
	var original: Dictionary=g.generate("level-design-v2-baseline/03",tuning,false,"","intro").manifest
	for kind: String in ["missing_step","reversed_step","unavailable_gate","future_ability"]:
		var changed: Dictionary=original.duplicate(true)
		var at: int=-1
		for i: int in changed.connections.size():
			var edge: Dictionary=changed.connections[i]
			if edge.a=="area_1_1" and edge.b=="area_2_1": at=i;break
		check(at>=0,"real required second step exists for negative "+kind)
		if at<0:continue
		if kind=="missing_step": changed.connections.remove_at(at)
		elif kind=="reversed_step": changed.connections[at].a="area_2_1";changed.connections[at].b="area_1_1";changed.connections[at].bidirectional=false
		elif kind=="unavailable_gate":changed.connections[at].condition="backside"
		else:changed.connections[at].required_capabilities=["hook"]
		changed.manifest_hash=g._hash(changed)
		var errors:=g.semantic_route_errors(changed)
		var rejected: bool=not errors.is_empty()
		check(rejected,"direct semantic validator rejects rehashed "+kind+" without relying on regeneration hash")
		check(not g.validate(changed,tuning),"production validation also rejects "+kind)
		semantic_negatives.append({"kind":kind,"rejected":rejected,"direct_errors":errors,"hash":changed.manifest_hash})

func finish() -> void:

	var data: Dictionary={"version":PlainsRegionGenerator.VERSION,"assertions":assertions,"failures":failures,"deleted_receiver":broken,"manifests":manifests,"observations":observations,"semantic_cases":semantic_cases,"semantic_negatives":semantic_negatives,"corpus_mode":corpus_mode}
	if not output.is_empty():
		var f:=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
	print("PLAINS REDESIGN SPATIAL: %s assertions, %s failures"%[assertions,failures])
	quit(1 if failures else 0)
