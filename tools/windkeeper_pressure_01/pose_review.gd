extends SceneTree
## Actual formal map2/GPU screenshots for art review ONLY. Every pose, phase,
## Actor/camera position and paused clock below is an explicitly labelled fixture.
## This producer is not a natural fight, evade route, hit or death proof.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
var output := "res://build/windkeeper_pressure_01/pose-review-01"
var app: Variant
var encounter: WindkeeperPressureEncounter
var boss: BossMotor
var presentation: Node2D
var fixture_label: Label
var detail_label: Label
var rows: Array[Dictionary] = []
var failures: Array[String] = []
var base_position := Vector2.ZERO
var platform_target := Vector2.ZERO
var original_manifest := ""
var source_before: Dictionary = {}
var normal_zoom := Vector2.ONE
var capture_count := 0

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	start.call_deferred()

func fail(message: String) -> void:
	failures.append(message)
	printerr("POSE REVIEW FAIL: ",message)

func ticks(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func start() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Pose review requires a real render surface (X11/GL or native window), not --headless")
		quit(2)
		return
	if DirAccess.dir_exists_absolute(output):
		printerr("Use a new output directory; previous review evidence is never overwritten: ",output)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	source_before = leaf_hashes()
	app = load("res://game/application/demo_app.gd").new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	if not app.start_debug_region(&"plains",2,"windkeeper-pressure-01"):
		fail("Actual App refused explicit map2 debug entry")
		await finish()
		return
	for index: int in 3600:
		if not app._stage_pending and app.stage is PlainsRegionStage and app.stage.assembly_ok and app._can_interact(): break
		await ticks(1)
	if app._stage_pending or not app.stage is PlainsRegionStage or not app.stage.assembly_ok:
		fail("Actual formal map2 did not assemble")
		await finish()
		return
	boss = app.stage.boss as BossMotor
	encounter = boss.get_node("Encounter") as WindkeeperPressureEncounter
	presentation = boss.get_node("Presentation") as Node2D
	if encounter == null or presentation.get_script().resource_path != "res://game/bosses/windkeeper/windkeeper_pressure_presentation.gd":
		fail("Formal map2 did not instantiate current pressure encounter/renderer")
		await finish()
		return
	original_manifest = JSON.stringify(app.stage.generated.manifest)
	# Only the explicit initial entry is run; the rest of this tool is paused
	# pose sampling, with the original App, assets, terrain, player and UI present.
	var x := boss.global_position.x-230.0
	var query := PhysicsRayQueryParameters2D.create(Vector2(x,boss.global_position.y+20),Vector2(x,boss.global_position.y+240),1,[app.player.get_rid()])
	var support: Dictionary = app.player.get_world_2d().direct_space_state.intersect_ray(query)
	if support.is_empty():
		fail("Initial fixture has no actual map2 support")
		await finish()
		return
	app.lifetime.invalidate_actor()
	app.controller.router.clear("explicit_pose_review_entry_fixture")
	app.player.reset_at((support.position as Vector2)-Vector2(0,18))
	await ticks(3)
	if not app._boss_started or not encounter.active:
		fail("Original App arena entry did not activate the actual Boss")
		await finish()
		return
	for index: int in 360:
		if encounter.mode != &"intro": break
		await ticks(1)
	encounter.cancel_pending_attacks()
	base_position = boss.global_position
	platform_target = base_position+Vector2(140,-65)
	if encounter.reward_stands.size()==3:
		# Use a real existing shelf anchor, not a made-up floating impact point.
		platform_target = encounter.reward_stands[2]+Vector2(0,18)
		base_position.x = platform_target.x-140
	boss.global_position = base_position
	app.player.reset_at(base_position+Vector2(-145,47))
	app.controller.router.clear("explicit_pose_review_player_scale_fixture")
	normal_zoom = app._run_camera.zoom
	paused = true
	build_caption()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		await capture_size(size)
	await finish()

func build_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 8
	panel.offset_right = -8
	panel.offset_top = -62
	panel.offset_bottom = -6
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.035,.07,.065,.94)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	fixture_label = Label.new()
	fixture_label.add_theme_font_size_override("font_size",17)
	column.add_child(fixture_label)
	detail_label = Label.new()
	detail_label.add_theme_font_size_override("font_size",13)
	column.add_child(detail_label)

