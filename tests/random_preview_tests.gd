extends RefCounted

const SCENE := preload("res://scenes/demo/random_stage_preview.tscn")
var tree: SceneTree
var check: Callable
var preview: RandomStagePreview
var completed_count := 0
var home_count := 0

func run(p_tree: SceneTree, p_check: Callable) -> void:
	tree = p_tree
	check = p_check
	preview = SCENE.instantiate()
	check.call(preview.configure(InputProfile.load_default().values, "preview-contract-proof"), "generated preview accepts existing unified input configuration")
	tree.root.add_child(preview)
	preview.completed.connect(func() -> void: completed_count += 1)
	preview.home_requested.connect(func() -> void: home_count += 1)
	await ready()
	check.call(preview.ready_for_play and preview.stage.modules.size() == 7, "actual preview builds and safely activates complete seven-module stage")
	var initial_manifest := JSON.stringify(preview.manifest)
	var initial_player := preview.player.get_instance_id()
	var start_camera := preview.camera.global_position
	preview.controller.router.set_move_axis(1.0)
	for unused: int in 130:
		await tree.physics_frame
		if preview.player.global_position.x >= 830:
			break
	preview.controller.router.set_move_axis(0.0)
	for unused: int in 8:
		await tree.physics_frame
	check.call(preview.player.global_position.x > 800 and preview.camera.global_position.x > start_camera.x + 80, "camera follows actual action-driven Motor across large-world coordinates")
	check.call(preview.camera.global_position == preview.camera.bounded_center(preview.camera.global_position), "camera remains bounded by actual assembled world footprint")
	preview.camera.force_update_scroll()
	await tree.process_frame
	var keyboard := preview.player.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter
	var world_target := preview.player.global_position + Vector2(160, -80)
	var viewport_target := preview.player.get_canvas_transform() * world_target
	check.call(keyboard.world_direction(viewport_target).distance_to(Vector2(160, -80).normalized()) < 0.00001, "actual keyboard mouse adapter inverts moving camera canvas to world aim")
	var clamped_low := preview.camera.bounded_center(preview.stage.bounds.position - Vector2(10000, 10000))
	var clamped_high := preview.camera.bounded_center(preview.stage.bounds.end + Vector2(10000, 10000))
	check.call(clamped_low.x < clamped_high.x and preview.stage.bounds.has_point(clamped_low) and preview.stage.bounds.has_point(clamped_high), "large-world camera clamps both horizontal extremes without moving player")
	await environment_return(initial_manifest)
	await tree.process_frame
	preview.toggle_pause()
	var clocks: Array[float] = []
	for module: PlatformingModule in preview.stage.modules:
		clocks.append(module.clock)
	var elapsed := preview.elapsed
	var camera_position := preview.camera.global_position
	for unused: int in 4:
		await tree.physics_frame
	var preserved := true
	for index: int in clocks.size():
		preserved = preserved and preview.stage.modules[index].clock == clocks[index]
	check.call(tree.paused and preserved and preview.elapsed == elapsed and preview.camera.global_position == camera_position, "real pause freezes stage clocks, attempt time and camera")
	await tree.process_frame
	preview.toggle_pause()
	await tree.physics_frame
	await tree.physics_frame
	check.call(not tree.paused and preview.elapsed > elapsed, "resume continues existing attempt clocks")
	await tree.process_frame
	preview.toggle_overview()
	check.call(tree.paused and preview.camera.zoom.x < 1.0 and preview.camera.zoom.x == preview.camera.zoom.y, "whole-stage overview fits actual long world while pausing gameplay")
	await tree.process_frame
	check.call(is_equal_approx(preview.get_viewport().canvas_transform.x.length(), preview.camera.zoom.x), "paused overview updates actual viewport canvas scale rather than only Camera2D zoom property")
	preview.toggle_overview()
	check.call(not tree.paused and preview.camera.zoom == Vector2.ONE, "overview closes to bounded play camera with original physics")
	var old_token := preview.lifetime.token()
	preview.retry_same_seed()
	check.call(not preview.lifetime.accepts(old_token) and not preview.ready_for_play, "retry immediately invalidates old asynchronous attempt token")
	await ready()
	check.call(preview.player.get_instance_id() != initial_player and JSON.stringify(preview.manifest) == initial_manifest, "same seed retry creates fresh actor but exactly reproduces recorded graph and phases")
	await tree.process_frame
	check.call(preview.camera.is_current() and preview.get_viewport().get_camera_2d() == preview.camera, "replacement camera owns actual viewport after retry before overview is opened")
	preview.toggle_overview()
	await tree.process_frame
	var replacement_canvas := preview.get_viewport().canvas_transform.x.length()
	var active_camera := preview.get_viewport().get_camera_2d()
	var camera_trace: Array[String] = []
	for candidate: Camera2D in tree.root.find_children("*", "Camera2D", true, false):
		camera_trace.append("%s/current=%s" % [candidate.get_path(), candidate.is_current()])
	check.call(tree.paused and preview.camera.zoom.x < 1.0 and is_equal_approx(replacement_canvas, preview.camera.zoom.x), "overview after retry activates replacement camera and applies actual paused viewport scale (canvas=%s zoom=%s current=%s paused=%s viewport_camera=%s tree_cameras=%s)" % [replacement_canvas, preview.camera.zoom.x, preview.camera.is_current(), tree.paused, str(active_camera), str(camera_trace)])
	preview.toggle_overview()
	await tree.process_frame
	check.call(is_equal_approx(preview.get_viewport().canvas_transform.x.length(), 1.0), "replacement overview returns actual viewport canvas to normal play scale")
	var old_seed := preview.seed_text
	preview.new_seed()
	await ready()
	check.call(preview.seed_text != old_seed and JSON.stringify(preview.manifest) != initial_manifest, "explicit new seed starts a different recorded generated attempt")
	await completion_fixture()
	await fatal_fixture()
	preview.free()
	tree.paused = false

