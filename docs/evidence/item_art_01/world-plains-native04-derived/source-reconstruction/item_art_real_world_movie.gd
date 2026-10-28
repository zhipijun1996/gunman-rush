extends "res://tests/item_v5_movie.gd"
## Supplement only. Never calls inherited _run/training_fixture/shoot_target.
## Real stage, real EnemyActor, real terrain/hazards. One player placement only.
const WATERMARK := "美术验证：道具/共鸣/站位为测试初始化"
var region: StringName = &"plains"
var world_seed := "level-design-v2-baseline/08"
var selected: Dictionary = {}
var candidates: Array[Dictionary] = []
var setup: Dictionary = {}
var art_cues: Array[Dictionary] = []
var probe_only := false
var start_world_draw := -1
var end_world_draw := -1
var initial_session := -1
var initial_stage_epoch := -1

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--trace="): destination = arg.trim_prefix("--trace=")
		elif arg.begins_with("--region="): region = StringName(arg.trim_prefix("--region="))
		elif arg.begins_with("--seed="): world_seed = arg.trim_prefix("--seed=")
		elif arg == "--probe": probe_only = true
	_run.call_deferred()

func target_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(app) or not is_instance_valid(app.stage): return result
	for index: int in app.stage.enemies.size():
		var motor: EnemyMotor = app.stage.enemies[index]
		if not is_instance_valid(motor): continue
		var actor := motor.get_node("Actor") as EnemyActor
		var attack := actor.attack_behavior
		result.append({"target":str(app.stage.enemy_manifest[index].id),"actor_id":actor.damageable.actor_id,"behavior":str(actor.definition.behavior_id),"hp":actor.health.current,"capacity":actor.health.capacity,"position":[motor.global_position.x,motor.global_position.y],"velocity":[motor.velocity.x,motor.velocity.y],"grounded":motor.is_on_floor(),"terminal":actor.health.terminal,"physics_enabled":actor.is_physics_processing(),"brain_direction":actor.brain.direction,"collision_layer":motor.collision_layer,"collision_mask":motor.collision_mask,"attack_state":str(attack.state) if attack != null else "patrol"})
	return result

func entity_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(app) or not is_instance_valid(app.stage): return result
	for node: Node in app.stage.get_children():
		if node is ItemV5Entity:
			var view := node as ItemV5Entity
			result.append({"kind":str(view.kind),"position":[view.global_position.x,view.global_position.y],"direction":[view.direction.x,view.direction.y],"age":view.age,"progress":view.progress,"artist":view.visual_snapshot()})
	return result

func hazard_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(app) or not is_instance_valid(app.stage) or not is_instance_valid(app.stage.assembler): return result
	for node: Node in app.stage.find_children("*","",true,false):
		if not node is ModuleSawHazard: continue
		var saw := node as ModuleSawHazard
		result.append({"kind":"saw","id":str(saw.runtime_source_id),"position":[saw.global_position.x,saw.global_position.y],"radius":saw.definition.radius,"enabled":saw.enabled,"clock":saw.module.clock})
	for record: Dictionary in app.stage.assembler.world_static_hazard_records():
		if record.get("role","") == "fall_plane": continue
		var rectangle: Rect2 = record.rect
		result.append({"kind":"static","position":[rectangle.get_center().x,rectangle.get_center().y],"rect":[rectangle.position.x,rectangle.position.y,rectangle.size.x,rectangle.size.y],"record":record})
	return result

func artist_snapshot() -> Dictionary:
	var result := {"library":ItemArtLibrary.diagnostics(),"view":{}}
	if not is_instance_valid(app) or not is_instance_valid(app.stage): return result
	for node: Node in app.stage.get_children():
		if node is ItemEffectView: result.view = (node as ItemEffectView).snapshot()
	return result

func frames(count: int) -> void:
	for unused: int in count:
		await super.frames(1)
		if rows.is_empty() or not is_instance_valid(app): continue
		rows[-1].artist = artist_snapshot()
		rows[-1].hazards = hazard_rows()
		rows[-1].application_focus = app.controller.router.has_application_focus if is_instance_valid(app.controller) else false
		if is_instance_valid(app._run_camera):
			var camera_point: Vector2 = app._run_camera.get_screen_center_position()
			rows[-1].camera = [camera_point.x,camera_point.y]
			rows[-1].zoom = [app._run_camera.zoom.x,app._run_camera.zoom.y]
		if is_instance_valid(app.controller):
			rows[-1].session = app.controller.session_id
			rows[-1].actor_epoch = app.lifetime.actor_epoch
			rows[-1].stage_epoch = app.lifetime.stage_epoch
			rows[-1].player_collision = [app.player.collision_layer,app.player.collision_mask]
			if not selected.is_empty():
				for actor_row: Dictionary in rows[-1].targets:
					if actor_row.target != selected.target: continue
					var actor_point := Vector2(actor_row.position[0],actor_row.position[1])
					var obstruction := _ray(app.player.global_position+Vector2(0,-7),actor_point)
					rows[-1].selected_target_los = {"clear":obstruction.is_empty(),"target":selected.target,"target_terminal":actor_row.terminal,"obstruction":[obstruction.position.x,obstruction.position.y] if not obstruction.is_empty() else []}

