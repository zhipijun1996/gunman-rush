extends SceneTree
## Six explicitly staged scale comparisons on an unchanged generated plains
## shore. Factory actors and the original player/renderer/camera are real;
## this driver deliberately supplies no combat or natural-route evidence.
const PAGE_FRAMES := 300
const STARTUP_FRAME_BUDGET := 3600
const SPECIES: Array[StringName] = [&"patrol",&"charger",&"hopper",&"sentry",&"fan_sentry",&"root_bell"]
const SOURCE_PATHS: Array[String] = [
	"res://tools/plains_revision_01_comparison.gd",
	"res://scripts/demo/demo_app.gd", "res://scripts/demo/plains_region_stage.gd",
	"res://scripts/generation/stage_camera_rig.gd",
	"res://scripts/enemies/enemy_factory.gd", "res://scripts/enemies/enemy_actor.gd",
	"res://scripts/enemies/enemy_motor.gd", "res://scripts/presentation/enemy_presentation_binding.gd",
	"res://scripts/underworld_plains/underworld_actor_installer.gd",
	"res://scripts/underworld_plains/underworld_enemy.gd",
	"res://scripts/underworld_plains/underworld_player.gd",
	"res://scripts/enemies/plains_revision_skin.gd", "res://scripts/enemies/plains_revision_visual.gd",
	"res://scripts/enemies/plains_revision_ground.gd", "res://scripts/enemies/plains_revision_flora.gd",
	"res://scripts/enemies/plains_revision_skin.gdshader", "res://scripts/enemies/plains_motion_02.gd",
	"res://scripts/enemies/enemy_feedback_01_body.gd", "res://scripts/enemies/enemy_feedback_01_frames.gd",
	"res://scripts/enemies/enemy_feedback_01_flash.gdshader",
	"res://assets/enemy_feedback_01/frames_v8/manifest.json",
	"res://assets/enemy_feedback_01/frames_v8/underworld_diver.png",
	"res://assets/underworld_plains/actors/aerial.png",
	"res://assets/underworld_plains/player_animation/animation_build.json",
	"res://assets/underworld_plains/player_animation/run_sheet.png",
	"res://assets/underworld_plains/player_animation/states_sheet.png",
	"res://config/player_tuning.json", "res://resources/enemies/patrol_health.tres"
]
var trace_path := ""
var seed_label := "plains-revision-01-scale"
var app: DemoApp
var audio: GameAudio
var heading: Label
var detail: Label
var reference: EnemyMotor
var revised: EnemyMotor
var gallery: Node2D
var pages: Array[Dictionary] = []
var frames: Array[Dictionary] = []
var failures: Array[String] = []
var frame := 0
var page_index := -1
var page_frame := 0
var ready := false
var busy := false
var finished := false
var original_spawn := Vector2.ZERO
var stand := Vector2.ZERO
var floor_y := 0.0
var support: Dictionary = {}
var manifest_json := ""
var source_before: Dictionary = {}
var git_before: Dictionary = {}
var native_inventory: Array[Dictionary] = []
var player_health_at_start := -1.0
var original_camera_zoom := Vector2.ONE

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--trace="): trace_path = argument.trim_prefix("--trace=")
		elif argument.begins_with("--seed="): seed_label = argument.trim_prefix("--seed=")
	if trace_path.is_empty():
		printerr("Scale comparison requires --trace=PATH")
		quit(1)
		return
	start.call_deferred()

