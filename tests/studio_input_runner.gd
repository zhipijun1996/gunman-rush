extends SceneTree
var studio: ActionStudio
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1; print("FAIL: "+label)
func frames(count: int) -> void:
	for i: int in count: await physics_frame
func positions() -> Array[Vector2]:
	var values: Array[Vector2]=[]
	for target: EnemyActor in studio.training_actors: values.append(target.motor.global_position)
	return values
func moved(before: Array[Vector2], minimum: float) -> void:
	var after := positions()
	for i: int in before.size(): check(after[i].distance_to(before[i])>=minimum,"actual patrol Motor moves target %s" % i)
func stopped(before: Array[Vector2]) -> void:
	var after := positions()
	for i: int in before.size(): check(after[i].distance_to(before[i])<.01,"target %s remains fixed" % i)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/studio_input")
	studio=preload("res://scenes/demo/action_studio.tscn").instantiate();root.add_child(studio)
	await frames(2)
	check(not studio.training_static and studio.training_actors.size()==4,"practice defaults to four patrol enemies")
	var before := positions();await frames(45);moved(before,10)
	studio._training_toggle.pressed.emit()
	check(studio.training_static,"actual mode button switches to explicit stationary targets")
	await frames(2);before=positions();await frames(45);stopped(before)
	studio._training_toggle.pressed.emit()
	check(not studio.training_static,"actual mode button restores patrol")
	await frames(2);before=positions();await frames(45);moved(before,10)
	studio._toggle_pause();before=positions();await frames(15);stopped(before);studio._toggle_pause()
	for target: EnemyActor in studio.training_actors:
		check(target.health.current==120 and target.definition.patrol_speed==preload("res://resources/enemies/patrol_drone.tres").patrol_speed,"mode restore uses base Definition without changing target HP")
	# Menu focus is held by a real PopupMenu across successive render frames.
	studio._weapon_picker.show_popup();await frames(2)
	studio._weapon_picker.get_popup().set_focused_item(4)
	await frames(6)
	check(studio._weapon_picker.get_popup().get_focused_item()==4,"render updates do not reset open popup navigation")
	studio._weapon_picker.get_popup().hide()
	studio.leave();studio.free();await process_frame
	print("STUDIO INPUT: %s assertions, %s failures" % [checks,failures]);quit(1 if failures else 0)