func _observe_art(kind: StringName, point: Vector2, detail: Dictionary) -> void:
	var origin := ItemArtLibrary.cue_source(kind,StringName(str(detail.get("definition_id",detail.get("origin",&"")))))
	art_cues.append({"kind":str(kind),"origin":str(origin),"event_id":str(detail.get("event_id",&"")),"point":[point.x,point.y],"clip":str(ItemArtLibrary.cue_clip(kind,origin)),"video_frame":frame,"drawn_frame":Engine.get_frames_drawn()})

func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from,to,1)
	query.collide_with_areas = false
	return app.player.get_world_2d().direct_space_state.intersect_ray(query)

func _candidate_points() -> void:
	var collision := app.player.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D
	var feet := collision.position.y+rectangle.size.y*.5
	var hazards := hazard_rows()
	for index: int in app.stage.enemies.size():
		var motor: EnemyMotor = app.stage.enemies[index]
		var actor := motor.get_node("Actor") as EnemyActor
		if actor.health.terminal: continue
		for offset: float in [-125.0,125.0,-95.0,95.0,-155.0,155.0]:
			var target := motor.global_position
			var ground := _ray(target+Vector2(offset,-90),target+Vector2(offset,110))
			if ground.is_empty() or ground.normal.y > -.7: continue
			var point := Vector2(target.x+offset,ground.position.y-feet-.2)
			if absf(point.y-target.y) > 45: continue
			var body_query := PhysicsShapeQueryParameters2D.new()
			body_query.shape = rectangle
			body_query.transform = Transform2D(0,point+collision.position)
			body_query.collision_mask = 1
			body_query.collide_with_areas = false
			if not app.player.get_world_2d().direct_space_state.intersect_shape(body_query,1).is_empty(): continue
			if not _ray(point+Vector2(0,-7),target).is_empty(): continue
			var hazard_distance := INF
			var hazard_kind := ""
			var immediate_danger := false
			for hazard: Dictionary in hazards:
				var hp := Vector2(hazard.position[0],hazard.position[1])
				var distance := hp.distance_to(point)
				if hazard.kind == "static":
					var r: Array = hazard.rect
					var danger := Rect2(r[0],r[1],r[2],r[3])
					if danger.grow(22).has_point(point): immediate_danger = true
					distance = point.distance_to(point.clamp(danger.position,danger.end))
				elif distance < float(hazard.radius)+35: immediate_danger = true
				if absf(hp.y-point.y) < 110 and distance < hazard_distance:
					hazard_distance = distance
					hazard_kind = str(hazard.kind)
			if immediate_danger or hazard_distance > 280 or hazard_distance < 55: continue
			var score := hazard_distance+absf(offset)*.2+(0 if hazard_kind == "saw" else 100)
			candidates.append({"index":index,"target":str(app.stage.enemy_manifest[index].id),"behavior":str(actor.definition.behavior_id),"position":[point.x,point.y],"target_position":[target.x,target.y],"initial_target_hp":actor.health.current,"floor":[ground.position.x,ground.position.y],"hazard_kind":hazard_kind,"hazard_distance":hazard_distance,"score":score})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.score) < float(b.score))
	if not candidates.is_empty(): selected = candidates[0]

func _screen(point: Vector2) -> Vector2:
	return app.player.get_canvas_transform()*point

