extends SceneTree
var app: FixedWorldApp
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)
func ticks(count: int) -> void:
	for i: int in count: await physics_frame
func settle() -> void:
	for i: int in 160:
		await physics_frame
		if not app.busy and app.room!=null: return
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://world_lifecycle_test.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app)
	app.start_new()
	await settle()
	await ticks(3)
	var revision := app.state.revision
	app.show_map()
	await ticks(4)
	check(app.state.revision==revision and app.state.value.explored==["P-R03"],"map viewing cannot commit exploration")
	app.toggle_pause()
	var start := app.player.position
	var cycle: int = app.state.value.cycle
	app.submit_damage(&"pit_fixture",DamageRequest.Kind.ENVIRONMENT,1,&"pit_fixture_once")
	await ticks(4)
	check(app.controller.actor_resources.health.current==4 and app.player.position.distance_to(start)<2,"surviving terrain failure returns actual approach without healing")
	check(app.state.value.cycle==cycle,"terrain failure preserves cycle")
	var token := app.lifetime.token()
	app.load_room("P-R01","START-P03-P01:P-R01")
	await settle()
	check(app.room.room_id=="P-R01" and app.controller.actor_resources.health.current==4,"ordinary room transition preserves HP")
	check(not app.lifetime.accepts(token),"old room ticket rejected")
	var stable_room := app.room
	app.load_room("P-R03","missing")
	check(app.room==stable_room and not app.busy and app.controller.active,"invalid entry leaves current playable room")
	app.state.storage.blocked=true
	app.load_room("P-R03","")
	await ticks(8)
	check(app.room==stable_room and app.controller.active,"failed transition write restores previous room")
	app.state.storage.blocked=false
	# Explicit ability precondition: Q is not a reward anywhere on the normal loop.
	var candidate := app.state.value.duplicate(true)
	candidate.flags.append("Q")
	check(app.state.commit(candidate,app.state.revision),"declared Q test precondition")
	app._apply_capabilities()
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	await ticks(8)
	app.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(2)
	check(app.q_guard.active and app.q_guard.cooldown>1.8 and not app.q_guard.landing_ready,"Q activates on real recoil with landing qualification")
	var monster := DamageRequest.new()
	monster.kind=DamageRequest.Kind.MONSTER
	var solid := DamageRequest.new()
	solid.kind=DamageRequest.Kind.ENVIRONMENT
	var light := DamageRequest.new()
	light.kind=DamageRequest.Kind.ENVIRONMENT;light.hazard_category=&"phase_light"
	check(app.q_guard.protects(monster) and app.q_guard.protects(light) and not app.q_guard.protects(solid),"Q filters enemy/light and never solid terrain")
	var protected_hp:=app.controller.actor_resources.health.current
	app.submit_damage(&"phase_fixture",DamageRequest.Kind.ENVIRONMENT,1,&"phase_once",&"phase_light")
	await ticks(1)
	check(app.controller.actor_resources.health.current==protected_hp,"real frame policy rejects light damage during qualified Q movement")
	var cooldown := app.q_guard.cooldown
	app.toggle_pause()
	await ticks(15)
	check(is_equal_approx(app.q_guard.cooldown,cooldown) and not app.q_guard.active,"pause cancels protection without advancing cooldown")
	app.toggle_pause()
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.load_room("P-R03","")
	await settle()
	check(app.q_guard.cooldown>0 and not app.q_guard.active,"room handoff preserves cooldown and cancels old protection")
	await ticks(5)
	check(app.q_guard.landing_ready,"actual landing requalifies without clearing cooldown")
	# Candidate and lethal damage share one frame; damage arbitration must win.
	app.enqueue("action","tutorial_move")
	app.submit_damage(&"fatal_fixture",DamageRequest.Kind.MONSTER,99,&"fatal_fixture_once")
	await ticks(8)
	await settle()
	check(not app.state.has("intro_move"),"same-frame fatal damage suppresses uncommitted action")
	check(app.state.has("Q") and app.state.value.cycle==cycle+1,"death keeps permanent facts and advances cycle")
	check(app.room.room_id=="P-R03" and app.player.is_on_floor(),"death recovers at registered initial rest before first station rest")
	# Declared Boss-terrain fixture, separate from the unmodified normal input route.
	app.load_room("P-R14","L02:P-R14")
	await settle()
	app.player.reset_at(Vector2(1380,620))
	await ticks(3)
	check(app.room.battle_started,"terrain fixture enters real sealed encounter")
	app.submit_damage(&"boss_terrain_fixture",DamageRequest.Kind.ENVIRONMENT,1,&"boss_terrain_once")
	await ticks(4)
	check(app.room.arena_bounds.has_point(app.player.position) and app.player.is_on_floor(),"Boss terrain return stays on supported entering side inside seals")
	app.return_title()
	await ticks(3)
	app.start_new()
	await settle()
	check(not app.tutorial.shot and not app.tutorial.recoil and not app.tutorial.move_landed,"new world clears prior tutorial proofs")
	app.queue_free()
	await ticks(5)
	print("WORLD LIFECYCLE: %d assertions, %d failures" % [checks,failures])
	quit(failures)
