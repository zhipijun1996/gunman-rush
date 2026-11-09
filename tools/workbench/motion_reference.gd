extends SceneTree
## Measured examples, not maximum reach envelopes or room playability proofs.
var output := "res://build/workbench/motion-reference.json"
var samples: Array[Dictionary] = []
var failures := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()

func ticks(n: int) -> void:
	for i: int in n: await physics_frame

func sample(id: String, label: String, hold: int, shot: int = -1, double_jump: bool = false, grapple: bool = false) -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(1000, 520)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(6000, 40)
	shape.shape = rectangle
	floor_body.add_child(shape)
	scene.add_child(floor_body)
	var player := preload("res://game/player/player.tscn").instantiate() as PlayerMotor
	player.position = Vector2(200, 480)
	scene.add_child(player)
	player.get_node("KeyboardMouseAdapter").set_process(false)
	var controller := player.get_node("Controller") as PlayerController
	controller.traversal.grant(&"double_jump", double_jump)
	controller.traversal.grant(&"grapple", grapple)
	var anchor: GrappleAnchor
	if grapple:
		anchor = GrappleAnchor.new()
		anchor.position = Vector2(400, 340)
		scene.add_child(anchor)
	await ticks(12)
	var origin := player.position
	var points: Array[Array] = [[0.0, 0.0, 0.0]]
	var receipt := {"shots": 0, "jumps": 0, "hooks": 0}
	controller.shoot_ability.shot_fired.connect(func(_aim: Vector2, _id: int) -> void: receipt.shots += 1)
	controller.jump_ability.jumped.connect(func() -> void: receipt.jumps += 1)
	controller.traversal.hook_contact.connect(func(_point: Vector2) -> void: receipt.hooks += 1)
	controller.router.set_source_axis(&"keyboard_mouse", 1)
	controller.router.set_jump_held(&"keyboard_mouse", true)
	var landed := false
	for frame: int in 240:
		if frame == hold: controller.router.set_jump_held(&"keyboard_mouse", false)
		if frame == shot: controller.router.request_action(&"shoot_release", Vector2.LEFT)
		if double_jump and frame == 22: controller.router.set_jump_held(&"keyboard_mouse", true)
		if double_jump and frame == 36: controller.router.set_jump_held(&"keyboard_mouse", false)
		if grapple and frame == 9: controller.router.request_action(&"grapple", (anchor.position - player.position - Vector2(0,-6)).normalized())
		await ticks(1)
		var relative := player.position - origin
		points.append([snappedf((frame+1)/60.0, .001), snappedf(relative.x, .01), snappedf(relative.y, .01)])
		if frame > 10 and player.is_on_floor(): landed = true; break
	var valid: bool = landed and receipt.jumps >= (2 if double_jump else 1) and (shot < 0 or receipt.shots > 0) and (not grapple or receipt.hooks > 0)
	if not valid: failures += 1
	samples.append({"id":id,"label":label,"points":points,"receipts":receipt,"landed":landed,"valid":valid,
		"stage":"hd" if double_jump else "h" if grapple else "base",
		"input":{"move":1,"jump_hold_frames":hold,"shoot_left_frame":shot,"second_jump_frame":22 if double_jump else -1,"hook_frame":9 if grapple else -1},
		"anchor_relative":[200,-142] if grapple else []})
	print("MOTION ", id, " valid=", valid, " receipts=",receipt," landing=",points[-1])
	controller.router.clear("sample_finished")
	scene.queue_free()
	await ticks(3)

func run() -> void:
	Engine.physics_ticks_per_second = 60
	await sample("short_jump", "短按跳跃", 2)
	await sample("held_jump", "按住跳跃", 18)
	await sample("recoil_jump", "跳跃后向后射击", 18, 9)
	await sample("double_jump", "二段跳", 14, -1, true)
	await sample("grapple_jump", "跳跃接近钩点", 18, -1, false, true)
	var hashes := {}
	for path: String in ["config/player_tuning.json", "game/player/player_motor.gd", "game/player/player_controller.gd", "game/player/actions/jump_ability.gd", "game/player/actions/traversal_ability.gd", "resources/player/traversal.tres", "scripts/player/traversal_definition.gd", "resources/weapons/motion.tres"]:
		hashes[path] = FileAccess.get_sha256("res://"+path)
	var traversal := preload("res://resources/player/traversal.tres")
	var ability_parameters := {}
	for property: Dictionary in traversal.get_property_list():
		var key := str(property.name)
		if not key.begins_with("hook_") and not key.begins_with("wall_"): continue
		var value: Variant = traversal.get(key)
		ability_parameters[key] = [value.x, value.y] if value is Vector2 else value
	var result := {"schema":1,"physics_hz":60,"source_hashes":hashes,"samples":samples,"failures":failures,"ability_parameters":ability_parameters,
		"method":"InputRouter → PlayerController → PlayerMotor; isolated flat floor; default weapon; legal capability fixture",
		"limits":"Measured input examples only. Not maximum range, room traversal, first-time readability or fun certification."}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	quit(failures)
