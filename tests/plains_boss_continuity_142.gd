extends "res://tools/art/capture_plains_enemy_context.gd"
## Continuous visual anchors, data texture fidelity and real broad wind admission.
var checks:=0
var failures:=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL CONTINUITY142: ",label)
func run() -> void:
	var cache: Dictionary={}
	for kind: StringName in [&"bellstrider",&"windkeeper"]:
		for phase: int in ([1] if kind==&"bellstrider" else [1,2]):
			var mode: StringName=&"lob" if kind==&"bellstrider" else &"gust"
			var data: Dictionary={"mode":mode,"phase":phase,"direction":-1,"state_age":0.0,"state_duration":1.0}
			var previous:=Vector2.ZERO
			var largest:=0.0
			for step: int in 201:
				data.state_age=float(step)/200
				var frame:=PlainsBossFrames.sample(kind,data,cache)
				var core:=PlainsBossFrames.core_transform(frame).origin
				if step>0:largest=maxf(largest,core.distance_to(previous))
				previous=core
			check(largest<3.0,"weakpoint follows continuous geometry across keyframe boundaries: %s/%d" % [kind,phase])
	var early:=PlainsBossFrames.sample(&"bellstrider",{"mode":&"roll","state_age":.4,"state_duration":1.35,"travel":220},cache)
	var late:=PlainsBossFrames.sample(&"bellstrider",{"mode":&"roll","state_age":1.1,"state_duration":1.35,"travel":660},cache)
	check(early.progress==1.0 and late.progress==1.0,"committed charge holds its loaded body instead of restarting every 110 units")
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/plains_boss_motion_142/manifest.json")):
		var path: String="res://assets/plains_boss_motion_142/"+row.id+"_vectors.png"
		var imported: Image=(load(path) as Texture2D).get_image()
		var original:=Image.new()
		original.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		imported.convert(Image.FORMAT_RGBA8);original.convert(Image.FORMAT_RGBA8)
		check(imported.get_data()==original.get_data(),"motion vector import preserves all four data channels: "+row.id)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://boss_continuity_142.json";app.settings_path="user://boss_continuity_142_settings.json"
	root.add_child(app);app.start_new();await settle();app.load_room("P-R14","");await settle()
	var encounter:=app.room.encounter as WindkeeperPressureEncounter
	encounter.activate();app.room.battle_started=true;encounter.set_physics_process(false)
	encounter.stage_phase=2
	for direction: int in [-1,1]:
		encounter.locked_direction=direction
		var field:=encounter.wind_field_rect()
		for y: float in [-270,-140,40]:
			var local:=Vector2(direction*220,y)
			check(field.has_point(local),"wind covers upper/middle/near-ground forward space")
			app.player.global_position=encounter.motor.global_position+local
			app.player.clear_local_velocity();encounter._apply_wind(1.0/60)
			check(app.player._local_velocity.x*direction>70,"actual PlayerMotor accepts wind at all three elevations")
		check(not field.has_point(Vector2(-direction*100,-100)),"wind excludes space behind boss")
		check(not field.has_point(Vector2(direction*500,-100)),"wind excludes beyond the configured front edge")
		check(not field.has_point(Vector2(direction*220,-340)),"wind excludes above the configured ceiling")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
	print("PLAINS BOSS CONTINUITY142: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
