extends Node
## Diagnostic-only child of the real DemoApp. Observation/capture only.
var app: Node
var measuring := false
var begin_usec := 0
var last_usec := 0
var stop_usec := 0
var next_poll := 0
var next_snapshot := 0
var sequence := 0
var frames: Array = []
var initial: Dictionary = {}
var costs_per_frame: Array = []
var previous_costs: Dictionary = {}
var samples: Array = []
var observed_audio: GameAudio

func _cue_count(played: Dictionary, cue: String) -> int:
	var count := int(played.get(cue, 0)) + int(played.get("motion_"+cue,0))
	for key: String in played:
		if key == "director_"+cue or (cue == "shot" and key.begins_with("director_shot_")):
			count += int(played[key])
	return count

func _ready() -> void:
	app = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 30000
	get_tree().root.set_meta("fps04_active", false)
	get_tree().root.set_meta("fps04_costs", {})
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.FPS04_RESULTS=[];window.FPS04_COMMAND='';window.FPS04_SECONDS=10;window.FPS04_READY=true")
	_publish()

func _state() -> Dictionary:
	var scene: Node = app.home_scene if is_instance_valid(app.home_scene) else app.stage
	var context := "home" if is_instance_valid(app.home_scene) else ("plains" if is_instance_valid(app.stage) else "title")
	var fg: Node = scene.get_node_or_null("UnderworldForeground") if is_instance_valid(scene) else null
	var controller: Node = app.home_scene.controller if context == "home" else app.controller
	var actor: Node2D = controller.motor if is_instance_valid(controller) else null
	var camera := get_viewport().get_camera_2d()
	var viewport := get_viewport()
	var size := viewport.get_visible_rect().size
	var texture_size := viewport.get_texture().get_size()
	var foreground: Dictionary = {}
	if is_instance_valid(fg):
		var drawn := 0
		var uploaded := 0
		var drawn_masks := 0
		for resident: Dictionary in fg._residents.values():
			uploaded += int(resident.get("mask_rect_count", 0))
			if resident.sprite.visible:
				drawn += 1
				drawn_masks += int(resident.get("mask_rect_count", 0))
		foreground = {"tracked": fg._tracked.size(), "residents": fg._residents.size(), "drawn": drawn, "protect": fg._protect.size(), "static": fg._static_protect.size(), "dynamic": fg._dynamic_protect.size(), "mask_rectangles_all": uploaded, "mask_rectangles_drawn": drawn_masks}
	var manifest: Dictionary = {}
	if scene is PlainsRegionStage:
		manifest = {"hash": str(scene.generated.manifest.manifest_hash), "seed": str(scene.generated.manifest.seed)}
	var audio_service := get_tree().get_first_node_in_group(&"game_audio") as GameAudio
	var health: Dictionary = {}
	if is_instance_valid(controller) and controller.actor_resources != null:
		health = {"current": controller.actor_resources.health.current, "terminal": controller.actor_resources.health.terminal}
	return {"context": context, "tree_paused": get_tree().paused, "menu": str(app.menu.visible_panel), "player": [actor.global_position.x, actor.global_position.y] if is_instance_valid(actor) else [], "player_health": health, "audio_played": audio_service.played.duplicate() if is_instance_valid(audio_service) else {}, "camera": [camera.get_screen_center_position().x, camera.get_screen_center_position().y] if camera != null else [], "viewport": {"logical": [size.x,size.y], "texture": [texture_size.x,texture_size.y]}, "manifest": manifest, "foreground": foreground, "node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}

func _publish() -> void:
	if OS.has_feature("web"):
		var state := _state()
		state["measuring"] = measuring
		JavaScriptBridge.eval("window.FPS04_STATE=" + JSON.stringify(state))

func _start(seconds: float) -> void:
	if measuring: return
	frames.clear()
	costs_per_frame.clear()
	previous_costs.clear()
	samples.clear()
	observed_audio = get_tree().get_first_node_in_group(&"game_audio") as GameAudio
	initial = _state()
	begin_usec = Time.get_ticks_usec()
	last_usec = begin_usec
	stop_usec = begin_usec + int(clampf(seconds, 3.0, 30.0) * 1000000.0)
	get_tree().root.set_meta("fps04_costs", {})
	get_tree().root.set_meta("fps04_active", true)
	get_tree().root.set_meta("fps04_events", {})
	measuring = true

func _finish() -> void:
	get_tree().root.set_meta("fps04_active", false)
	measuring = false
	sequence += 1
	var result := {"sequence": sequence, "elapsed_msec": (last_usec-begin_usec)/1000.0, "frames": frames, "costs": get_tree().root.get_meta("fps04_costs", {}).duplicate(true), "costs_per_frame": costs_per_frame, "samples": samples, "sample_columns": ["elapsed_ms", "nodes", "objects", "resources", "player_x", "player_y", "health", "jump_cues", "shot_cues", "death_cues"], "initial": initial, "final": _state(), "scope": "Instrumented real demo; inclusive nested script costs, no summed total or phone/GPU attribution. Per-frame counter reads/delta dictionaries add observer work; no image/audio readback in capture."}
	if OS.has_feature("web"):
		result["event_counts"] = get_tree().root.get_meta("fps04_events", {}).duplicate()
		JavaScriptBridge.eval("window.FPS04_RESULTS.push("+JSON.stringify(result)+")")
	_publish()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if measuring:
		frames.append([(now-last_usec)/1000.0, Performance.get_monitor(Performance.TIME_PROCESS)*1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		var current: Dictionary = get_tree().root.get_meta("fps04_costs", {})
		var differences: Dictionary = {}
		for key: String in current:
			var row: Array = current[key]
			var old: Array = previous_costs.get(key, [0,0])
			if row[1] != old[1]: differences[key] = [row[0]-old[0],row[1]-old[1]]
			previous_costs[key] = [row[0],row[1]]
		costs_per_frame.append(differences)
		var controller: Node = app.home_scene.controller if is_instance_valid(app.home_scene) else app.controller
		var actor: Node2D = controller.motor if is_instance_valid(controller) else null
		var hp: float = float(controller.actor_resources.health.current) if is_instance_valid(controller) and controller.actor_resources != null else -1.0
		var played: Dictionary = observed_audio.played if is_instance_valid(observed_audio) else {}
		samples.append([(now-begin_usec)/1000.0,Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),actor.global_position.x if is_instance_valid(actor) else null,actor.global_position.y if is_instance_valid(actor) else null,hp,_cue_count(played,"jump"),_cue_count(played,"shot"),_cue_count(played,"death")])
		last_usec = now
		if now >= stop_usec: _finish()
		return
	if OS.has_feature("web") and now >= next_poll:
		next_poll = now + 200000
		var command: Variant = JavaScriptBridge.eval("(()=>{const c=window.FPS04_COMMAND||'';window.FPS04_COMMAND='';return c})()")
		if command == "capture":
			var duration: Variant = JavaScriptBridge.eval("Number(window.FPS04_SECONDS)||10")
			_start(float(duration))
	if not measuring and now >= next_snapshot:
		next_snapshot = now + 1000000
		_publish()
