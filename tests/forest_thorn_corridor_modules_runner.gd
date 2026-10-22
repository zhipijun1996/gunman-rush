extends SceneTree
## Full-body root screens plus actual isolated Motor input cases. World/art/FUN remain separate.
const LIBRARY := preload("res://scripts/generation/forest_thorn_corridor_modules.gd")
const PLAYER := preload("res://scenes/player/player.tscn")
var assertions := 0
var failures := 0
var body_size := Vector2.ZERO
var observations: Array[Dictionary] = []
var output := "res://build/region_bible_v2/forest-thorn-corridors"
var _native_world: Node2D
var _native_player: PlayerMotor
var _native_controller: PlayerController
var _native_tick := 0
var _native_case := ""
var _native_phase := ""
var _native_failure := ""
var _native_jump_held := false
var _native_cache_point_touched := false
var _native_frames: Array[Dictionary] = []
var _native_requests: Array[Dictionary] = []
var _native_events: Array[Dictionary] = []
var _native_legs: Array[Dictionary] = []
var _native_cases: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	assertions += 1
	observations.append({"label":label,"passed":ok})
	if not ok: failures += 1; push_error(label)

func run() -> void:
	var state := PLAYER.get_state()
	for index: int in state.get_node_count():
		if state.get_node_name(index) != &"CollisionShape2D": continue
		for property: int in state.get_node_property_count(index):
			if state.get_node_property_name(index,property) == &"shape":
				var shape := state.get_node_property_value(index,property) as RectangleShape2D
				if shape != null: body_size = shape.size
	check(body_size.x>0.0 and body_size.y>0.0,"use actual player body, never point-route clearance")
	check(LIBRARY.build("not_a_thorn_corridor").is_empty(),"unknown bend id is refused")
	var ids: Dictionary = {}
	for row: Dictionary in LIBRARY.catalogue():
		check(not ids.has(str(row.id)),"unique registered bend identity")
		ids[str(row.id)] = true
		var m: Dictionary = LIBRARY.build(str(row.id))
		check(not m.is_empty() and m.requires==["grapple"] and m.admission.motor=="unverified" and not m.admission.production_pool,"actual geometry candidate is S2-H only and makes no Motor claim")
		var supports := support_map(m)
		var bounds := rect(m.world_bounds)
		for platform: Dictionary in m.platforms:
			check(rect(platform.rect).has_area() and bounds.encloses(rect(platform.rect)),"complete actual root/recovery support is inside its deployment footprint")
		check(standing(m.spawn,str(m.entry_support_id),supports) and body_clear(point(m.spawn),supports),"full body fits actual entry port")
		check(standing(m.goal,str(m.exit_support_id),supports) and body_clear(point(m.goal),supports),"full body fits actual non-level exit port")
		check(standing(m.reward_position,str(m.reward_support_id),supports) and body_clear(point(m.reward_position),supports),"receiving-root reward has real full-body support")
		check(route_clear(m.steps,point(m.spawn),supports),"ordinary main route has actual landings, body-clear walks and drop columns")
		check(route_clear(m.routes.returning,point(m.reward_position),supports),"represented return reaches departure using actual root/recovery support")
		check(route_clear(m.routes.recovery,point(m.recovery_start),supports),"failure basin has full-body retry path")
		check(m.routes.returning[-1].landing==m.spawn and m.routes.returning[-1].support_id==m.entry_support_id,"return ends at its declared original departure, not a fake other-hub rejoin")
		check(hazards(m,supports),"up24/down16 thorns contact the named real solid surface")
		check(catch_clear(m,supports),"entire catch basin keeps standing body clear of upper roots")
		var anchors: Dictionary = {}
		for anchor: Dictionary in m.hook_anchors:
			anchors[str(anchor.id)] = anchor
			check(supports.has(str(anchor.host_support_id)) and on_surface(point(anchor.stem_root),rect(supports[anchor.host_support_id].rect)),"fruit stem originates on its real connected host bough")
		for action: Dictionary in m.action_program:
			check((action.action=="H" and anchors.has(str(action.get("anchor","")))) or (action.action=="R" and point(action.get("direction",[0,0])).length_squared()>0.0),"optional H/R references actual fruit and direction")
		if str(row.id)=="thorn_l_root_turn": l_counterexamples(m,supports)
		else: folded_root_checks(m,supports)
	if failures==0:
		await actual_corridor_case("thorn_l_root_turn","whole_main_from_spawn",false)
		await actual_corridor_case("thorn_l_root_turn","reward_and_return_same_body",true)
		for id: String in ["thorn_7_root_fold","thorn_z_root_switchback"]:
			await actual_corridor_case(id,id+"/whole_main_from_spawn",false)
			await actual_corridor_case(id,id+"/reward_and_return_same_body",true)
			await actual_corridor_case(id,id+"/cheap_ordinary_onward",false,true)
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions,"failures":failures,"body_size":[body_size.x,body_size.y],"checks":observations,"native_cases":_native_cases,"native_frames":_native_frames,"native_requests":_native_requests,"native_events":_native_events,"native_legs":_native_legs,"geometry_sha256":FileAccess.get_sha256("res://scripts/generation/forest_thorn_corridor_modules.gd"),"runner_sha256":FileAccess.get_sha256("res://tests/forest_thorn_corridor_modules_runner.gd"),"scope":"static full-body screens plus isolated actual Router/Controller/Motor main, same-body reward return and ordinary fast-onward comparisons; geometric hazard sweep is not formal DamagePolicy, whole-world, graphics or player/FUN approval"},"\t"))
	print("FOREST THORN CORRIDORS: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)

func l_counterexamples(m: Dictionary,supports: Dictionary) -> void:
	check(float(m.goal[1])>float(m.spawn[1]) and float(m.corridor_contract.exit_floor_y)==160.0 and bool(m.corridor_contract.non_level_ports),"L actually descends then advances horizontally; lower output is explicit")
	var drop: Dictionary = m.steps[1]
	check(drop.kind=="drop_through" and float(drop.path[-1][1])-float(drop.path[0][1])>=160.0,"L descent is an executable outside drop rather than a shape label")
	var tuning := PlayerTuning.load_default()
	var dt := 1.0/float(Engine.physics_ticks_per_second)
	var first_delta := Vector2(minf(tuning.ground_speed,tuning.air_acceleration*dt)*dt,(tuning.jump_speeds[0]+tuning.gravity*dt)*dt)
	var bad_body := Rect2(Vector2(544.0,142.0)+first_delta-body_size*.5,body_size)
	var good_body := Rect2(Vector2(528.0,142.0)+first_delta-body_size*.5,body_size)
	check(bad_body.intersects(rect(m.dangers[1])),"retained bad544 takeoff overlaps the actual thorn on the first full-speed jump frame")
	check(not good_body.intersects(rect(m.dangers[1])),"earlier528 takeoff separates first jump body from thorn; full arc still requires Motor")
	var definition := load("res://resources/player/traversal.tres") as TraversalDefinition
	var shortcut: Dictionary = m.shortcut_contract
	var anchor: Dictionary = m.hook_anchors[0]
	var origin := point(shortcut.start)+Vector2(0,-6)
	check(point(anchor.position).distance_to(origin)+definition.hook_capture_radius<definition.hook_range,"actual shortcut departure and fruit fit production range with capture margin")
	check(body_clear(point(shortcut.start),supports) and standing(shortcut.start,str(shortcut.start_support),supports) and shortcut.jump_before_hook,"optional HR begins at real safe root and records jump before capture")
	var bad := m.duplicate(true)
	bad.danger_surfaces[0].host_support_id="entry"
	check(not hazards(bad,supports),"remote host relabel cannot make floating thorns valid")
	bad=m.duplicate(true); bad.dangers[1][1]-=8.0
	check(not hazards(bad,supports),"detached upper thorn strip is rejected")
	bad=m.duplicate(true)
	for platform: Dictionary in bad.platforms:
		if platform.id=="catch": platform.rect[1]=240.0
	check(not catch_clear(bad,support_map(bad)),"catch floor with less than a full body below roots is rejected")
	var bad_steps: Array=m.steps.duplicate(true)
	bad_steps[1].path[1][0]=480.0; bad_steps[1].path[-1][0]=480.0; bad_steps[1].landing[0]=480.0
	check(not route_clear(bad_steps,point(m.spawn),supports),"drop column through the real upright root is rejected")
	bad_steps=m.steps.duplicate(true); bad_steps[3].landing=[676.0,142.0]
	check(not route_clear(bad_steps,point(m.spawn),supports),"landing centre inside branch but left body over gap is rejected")

func folded_root_checks(m: Dictionary,supports: Dictionary) -> void:
	check(route_clear(m.routes.reward,point(m.spawn),supports) and m.routes.reward[-1].landing==m.reward_position and m.routes.reward[-1].support_id==m.reward_support_id,"exploration reward route actually reaches its declared cache support and point")
	check(m.branch_reward_contract.reward_support_id==m.reward_support_id and m.branch_reward_contract.reward_position==m.reward_position and m.branch_reward_contract.fast_bypass_native.begins_with("unverified"),"legal fast bypass is acknowledged without a fabricated native proof or public-exit payout")
	var upper:=rect(supports.upper_root.rect)
	var inward:=rect(supports.middle_root.rect) if supports.has("middle_root") else rect(supports.lower_root.rect)
	check(absf(inward.position.y-upper.position.y-288.0)<.01 and inward.position.y-upper.end.y>=240.0,"folded roots leave240wu real standing/jump space rather than a low ceiling")
	check(standing(m.steps[3].landing,str(m.steps[3].support_id),supports) and point(m.steps[3].landing).x>upper.end.x+body_size.x*.5,"far-side controlled fall clears the upper root and has a full-body receiver")
	check(float(m.steps[4].landing[0])>float(m.steps[5].landing[0]) and m.steps[5].from_support_id==m.steps[5].support_id,"inward leg is an actual reverse thorn crossing on the receiving root")
	if str(m.id)=="thorn_7_root_fold":
		check(float(m.goal[0])<float(m.steps[3].landing[0]) and float(m.goal[1])>float(m.spawn[1]),"7 preserves its actual lower-left output rather than a fabricated right port")
		check(m.reward_support_id=="lower_root" and float(m.reward_position[0])>960.0 and m.routes.reward[-1].landing==m.reward_position,"7 actual far-side cache is separate from near-side fast output")
	else:
		var lower:=rect(supports.lower_root.rect)
		check(m.reward_support_id=="middle_root" and float(m.reward_position[0])<640.0 and m.routes.reward[-1].landing==m.reward_position,"Z actual cache is in the middle-left fold, not at the cheap lower-right output")
		check(inward.end.x>=upper.end.x+body_size.x and lower.position.x<inward.position.x-body_size.x,"Z alternating solid roots catch both normal outside drops on the next tier")
		check(float(m.steps[7].landing[0])<inward.position.x-body_size.x*.5 and float(m.steps[9].landing[0])>float(m.steps[9].takeoff[0]),"Z actually turns left through its middle opening then right on the bottom root")
		check(m.optional_phrases.size()==2 and m.optional_phrases[0].start_support=="middle_root" and m.optional_phrases[1].start_support=="lower_root","opposite optional H/R phrases have actual intermediate receiving roots; not a fictitious unbroken air chain")
		var broken:=supports.duplicate(true)
		broken.middle_root.rect[2]=768.0
		check(not standing(m.steps[3].landing,"middle_root",broken),"shortened middle root cannot falsely catch the upper right drop")

func support_map(m: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for row: Dictionary in m.platforms: result[str(row.id)]=row
	return result

func standing(at: Array,id: String,supports: Dictionary) -> bool:
	if at.size()!=2 or not supports.has(id): return false
	var r:=rect(supports[id].rect); var p:=point(at)
	return absf(p.y+body_size.y*.5-r.position.y)<.01 and p.x-body_size.x*.5>=r.position.x-.01 and p.x+body_size.x*.5<=r.end.x+.01

func body_clear(at: Vector2,supports: Dictionary) -> bool:
	return sweep_clear(at,at,supports)

func sweep_clear(a: Vector2,b: Vector2,supports: Dictionary) -> bool:
	var sweep:=Rect2(a-body_size*.5,body_size).merge(Rect2(b-body_size*.5,body_size)).grow(-.001)
	for row: Dictionary in supports.values():
		if not bool(row.one_way) and sweep.intersects(rect(row.rect)): return false
	return true

func route_clear(steps: Array,start: Vector2,supports: Dictionary) -> bool:
	var previous:=start
	for step: Dictionary in steps:
		if not step.has("landing"): return false
		var target:=point(step.landing)
		var takeoff:=point(step.get("takeoff",[previous.x,previous.y]))
		if not standing(step.landing,str(step.get("support_id","")),supports) or not body_clear(target,supports): return false
		if step.has("from_support_id") and not standing(step.get("takeoff",[]),str(step.from_support_id),supports): return false
		if not body_clear(takeoff,supports): return false
		if step.kind=="walk" and not sweep_clear(previous,target,supports): return false
		if step.kind=="drop_through":
			var path: Array=step.get("path",[])
			if path.size()<2 or path[0]!=step.takeoff or path[-1]!=step.landing: return false
			for index: int in range(1,path.size()):
				var a:=point(path[index-1]); var b:=point(path[index])
				if not is_equal_approx(a.x,b.x) and not is_equal_approx(a.y,b.y): return false
				if not sweep_clear(a,b,supports): return false
		elif step.kind not in ["walk","jump_gap","jump_rise"]: return false
		previous=target
	return true

func hazards(m: Dictionary,supports: Dictionary) -> bool:
	if m.dangers.size()!=m.danger_surfaces.size(): return false
	for surface: Dictionary in m.danger_surfaces:
		if not supports.has(str(surface.host_support_id)): return false
		var host: Dictionary=supports[surface.host_support_id]
		if bool(host.one_way): return false
		var r:=rect(host.rect); var d:=rect(m.dangers[int(surface.danger_index)])
		if d.position.x<r.position.x or d.end.x>r.end.x: return false
		if surface.face=="up":
			if absf(d.end.y-r.position.y)>.01 or absf(d.size.y-24.0)>.01: return false
		elif surface.face=="down":
			if absf(d.position.y-r.end.y)>.01 or absf(d.size.y-16.0)>.01: return false
		else: return false
	return true

func catch_clear(m: Dictionary,supports: Dictionary) -> bool:
	var r:=rect(supports.catch.rect)
	return sweep_clear(Vector2(r.position.x+body_size.x*.5,r.position.y-body_size.y*.5),Vector2(r.end.x-body_size.x*.5,r.position.y-body_size.y*.5),supports)

func on_surface(p: Vector2,r: Rect2) -> bool:
	return r.has_point(p) or is_equal_approx(p.x,r.end.x) and p.y>=r.position.y and p.y<=r.end.y or is_equal_approx(p.y,r.end.y) and p.x>=r.position.x and p.x<=r.end.x

func point(at: Array) -> Vector2: return Vector2(float(at[0]),float(at[1]))
func rect(at: Array) -> Rect2: return Rect2(float(at[0]),float(at[1]),float(at[2]),float(at[3]))

func actual_corridor_case(module_id: String,case_name: String,return_to_spawn: bool,cheap_onward := false) -> void:
	var m: Dictionary=LIBRARY.build(module_id)
	var supports:=support_map(m)
	_native_case=case_name; _native_failure=""; _native_phase="settle"; _native_jump_held=false; _native_cache_point_touched=false
	_native_world=Node2D.new(); root.add_child(_native_world)
	for row: Dictionary in m.platforms:
		var at:=rect(row.rect)
		var body:=StaticBody2D.new(); body.name=str(row.id); body.position=at.get_center()
		body.collision_layer=1
		body.set_meta("support_ids",[str(row.id)])
		if bool(row.one_way): body.add_to_group(&"one_way_platform")
		var shape:=CollisionShape2D.new(); var rectangle:=RectangleShape2D.new()
		rectangle.size=at.size; shape.shape=rectangle
		shape.one_way_collision=bool(row.one_way)
		if shape.one_way_collision: shape.one_way_collision_margin=4.0
		body.add_child(shape); _native_world.add_child(body)
	for row: Dictionary in m.hook_anchors:
		var anchor:=GrappleAnchor.new(); anchor.name=str(row.id); anchor.position=point(row.position)
		anchor.hang_enabled=bool(row.get("hang_enabled",false)); _native_world.add_child(anchor)
	_native_player=PLAYER.instantiate()
	# The only body-position assignment in this fixture is its initial spawn.
	_native_player.position=point(m.spawn); _native_world.add_child(_native_player)
	_native_controller=_native_player.get_node("Controller") as PlayerController
	_native_controller.set_physics_process(false)
	for name: String in ["KeyboardMouseAdapter","PlayerVisualAdapter"]:
		_native_player.get_node(name).process_mode=Node.PROCESS_MODE_DISABLED
	_native_controller.traversal.grant(&"grapple") # Initial S2 fixture capability only.
	_native_controller.jump_ability.jumped.connect(func() -> void:
		_native_events.append({"case":_native_case,"tick":_native_tick,"kind":"jumped","position":[_native_player.position.x,_native_player.position.y]}))
	var before:=native_snapshot()
	for unused: int in 3:
		if not await native_frame(m): break
	var reward_checkpoint_verified:=false
	var ok: bool=_native_failure.is_empty()
	if ok: ok=await native_move(point(m.spawn),str(m.entry_support_id),supports,m,"initial_entry")
	if ok:
		if cheap_onward:
			if module_id=="thorn_z_root_switchback": ok=await native_steps(m.steps.slice(0,4),supports,m,"ordinary_fast_upper_approach")
			if ok: ok=await native_outer_descent(m,supports,-1 if module_id=="thorn_7_root_fold" else 1,"upper_root" if module_id=="thorn_7_root_fold" else "middle_root",point(m.goal),str(m.exit_support_id))
		elif return_to_spawn:
			# The same real body follows the explicit prefix to the cache root,
			# walks to the actual reward point, then returns. No reward-pose fixture.
			ok=await native_steps(m.steps.slice(0,int(m.reward_outbound_step_count)),supports,m,"outbound_to_receiver")
			if ok:
				ok=await native_move(point(m.reward_position),str(m.reward_support_id),supports,m,"actual_reward_arrival")
				reward_checkpoint_verified=ok
				if ok: _native_events.append({"case":_native_case,"tick":_native_tick,"kind":"actual_cache_arrival","position":[_native_player.position.x,_native_player.position.y],"reward_support_id":str(m.reward_support_id),"expected_position":m.reward_position.duplicate(),"stable_frames":12})
			if ok: ok=await native_steps(m.routes.returning,supports,m,"reward_return")
		else: ok=await native_steps(m.steps,supports,m,"whole_main")
	var final:=native_snapshot()
	var destination: Array=m.spawn if return_to_spawn else m.goal
	var destination_support: String=str(m.entry_support_id) if return_to_spawn else str(m.exit_support_id)
	var completed: bool=ok and _native_failure.is_empty() and native_at(point(destination),destination_support,supports) and (not cheap_onward or not _native_cache_point_touched) and (not return_to_spawn or reward_checkpoint_verified)
	check(completed,"actual Router/Controller/Motor completes "+case_name+" with12 supported final frames")
	check(before.config==final.config and before.collision_size==final.collision_size and final.double_enabled==false and final.wall_enabled==false and final.maximum_jumps==1,"actual corridor route preserves configuration/body and S2-H grants / "+case_name)
	check(before.shots==final.shots and before.health==final.health,"ordinary corridor route and return do not inject/spend shots or health / "+case_name)
	_native_cases.append({"id":case_name,"module_id":module_id,"passed":completed,"failure":_native_failure,
		"initial":before,"final":final,"expected_destination":destination.duplicate(),"expected_support":destination_support,
		"reward_checkpoint_verified":reward_checkpoint_verified,"cheap_ordinary_onward":cheap_onward,"cache_point_touched_by_body_plus16wu":_native_cache_point_touched,"reward_support_id":str(m.reward_support_id),"reward_position":m.reward_position.duplicate(),
		"midroute_position_writes":false,"manual_motor_step":false,"controller_tick_only":true,
		"scope":"actual isolated module Router/Controller/Motor + exact geometric hazard sweep; not formal DamagePolicy, complete world, graphics or player approval"})
	_native_controller.router.clear("fixture_finished")
	_native_world.free(); _native_world=null; _native_player=null; _native_controller=null
	await physics_frame

func native_steps(steps: Array,supports: Dictionary,m: Dictionary,route_name: String) -> bool:
	for index: int in steps.size():
		if not _native_failure.is_empty(): return false
		var row: Dictionary=steps[index]
		var target:=point(row.landing)
		var support:=str(row.support_id)
		var label:=route_name+"/"+str(index)+"/"+str(row.kind)
		if row.kind=="walk":
			if not await native_move(target,support,supports,m,label): return false
		elif row.kind in ["jump_gap","jump_rise"]:
			if not await native_jump(row,supports,m,label): return false
		elif row.kind=="drop_through":
			if not await native_drop(row,supports,m,label): return false
		else: return native_fail("unsupported_actual_step/"+str(row.kind))
	return true

func native_move(target: Vector2,support: String,supports: Dictionary,m: Dictionary,label: String) -> bool:
	_native_phase=label
	var stable:=0; var started:=_native_tick
	native_hold(false)
	for unused: int in 1200:
		_native_controller.router.set_move_axis(clampf((target.x-_native_player.position.x)/12.0,-1.0,1.0))
		if not await native_frame(m): return false
		stable=stable+1 if native_at(target,support,supports) and absf(_native_player.velocity.x)<1.0 else 0
		if stable>=12:
			_native_legs.append({"case":_native_case,"kind":"walk","label":label,"start_tick":started+1,"tick":_native_tick,"target":[target.x,target.y],"support_id":support,"stable_frames":stable})
			return true
	return native_fail("walk_tick_budget/"+label)

func native_jump(row: Dictionary,supports: Dictionary,m: Dictionary,label: String) -> bool:
	if not await native_move(point(row.takeoff),str(row.from_support_id),supports,m,label+"/takeoff"): return false
	_native_phase=label
	var target:=point(row.landing); var support:=str(row.support_id)
	var target_rect:=rect(supports[support].rect)
	var stable:=0; var started:=_native_tick; var released:=false
	var same_support: bool=str(row.from_support_id)==support
	native_hold(true)
	for index: int in 1200:
		_native_controller.router.set_move_axis(clampf((target.x-_native_player.position.x)/12.0,-1.0,1.0))
		if not await native_frame(m): return false
		var foot:=_native_player.position+Vector2(0,body_size.y*.5)
		var full_x: bool=foot.x-body_size.x*.5>=target_rect.position.x and foot.x+body_size.x*.5<=target_rect.end.x
		var designated_receiver_x: bool=not same_support or absf(foot.x-target.x)<=body_size.x*.5
		if not released and foot.y<target_rect.position.y-1.0 and full_x and designated_receiver_x:
			native_hold(false); released=true
			_native_events.append({"case":_native_case,"tick":_native_tick,"kind":"actual_receiver_clearance_release","position":[_native_player.position.x,_native_player.position.y],"support_id":support,"same_support":same_support,"designated_landing_x":target.x})
		stable=stable+1 if native_at(target,support,supports) and absf(_native_player.velocity.x)<1.0 else 0
		if stable>=12:
			native_hold(false)
			_native_legs.append({"case":_native_case,"kind":str(row.kind),"label":label,"start_tick":started+1,"tick":_native_tick,"target":[target.x,target.y],"support_id":support,"stable_frames":stable})
			return true
		if index>25 and _native_player.is_on_floor() and not native_supported(support,supports): return native_fail("actual_jump_wrong_support/"+label)
	return native_fail("jump_tick_budget/"+label)

func native_drop(row: Dictionary,supports: Dictionary,m: Dictionary,label: String) -> bool:
	if not await native_move(point(row.takeoff),str(row.from_support_id),supports,m,label+"/takeoff"): return false
	_native_phase=label
	var path: Array=row.path
	var cursor:=1; var stable:=0; var started:=_native_tick; var last_drop:=-100
	native_hold(false)
	for unused: int in 1200:
		var target:=point(path[cursor])
		_native_controller.router.set_move_axis(clampf((target.x-_native_player.position.x)/12.0,-1.0,1.0))
		if cursor>1 and _native_player.is_on_floor() and _native_player.position.y<target.y-20.0 and _native_tick-last_drop>=20:
			_native_controller.router.request_action(&"drop_through"); last_drop=_native_tick
			_native_requests.append({"case":_native_case,"tick":_native_tick+1,"kind":"drop_through"})
		if not await native_frame(m): return false
		if cursor==1 and path.size()>2:
			if absf(_native_player.position.x-target.x)<7.0:
				_native_events.append({"case":_native_case,"tick":_native_tick,"kind":"actual_drop_mouth","point":path[cursor].duplicate()});cursor+=1
			continue
		stable=stable+1 if native_at(target,str(row.support_id),supports) and absf(_native_player.velocity.x)<1.0 else 0
		if stable>=12:
			_native_legs.append({"case":_native_case,"kind":"drop_through","label":label,"start_tick":started+1,"tick":_native_tick,"target":row.landing.duplicate(),"support_id":str(row.support_id),"stable_frames":stable})
			return true
	return native_fail("drop_tick_budget/"+label)

func native_outer_descent(m: Dictionary,supports: Dictionary,side: int,root_id: String,target: Vector2,target_support: String) -> bool:
	# Real ordinary alternate: walk off the chosen outside edge, wait until
	# the full body is below that root, then steer into the lower receiver.
	# This deliberately proves a legal cheap onward route, not a cache route.
	var root_rect:=rect(supports[root_id].rect)
	var outside_x:=root_rect.end.x+body_size.x*.5+4.0 if side>0 else root_rect.position.x-body_size.x*.5-4.0
	_native_phase="ordinary_fast_outside_walkoff"
	native_hold(false)
	var cleared_edge:=false
	for unused: int in 600:
		_native_controller.router.set_move_axis(clampf((outside_x-_native_player.position.x)/12.0,-1.0,1.0))
		if not await native_frame(m): return false
		if absf(_native_player.position.x-outside_x)<=1.0:
			cleared_edge=true;break
	if not cleared_edge: return native_fail("ordinary_outer_edge_tick_budget")
	_native_events.append({"case":_native_case,"tick":_native_tick,"kind":"actual_ordinary_outer_edge","root":root_id,"position":[_native_player.position.x,_native_player.position.y]})
	_native_phase="ordinary_fast_outside_fall"
	var cleared_underside:=false
	for unused: int in 600:
		_native_controller.router.set_move_axis(clampf((outside_x-_native_player.position.x)/12.0,-1.0,1.0))
		if not await native_frame(m): return false
		if _native_player.position.y-body_size.y*.5>=root_rect.end.y+2.0:
			cleared_underside=true;break
	if not cleared_underside: return native_fail("ordinary_outer_underside_tick_budget")
	_native_events.append({"case":_native_case,"tick":_native_tick,"kind":"actual_ordinary_outer_fullbody_below_root","root":root_id,"position":[_native_player.position.x,_native_player.position.y]})
	return await native_move(target,target_support,supports,m,"ordinary_fast_lower_receiver")

func native_frame(m: Dictionary) -> bool:
	if not _native_failure.is_empty(): return false
	await physics_frame
	_native_tick+=1
	var previous:=_native_player.position
	var before_steps:=_native_player.motion_steps
	_native_controller.physics_tick(1.0/float(Engine.physics_ticks_per_second))
	var actual:=_native_player.position
	if Rect2(actual-body_size*.5,body_size).grow(16.0).has_point(point(m.reward_position)): _native_cache_point_touched=true
	var motion_delta:=_native_player.motion_steps-before_steps
	var frame: Dictionary={"case":_native_case,"tick":_native_tick,"phase":_native_phase,"position":[actual.x,actual.y],"previous_position":[previous.x,previous.y],"body":[actual.x-body_size.x*.5,actual.y-body_size.y*.5,body_size.x,body_size.y],"grounded":_native_player.is_on_floor(),"velocity":[_native_player.velocity.x,_native_player.velocity.y],"motor_step_delta":motion_delta,"shots":_native_controller.action_resources.shot_charges,"health":_native_controller.actor_resources.health.current,"hook_state":String(_native_controller.traversal.state),"jump_used":_native_controller.jump_ability.used_jumps}
	_native_frames.append(frame)
	if motion_delta!=1: return native_fail("one_controller_tick_must_make_one_actual_Motor_step")
	if _native_tick>16000: return native_fail("isolated_module_total_tick_budget")
	for index: int in m.dangers.size():
		var expanded:=Rect2(rect(m.dangers[index]).position-body_size*.5,rect(m.dangers[index]).size+body_size).grow(-.001)
		if segment_hits_rect(previous,actual,expanded):
			frame.hazard_index=index;frame.actual_hazard=m.dangers[index].duplicate()
			return native_fail("actual_body_sweeps_hazard/"+str(index)+"/"+_native_phase)
	return true

func segment_hits_rect(a: Vector2,b: Vector2,r: Rect2) -> bool:
	var delta:=b-a; var first:=0.0; var last:=1.0
	for axis: int in 2:
		if absf(delta[axis])<.000001:
			if a[axis]<=r.position[axis] or a[axis]>=r.end[axis]: return false
		else:
			var lo: float=(r.position[axis]-a[axis])/delta[axis]
			var hi: float=(r.end[axis]-a[axis])/delta[axis]
			first=maxf(first,minf(lo,hi));last=minf(last,maxf(lo,hi))
			if first>last: return false
	return first<=last and last>=0.0 and first<=1.0

func native_hold(held: bool) -> void:
	if held==_native_jump_held: return
	_native_jump_held=held
	_native_controller.router.set_jump_held(&"corridor_native",held)
	_native_requests.append({"case":_native_case,"tick":_native_tick+1,"kind":"jump_held","held":held})

func native_supported(id: String,supports: Dictionary) -> bool:
	if not is_instance_valid(_native_player) or not _native_player.is_on_floor() or not supports.has(id): return false
	var p:=_native_player.position; var r:=rect(supports[id].rect)
	if absf(p.y+body_size.y*.5-r.position.y)>1.0 or p.x-body_size.x*.5<r.position.x-.1 or p.x+body_size.x*.5>r.end.x+.1: return false
	for index: int in _native_player.get_slide_collision_count():
		var collision:=_native_player.get_slide_collision(index)
		var owner:=collision.get_collider() as Node
		if collision.get_normal().y<-.7 and owner!=null and id in owner.get_meta("support_ids",[]): return true
	return false

func native_at(target: Vector2,support: String,supports: Dictionary) -> bool:
	return native_supported(support,supports) and absf(_native_player.position.x-target.x)<=1.0 and absf(_native_player.position.y-target.y)<=1.0

func native_snapshot() -> Dictionary:
	return {"position":[_native_player.position.x,_native_player.position.y],"collision_size":[body_size.x,body_size.y],"double_enabled":_native_controller.traversal.double_enabled,"wall_enabled":_native_controller.traversal.wall_enabled,"hook_enabled":_native_controller.traversal.hook_enabled,"maximum_jumps":_native_controller.jump_ability.maximum_jumps(),"shots":_native_controller.action_resources.shot_charges,"health":_native_controller.actor_resources.health.current,"config":{"tuning":FileAccess.get_sha256("res://config/player_tuning.json"),"traversal":FileAccess.get_sha256("res://resources/player/traversal.tres")}}

func native_fail(reason: String) -> bool:
	if _native_failure.is_empty():
		_native_failure=reason
		_native_events.append({"case":_native_case,"tick":_native_tick,"kind":"failure","reason":reason})
	return false
