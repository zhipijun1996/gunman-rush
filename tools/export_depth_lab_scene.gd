extends SceneTree
## Freeze generated geometry into an inspector-editable scene, without its builder.
func _initialize() -> void:
	run.call_deferred()
func own(node: Node, scene: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene
		own(child,scene)
func run() -> void:
	var source: Control = load("res://game/presentation/experiments/depth_lab/depth_lab.tscn").instantiate()
	root.add_child(source)
	await process_frame
	await physics_frame
	var scene: Node = source.duplicate()
	scene.set_script(null)
	own(scene,scene)
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed,"res://build/depth-lab/editable.tscn") == OK)
	scene.free();source.queue_free()
	await process_frame
	print("DEPTH LAB EDITABLE SCENE: exported generated nodes without builder")
	quit()
