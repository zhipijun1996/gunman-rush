extends "res://tests/thorn_queen_weave_runner.gd"
## All strategies share the real Queen Definition, arena, resources and shooting cooldown.
var _shot_cooldown := 0
var _ordinary_shape_traces: Array[Dictionary] = []
func frames(count: int) -> void:
	for index: int in count:
		await super.frames(1)
		if not frames_data.is_empty() and is_instance_valid(queen):
			var row: Dictionary=frames_data.back()
			row.boss_position=[queen.motor.position.x,queen.motor.position.y]
			row.motion_mode=queen.motion_mode;row.perch=queen.perch_index;row.migrations=queen.migrations
			row.fields=queen.combat_snapshot().fields
func ordinary_surface_aim() -> Dictionary:
	_ordinary_shape_traces.clear()
	# All strategies share these actual-body samples and radius-three projectile clearance.
	# This is a finite fair-driver sample, never proof of all possible shot angles.
	var half := queen.definition.collision_size*.5-Vector2(2,2)
	var samples: Array[Vector2]=[Vector2.ZERO,Vector2(0,-half.y),Vector2(-half.x,0),Vector2(half.x,0),Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(-half.x,half.y),Vector2(half.x,half.y),Vector2(0,half.y)]
	var velocity := queen.motor.velocity
	var speed := controller.shoot_ability.tuning.projectile_speed
	var circle := CircleShape2D.new()
	circle.radius=controller.shoot_ability.tuning.projectile_radius
	for surface: Vector2 in samples:
		var offset := queen.motor.global_position+surface-player.global_position
		var aa := velocity.length_squared()-speed*speed
		var bb := 2*offset.dot(velocity)
		var cc := offset.length_squared()
		var disc := bb*bb-4*aa*cc
		var travel := 0.0
		if disc>=0 and absf(aa)>.001:
			var first := (-bb+sqrt(disc))/(2*aa)
			var second := (-bb-sqrt(disc))/(2*aa)
			travel=maxf(first,second) if minf(first,second)<=0 else minf(first,second)
		var target_point := queen.motor.global_position+surface+velocity*maxf(0,travel)
		var aim := (target_point-player.global_position).normalized()
		var visual := player.get_node("CourierVisual") as CourierVisual
		# Same live visual API used by ShootAbility._emit_round; this only poses candidate aim.
		var muzzle := visual.muzzle_position(aim)
		for iteration: int in 2:
			aim=(target_point-muzzle).normalized()
			muzzle=visual.muzzle_position(aim)
		if not clear_ordinary_segment(player.global_position,muzzle,circle): continue
		if not clear_ordinary_segment(muzzle,target_point,circle): continue
		return {"aim":aim,"surface":surface,"predicted_body_point":target_point,"muzzle":muzzle}

	return {}
func clear_ordinary_segment(first: Vector2,last: Vector2,circle: CircleShape2D) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape=circle;query.transform=Transform2D(0,first)
	query.collision_mask=0xFFFFFFFF;query.collide_with_areas=true
	query.exclude=[player.get_rid(),queen.motor.get_rid()]
	var space := player.get_world_2d().direct_space_state
	var overlaps := space.intersect_shape(query,1)
	if not overlaps.is_empty():
		_ordinary_shape_traces.append({"start":[first.x,first.y],"end":[last.x,last.y],"radius":circle.radius,"overlap_count":overlaps.size(),"safe_fraction":[]})
		return false
	query.motion=last-first
	var sweep := space.cast_motion(query)
	_ordinary_shape_traces.append({"start":[first.x,first.y],"end":[last.x,last.y],"radius":circle.radius,"overlap_count":0,"safe_fraction":Array(sweep)})
	return sweep.size()==2 and sweep[0]>=.99999
func continuous_fire() -> void:
	if controller.shoot_ability.cooldown_remaining>0: return
	var shot := ordinary_surface_aim()
	if shot.is_empty(): return
	var aim: Vector2=shot.aim
	if player.is_on_floor():
		# Fire at the actual maximum cadence once the real recoil has a receiving bank.
		var distance := player.weapon_motion.base_distance(controller.shoot_ability.tuning,true)
		var landing_x := player.global_position.x-aim.x*distance
		for bank: Dictionary in geometry.platforms:
			var a: Array=bank.rect
			if absf(player.global_position.y+actual_body_half.y-float(a[1]))>1: continue
			if player.global_position.x-actual_body_half.x<float(a[0]) or player.global_position.x+actual_body_half.x>float(a[0])+float(a[2]): continue
			if landing_x-actual_body_half.x<float(a[0]) or landing_x+actual_body_half.x>float(a[0])+float(a[2]):
				controller.router.set_move_axis(signf(aim.x))
				return
			break
	else:
		var distance := player.weapon_motion.base_distance(controller.shoot_ability.tuning,false)
		var predicted := player.global_position-aim*distance
		var a: Array=geometry.boss_arena
		var allowed := Rect2(a[0],a[1],a[2],a[3])
		if not allowed.encloses(Rect2(predicted-actual_body_half,actual_body_half*2)): return
	var surface: Vector2=shot.surface
	var queued := controller.router.request_action(&"shoot_release",aim)
	events.append({"case":current,"tick":tick,"event":"shot_request","queued":queued,"aim":[aim.x,aim.y],"aim_surface_local":[surface.x,surface.y],"projectile_radius":controller.shoot_ability.tuning.projectile_radius,"visibility_method":"actual_barrel_then_muzzle_circle_except_target","predicted_muzzle":[shot.muzzle.x,shot.muzzle.y]})
