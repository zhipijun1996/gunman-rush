extends "res://tools/art/capture_plains_enemy_context.gd"
## Authored-frame inspection on actual PR142 tiles/light/camera. Not AI combat.
const OUT := "res://build/plains_actors_142/context/"
var timeline: Array[Dictionary] = []
class FrameActor extends Node2D:
	var deck: Array[Dictionary] = []
	var age := 0.0
	var sheet: PlainsActorAnimation
	var clip: StringName
	var progress := 0.0
	func _process(delta: float) -> void:
		age += delta
		var remaining := age
		for step: Dictionary in deck:
			sheet = step.sheet
			clip = step.clip
			progress = clampf(remaining / step.seconds, 0.0, 1.0)
			if remaining < step.seconds: break
			remaining -= step.seconds
		queue_redraw()
	func _draw() -> void:
		if sheet != null: sheet.draw_frame(self, clip, progress)

func step(id: String, clip: String, seconds: float) -> Dictionary:
	return {"sheet": load("res://assets/plains_actors_142/atlases/" + id + ".tres"), "clip": StringName(clip), "seconds": seconds}

func sequence(id: String) -> Array[Dictionary]:
	var deck: Array[Dictionary] = [step(id, "idle", 1.0), step(id, "move", .8)]
	if id.begins_with("windkeeper") or id == "bellstrider":
		if id == "windkeeper_phase2":
			deck = [step("windkeeper_phase1", "idle", .8)]
			deck.append(step("windkeeper_transition", "transition_start", .65))
			deck.append(step("windkeeper_transition", "transition_finish", .65))
		var attacks := ["roll", "ring", "lob"] if id == "bellstrider" else ["stomp", "lunge"] if id == "windkeeper_phase1" else ["sweep", "gust"]
		for attack: String in attacks:
			deck.append(step(id + "_" + attack, "anticipation", .65))
			deck.append(step(id + "_" + attack, "attack", .6))
			deck.append(step(id + "_" + attack, "recovery", .65))
	else:
		deck.append(step(id, "anticipation", .65))
		deck.append(step(id, "attack", .45))
		deck.append(step(id, "recovery", .7))
	deck.append(step(id, "hurt", .24))
	deck.append(step(id, "death", 1.1))
	deck.append(step(id, "death", .5))
	return deck

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280,720)
	app = preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path = "user://plains_actor_animation_review.json"
	app.settings_path = "user://plains_actor_animation_review_settings.json"
	for suffix: String in ["", ".backup", ".tmp", ".corrupt"]: DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app); app.start_new(); await settle()
	var layer := CanvasLayer.new(); layer.layer = 200; root.add_child(layer)
	note = Label.new(); note.position = Vector2(320,14); note.add_theme_font_size_override("font_size",16)
	note.add_theme_color_override("font_outline_color",Color("142b2b")); note.add_theme_constant_override("outline_size",5); layer.add_child(note)
	for shot: Dictionary in shots:
		if not OS.get_cmdline_user_args().is_empty() and shot.id not in OS.get_cmdline_user_args()[0].split(","): continue
		app.process_mode = Node.PROCESS_MODE_INHERIT
		app.load_room(shot.room, ""); await settle()
		app.set_physics_process(false); app.controller.active = false
		for actor: EnemyActor in app.room.enemies.values():
			actor.set_physics_process(false); actor.motor.hide()
		if app.room.encounter != null: app.room.encounter.set_physics_process(false)
		if app.room.boss != null: app.room.boss.hide()
		app.player.reset_at(shot.player); app._update_hud(); app.player.set_physics_process(false)
		(app.camera as WorldCamera).enter_room(FixedWorldProvider.rect(app.room.contract.world_geometry.bounds_world_units))
		await ticks(90)
		app.process_mode = Node.PROCESS_MODE_DISABLED
		note.text = shot.title + "\n动作检视 · 正式地形与光照 · 定点播放，非战斗录像"
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + shot.id + "-background.png")
		var subjects: Array[FrameActor] = []
		var longest := 0.0
		for placement: Array in shot.poses:
			var body := FrameActor.new()
			body.deck = sequence(placement[0]); body.position = placement[1]
			body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			body.process_mode = Node.PROCESS_MODE_ALWAYS
			var surface := ShaderMaterial.new()
			surface.shader = preload("res://game/presentation/actors/art/plains_actor_separation.gdshader")
			body.material = surface; body.z_index = 1
			if body.position.x > app.player.position.x: body.scale.x = -1
			app.room.add_child(body); subjects.append(body)
			var duration := 0.0
			for action: Dictionary in body.deck: duration += action.seconds
			longest = maxf(longest, duration)
		var start_frame := Engine.get_process_frames()
		for i: int in ceili(longest*60):
			await process_frame
			if i in [20, 140, 220]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUT + shot.id + "-%03d.png" % i)
		timeline.append({"scene": shot.id, "room": shot.room, "start_frame": start_frame, "end_frame": Engine.get_process_frames()})
		for body: FrameActor in subjects: body.queue_free()
	var file := FileAccess.open(OUT+"timeline.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(timeline,"\t")); file.close()
	app.process_mode = Node.PROCESS_MODE_INHERIT
	await WorldAudioLifecycle.drain_world(app); app.queue_free(); await ticks(5)
	quit()
