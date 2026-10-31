extends "res://tests/player_presentation_01/feel_trace.gd"
## Reuse the real terrace route; adversarial task component lifetime checks.

func ready_home() -> void:
	for unused: int in 180:
		await physics_frame
		if is_instance_valid(app.motion_visual): break
	check(is_instance_valid(app.motion_visual),"actual Home candidate ready")
	actor=app.home_scene.player
	controller=app.home_scene.controller
	visual=app.motion_visual
	controller.router.activate_device(&"gamepad")

func run() -> void:
	root.size=Vector2i(1280,720)
	if output.is_empty() or FileAccess.file_exists(output): quit(1);return
	var profile := PlayerMotionCandidateProfile.new()
	for property: String in ["heavy_min_drop","heavy_min_speed_ratio","heavy_shake_seconds","heavy_shake_pixels","heavy_recovery_seconds"]:
		var original: float = profile.get(property)
		for bad: float in [INF,NAN,-1.0]:
			profile.set(property,bad)
			check(not profile.valid(),"invalid heavy profile rejects "+property)
		profile.set(property,original)
	app=preload("res://experiments/motion/entries/landing_feel.tscn").instantiate()
	root.add_child(app)
	await ready_home()
	await terrace_drop()
	var feel := actor.get_node("MotionFeel") as PlayerMotionFeel
	check(feel._remaining>0 and visual._heavy_recovery>0,"live heavy shake and recovery")
	var remaining := feel._remaining
	var recovery := visual._heavy_recovery
	paused=true
	for unused: int in 8: await process_frame
	check(feel._remaining==remaining and visual._heavy_recovery==recovery,"pause freezes active shake and visual recovery")
	paused=false
	app.set_motion_enabled(false)
	check(feel._remaining==0 and visual._heavy_recovery==0 and not feel._screen.visible,"OFF clears live heavy feedback immediately")
	check(feel.legacy._fall_speed==0,"accepted ON landing resets hidden legacy speed")
	app.set_motion_enabled(true)
	check(feel._remaining==0 and visual._heavy_recovery==0,"ON never replays old heavy event")
	var event_count := app.motion_audio.motion_events.size()
	app.motion_audio.volume=0
	check(not app.motion_audio.motion_cue(&"heavy",1,actor.get_instance_id()) and app.motion_audio.motion_events.size()==event_count,"mute admits no new motion voice")
	app.motion_audio.volume=.7
	var old_visual: WeakRef = weakref(visual)
	var old_feel: WeakRef = weakref(feel)
	app.return_full_game()
	check(old_visual.get_ref()==null and old_feel.get_ref()==null,"Home full-game return releases both candidate components")
	var original := actor.get_node("UnderworldPlayer")
	check(original is UnderworldPlayer and not original is PlayerMotionCandidateVisual,"Home restores original actual body")
	var legacy := actor.get_node("PlayerFeedback") as PlayerFeedback
	check(controller.jump_ability.jumped.is_connected(legacy._jump) and controller.landed.is_connected(legacy._land),"original accepted audio hooks restored")
	for unused: int in 2:
		app.open_home_sample()
		await ready_home()
		check(actor.get_node("MotionFeel") is PlayerMotionFeel,"repeated HOME DROP has one live consumer")
	var last_feel := actor.get_node("MotionFeel") as PlayerMotionFeel
	last_feel.free()
	check(controller.jump_ability.jumped.is_connected(legacy._jump) and controller.landed.is_connected(legacy._land),"standalone component removal restores legacy hooks")
	# Reattach through the actual public Home command, then verify teardown.
	app.open_home_sample()
	await ready_home()
	await finish()