func opening(strategy: String) -> void:
	if strategy=="H_pursuit":
		await walk(235)
		controller.router.set_jump_held(&"queen_migration",true);await frames(23);controller.router.set_jump_held(&"queen_migration",false)
		for index: int in 70:
			if player.is_on_floor() and player.position.y<400: break
			await frames(1)
		check(await hook(queen.knot.global_position),"actual knot H contact")
		check(await hook(Vector2(geometry.hook_anchors[0].position[0],geometry.hook_anchors[0].position[1])),"actual fixed upper H")
		controller.router.request_action(&"shoot_release",Vector2.LEFT);await frames(15)
		for index: int in 90:
			if player.is_on_floor(): break
			await frames(1)
	elif strategy in ["noH_upper_camp","noH_central_camp","cut_then_upper","cut_all_then_upper"]:
		if strategy in ["cut_then_upper","cut_all_then_upper"]:
			await walk(350)
			for index: int in 4:
				if queen.knot.health.terminal: break
				await shoot(queen.knot.global_position)
			if strategy=="cut_all_then_upper":
				await walk(610)
				for index: int in 4:
					if queen.knots[1].health.terminal: break
					await shoot(queen.knots[1].global_position)
				await walk(130)
		controller.router.set_move_axis(1)
		controller.router.set_jump_held(&"queen_migration",true);await frames(23);controller.router.set_jump_held(&"queen_migration",false)
		controller.router.request_action(&"shoot_release",Vector2(-1,1).normalized());await frames(15)
		controller.router.request_action(&"shoot_release",Vector2(-1,1).normalized());await frames(10)
		for index: int in 100:
			if player.position.x>540: controller.router.set_move_axis(0)
			if player.is_on_floor(): break
			await frames(1)
		controller.router.set_move_axis(0)
		if strategy=="noH_central_camp": await walk(465)
	elif strategy=="noH_right_jump":
		await walk(760,240)
		controller.router.set_jump_held(&"queen_migration",true);await frames(23);controller.router.set_jump_held(&"queen_migration",false)
		for index: int in 100:
			if player.is_on_floor(): break
			await frames(1)
func strategy_case(strategy: String) -> void:
	await fixture(strategy,strategy=="H_pursuit" or strategy=="observe_two_changes")
	_shot_cooldown=0
	var row := {"id":current,"initial_player_hp":controller.actor_resources.health.current,"initial_boss_hp":queen.health.current,"initial_energy":controller.actor_resources.stamina.current,"initial_knots":[queen.knots[0].health.current,queen.knots[1].health.current],"observation_only":strategy=="observe_two_changes"}
	await opening(strategy)
	row.opening_tick=tick;row.opening_position=[player.position.x,player.position.y]
	for index: int in 1000:
		if queen.health.terminal or controller.actor_resources.health.terminal: break
		if strategy=="observe_two_changes":
			if queen.migrations>=2: break
		else:
			continuous_fire()
			var destination := 465.0 if queen.perch_index==1 else 620.0
			if strategy!="H_pursuit": destination=float(row.opening_position[0])
			# Normal axis correction counters real recoil for every waiting/control strategy too.
			controller.router.set_move_axis(0 if absf(player.position.x-destination)<8 else signf(destination-player.position.x))
			if strategy=="noH_right_jump": controller.router.set_jump_held(&"queen_migration_repeat",queen.perch_index==1)
		await frames(1)
	controller.router.set_move_axis(0)
	row.ticks=tick;row.boss_damage=row.initial_boss_hp-queen.health.current;row.player_damage=row.initial_player_hp-controller.actor_resources.health.current
	row.boss_defeated=queen.health.terminal;row.migrations=queen.migrations;row.final_energy=controller.actor_resources.stamina.current
	row.final_position=[player.position.x,player.position.y];row.final_knots=[queen.knots[0].health.current,queen.knots[1].health.current]
	var arena_row: Array=geometry.boss_arena
	row.retained_in_arena=Rect2(arena_row[0],arena_row[1],arena_row[2],arena_row[3]).encloses(Rect2(player.position-actual_body_half,actual_body_half*2))
	check(row.retained_in_arena,"terminal strategy remains inside real full-body arena")
	if strategy=="observe_two_changes": check(queen.migrations>=2,"actual continuous A-B-A movement completes without teleport or collision stall")
	cases.append(row)
func queen_definition() -> Resource: return load("res://resources/bosses/thorn_queen_v2.tres")
func run() -> void:
	var names := ["observe_two_changes","H_pursuit","noH_upper_camp","noH_central_camp","noH_right_jump","cut_then_upper","cut_all_then_upper"]
	for strategy: String in names:
		if selected in ["all",strategy]: await strategy_case(strategy)
	await cleanup()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := {"capture_schema":3,"task_id":"FOREST-DEPTH-02","scope":"Queen two-perch mechanism comparison, not map2 admission","selected":selected,"assertions":assertions,"failures":failures,"cases":cases,"events":events,"frames":frames_data,"geometry":geometry,"migration_speed":(queen_definition() as ThornQueenWeaveDefinition).migration_speed,"definition_sha256":FileAccess.get_sha256("res://resources/bosses/thorn_queen_v2.tres"),"player_tuning_sha256":FileAccess.get_sha256("res://config/player_tuning.json"),"actual_body_half_extents":[actual_body_half.x,actual_body_half.y],"manual_motor_step":false,"midroute_player_position_or_resource_writes":false,"design_verdict":"requires_independent_comparison"}
	FileAccess.open(output_dir+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("QUEEN MIGRATION GOLDEN: %s assertions, %s failures"%[assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
