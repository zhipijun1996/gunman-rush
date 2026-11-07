extends Node2D
## Data-driven regional materials, independent depth layers and native lights.

var data: Dictionary = {}
var geometry: Dictionary = {}
var active_region := "mushroom_caverns"
var time_state := "restored"
var lighting_enabled := true
var depth_enabled := true
var protection_enabled := true
var camera_manual := false
var manual_offset := 0
var camera_offset := 0
var ambient_time := 1.2
var ambient_paused := true
var runtime := 0.0
var capture_path := ""
var capture_started := false
var capture_time := 1.2

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/study.json"))
	geometry = JSON.parse_string(FileAccess.get_file_as_string("res://assets/geometry.json"))
	active_region = str(data.get("defaultRegion", "mushroom_caverns"))
	var selector: OptionButton = $Interface/RegionSelect
	for region in data.get("regions", []):
		selector.add_item(str(region.get("name", region["id"])))
	selector.item_selected.connect(_on_region_selected)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--region="):
			active_region = arg.trim_prefix("--region=")
		elif arg.begins_with("--state="):
			time_state = arg.trim_prefix("--state=")
		elif arg == "--unlit":
			lighting_enabled = false
		elif arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-time="):
			capture_time = float(arg.trim_prefix("--capture-time="))
	if region_spec(active_region).is_empty() and not data.get("regions", []).is_empty():
		active_region = str(data["regions"][0]["id"])
	set_region(active_region)
	set_time_state(time_state)
	_update_depth()

func _on_region_selected(index: int) -> void:
	if index >= 0 and index < data.get("regions", []).size():
		set_region(str(data["regions"][index]["id"]))

func cycle_region(direction: int) -> void:
	var regions: Array = data.get("regions", [])
	if regions.is_empty():
		return
	var index := 0
	for i in regions.size():
		if str(regions[i]["id"]) == active_region:
			index = i
	_on_region_selected(posmod(index + direction, regions.size()))

func region_spec(region_id: String) -> Dictionary:
	for region in data.get("regions", []):
		if str(region.get("id", "")) == region_id:
			return region
	return {}

func rgb(value: Array, alpha: float = 1.0) -> Color:
	return Color(float(value[0]), float(value[1]), float(value[2]), alpha)

func set_region(region_id: String) -> void:
	if region_spec(region_id).is_empty():
		return
	active_region = region_id
	for region in $Regions.get_children():
		region.visible = str(region.get_meta("region_id")) == active_region
	for group in $Geometry.get_children():
		for body: StaticBody2D in group.get_children():
			body.collision_layer = 1 if str(group.name) == active_region else 0
	for i in data["regions"].size():
		if str(data["regions"][i]["id"]) == active_region:
			$Interface/RegionSelect.select(i)
	_sync_lighting()
	_update_depth()
	_update_help()

func set_lighting_enabled(value: bool) -> void:
	lighting_enabled = value
	_sync_lighting()
	_update_help()

func set_depth_enabled(value: bool) -> void:
	depth_enabled = value
	_update_depth()
	_update_help()

func set_protection_enabled(value: bool) -> void:
	protection_enabled = value
	_update_depth()
	_update_help()

func terrain_bodies(region_id: String) -> Array:
	return geometry.get(region_id, {}).get("bodies", [])

func set_camera_offset(value: int) -> void:
	camera_manual = true
	manual_offset = clampi(value, -32, 32)
	_update_depth()

func _update_depth() -> void:
	if data.is_empty():
		return
	var camera: Dictionary = data.get("camera", {})
	var amplitude := clampf(float(camera.get("amplitude", 32)), 0, 32)
	var origin := float(camera.get("originSeconds", 1.2))
	var frequency := float(camera.get("frequency", 0.45))
	camera_offset = manual_offset if camera_manual else int(floorf(amplitude * sin((ambient_time - origin) * frequency) + 0.5))
	$Camera.position = Vector2(float(data["viewport"]["width"]) / 2.0 + camera_offset, float(data["viewport"]["height"]) / 2.0)
	for region: Node2D in $Regions.get_children():
		var spec: Dictionary = region_spec(str(region.get_meta("region_id")))
		var background_speed := float(spec.get("backgroundParallax", 0.12))
		region.get_node("Background").position.x = camera_offset - floorf(camera_offset * background_speed + 0.5)
		for group_name in ["Midground", "Nearground"]:
			var group: Node2D = region.get_node(group_name)
			group.visible = depth_enabled
			for layer: Sprite2D in group.get_children():
				var base: Vector2 = layer.get_meta("base_position", Vector2.ZERO)
				var speed := float(layer.get_meta("parallax", 0.45))
				layer.position = base + Vector2(camera_offset - floorf(camera_offset * speed + 0.5), 0)
				var tint: Color = layer.get_meta("base_tint", Color.WHITE)
				layer.modulate = tint * (layer.get_meta("layer_ambient", Color.WHITE) if lighting_enabled else Color.WHITE)
				if layer.material is ShaderMaterial:
					var shader_material := layer.material as ShaderMaterial
					shader_material.set_shader_parameter("hero_center", $Traveler.global_position.round() + Vector2(-8, -22))
					shader_material.set_shader_parameter("protection_enabled", protection_enabled)

