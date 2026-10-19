extends SceneTree
var failures: Array[String] = []
func _init() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	print("PROBE ",message,": ",value)
	if not value: failures.append(message)
func run() -> void:
	var lab := preload("res://scenes/demo/blob47_lab.tscn").instantiate() as Blob47Lab
	root.add_child(lab)
	for adapter: String in ["KeyboardMouseAdapter", "GamepadAdapter"]:
		lab.player.get_node(adapter).process_mode = Node.PROCESS_MODE_DISABLED
	lab._toggle_catalog()
	check(paused and lab._catalog.visible, "catalog pauses")
	lab.restart()
	check(not paused and not lab._catalog.visible,"restart dismisses catalog before resume")
	lab._toggle_catalog()
	lab._next_seed()
	check(not paused and not lab._catalog.visible,"reseed dismisses catalog before resume")
	var platform: Blob47Platform
	for node: Node in lab._world.get_children():
		if node is Blob47Platform and node.one_way: platform = node; break
	check(platform != null,"one-way has real consumer")
	check(platform.get_node_or_null("CollisionShape2D") != null,"one-way exposes Motor shape contract")
	lab.controller.reset_at(platform.position + Vector2(32,-32))
	for frame: int in 70: await physics_frame
	print("ONEWAY grounded=", lab.player.is_on_floor(), " at=",lab.player.position," platform=",platform.position," children=",platform.get_children())
	check(lab.player.is_on_floor() and absf(lab.player.position.y - platform.position.y + 18) < 2,"Motor lands on one-way")
	check(lab.player.request_drop_through(), "Motor accepts drop-through on one-way")
	for frame: int in 35: await physics_frame
	check(lab.player.position.y > platform.position.y + 30,"Motor passes below one-way")
	lab.leave()
	lab.free()
	await process_frame
	await process_frame
	print("INDEPENDENT_PROBES failures=", failures.size(), " ",failures)
	quit(0 if failures.is_empty() else 1)