func _label(text_value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_outline_color",Color("10201d"))
	label.add_theme_constant_override("outline_size",4)
	return label

func start() -> void:
	root.size = Vector2i(1280,720)
	source_before = _source_hashes()
	if source_before.values().has("missing"): failures.append("A direct comparison source resource is missing")
	git_before = _git_source()
	audio = GameAudio.new()
	root.add_child(audio)
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	heading = _label("STAGED SCALE COMPARISON / ORIGINAL PLAINS TERRAIN / NOT COMBAT",Vector2(12,666),16)
	detail = _label("Loading original DemoApp.start_plains; no replacement terrain",Vector2(12,691),14)
	overlay.add_child(heading)
	overlay.add_child(detail)
	if not app.start_plains(seed_label): failures.append("DemoApp.start_plains refused")
	process_frame.connect(drive)

func _stage_ready() -> bool:
	return is_instance_valid(app) and not app._stage_pending and app.stage is PlainsRegionStage and (app.stage as PlainsRegionStage).assembly_ok and is_instance_valid(app.player) and is_instance_valid(app.controller) and app._can_interact() and is_instance_valid(app._run_camera)

func _ray(x: float, from_y: float, to_y: float) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(Vector2(x,from_y),Vector2(x,to_y),1,[app.player.get_rid()])
	query.collide_with_areas = false
	return app.player.get_world_2d().direct_space_state.intersect_ray(query)

func _support_record(hit: Dictionary) -> Dictionary:
	var body := hit.collider as StaticBody2D
	var shape_rows: Array[Dictionary] = []
	for child: Node in body.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			var collider := child as CollisionShape2D
			shape_rows.append({"path":String(collider.get_path()),"shape_class":collider.shape.get_class(),"world_aabb":_rect(collider.global_transform*collider.shape.get_rect()),"one_way":collider.one_way_collision})
	return {"path":String(body.get_path()),"class":body.get_class(),"point":_vec(hit.position),"normal":_vec(hit.normal),"shape_index":int(hit.shape),"actual_collision_shapes":shape_rows}

func _find_stand() -> Dictionary:
	var player_shape := app.player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if player_shape == null or not player_shape.shape is RectangleShape2D: return {}
	var rectangle := player_shape.shape as RectangleShape2D
	var space := app.player.get_world_2d().direct_space_state
	# A single continuous real shore must carry all three sample positions.
	# No failed search is repaired by moving a platform or inserting geometry.
	for offset: float in [0.0,64.0,128.0,-64.0,192.0,-128.0,256.0,320.0]:
		var x := original_spawn.x+offset
		var center := _ray(x,original_spawn.y-96.0,original_spawn.y+192.0)
		if center.is_empty() or not center.collider is StaticBody2D or (center.normal as Vector2).dot(Vector2.UP)<0.7: continue
		var y: float = center.position.y
		var location := Vector2(x,y-rectangle.size.y*.5-player_shape.position.y)
		if app.segment == null or not app.segment.is_safe(location): continue
		var checks: Array[Dictionary] = []
		var continuous := true
		for step: int in range(-128,129,16):
			var hit := _ray(x+step,y-4.0,y+8.0)
			if hit.is_empty() or not hit.collider is StaticBody2D or (hit.normal as Vector2).dot(Vector2.UP)<0.7 or absf(float(hit.position.y)-y)>.5:
				continuous = false
				break
			checks.append(_support_record(hit))
		if not continuous: continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = RectangleShape2D.new()
		(query.shape as RectangleShape2D).size = Vector2(254,100)
		query.transform = Transform2D(0.0,Vector2(x,y-50.05))
		query.collision_mask = 1
		query.margin = 0.0
		query.exclude = [app.player.get_rid()]
		if not space.intersect_shape(query).is_empty(): continue
		var safe := true
		var exhibit := Rect2(Vector2(x-128,y-100),Vector2(256,100))
		for danger: Rect2 in app.segment.danger_bounds:
			if danger.intersects(exhibit,true): safe = false
		if not safe: continue
		return {"player_location":location,"floor_y":y,"center":_support_record(center),"continuous_shore_probes":checks,"checks":"17 real layer1 UP rays across256wu +100wu overhead real shape clearance + original SegmentRespawn safe stand/danger bounds"}
	return {}

func prepare() -> void:
	original_spawn = app.player.global_position
	manifest_json = JSON.stringify((app.stage as PlainsRegionStage).generated.manifest)
	for child: Node in app.stage.find_children("*","",true,false):
		if child is EnemyMotor:
			var actor := child.get_node("Actor") as EnemyActor
			native_inventory.append({"path":String(child.get_path()),"definition":String(actor.definition.stable_id),"position":_vec((child as EnemyMotor).global_position),"physics_enabled":actor.is_physics_processing()})
	support = _find_stand()
	if support.is_empty():
		failures.append("No original continuous safe static shore found; no fallback terrain or false scale page fabricated")
		finish.call_deferred()
		return
	stand = support.player_location
	floor_y = support.floor_y
	support["player_location"] = _vec(stand)
	app.player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	app.controller.router.activate_device(&"gamepad")
	app.controller.router.clear("disclosed_staged_scale_comparison")
	app.controller.router.set_source_axis(&"gamepad",0.0)
	app.player.reset_at(stand)
	# Let the real Motor contact the real floor before holding this exhibit.
	for _tick: int in 4: await physics_frame
	stand = app.player.global_position
	player_health_at_start = app.controller.actor_resources.health.current
	app.controller.active = false
	app.controller.set_physics_process(false)
	app.player.normal_velocity = Vector2.ZERO
	app.player.velocity = Vector2.ZERO
	original_camera_zoom = app._run_camera.zoom
	app._run_camera.snap_to_target()
	app._run_camera.set_physics_process(false)
	app._run_camera.force_update_scroll()
	gallery = Node2D.new()
	gallery.name = "DisclosedScaleComparisonSamples"
	app.stage.add_child(gallery)
	reference = _spawn_sample(&"diver",-90.0)
	if reference == null:
		failures.append("Original diver reference could not be created")
		finish.call_deferred()
		return
	ready = true
	_next_page()

func _spawn_sample(behavior: StringName, horizontal_offset: float) -> EnemyMotor:
	var motor := EnemyFactory.create_for_behavior(behavior)
	if motor == null: return null
	var actor := motor.get_node("Actor") as EnemyActor
	motor.name = "ScaleReferenceDiver" if behavior==&"diver" else "ScaleRevision_"+String(behavior)
	var hover := 22.0 if actor.definition.aerial else 0.0
	motor.position = app.stage.to_local(Vector2(stand.x+horizontal_offset,floor_y-actor.definition.collision_size.y*.5-hover))
	gallery.add_child(motor)
	actor.set_physics_process(false)
	motor.stop()
	# Exactly the formal installer route, not a separately scaled image proxy.
	if not EnemyPresentationBinding.replace(actor,&"underworld"):
		motor.free()
		return null
	EnemyPresentationBinding.synchronize(actor)
	return motor

func _next_page() -> void:
	if is_instance_valid(revised): revised.free()
	page_index += 1
	if page_index >= SPECIES.size():
		finish.call_deferred()
		return
	revised = _spawn_sample(SPECIES[page_index],90.0)
	if revised == null:
		failures.append("Factory/formal renderer refused "+String(SPECIES[page_index]))
		finish.call_deferred()
		return
	page_frame = 0
	var label := "%d/6  LEFT: DIVER REFERENCE / CENTRE: PLAYER / RIGHT: %s / ORIGINAL ZOOM %.2f" % [page_index+1,String(SPECIES[page_index]).to_upper(),original_camera_zoom.x]
	detail.text = label
	pages.append({"page":page_index,"species":String(SPECIES[page_index]),"start_movie_process_frame":Engine.get_process_frames()+1,"source_definition":EnemyFactory.definition_path_for_behavior(SPECIES[page_index]),"fixture":"Initial/page-cut placement; comparison sample AI and player controls held; idle body clocks continue; NOT COMBAT","player":_player_report(),"reference":_sample_report(reference),"revised":_sample_report(revised),"camera_zoom":_vec(app._run_camera.zoom),"camera_position":_vec(app._run_camera.global_position)})
	busy = false

func drive() -> void:
	frame += 1
	if busy or finished: return
	if not ready:
		if _stage_ready():
			busy = true
			prepare.call_deferred()
		elif frame>=STARTUP_FRAME_BUDGET:
			failures.append("Original generated plains did not become ready within startup frame budget")
			busy = true
			finish.call_deferred()
		return
	page_frame += 1
	if not app._run_camera.zoom.is_equal_approx(original_camera_zoom): failures.append("Comparison camera zoom changed")
	if app.controller.actor_resources.health.current != player_health_at_start: failures.append("Player health changed in non-combat comparison")
	frames.append({"frame":frame,"movie_process_frame":Engine.get_process_frames(),"page":page_index,"page_frame":page_frame,"player_position":_vec(app.player.global_position),"reference_position":_vec(reference.global_position),"revised_position":_vec(revised.global_position),"reference_body_clock":_motion_clock(reference),"revised_body_clock":_motion_clock(revised),"camera_zoom":_vec(app._run_camera.zoom),"camera_position":_vec(app._run_camera.global_position)})
	if not failures.is_empty() or page_frame>=PAGE_FRAMES:
		busy = true
		end_page.call_deferred()

func end_page() -> void:
	await RenderingServer.frame_post_draw
	pages.back()["end_movie_process_frame"] = Engine.get_process_frames()
	pages.back()["observed_frames"] = page_frame
	pages.back()["reference_at_end"] = _sample_report(reference)
	pages.back()["revised_at_end"] = _sample_report(revised)
	if not failures.is_empty(): finish.call_deferred()
	else: _next_page()

func _optional(object: Object, key: StringName) -> Variant:
	if object==null: return null
	for row: Dictionary in object.get_property_list():
		if StringName(row.name)==key: return object.get(key)
	return null

func _motion_clock(motor: EnemyMotor) -> Variant:
	var motion: Variant = _optional(motor.get_node_or_null("Presentation"),&"body_motion")
	return _optional(motion,&"clock") if motion is Object else null

func _player_report() -> Dictionary:
	var collision := app.player.get_node("CollisionShape2D") as CollisionShape2D
	return {"scene":"res://scenes/player/player.tscn","position":_vec(app.player.global_position),"actual_shape_class":collision.shape.get_class(),"actual_shape_world_aabb":_rect(collision.global_transform*collision.shape.get_rect()),"actual_on_floor":app.player.is_on_floor(),"underworld_stature_world_units":UnderworldActors.HUMANOID_HEIGHT,"source":"unchanged actual DemoApp player and UnderworldPlayer; no visual scale override"}

func _sample_report(motor: EnemyMotor) -> Dictionary:
	var actor := motor.get_node("Actor") as EnemyActor
	var host := motor.get_node("Presentation") as Node2D
	var collision := motor.get_node("CollisionShape2D") as CollisionShape2D
	var shape_world := collision.global_transform*collision.shape.get_rect()
	var body_world := Rect2()
	var texture: Texture2D
	var authored := Rect2()
	var visual := host.get_node_or_null("ArticulatedBody") as Node2D
	if visual != null:
		var rig: Variant = _optional(visual,&"rig")
		if rig is Object:
			texture = _optional(rig,&"texture") as Texture2D
			authored = _optional(rig,&"bounds")
			if texture != null: body_world = visual.global_transform*EnemyFeedback01Frames.visible_bounds(texture,authored)
	else:
		var body := _optional(host,&"feedback_body") as EnemyFeedback01Body
		if body != null and body.source != null:
			texture = body.source
			authored = body.destination
			body_world = body.global_transform*EnemyFeedback01Frames.visible_bounds(texture,authored)
	var normalized := Rect2()
	if body_world.has_area(): normalized = Rect2((shape_world.position-body_world.position)/body_world.size,shape_world.size/body_world.size)
	var binding := EnemyPresentationBinding.view(host)
	return {"definition":String(actor.definition.stable_id),"behavior":String(actor.definition.behavior_id),"position":_vec(motor.global_position),"actual_shape_class":collision.shape.get_class(),"actual_shape_size":_vec(collision.shape.get_rect().size),"actual_shape_world_aabb":_rect(shape_world),"definition_collision_size":_vec(actor.definition.collision_size),"collision_layers":[motor.collision_layer,motor.collision_mask],"renderer":String(binding.get("renderer","")),"profile":String(binding.get("profile","")),"texture_resource":texture.resource_path if texture != null else "", "authored_body_rect":_rect(authored),"neutral_visible_body_world_aabb":_rect(body_world),"collision_in_visible_body_uv":_rect(normalized),"body_shape_measurement_scope":"Neutral authored alpha>16 bounds and actual RectangleShape2D; normalized mapping is diagnostic, not an automatic main-body/animated-silhouette acceptance","comparison_AI_disabled":not actor.is_physics_processing(),"combat_binding":"none; this isolated display sample is not in production encounter/drop arrays","body_clock":_motion_clock(motor)}

func _vec(value: Vector2) -> Array:
	return [value.x,value.y]

func _rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]

