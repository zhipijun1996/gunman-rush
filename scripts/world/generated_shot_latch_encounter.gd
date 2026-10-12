class_name GeneratedShotLatchEncounter
extends Node2D
## Same local ShotLatch consumer for real generated rooms and physical traces.
var latches: Array[ShotLatch] = []
var _modules: Dictionary = {}
var controller: PlayerController
func setup(manifest: Dictionary, assembler: RandomStageAssembler, player: PlayerController, lifetime: DemoLifetime) -> bool:
	if not PlainsShotLatchPlanner.validate(manifest):
		return false
	controller = player
	for data: Dictionary in manifest.shot_latch_plan.latches:
		var module: PlatformingModule = assembler.modules[int(data.node_index)]
		var latch := ShotLatch.new()
		latch.position = module.position
		latch.link_id = str(data.link_id)
		latch.sigil_index=int(data.sigil_index)
		latch.formal_presentation = true
		latch.prompt_text = data.prompt
		latch.open_seconds = float(data.open_seconds)
		latch.sequence_offset = Vector2(data.sequence_offset[0],data.sequence_offset[1]) * Vector2(-1 if module.definition.mirrored_horizontal else 1,1)
		latch.link_color = Color(data.link_color)
		add_child(latch)
		if not data.get("sequence_gate",[]).is_empty():latch.sequence_gate_rect=Rect2(data.sequence_gate[0],data.sequence_gate[1],data.sequence_gate[2],data.sequence_gate[3])
		latch.setup(player,lifetime,Vector2(data.bell[0],data.bell[1]),Rect2(data.gate[0],data.gate[1],data.gate[2],data.gate[3]))
		if data.kind=="toggle_ferry":
			for platform:ModuleMovingPlatform in module.moving_platforms:
				if str(platform.definition.platform_id)==str(data.actuator_id):latch.bind_motion(platform)
			if not latch.motion_mode:return false
		if manifest.get("layout_id") == "connected_region":
			var return_y: float=minf(float(data.bell[1]),module.definition.exit_port.position.y-47)
			var right := Vector2(module.definition.world_bounds.end.x-50,return_y)
			latch.add_access_bell(right,false,data.kind!="toggle_ferry")
			if not latch.sequence_offset.is_zero_approx(): latch.add_access_bell(right+(Vector2(0,-70) if data.kind=="remote_sequence" else Vector2(-50,0)),true,true)
		latches.append(latch)
		_modules[module.get_instance_id()] = latch
	return true
func for_module(module: PlatformingModule) -> ShotLatch:
	return _modules.get(module.get_instance_id())
func cancel_pending() -> void:
	if is_instance_valid(controller):
		controller.shoot_ability.clear_projectiles()
	for latch: ShotLatch in latches:
		latch.cancel_pending()
func cancel() -> void:
	cancel_pending()
	for latch: ShotLatch in latches:
		latch.cancel()
func _exit_tree() -> void:
	cancel()
