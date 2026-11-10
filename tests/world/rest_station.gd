extends "res://tests/world/plains35_fixture.gd"
var audio_host: GameAudio
var seen: Dictionary={}
var peak_flash:=0.0

func station_start() -> void:
	app.player.reset_at(app.room.rest_point-Vector2(38,1))
	await ticks(4)
	check(app.context_target().get("kind")=="rest","real proximity selects station")
	app._interact()
	await ticks(4)
	check(is_instance_valid(app.rest_sequence) and app.rest_sequence.active,"real interaction starts rest presentation")

func finish_rest() -> void:
	for i:int in 360:
		await ticks(1)
		if not is_instance_valid(app.rest_sequence) or not app.rest_sequence.active:return
		var sequence:=app.rest_sequence
		seen[sequence.phase]=true
		peak_flash=maxf(peak_flash,sequence.flash.color.a)
	check(false,"rest times out")

func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://station_animation_test.json";root.add_child(app)
	app.start_new()
	for i:int in 180:
		await ticks(1)
		if not app.busy:break
	app.load_room("P-R01","")
	for i:int in 180:
		await ticks(1)
		if not app.busy:break
	await ticks(10)
	audio_host=GameAudio.for_origin(app) as GameAudio
	app._restore_hp(2)
	app.controller.combat_energy.grant("declared_rest_fixture",25)
	var cycle:int=app.state.value.cycle
	await station_start()
	check(app.state.value.cycle==cycle and app.controller.actor_resources.health.current==2,"entry cannot grant restoration before commit")
	for i:int in 150:
		await ticks(1)
		if app.rest_sequence.phase=="charge" and app.rest_sequence.age>.2:break
	var age:=app.rest_sequence.age
	var position:=app.player.position
	app.toggle_pause();await ticks(20)
	check(app.rest_sequence.suspended and is_equal_approx(age,app.rest_sequence.age) and app.player.position==position,"pause freezes pose, charging clock and physics")
	app._rest()
	check(app.state.value.cycle==cycle,"repeat interaction cannot duplicate transaction")
	app.toggle_pause()
	await finish_rest()
	check(app.controller.active and not paused and not app.paused,"exit restores controller and world")
	check(app.controller.actor_resources.health.current==5 and app.controller.combat_energy.current==25,"rest heals HP without altering resonance")
	check(app.state.value.cycle==cycle+1 and app.state.value.rest.room=="P-R01","one committed cycle and registered station")
	check(seen.has("exit") and peak_flash>0 and peak_flash<=.0751,"exit frames and single gentle flash after commit")
	check(int(audio_host.played.get(&"rest_contact",0))==1 and int(audio_host.played.get(&"rest_current",0))==1 and int(audio_host.played.get(&"rest_restore",0))==1,"contact, electric and restoration cues each emitted once")
	check(not PlayerPresentationRuntime.current_body(app.player).authored_pose.resting,"original body renderer owns idle after exit")
	app._restore_hp(2)
	cycle=app.state.value.cycle
	app.state.storage.blocked=true;peak_flash=0
	await station_start();await finish_rest()
	check(app.state.value.cycle==cycle and app.controller.actor_resources.health.current==2 and peak_flash==0,"failed save keeps state and skips success flash")
	check(int(audio_host.played.get(&"rest_restore",0))==1,"failed save never plays restoration cue")
	app.state.storage.blocked=false
	var obstruction:=StaticBody2D.new()
	var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new()
	shape.size=Vector2(8,64);collider.shape=shape;obstruction.add_child(collider)
	obstruction.position=app.room.rest_point-Vector2(18,14);app.room.add_child(obstruction)
	await station_start();await finish_rest()
	check(app.player.position.x<app.room.rest_point.x-20 and app.state.value.cycle==cycle,"blocked approach stays behind collision and does not rest")
	obstruction.queue_free();await ticks(2)
	await station_start();await ticks(45)
	app.load_room("P-R21","")
	for i:int in 180:
		await ticks(1)
		if not app.busy:break
	check(app.room.room_id=="P-R21" and app.controller.active and not paused,"room handoff releases station freeze")
	check(app.state.value.cycle==cycle,"cancelled entry cannot commit into next room")
	for voice:AudioStreamPlayer in audio_host._voices:
		check(not voice.has_meta("director_origin") or not voice.get_meta("director_origin").get_ref() is WorldRestSequence,"station voices are released on cancellation")
	app.load_room("P-R01","")
	for i:int in 180:
		await ticks(1)
		if not app.busy:break
	app.player.reset_at(app.room.rest_point);await ticks(4)
	app.submit_damage(&"rest_priority",DamageRequest.Kind.MONSTER,1,&"rest_priority_once")
	app._rest();await ticks(4)
	check(not is_instance_valid(app.rest_sequence) or not app.rest_sequence.active,"pending accepted damage wins over starting rest")
	await ticks(50)
	app.preferences.value.reduced=true;peak_flash=0
	await station_start();await finish_rest()
	check(peak_flash>0 and peak_flash<=.0251,"reduced effects uses a smaller successful refresh pulse")
	await station_start();app.toggle_pause()
	app.return_title();await ticks(3)
	check(app.controller==null and not paused,"exit to title during paused rest releases temporary ownership")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
	print("REST STATION: ",failures," failures")
	quit(failures)
