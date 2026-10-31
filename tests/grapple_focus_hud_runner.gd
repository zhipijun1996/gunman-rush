extends SceneTree
## Focused real adapter/Router/Controller + independent HUD regression.
## Initial high spawn is a fixture only; not proof of a playable forest route.
var checks := 0
var failures := 0
var ledger: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	ledger.append({"label": label, "passed": ok})
	if not ok:
		failures += 1
		printerr("FOCUS HUD FAIL: " + label)
func frames(count: int = 2) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func run() -> void:
	var fixture := preload("res://tests/combat_tests.gd").new()
	fixture.tree = self
	await fixture.fixture(Vector2(80, -1000))
	var actor: PlayerController = fixture.controller
	check(actor.enable_shot_energy(preload("res://game/player/resources/plains_shot_energy.tres")), "explicit historical D079 split focus/shot fixture enabled")
	check(actor.traversal.grant(&"grapple"), "H granted through real traversal ability")
	actor.set_physics_process(true)
	await frames()
	var overlay := InputSetup.attach(fixture.motor, actor.router)
	overlay.set_enabled(false)
	var keyboard := fixture.motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter
	var gamepad := fixture.motor.get_node("GamepadAdapter") as GamepadAdapter
	gamepad.set_physics_process(false)
	var hud := ActorResourcesHud.new()
	fixture.world.add_child(hud)
	hud.bind(actor.actor_resources, actor.air_focus_ability, actor)
	hud.set_region_compact(true)
	var focus := actor.air_focus_ability
	var energy_before := actor.actor_resources.stamina.current
	check(focus.stamina_state != actor.actor_resources.stamina, "formal focus and shot energy are distinct real ledgers")
	for key: bool in [false, true]:
		actor.router.clear("fresh_focus_fixture")
		focus.reset()
		var press: InputEvent
		if key:
			var event := InputEventKey.new()
			event.physical_keycode = KEY_E
			event.pressed = true
			press = event
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_RIGHT
			event.position = Vector2(400, 100)
			event.pressed = true
			press = event
		keyboard._unhandled_input(press)
		await frames()
		check(actor.router.aim_engaged and actor.router.aim_mode == &"grapple", "held right mouse/E reports real grapple aim")
		check(focus.active and is_equal_approx(Engine.time_scale, 0.15), "actual airborne Controller enters fifteen-percent focus")
		check(focus.stamina < focus.stamina_state.capacity and actor.actor_resources.stamina.current == energy_before, "actual hook aim spends focus and preserves shot energy")
		hud._process(0.0)
		check(hud.focus_bar.value == focus.stamina and hud.stamina_bar.value == energy_before and hud.focus_label.text.contains("15%"), "HUD shows actual independent focus and accepted slow state")
		# Cancel the held gesture without releasing a shot/hook; existing input
		# cancellation must restore time and require its physical release.
		actor.router.clear("focus_cancel_fixture")
		if press is InputEventKey: press.pressed = false
		else: (press as InputEventMouseButton).pressed = false
		keyboard._unhandled_input(press)
		await frames()
		check(not actor.router.aim_engaged and not focus.active and Engine.time_scale == 1.0, "actual cancel/release restores speed with no stale hook aim")
	# Deterministic boundary checks use the actual ability's real-second API;
	# they do not pretend these direct samples are natural player movement.
	actor.set_physics_process(false)
	focus.reset()
	focus.advance(2.0, false, true)
	hud._process(0.0)
	check(not focus.active and Engine.time_scale == 1.0 and is_equal_approx(focus.air_time_used, 2.0), "unchanged per-flight two-real-second cap restores normal speed")
	check(hud.focus_label.text.contains("0.0s") and hud.focus_label.text.contains("LAND TO REARM"), "HUD explains flight-budget exhaustion even with residual focus stamina")
	focus.advance(0.5, true, false)
	hud._process(0.0)
	check(focus.air_time_used == 0.0 and is_equal_approx(focus.stamina, 25.0), "landing resets duration and gradually recovers unchanged focus resource")
	check(hud.focus_bar.value == 25.0 and hud.focus_label.text.contains("2.0s") and hud.focus_label.text.contains("READY"), "HUD reflects gradual landing recovery and rearmed duration")
	check(hud.focus_bar.visible and hud.focus_label.visible and hud.focus_bar.size.x == 132.0 and hud.focus_bar.position.y > hud.combat_bar.position.y, "compact focus row remains visible and distinct from combat/shot rows")
	hud.set_region_compact(false)
	check(hud.focus_bar.size.x == 220.0 and hud.focus_bar.position.y > hud.combat_bar.position.y, "expanded layout retains separate readable focus row")
	check(actor.actor_resources.stamina.current == energy_before, "focus depletion/landing never drains or refills formal shot energy")
	# Sustained weapon steering shares the producer but legitimately outlasts
	# the ordinary two-second flight cap. Observe its real accepted state.
	focus.reset()
	focus.advance(2.1, false, true, true, true, 0.1)
	hud._process(0.0)
	check(focus.active and focus.air_time_used > 2.0 and hud.focus_label.text.contains("15%") and not hud.focus_label.text.contains("LAND TO REARM"), "sustained active focus is displayed as slow rather than an exhausted flight")
	hud.set_region_compact(true)
	for active_state: bool in [true, false]:
		if not active_state:
			focus.reset(); focus.advance(2.0, false, true)
		hud._process(0.0)
		var font := hud.focus_label.get_theme_font("font")
		var text_width := font.get_string_size(hud.focus_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hud.focus_label.get_theme_font_size("font_size")).x
		check(hud.focus_label.position.x + text_width <= 320.0, "actual compact font bounds retain the entire focus status within its panel")
		check(hud.focus_bar.position.y + hud.focus_bar.size.y <= 140.0, "focus track fits the formal compact HUD protected height")
	focus.stop()
	if not await load("res://tests/audio_teardown.gd").drain_world(fixture.world): failures += 1
	fixture.world.free()
	DirAccess.make_dir_recursive_absolute("res://build/verification")
	var evidence := FileAccess.open("res://build/verification/grapple_focus_hud.json", FileAccess.WRITE)
	if evidence == null:
		push_error("Cannot persist focus HUD assertion ledger")
		quit(1)
		return
	evidence.store_string(JSON.stringify({"checks": checks, "failures": failures, "ledger": ledger,
		"scope": "real input focus/HUD fixture; not regional or device acceptance",
		"sources": {get_script().resource_path: FileAccess.get_sha256(get_script().resource_path),
			"res://game/presentation/ui/actor_resources_hud.gd": FileAccess.get_sha256("res://game/presentation/ui/actor_resources_hud.gd")}}))
	evidence.close()
	print("GRAPPLE FOCUS HUD: %s checks / %s failures" % [checks, failures])
	quit(1 if failures else 0)
