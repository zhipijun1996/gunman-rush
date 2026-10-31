extends Node
## Diagnostic copy only. Presentation knockouts and explicitly labelled scene/cue fixtures.
const MODES := ["baseline", "ambience_off", "foreground_render_off", "foreground_update_off", "shadows_off", "hud_avoidance_off", "lights_off", "all_audio_off", "audio_pause_guard", "web_sample_music", "web_sample_audio", "transparent_skip", "audio_bus_fix", "sample_only", "menu"]
var app: Node
var mode := "baseline"
var active := false
var frames: Array = []
var begin_usec := 0
var last_usec := 0
var warm_until := 0
var command_at := 0
var snapshot_at := 0
var sequence := 0
var context_id := 0
var subject: Node
var fg: CanvasLayer
var lights: Array = []
var selected: Node
var audio: GameAudio
var begin_audio := 0
var measuring := false
var capture_seconds := 10.0
var stop_at := 0
var initial: Dictionary = {}
var stopped_players: Array = []
var stopped_audio_nodes: Array = []
var original_playback_types: Array = []
var camera_fixture:=false
var input_rejections: Array = []
var shader_materials: Array = []
var discard_shaders: Dictionary = {}

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	process_priority=30000
	app=get_meta("app_ref").get_ref()
	app.meta_persistence_enabled=false
	audio=get_tree().get_first_node_in_group(&"game_audio") as GameAudio
	selected=app.get_node_or_null("SelectedAmbienceRuntime")
	if selected==null:
		for node: Node in app.get_children():
			if node is SelectedAmbienceRuntime:selected=node
	if OS.has_feature("web"):JavaScriptBridge.eval("window.MOBILE_PERF_READY=true;window.MOBILE_PERF_RESULTS=[];")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode==KEY_F6:_command("capture")
	if event.physical_keycode==KEY_F7:_command("plains")

func _cache() -> bool:
	if not is_instance_valid(app) or not app.is_inside_tree():return false
	var current: Node=app.home_scene if is_instance_valid(app.home_scene) else app.stage
	if not is_instance_valid(current):return false
	if current.get_instance_id()==context_id:return true
	var foreground:=current.get_node_or_null("UnderworldForeground") as CanvasLayer
	if not is_instance_valid(foreground):return false
	subject=current;context_id=subject.get_instance_id();lights.clear();fg=foreground
	for node: Node in subject.find_children("*","PointLight2D",true,false):
		lights.append([node,node.enabled,node.shadow_enabled])
	var controller: PlayerController=app.home_scene.controller if is_instance_valid(app.home_scene) else app.controller
	if is_instance_valid(controller) and not controller.router.action_rejected.is_connected(_input_rejected):controller.router.action_rejected.connect(_input_rejected)
	shader_materials.clear()
	var seen: Dictionary={}
	for node: Node in subject.find_children("*","CanvasItem",true,false):
		var material: Material=(node as CanvasItem).material
		if not material is ShaderMaterial or seen.has(material.get_instance_id()):continue
		seen[material.get_instance_id()]=true
		var shader: Shader=(material as ShaderMaterial).shader
		if shader!=null and shader.resource_path in ["res://shaders/underworld_fine_sprite.gdshader","res://shaders/formal_fine_lit.gdshader","res://shaders/formal_fine_boundary.gdshader"]:
			shader_materials.append([material,shader])
	active=true;mode="baseline";frames.clear();measuring=false;warm_until=Time.get_ticks_usec()+2500000
	return true

func _restore() -> void:
	if not active:return
	if app.menu.visible_panel==&"home" and is_instance_valid(app.home_scene):
		app.menu._close_home_overlay()
	elif get_tree().paused and mode=="menu":app.toggle_pause()
	if is_instance_valid(fg):fg.visible=true;fg.set_process(true)
	for row: Array in shader_materials:
		if is_instance_valid(row[0]):row[0].shader=row[1]
	for row: Array in lights:
		if is_instance_valid(row[0]):row[0].enabled=row[1];row[0].shadow_enabled=row[2]
	get_tree().root.set_meta("mobile_perf_hud_off",false)
	get_tree().root.set_meta("mobile_perf_audio_off",false)
	get_tree().root.set_meta("mobile_perf_audio_pause_guard",false)
	if OS.has_feature("web"):JavaScriptBridge.eval("window.MOBILE_PERF_MASTER_ROUTING?.(false)")
	for row: Array in original_playback_types:
		if is_instance_valid(row[0]):
			var pos: float=row[0].get_playback_position()
			var playing: bool=row[0].playing
			row[0].stop();row[0].playback_type=row[1]
			if playing:row[0].play(pos)
	original_playback_types.clear()
	for row: Array in stopped_audio_nodes:
		if is_instance_valid(row[0]):row[0].set_process(row[1])
	for row: Array in stopped_players:
		if is_instance_valid(row[0]) and row[1]:row[0].play(row[2])
	stopped_audio_nodes.clear();stopped_players.clear()
	if is_instance_valid(selected):selected.set_process(true)

