extends SceneTree
## Drive the default title's real buttons, save slot and world without using the user's slot.
var checks := 0
var failures := 0
var shell: WorldShell

class RejectedWrite extends PlayableWorldSave:
	var reject := false
	func commit(value: Dictionary, revision: int) -> bool:
		return false if reject else super.commit(value,revision)

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL ",label)

func button(id: String) -> Button:
	return shell.page_host.find_child(id,true,false) as Button

func press(id: String) -> void:
	var control := button(id)
	check(control!=null and not control.disabled and control.is_visible_in_tree(),"available button "+id)
	if control != null and not control.disabled:
		control.grab_focus()
		control.pressed.emit()
	await process_frame

func tap(id: String) -> void:
	var at := button(id).get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var e := InputEventScreenTouch.new()
		e.position = at
		e.index = 3
		e.pressed = pressed
		root.push_input(e,true)
		await process_frame

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode=code
	e.physical_keycode=code
	e.pressed=true
	root.push_input(e,true)
	e=e.duplicate()
	e.pressed=false
	root.push_input(e,true)
	await process_frame

func run() -> void:
	var slot := RejectedWrite.new()
	slot.configure_world("user://world_shell_%d.json"%Time.get_ticks_usec(),false,"shell")
	var scene := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	shell=scene.instantiate()
	shell.storage=slot
	root.add_child(shell)
	await process_frame
	check(shell.page==&"title" and shell.world==null and button("ContinueAdventure").disabled,"clean boot is at title without an invented continue slot")
	check(root.gui_get_focus_owner()==button("BeginAdventure") and shell.page_host.find_child("TitleBackdrop",true,false)!=null,"original illustration and new-game focus appear together")
	await tap("Help")
	check(shell.page==&"help","a real viewport touch opens the operating guide from title")
	shell.handle_back()
	check(root.gui_get_focus_owner()==button("Help"),"closing the guide restores the initiating control")
	await press("Settings")
	check(shell.page==&"settings" and shell.subpage!=null,"settings opens without creating a world")
	shell.handle_back()
	await press("BeginAdventure")
	check(shell.world!=null and shell.page==&"play" and slot.startup_room().get("has_save",false),"new game only replaces the slot after P01 actually opens")
	check(await preload("res://tests/plains_start_input.gd").take_ground_gun(shell.world),"pick up the P01 gun before saving")
	await key(KEY_ESCAPE)
	check(shell.page==&"pause" and paused,"Escape freezes ordinary world")
	var fixed: Vector2 = shell.world.active.player.position
	for i in 12: await physics_frame
	check(shell.world.active.player.position==fixed,"body stays still throughout pause")
	await press("Map")
	check(shell.page==&"map" and paused and shell.world.route_map.visible,"pause opens actual world map")
	shell.handle_back()
	check(paused and not shell.world.route_map.visible and shell.page==&"pause","map returns to its originating pause menu")
	shell.open_pause()
	await press("Equipment")
	check(shell.world.active.equipment_menu.panel.visible and paused,"pause opens actual equipment")
	shell.handle_back()
	shell.open_pause()
	var original := shell.world
	var before := FileAccess.get_file_as_bytes(slot.path)
	slot.reject=true
	await press("SaveAndTitle")
	check(shell.world==original and shell.page==&"pause" and before==FileAccess.get_file_as_bytes(slot.path),"failed save leaves the same paused world and previous disk bytes")
	slot.reject=false
	await press("SaveAndTitle")
	check(shell.world==null and shell.page==&"title" and not button("ContinueAdventure").disabled,"successful checkpoint returns to title and enables continue")
	await process_frame
	check(not is_instance_valid(original),"released world has left the tree")
	before=FileAccess.get_file_as_bytes(slot.path)
	await press("BeginAdventure")
	check(shell.page==&"confirm" and root.gui_get_focus_owner()==button("KeepProgress"),"overwrite asks with safe cancel focus")
	await press("KeepProgress")
	check(before==FileAccess.get_file_as_bytes(slot.path) and shell.page==&"title","cancel keeps exact saved bytes")
	await press("BeginAdventure")
	slot.reject=true
	await press("ReplaceProgress")
	check(shell.page==&"confirm" and shell.world==null and before==FileAccess.get_file_as_bytes(slot.path),"rejected overwrite keeps previous slot and confirmation")
	slot.reject=false
	await press("KeepProgress")
	await press("ContinueAdventure")
	check(shell.world.active.state.has("gun") and shell.world.active.room.room_id=="P01","continuation restores actual progression")
	shell.open_pause()
	await press("SaveAndTitle")
	await press("BeginAdventure")
	await press("ReplaceProgress")
	check(shell.page==&"play" and not shell.world.active.state.has("gun") and not slot.load_profile().payload.flags.has("gun"),"confirmed replacement opens a fresh real P01 and atomically replaces the old save")
	shell.free()
	await process_frame
	for suffix: String in ["",".backup",".tmp",".corrupt"]:
		if FileAccess.file_exists(slot.path+suffix): DirAccess.remove_absolute(slot.path+suffix)
	print("WORLD SHELL failures=",failures," checks=",checks)
	quit(1 if failures else 0)