func cases() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# Eight variant rows cover six moves plus single/double stomp and high/low
	# sweep. All are production clock/anchor fixtures, not actual attack release.
	for entry: Array in [["stomp-single",&"stomp",1,false,false],["stomp-double",&"stomp",1,true,false],["lunge",&"lunge",1,false,false],["sweep-low",&"sweep",2,false,false],["sweep-high",&"sweep",2,false,true],["gust",&"gust",2,false,false],["seeds",&"seeds",1,false,false],["platform",&"platform",3,false,false]]:
		for state: String in ["warning","execute","recover"]:
			var mode := StringName(String(entry[1])+"_warning") if state=="warning" else (entry[1] as StringName) if state=="execute" else &"recover"
			result.append({"id":str(entry[0])+"-"+state,"mode":mode,"phase":int(entry[2]),"double":bool(entry[3]),"high":bool(entry[4]),"progress":.88 if state=="warning" else .62 if state=="execute" else .58,"attack":entry[1],"group_remaining":0 if state=="recover" else 1})
	for phase: int in [1,2,3]:
		result.append({"id":"phase-%s-rest"%phase,"mode":&"observe","phase":phase,"progress":.25,"attack":&"stomp","group_remaining":0})
	for age: float in [.25,1.05,1.90]:
		result.append({"id":"death-%s-ms"%roundi(age*1000),"mode":&"dead","phase":3,"progress":age/1.9,"death_age":age,"attack":&"stomp","group_remaining":0})
	return result

func apply_fixture(spec: Dictionary) -> void:
	boss.global_position = base_position
	boss.stop()
	encounter.direction = 1
	encounter.locked_direction = 1
	encounter.stage_phase = int(spec.phase)
	encounter.locked_target = platform_target
	encounter.sweep_high = bool(spec.get("high",false))
	encounter.foot_index = 0
	var attack: StringName = spec.attack
	var attacks: Array = [attack,attack] if bool(spec.get("double",false)) else [attack,&"seeds"]
	encounter._group_plan = {"attacks":attacks,"double_stomp":bool(spec.get("double",false)),"phase":int(spec.phase),"fixture":true}
	encounter._attack_index = 0 if int(spec.group_remaining)>0 else 1
	var mode: StringName = spec.mode
	var config := encounter._config()
	var duration := config.normal_warning_seconds
	if mode == &"sweep_warning": duration = config.sweep_warning_seconds
	elif mode == &"platform_warning": duration = config.platform_warning_seconds
	elif mode == &"stomp": duration = config.stomp_seconds
	elif mode == &"lunge": duration = config.lunge_seconds
	elif mode == &"sweep": duration = config.sweep_seconds
	elif mode == &"gust": duration = config.gust_seconds
	elif mode == &"seeds": duration = config.seeds_seconds
	elif mode == &"platform": duration = config.platform_seconds
	elif mode == &"recover": duration = config.group_recovery_seconds
	elif mode == &"dead": duration = config.death_seconds
	encounter.mode = mode
	encounter._state_duration = duration
	encounter._state_age = duration*float(spec.progress)
	encounter.clock = duration-encounter._state_age
	encounter._fight_age = 12.5
	encounter._death_age = float(spec.get("death_age",0))
	encounter._bell_hit_age = -1
	encounter._pose_from.clear()
	if mode == &"lunge":
		# Same production ballistic arc, explicitly sampled via Actor-position
		# fixture so a static frame does not falsely show airborne feet grounded.
		boss.global_position.y -= sin(float(spec.progress)*PI)*config.lunge_height
	encounter._update_combat_shapes()
	presentation.synchronize_presentation()
	presentation.queue_redraw()
	app._run_camera.position_smoothing_enabled = false
	app._run_camera.zoom = normal_zoom
	app._run_camera.offset = Vector2.ZERO
	app._run_camera.global_position = base_position+Vector2(-20,-30)
	app._run_camera.force_update_scroll()
	refresh_hud(app)

func refresh_hud(node: Node) -> void:
	if node is WindkeeperHud: (node as WindkeeperHud)._process(0)
	for child: Node in node.get_children(): refresh_hud(child)