func _apply(value: String) -> void:
	if value not in MODES:return
	if not _cache():return
	if measuring:_finish()
	_restore();mode=value
	if value=="ambience_off" and is_instance_valid(selected):
		selected.set_process(false)
		selected._clear_context()
	if value=="foreground_render_off":fg.visible=false
	if value=="foreground_update_off":fg.set_process(false)
	if value=="shadows_off":
		for row: Array in lights:row[0].shadow_enabled=false
	if value=="lights_off":
		for row: Array in lights:row[0].enabled=false
	if value=="audio_bus_fix":
		get_tree().root.set_meta("mobile_perf_audio_pause_guard",true)
		if OS.has_feature("web"):JavaScriptBridge.eval("window.MOBILE_PERF_MASTER_ROUTING?.(true)")
	if value=="sample_only":
		if is_instance_valid(selected):selected.set_process(false);selected._clear_context()
		stopped_audio_nodes.append([app._music,app._music.is_processing()]);app._music.set_process(false)
		for voice: AudioStreamPlayer in app._music._voices:
			stopped_players.append([voice,voice.playing,voice.get_playback_position()]);voice.stop()
	if value=="transparent_skip":
		for row: Array in shader_materials:
			var original: Shader=row[1]
			var key:=original.resource_path
			if not discard_shaders.has(key):
				var shader:=Shader.new()
				var code:=original.code
				var end:=code.find("void light()")
				var close:=code.rfind("}",end)
				code=code.substr(0,close)+"if(COLOR.a == 0.0) { discard; }\n"+code.substr(close)
				shader.code=code;discard_shaders[key]=shader
			(row[0] as ShaderMaterial).shader=discard_shaders[key]
	if value=="all_audio_off":
		get_tree().root.set_meta("mobile_perf_audio_off",true)
		for node: Node in app.find_children("*","Node",true,false):
			if node is AudioStreamPlayer:
				stopped_players.append([node,node.playing,node.get_playback_position()]);node.stop()
			if node is GameAudio or node is GameMusic or node is GameAmbience or node is HomeAmbienceAudition or node is SelectedAmbienceRuntime:
				stopped_audio_nodes.append([node,node.is_processing()]);node.set_process(false)
	if value=="audio_pause_guard":get_tree().root.set_meta("mobile_perf_audio_pause_guard",true)
	if value in ["web_sample_music","web_sample_audio"]:
		var sample_players: Array=app._music._voices.duplicate()
		if value=="web_sample_audio" and is_instance_valid(audio.ambience):
			sample_players.append_array(audio.ambience._beds)
			get_tree().root.set_meta("mobile_perf_audio_pause_guard",true)
		for voice: AudioStreamPlayer in sample_players:
			original_playback_types.append([voice,voice.playback_type])
			var pos:=voice.get_playback_position();var playing:=voice.playing
			voice.stop();voice.playback_type=AudioServer.PLAYBACK_TYPE_SAMPLE
			if playing:voice.play(pos)
	if value=="hud_avoidance_off":get_tree().root.set_meta("mobile_perf_hud_off",true)
	if value=="menu":
		if is_instance_valid(app.home_scene):app._open_home_navigation()
		else:app.toggle_pause()
	warm_until=Time.get_ticks_usec()+2500000;frames.clear();measuring=false
	initial=_state()
	_publish()

func _command(command: String) -> void:
	if command.begins_with("mode:"):_apply(command.trim_prefix("mode:"))
	elif command=="capture":
		if not _cache():return
		warm_until=maxi(warm_until,Time.get_ticks_usec()+100000)
		begin_usec=0;last_usec=0;frames.clear();measuring=true;stop_at=0
	elif command=="stop" and measuring:_finish()
	elif command=="plains":
		if measuring:_finish()
		_restore();active=false;context_id=0
		app.start_plains("plains-run")
	elif command=="home":
		if measuring:_finish()
		_restore();active=false;context_id=0
		app._show_home()
	elif command=="freeze_visuals":get_tree().paused=true
	elif command=="lamp_view" and not is_instance_valid(app.home_scene) and not lights.is_empty():
		if is_instance_valid(app._run_camera):
			app._run_camera.set_physics_process(false)
			app._run_camera.global_position=lights[0][0].global_position+Vector2(0,100)
			camera_fixture=true
	elif command=="cue_coin" and is_instance_valid(audio):
		# Explicit audio-only request fixture, not a claimed natural pickup.
		audio.play(&"coin")
	elif command.begins_with("seconds:"):capture_seconds=clampf(float(command.trim_prefix("seconds:")),3,60)
	_publish()