func _sync_lighting() -> void:
	var current: Dictionary = region_spec(active_region).get("lighting", {})
	$Ambient.color = rgb(current.get("ambient", [1, 1, 1])) if lighting_enabled else Color.WHITE
	for region in $Regions.get_children():
		var region_id := str(region.get_meta("region_id"))
		var enabled := lighting_enabled and region_id == active_region
		var spec: Dictionary = region_spec(region_id).get("lighting", {})
		region.get_node("Background").modulate = rgb(spec.get("backgroundAmbient", [1, 1, 1])) if lighting_enabled else Color.WHITE
		region.get_node("ContactShadows").visible = enabled
		var rig: Node2D = region.get_node("Lighting")
		rig.visible = enabled
		for light: PointLight2D in rig.get_node("Lights").get_children():
			light.enabled = enabled
		for occluder: LightOccluder2D in rig.get_node("Occluders").get_children():
			occluder.visible = enabled
	var fill: PointLight2D = $Traveler/Visual/ReadabilityFill
	fill.energy = maxf(0, float(current.get("heroFill", 0.25)))
	fill.enabled = lighting_enabled and fill.energy > 0
	_update_flicker()
	_update_depth()

func _update_flicker() -> void:
	if not lighting_enabled:
		return
	var rig: Node2D = get_node("Regions/" + active_region + "/Lighting")
	for light: PointLight2D in rig.get_node("Lights").get_children():
		var index := float(light.get_meta("light_index", 0))
		var amount := float(light.get_meta("flicker", 0))
		var factor := 1.0 + amount * (0.65 * sin(ambient_time * 3.0 + index) + 0.35 * sin(ambient_time * 5.7 + index * 0.3))
		light.energy = maxf(0, float(light.get_meta("base_energy", 1)) * factor)
	for core: Node2D in rig.get_node("Cores").get_children():
		var index := float(core.get_meta("light_index", 0))
		var amount := float(core.get_meta("flicker", 0))
		core.modulate.a = clampf(1.0 + amount * (0.65 * sin(ambient_time * 3.0 + index) + 0.35 * sin(ambient_time * 5.7 + index * 0.3)), 0, 1)

func set_time_state(value: String) -> void:
	if value != "disordered" and value != "restored":
		return
	time_state = value
	_update_help()

func set_ambient_paused(value: bool) -> void:
	ambient_paused = value
	if not value:
		camera_manual = false
	_update_help()

func local_time(affected: bool, at_time: float = -1.0) -> float:
	var t := ambient_time if at_time < 0.0 else at_time
	if not affected or time_state == "restored":
		return t
	var period := float(data.get("motion", {}).get("period", 3.2))
	var active := period * 0.375
	return floorf(t / period) * active + minf(fposmod(t, period), active)

func patch_intersects(x: float, top: float, bottom: float) -> bool:
	var patch: Dictionary = data.get("motion", {}).get("patch", {"x": 282, "y": 100, "w": 120, "h": 150})
	return x >= float(patch["x"]) and x <= float(patch["x"]) + float(patch["w"]) and bottom >= float(patch["y"]) and top <= float(patch["y"]) + float(patch["h"])

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var index := int(key.keycode - KEY_1)
		if index < data["regions"].size():
			set_region(str(data["regions"][index]["id"]))
		return
	match key.keycode:
		KEY_LEFT:
			cycle_region(-1)
		KEY_RIGHT:
			cycle_region(1)
		KEY_B:
			set_depth_enabled(not depth_enabled)
		KEY_M:
			set_protection_enabled(not protection_enabled)
		KEY_Q:
			set_camera_offset(-32)
		KEY_E:
			set_camera_offset(32)
		KEY_R:
			set_camera_offset(0)
		KEY_L:
			set_lighting_enabled(not lighting_enabled)
		KEY_P:
			set_ambient_paused(not ambient_paused)
		KEY_T:
			set_time_state("restored" if time_state == "disordered" else "disordered")
		KEY_H:
			$Interface.visible = not $Interface.visible
		KEY_ESCAPE:
			get_tree().quit()

func _process(delta: float) -> void:
	runtime += delta
	if not ambient_paused:
		ambient_time += delta
	_update_flicker()
	_update_depth()
	if not capture_path.is_empty() and not capture_started and runtime > 0.5:
		capture_started = true
		ambient_time = capture_time
		ambient_paused = true
		_update_flicker()
		_update_depth()
		_capture(capture_path)

func _update_help() -> void:
	if not is_node_ready():
		return
	var region_name := str(region_spec(active_region).get("name", active_region))
	var light_name := "场景灯光" if lighting_enabled else "原素材对照"
	var pause_name := " · 已暂停" if ambient_paused else ""
	$Interface/Help.text = region_name + " · " + light_name + pause_name + "\nA / D / 空格：移动跳跃    ← →：换区    Q / E / R：镜头\nL：灯光    B：景深    M：角色避让    P：环境    H：文字"

func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_error("The headless Dummy driver cannot provide a rendered Godot screenshot. Use a real display renderer.")
		get_tree().quit(2)
		return
	$Interface.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	if picture == null or picture.is_empty():
		push_error("A rendered viewport image was not available.")
		get_tree().quit(2)
		return
	var error := picture.save_png(path)
	print("GODOT_CAPTURE ", path, " status=", error)
	get_tree().quit(error)