func capture_size(size: Vector2i) -> void:
	root.size = size
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := output+"/%sx%s"%[size.x,size.y]
	DirAccess.make_dir_recursive_absolute(folder)
	var specifications := cases()
	var tile := Vector2i(size.x/2,size.y/2)
	var sheet := Image.create(tile.x*3,tile.y*10,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("122522"))
	for index: int in specifications.size():
		var spec: Dictionary = specifications[index]
		apply_fixture(spec)
		fixture_label.text = "POSE FIXTURE / %s / PHASE %s / %sx%s"%[str(spec.id).to_upper(),spec.phase,size.x,size.y]
		detail_label.text = "Paused actual map2/App. Explicit pose/Actor/camera fixtures; no HP edits, no fight or terrain-transition claim."
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image.is_empty() or image.get_size()!=size:
			fail("Unexpected or empty native GPU surface for "+str(size))
			return
		var colors: Dictionary = {}
		for sy: int in range(0,size.y,maxi(1,size.y/24)):
			for sx: int in range(0,size.x,maxi(1,size.x/40)):
				colors[image.get_pixel(sx,sy).to_rgba32()] = true
		if colors.size()<12:
			fail("GPU surface has too few colors; not certifying blank output")
			return
		var name := "%02d-%s.png"%[index+1,spec.id]
		var path := folder+"/"+name
		if image.save_png(path)!=OK:
			fail("Failed writing actual GPU screenshot "+path)
			return
		var small := image.duplicate() as Image
		small.resize(tile.x,tile.y,Image.INTERPOLATE_NEAREST)
		if small.get_format()!=Image.FORMAT_RGBA8: small.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(small,Rect2i(Vector2i.ZERO,tile),Vector2i((index%3)*tile.x,(index/3)*tile.y))
		capture_count += 1
		rows.append({"path":path,"sha256":FileAccess.get_sha256(path),"spec":spec,"window":[size.x,size.y],"image_size":[image.get_width(),image.get_height()],"camera_zoom":normal_zoom,"camera_center":app._run_camera.global_position,"player_position":app.player.global_position,"boss_position":boss.global_position,"player_HP":app.controller.actor_resources.health.current,"boss_HP":encounter.health.current,"pose":encounter.rig_pose(),"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),"paused":paused,"manifest_unchanged":JSON.stringify(app.stage.generated.manifest)==original_manifest,"sampled_colors":colors.size()})
	var sheet_path := folder+"/contact-sheet-actual-gpu-fixtures.png"
	if sheet.save_png(sheet_path)!=OK: fail("Failed saving explicit contact sheet")
	print("POSE REVIEW SIZE ",size," screenshots=",specifications.size()," sheet=",sheet_path)

func leaf_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["game/bosses/windkeeper/windkeeper_pressure_encounter.gd","game/bosses/windkeeper/windkeeper_pressure_rig.gd","game/bosses/windkeeper/windkeeper_pressure_presentation.gd","scripts/bosses/windkeeper_pressure_definition.gd","game/bosses/windkeeper/windkeeper_pressure_wind.gd","shaders/windkeeper_pressure_foreground.gdshader","shaders/underworld_foreground.gdshader","resources/bosses/windkeeper_storm.tres","scenes/bosses/windkeeper_pressure.tscn","assets/underworld_plains/actors/windkeeper.png","tools/windkeeper_pressure_01/pose_review.gd"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	return result

func json_value(value: Variant) -> Variant:
	if value is Vector2: return [value.x,value.y]
	if value is Vector2i: return [value.x,value.y]
	if value is Transform2D: return [json_value(value.x),json_value(value.y),json_value(value.origin)]
	if value is Dictionary:
		var copied: Dictionary = {}
		for key: Variant in value: copied[str(key)] = json_value(value[key])
		return copied
	if value is Array or value is PackedVector2Array:
		var copied: Array = []
		for entry: Variant in value: copied.append(json_value(entry))
		return copied
	return value

func finish() -> void:
	var after := leaf_hashes()
	if source_before!=after: fail("Declared renderer/source leaves changed during pose sampling")
	var report := {"task":"WINDKEEPER-PRESSURE-01","scope":"Actual formal map2 GPU pose screenshots; explicit paused phase/clock/Actor/camera fixtures, no HP edits. Not natural battle, full death, damage, mobile device or terrain-transition acceptance.","display_driver":DisplayServer.get_name(),"rendering_adapter":RenderingServer.get_video_adapter_name(),"captures":capture_count,"rows":rows,"failures":failures,"declared_leaf_sha256_before":source_before,"declared_leaf_sha256_after":after,"declared_leaves_stable":source_before==after,"source_guard_scope":"These declared leaves only; whole-source inventory must be guarded by the caller for full freeze attribution.","contact_sheet":"Nearest-neighbor overview of actual full GPU screenshots, ordered rows perindex; not continuous video."}
	paused = false
	if is_instance_valid(app):
		app.abandon_run()
		if not await TEARDOWN.drain_world(app): fail("App audio/world drain failed")
		app.free()
	await ticks(2)
	var file := FileAccess.open(output+"/report.json",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(json_value(report),"\t"))
		file.close()
	print("WINDKEEPER PRESSURE POSE REVIEW: ",capture_count," GPU screenshots; 2 resolutions; ",failures.size()," failures")
	quit(0 if failures.is_empty() and capture_count==60 else 1)
