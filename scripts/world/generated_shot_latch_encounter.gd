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
		latch.link_id = ""
		latch.formal_presentation = true
		latch.prompt_text = data.prompt
		latch.open_seconds = float(data.open_seconds)
		latch.sequence_offset = Vector2(data.sequence_offset[0],data.sequence_offset[1]) * Vector2(-1 if module.definition.mirrored_horizontal else 1,1)
		latch.link_color = Color(data.link_color)
		add_child(latch)
		latch.setup(player,lifetime,Vector2(data.bell[0],data.bell[1]),Rect2(data.gate[0],data.gate[1],data.gate[2],data.gate[3]))
		if manifest.get("layout_id") == "connected_region":
			var right := Vector2(module.definition.world_bounds.end.x-50,float(data.bell[1]))
			latch.add_access_bell(right)
			if not latch.sequence_offset.is_zero_approx(): latch.add_access_bell(right+Vector2(-50,0),true)
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