func _process(_delta: float) -> void:
	if not is_instance_valid(app) or not app.is_inside_tree():
		set_process(false);queue_free();return
	var now:=Time.get_ticks_usec()
	if now>=command_at:
		command_at=now+200000
		if OS.has_feature("web"):
			var request: Variant=JavaScriptBridge.eval("(()=>{const c=window.MOBILE_PERF_COMMAND||'';window.MOBILE_PERF_COMMAND='';return c})()")
			if request is String and not request.is_empty():_command(request)
	_cache()
	if now>=snapshot_at:
		snapshot_at=now+1000000;_publish()
	if not measuring or now<warm_until:return
	if begin_usec==0:
		begin_usec=now;last_usec=now;stop_at=now+int(capture_seconds*1000000);get_tree().root.set_meta("perf_costs",{})
		begin_audio=audio._perf_events.size() if is_instance_valid(audio) else 0
		initial=_state()
		return
	frames.append([(now-last_usec)/1000.0,Performance.get_monitor(Performance.TIME_PROCESS)*1000,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	last_usec=now
	if now>=stop_at:_finish()

func _state() -> Dictionary:
	var lights_enabled:=0;var shadowed:=0
	for row: Array in lights:
		if is_instance_valid(row[0]) and row[0].enabled and row[0].visible:
			lights_enabled+=1
			if row[0].shadow_enabled:shadowed+=1
	var residents:=0;var masks:=0;var drawn:=0;var effective:=0
	if is_instance_valid(fg):
		residents=fg._residents.size()
		for row: Dictionary in fg._residents.values():
			masks+=int(row.get("mask_rect_count",0))
			if row.sprite.visible:
				drawn+=1
				if fg.visible:effective+=1
	var player: Node=app.home_scene.player if is_instance_valid(app.home_scene) else app.player
	var music: Dictionary={}
	if is_instance_valid(app._music):
		music={"requested_track":str(app._music.requested_track),"starts":app._music.starts,"playing":app._music._voices.map(func(v):return {"playing":v.playing,"position":v.get_playback_position(),"paused":v.stream_paused,"db":v.volume_db,"type":v.playback_type})}
	return {"context":"home" if is_instance_valid(app.home_scene) else "plains","mode":mode,"tree_paused":get_tree().paused,"menu":str(app.menu.visible_panel),"player":[player.global_position.x,player.global_position.y] if is_instance_valid(player) else [],"foreground":{"visible":fg.visible if is_instance_valid(fg) else false,"processing":fg.is_processing() if is_instance_valid(fg) else false,"tracked":fg._tracked.size() if is_instance_valid(fg) else 0,"protect":fg._protect.size() if is_instance_valid(fg) else 0,"static":fg._static_protect.size() if is_instance_valid(fg) else 0,"dynamic":fg._dynamic_protect.size() if is_instance_valid(fg) else 0,"residents":residents,"drawn":drawn,"effective_drawn":effective,"mask_rectangles_uploaded":masks},"lights_enabled":lights_enabled,"shadows_enabled":shadowed,"texture_memory":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"buffer_memory":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),"music":music,"selected_ambience":selected.snapshot() if is_instance_valid(selected) else {},"motion_events":audio.get("motion_events") if is_instance_valid(audio) else [],"weapon_events":audio.get("weapon_events") if is_instance_valid(audio) else [],"motion_dropped":audio.get("motion_dropped") if is_instance_valid(audio) else 0,"weapon_dropped":audio.get("weapon_dropped") if is_instance_valid(audio) else 0,"lamp_positions":lights.map(func(row):return [row[0].global_position.x,row[0].global_position.y]),"voices_busy":audio._voices.filter(func(v):return v.playing).size() if is_instance_valid(audio) else 0,"sfx_played":audio.played if is_instance_valid(audio) else {},"seed":"plains-run","camera_fixture":camera_fixture,"input_rejections":input_rejections}

func _publish() -> void:
	if not OS.has_feature("web"):return
	JavaScriptBridge.eval("window.MOBILE_PERF_STATE="+JSON.stringify({"state":_state(),"measuring":measuring,"sequence":sequence,"warm_until_usec":warm_until,"engine_usec":Time.get_ticks_usec()})+";")

func _finish() -> void:
	measuring=false
	if frames.is_empty():return
	sequence+=1
	var report: Dictionary={"sequence":sequence,"mode":mode,"elapsed_msec":(last_usec-begin_usec)/1000.0,"frames":frames,"costs":get_tree().root.get_meta("perf_costs",{}).duplicate(true),"initial":initial,"final":_state(),"audio_events":audio._perf_events.slice(begin_audio) if is_instance_valid(audio) else [],"scope":"instrumented actual public PCK; explicit scene and cue fixtures; not physical phone"}
	if OS.has_feature("web"):JavaScriptBridge.eval("window.MOBILE_PERF_RESULTS.push("+JSON.stringify(report)+");")
	frames=[];_publish()

func _input_rejected(reason: String) -> void:
	input_rejections.append({"reason":reason,"real_usec":Time.get_ticks_usec()})
	if input_rejections.size()>128:input_rejections.pop_front()