func ready() -> void:
	for unused: int in 12:
		await tree.physics_frame
		if preview.ready_for_play:
			return
	check.call(false, "generated preview activates within bounded twelve-frame initialization")

func damage(id: StringName, amount: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.token = preview.lifetime.token()
	request.event_id = id
	request.source_id = &"preview_contract_hazard"
	request.target_id = &"player"
	request.kind = DamageRequest.Kind.ENVIRONMENT
	request.amount = amount
	request.health_epoch = preview.controller.actor_resources.health.epoch
	request.actor_epoch = preview.lifetime.actor_epoch
	return request

func environment_return(manifest_text: String) -> void:
	var stage_id := preview.stage.get_instance_id()
	var player_id := preview.player.get_instance_id()
	var clocks: Array[float] = []
	for module: PlatformingModule in preview.stage.modules:
		clocks.append(module.clock)
	var hp := preview.controller.actor_resources.health.current
	var stamina := preview.controller.actor_resources.stamina.current
	var actor_epoch := preview.lifetime.actor_epoch
	preview.controller.shoot_ability.cooldown_remaining = 0.12
	preview.controller.router.request_action(&"shoot_release", Vector2.DOWN)
	preview.policy.clock += 2.0
	var request := damage(&"nonlethal_return", 1.0)
	check.call(preview.policy.submit(request), "preview production environment damage accepts live actor request")
	preview.policy.resolve_batch()
	var preserved := true
	for index: int in clocks.size():
		preserved = preserved and preview.stage.modules[index].clock == clocks[index]
	check.call(preview.stage.get_instance_id() == stage_id and preview.player.get_instance_id() == player_id and JSON.stringify(preview.manifest) == manifest_text and preserved, "nonlethal return preserves exact graph, module instances and hazard/carrier clocks")
	check.call(preview.controller.actor_resources.health.current == hp - 1.0 and preview.controller.actor_resources.stamina.current == stamina and preview.controller.shoot_ability.cooldown_remaining == 0.12, "segment return spends HP while preserving stamina and cooldown")
	check.call(preview.lifetime.actor_epoch == actor_epoch + 1 and not preview.policy.submit(request), "returned actor rejects delayed old-epoch damage")
	check.call(preview.controller.router.consume_actions(9999).is_empty() and preview.player.normal_velocity == Vector2.ZERO and preview.player.recoil_velocity == Vector2.ZERO, "segment return clears old shot requests, movement and recoil")

func completion_fixture() -> void:
	# Explicit terminal-state fixture teleport: route reachability is proved by
	# random_stage_tests using continuous action input, not by this consumer test.
	preview.player.reset_at(preview.stage.world_exit())
	for unused: int in 5:
		await tree.physics_frame
	check.call(preview.finished and completed_count == 1, "stationary actual final port completes local preview once")
	for unused: int in 4:
		await tree.physics_frame
	check.call(completed_count == 1, "remaining inside final port cannot emit repeated stage completion")

func fatal_fixture() -> void:
	preview.retry_same_seed()
	await ready()
	var before_completed := completed_count
	# Same-frame fatal damage and final-port fixture must choose failure before
	# preview completion; policy priority is production scheduling.
	preview.player.reset_at(preview.stage.world_exit())
	preview.controller.set_physics_process(false)
	preview.controller.physics_tick(1.0 / 60.0)
	preview.policy.clock += 2.0
	var fatal := damage(&"fatal_on_exit", 999.0)
	check.call(preview.policy.submit(fatal), "fatal final-port fixture queues actual production damage")
	await tree.physics_frame
	await tree.process_frame
	check.call(not preview.lifetime.active and not preview.ready_for_play and preview.controller.actor_resources.health.terminal and home_count == 1, "fatal environment damage ends generated attempt and requests Home")
	check.call(completed_count == before_completed and not preview.finished, "zero HP same frame at final port wins over stage-clear outcome")
	check.call(not preview.segment.return_to_anchor() and not preview.policy.submit(fatal), "ended attempt cannot respawn or replay delayed hazard damage")
	check.call(not preview.request_seed("late_seed"), "closed preview rejects asynchronous regeneration requests")