func _aim_original_enemy() -> void:
	var point: Vector2 = app.player.global_position+Vector2(150,0)
	for row: Dictionary in target_rows():
		if row.target == selected.target and not row.terminal:
			point = Vector2(row.position[0],row.position[1]); break
	move_pointer(_screen(point))

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	fixture_note = WATERMARK
	app = preload("res://scenes/demo/demo.tscn").instantiate()
	app.meta_persistence_enabled = false
	root.add_child(app)
	add_captions()
	set_phase("setup","正式两区美术补充 · 原敌人、原机关和原镜头")
	if not check(region in [&"plains",&"thorn_forest"],"only the existing two legal debug regions are accepted"): await finish(); return
	if not check(app.start_debug_region(region,1,world_seed),"existing debug entry starts the actual formal current region"): await finish(); return
	for unused: int in 180:
		if is_instance_valid(app.stage) and not app._stage_pending: break
		await frames(1)
	await frames(20)
	if not check(app.stage is PlainsRegionStage and app.stage.assembly_ok,"actual formal stage assembled"): await finish(); return
	_candidate_points()
	setup = {"natural_progression":false,"region":str(region),"map":1,"seed":world_seed,"manifest":app.stage.generated.manifest.duplicate(true),"watermark":WATERMARK,"candidates":candidates,"initial_actors":target_rows(),"initial_hazards":hazard_rows(),"forest_H_grant":"existing DemoApp debug entry campaign/traversal grant only" if region == &"thorn_forest" else "none","training_objects_created":0,"enemy_or_hazard_mutations":0,"player_pose_assignments":0}
	if probe_only: await finish(); return
	if not check(not selected.is_empty(),"a real collision-legal floor near a live original actor and visible original hazard exists"): await finish(); return
	await tap(KEY_ESCAPE)
	if not check(paused and app.menu.visible_panel == &"build","native Escape opens the original equipment session"): await finish(); return
	var loadout: Array[StringName] = []
	if region == &"plains": loadout.assign([&"P24",&"G15",&"P14"])
	else: loadout.assign([&"G16",&"P14"])
	var instance_ids: Array[StringName] = []
	for id: StringName in loadout:
		if not grant_fixture(id): await finish(); return
		instance_ids.append(StringName(fixture_instances[id]))
	var revision: int = app.build.equipment.snapshot().revision
	app._submit_equipment(instance_ids,revision,app._equipment_session)
	if not check(app.build.item_ids().size() == loadout.size(),"disclosed initial full proposal commits through the original atomic equipment owner"): await finish(); return
	var active: StringName = &"P24" if region == &"plains" else &"G16"
	app._select_equipment_active(StringName(fixture_instances[active]),int(app.build.equipment.snapshot().revision),app._equipment_session)
	if not check(app._item_runtime.selected_active() == active,"disclosed setup uses the original menu owner to refresh and select an equipped active"): await finish(); return
	app.player.global_position = Vector2(selected.position[0],selected.position[1])
	app.controller.motor.reset_motion()
	app._run_camera.snap_to_target()
	setup.player_pose_assignments = 1
	setup.selected = selected
	setup.equipment = app.build.equipment.snapshot()
	setup.energy_before_fixture = app.controller.combat_energy.current
	setup.energy_granted = app.controller.combat_energy.grant("item_art_world_setup/"+str(region),35 if active == &"P24" else 65)
	setup.energy_after_fixture = app.controller.combat_energy.current
	events.append({"kind":"explicit_world_initialization","video_frame":frame,"setup":setup.duplicate(true)})
	app.policy.batch_resolved.connect(batch_resolved)
	app.controller.weapon_damage_committed.connect(primary_committed)
	app._item_runtime.effect_cued.connect(_observe_art)
	await frames(30)
	set_phase("world_begin","风铃平原 · 双向回环飞轮与三巡钟" if region == &"plains" else "荆棘森林 · 三段钟波与三巡钟")
	await tap(KEY_ESCAPE)
	if not check(not paused,"native Escape resumes untouched real gameplay"): await finish(); return
	initial_session = app.controller.session_id
	initial_stage_epoch = app.lifetime.stage_epoch
	start_world_draw = Engine.get_frames_drawn()
	await frames(5)
	_aim_original_enemy()
	await tap(KEY_R)
	set_phase("world_active","原敌人可受击或躲开 · 命中表现只由实际扣血回执发出")
	await frames(120)
	_aim_original_enemy()
	# Native vertical jump keeps the original floor and nearby thorns visible.
	# Primary recoil is covered by the main movie; firing here would recoil
	# directly into the disclosed nearby hazard.
	await tap(KEY_SPACE)
	await frames(90)
	set_phase("world_observe","观察原敌人预警、移动机关、落脚面与技能遮挡")
	# No further pose, velocity, HP, AI or input-route changes during observation.
	await frames(720-(Engine.get_frames_drawn()-start_world_draw))
	end_world_draw = Engine.get_frames_drawn()
	check(app.controller.session_id == initial_session and app.lifetime.stage_epoch == initial_stage_epoch,"world clip retains its original actor session and stage; any death/return rejects this candidate")
	check(not app.controller.actor_resources.health.terminal,"original real health survives the observed segment")
	check(setup.player_pose_assignments == 1,"exactly one disclosed initial player pose was applied")
	check(not entity_rows().is_empty() or not art_cues.is_empty(),"actual authored item consumers produced visible entity/cue observations")
	await finish()

func finish() -> void:
	for code: Variant in held.keys(): key(code,false)
	paused = false
	var final_actors := target_rows()
	var final_artist := artist_snapshot()
	if is_instance_valid(app):
		check(await preload("res://tests/audio_teardown.gd").drain_world(app),"actual original audio releases cleanly")
		app.free()
		app = null
	ItemArtLibrary.clear_cache()
	for unused: int in 8: await process_frame
	var data := {"schema":"item-art-real-world-v1","scope":"Supplementary actual current formal region with real original EnemyActor AI, hazards, collision, normal camera, HP and death priority. Explicit known rewards/equipment/35-or65energy/one initial pose. Not natural progression or device acceptance. No training targets or added terrain.","region":str(region),"seed":world_seed,"probe_only":probe_only,"checks":assertions,"failures":failures,"setup":setup,"checkpoints":checkpoints,"input_events":events,"primary_receipts":primary_rows,"damage_receipts":damage_rows,"art_cues":art_cues,"frames":rows,"world_begin_drawn":start_world_draw,"world_end_drawn":end_world_draw,"final_actors":final_actors,"final_artist":final_artist}
	var file := FileAccess.open(destination,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(data,"  ")); file.close()
	else: check(false,"actual supplement trace can be written")
	print("ITEM ART REAL WORLD: %s frames, %s assertions, %s failures" % [frame,assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
