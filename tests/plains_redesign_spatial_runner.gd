extends SceneTree
## Default v10 consumer / recorded generated geometry. Motor proof excludes enemies;
## the unchanged region suites separately exercise the real fan/diver encounter.
var assertions:=0
var failures:=0
var output:=""
var broken:=false
var platform_only:=false
var receiver_fault: Dictionary={}
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
			frames.append({"floor_colliders":floor_colliders(),"tick":trace_ticks,"position":[motor.global_position.x,motor.global_position.y],"grounded":motor.is_on_floor(),"normal_velocity":[motor.normal_velocity.x,motor.normal_velocity.y],"recoil_velocity":[motor.recoil_velocity.x,motor.recoil_velocity.y],"energy":controller.actor_resources.stamina.current,"energy_capacity":controller.actor_resources.stamina.capacity,"shots":shots,"session":controller.session_id,"motor":motor.get_instance_id(),"safe":safe_trace,"continuous":continuous_trace})
	func floor_colliders() -> Array:
		var rows: Array=[]
		for index: int in motor.get_slide_collision_count():
			var hit:=motor.get_slide_collision(index)
			if hit.get_normal().dot(motor.up_direction)<.7:continue
			var body:=hit.get_collider() as Node2D
			if is_instance_valid(body):rows.append({"path":str(body.get_path()),"instance_id":body.get_instance_id(),"position":[hit.get_position().x,hit.get_position().y]})
		return rows
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg=="--delete-receiver": broken=true
		if arg=="--delete-receiver-platform-only": broken=true;platform_only=true
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
				receiver_fault=delete_receiver(trace.stage,well,not platform_only)
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


# Fault injection only: the actual receiving shore comprises its slab AND the
# collision-bearing earth directly attached beneath the slab. No production
# lifecycle behavior, other bank, lower room or unrelated support is changed.
func rect_array(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func support_inventory(supports: PlainsGroundSupports) -> Array:
	var rows: Array=[]
	if not is_instance_valid(supports):return rows
	for body: Node in supports.get_children():
		if not body is StaticBody2D:continue
		for child: Node in body.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				var shape: RectangleShape2D=child.shape
				rows.append({"path":str(body.get_path()),"instance_id":body.get_instance_id(),"rect":rect_array(Rect2(body.position+child.position-shape.size*.5,shape.size)),"collision_layer":body.collision_layer})
	return rows
func delete_receiver(assembler: PlainsRegionAssembler,well: PlatformingModule,complete: bool) -> Dictionary:
	var slab: Rect2=well.definition.platforms[1]
	var receiver:=Rect2(well.position+slab.position,slab.size)
	var supports: PlainsGroundSupports=assembler.ground_supports
	var before:=support_inventory(supports)
	var removed: Array=[]
	var kept: Array[Rect2]=[]
	well.get_node("Platform1").free()
	if complete and is_instance_valid(supports):
		for column: Rect2 in supports.columns:
			var left:=maxf(column.position.x,receiver.position.x)
			var right:=minf(column.end.x,receiver.end.x)
			if not is_equal_approx(column.position.y,receiver.end.y) or right<=left:
				kept.append(column);continue
			removed.append(rect_array(Rect2(Vector2(left,column.position.y),Vector2(right-left,column.size.y))))
			if left>column.position.x:kept.append(Rect2(column.position,Vector2(left-column.position.x,column.size.y)))
			if right<column.end.x:kept.append(Rect2(Vector2(right,column.position.y),Vector2(column.end.x-right,column.size.y)))
		# Preserve unrelated bodies and their IDs; replace only intersecting body
		# pieces by exact left/right remainders, rather than clearing all earth.
		for body: Node in supports.get_children():
			if not body is StaticBody2D:continue
			var shape_node:=body.get_child(0) as CollisionShape2D
			var rectangle:=shape_node.shape as RectangleShape2D
			var bounds:=Rect2(body.position+shape_node.position-rectangle.size*.5,rectangle.size)
			if not is_equal_approx(bounds.position.y,receiver.end.y) or bounds.end.x<=receiver.position.x or bounds.position.x>=receiver.end.x:continue
			var pieces: Array[Rect2]=[]
			if bounds.position.x<receiver.position.x:pieces.append(Rect2(bounds.position,Vector2(receiver.position.x-bounds.position.x,bounds.size.y)))
			if bounds.end.x>receiver.end.x:pieces.append(Rect2(Vector2(receiver.end.x,bounds.position.y),Vector2(bounds.end.x-receiver.end.x,bounds.size.y)))
			body.free()
			for piece: Rect2 in pieces:
				var replacement:=StaticBody2D.new();replacement.position=piece.get_center();replacement.collision_layer=1
				var collision:=CollisionShape2D.new();var actual:=RectangleShape2D.new();actual.size=piece.size;collision.shape=actual
				replacement.add_child(collision);supports.add_child(replacement)
		supports.columns=kept;supports.queue_redraw()
	var after:=support_inventory(supports)
	check(not before.is_empty(),"receiver fault observes actual collision-bearing earth before deletion")
	check(not complete or not removed.is_empty(),"complete receiver deletion removes attached earth only")
	return {"complete":complete,"receiver":rect_array(receiver),"slab_path":str(well.get_path())+"/Platform1","support_before":before,"support_after":after,"removed_fragments":removed,"scope":"actual slab plus exact immediately attached support footprint only; unrelated collider IDs retained"}

func finish() -> void:

	var data: Dictionary={"version":PlainsRegionGenerator.VERSION,"assertions":assertions,"failures":failures,"deleted_receiver":broken,"platform_only":platform_only,"receiver_fault":receiver_fault,"manifests":manifests,"observations":observations,"semantic_cases":semantic_cases,"semantic_negatives":semantic_negatives,"corpus_mode":corpus_mode}
	if not output.is_empty():
		var f:=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
	print("PLAINS REDESIGN SPATIAL: %s assertions, %s failures"%[assertions,failures])
	quit(1 if failures else 0)