func _source_hashes() -> Dictionary:
	var paths := SOURCE_PATHS.duplicate()
	for behavior: StringName in SPECIES:
		paths.append(EnemyFactory.definition_path_for_behavior(behavior))
		paths.append("res://assets/plains_revision_01/"+String(behavior)+".png")
	paths.append(EnemyFactory.definition_path_for_behavior(&"diver"))
	var hashes := {}
	for path: String in paths: hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return hashes

func _git_source() -> Dictionary:
	var head_output: Array = []
	var status_output: Array = []
	var working_directory := ProjectSettings.globalize_path("res://")
	var head_exit := OS.execute("git",["-C",working_directory,"rev-parse","HEAD"],head_output,true)
	var status_exit := OS.execute("git",["-C",working_directory,"status","--porcelain"],status_output,true)
	return {"head":String(head_output[0]).strip_edges() if head_exit==0 and not head_output.is_empty() else "unavailable","status":String(status_output[0]) if status_exit==0 and not status_output.is_empty() else "unavailable","head_exit_code":head_exit,"status_exit_code":status_exit}

func finish() -> void:
	if finished: return
	finished = true
	busy = true
	if process_frame.is_connected(drive): process_frame.disconnect(drive)
	var manifest_same := not manifest_json.is_empty() and is_instance_valid(app.stage) and JSON.stringify((app.stage as PlainsRegionStage).generated.manifest)==manifest_json
	var source_after := _source_hashes()
	var git_after := _git_source()
	if source_before != source_after: failures.append("Direct comparison source changed during capture")
	if git_before.head != git_after.head or git_before.status != git_after.status: failures.append("Git source identity/status changed during capture")
	if not manifest_same: failures.append("Original generated manifest absent or changed")
	if pages.size()!=6 or pages.any(func(page: Dictionary) -> bool: return int(page.get("observed_frames",0))!=PAGE_FRAMES): failures.append("Six complete five-second comparison pages were not observed")
	var camera_receipt := {"class":"StageCameraRig","zoom":_vec(original_camera_zoom),"policy":"Actual formal camera/zoom retained; snap once at disclosed player stand and freeze camera follow for all six exhibit pages"}
	var player_receipt := _player_report() if ready else {}
	app.abandon_run()
	if not await load("res://tests/audio_teardown.gd").drain_world(app): failures.append("Original DemoApp fallback audio failed to release")
	var sound_events: Dictionary = audio.played.duplicate(true)
	if not await audio.shutdown(): failures.append("GameAudio ownership did not release")
	var output := {"task":"PLAINS-MONSTER-REVISION-01","kind":"staged_scale_comparison","complete":failures.is_empty(),"seed":seed_label,"entry":"DemoApp.start_plains","stage_script":"res://scripts/demo/plains_region_stage.gd","resolution":[1280,720],"fps":60,"playback_speed":1,"pages":pages,"frames":frames,"failures":failures,"camera":camera_receipt,"player":player_receipt,"support":support,"original_spawn":_vec(original_spawn),"staged_player_stand":_vec(stand),"original_manifest_sha256":manifest_json.sha256_text(),"original_manifest_unchanged":manifest_same,"original_enemy_inventory":native_inventory,"source_before":source_before,"source_after":source_after,"git_before":git_before,"git_after":git_after,"source_stable":source_before==source_after and git_before.head==git_after.head and git_before.status==git_after.status,"source_guard_scope":"Finite direct driver/player/renderer/body/definition resources listed in source_before; not a claim to a complete project dependency closure","audio_events":sound_events,"disclosed_differences":["six page-cut placements of factory-created display samples on one original safe static shore","comparison sample Actor physics disabled; original body process clocks continue","comparison samples have no combat/encounter/drop binding","original player initial reset_at, four real physics settling ticks, then controller/input held inactive","original camera/zoom retained and camera following held fixed","permanent meta persistence disabled"],"not_verified":["combat readability","attack or death continuity","natural campaign traversal","human scale/color approval","physical device performance"]}
	var file := FileAccess.open(trace_path,FileAccess.WRITE)
	if file == null:
		printerr("Cannot write staged scale comparison trace")
		app.free()
		audio.free()
		quit(1)
		return
	file.store_string(JSON.stringify(output,"\t"))
	file.close()
	app.free()
	audio.free()
	await process_frame
	await process_frame
	print("PLAINS REVISION COMPARISON: complete; pages=%d; frames=%d" % [pages.size(),frame])
	quit(0 if failures.is_empty() else 1)
