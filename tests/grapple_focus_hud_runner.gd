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
	await focus_vignette_contract()
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

func focus_render_frames(count: int, gpu: bool) -> void:
	for _index: int in count:
		await process_frame
		if gpu: await RenderingServer.frame_post_draw

func focus_image_valid(image: Image, expected_size: Vector2i) -> bool:
	return image != null and not image.is_empty() and expected_size.x > 0 and expected_size.y > 0 and image.get_size() == expected_size and not image.get_data().is_empty()

func focus_vignette_contract() -> void:
	# Isolated presentation contract before the original real Router fixture.
	# Public Ability APIs produce active_changed; no private gameplay callback.
	var gpu := DisplayServer.get_name() != "headless"
	var starting_scale := Engine.time_scale
	var host := Node.new()
	root.add_child(host)
	var background := ColorRect.new()
	background.color = Color(0.11,0.21,0.31,1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ability := AirFocusAbility.new()
	host.add_child(ability)
	ability.configure(PlayerTuning.load_default())
	# One actual light and lit marker prove this is a rendered lighting case.
	var root_size := Vector2i(root.get_texture().get_size()) if gpu else Vector2i.ZERO
	if gpu:
		var light_image := Image.create(2,2,false,Image.FORMAT_RGBA8)
		light_image.fill(Color.WHITE)
		var light := PointLight2D.new()
		light.texture = ImageTexture.create_from_image(light_image)
		light.texture_scale = maxf(root_size.x,root_size.y)
		light.position = Vector2(root_size)*0.5
		light.energy = 0.5
		light.blend_mode = Light2D.BLEND_MODE_ADD
		light.range_layer_min = -1
		light.range_layer_max = 1
		light.range_z_min = -4096
		light.range_z_max = 4096
		light.enabled = false
		host.add_child(light)
		var marker := ColorRect.new()
		marker.color = Color(0.2,0.2,0.2,1.0)
		marker.position = Vector2(root_size)*0.5-Vector2(8,8)
		marker.size = Vector2(16,16)
		host.add_child(marker)
		await focus_render_frames(2,true)
		var unlit := root.get_texture().get_image()
		light.enabled = true
		await focus_render_frames(2,true)
		var lit := root.get_texture().get_image()
		check(focus_image_valid(unlit,root_size) and focus_image_valid(lit,root_size) and root.get_visible_rect().size.x > 0 and root.get_visible_rect().size.y > 0,"GPU fixture has actual nonempty positive-size images and root viewport")
		check(focus_image_valid(unlit,root_size) and focus_image_valid(lit,root_size) and unlit.get_pixelv(root_size/2) != lit.get_pixelv(root_size/2),"actual PointLight changes the lit marker pixel before unshaded vignette comparison")
	await focus_render_frames(2,gpu)
	var before: Image = root.get_texture().get_image() if gpu else null
	var positive_changed := false
	var warm_refs: Array[WeakRef] = []
	var observe_viewport := func(node: Node) -> void:
		if node is SubViewport: warm_refs.append(weakref(node))
	node_added.connect(observe_viewport)
	var vignette := FocusVignette.new()
	vignette.ability = ability
	host.add_child(vignette)
	vignette.set_process(false)
	var rect := vignette.get("_rect") as ColorRect
	check(rect != null and not rect.visible and rect.mouse_filter == Control.MOUSE_FILTER_IGNORE,"focus real rect starts hidden and does not intercept input")
	check(float(vignette.get("_strength")) == 0.0 and Engine.time_scale == starting_scale and not ability.active,"warming does not activate focus or change game time")
	await focus_render_frames(3,gpu)
	var normal_warm_count := warm_refs.size()
	if gpu:
		var after := root.get_texture().get_image()
		check(focus_image_valid(before,root_size) and focus_image_valid(after,root_size) and Vector2i(root.get_texture().get_size()) == root_size and before.get_data() == after.get_data(),"offscreen warmup does not change any root viewport pixel")
	var live_warm := false
	for reference: WeakRef in warm_refs:
		if reference.get_ref() != null: live_warm = true
	check(not live_warm,"all observed normal warm viewports are freed after submitted frames")
	# Reference only draws the unchanged shader with independently calculated
	# uniforms. This is pixel equality, not a visual-quality or performance claim.
	var reference_layer := CanvasLayer.new()
	reference_layer.layer = vignette.layer
	host.add_child(reference_layer)
	var reference_rect := ColorRect.new()
	reference_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reference_material := ShaderMaterial.new()
	reference_material.shader = preload("res://shaders/focus_vignette.gdshader")
	reference_rect.material = reference_material
	reference_layer.add_child(reference_rect)
	reference_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reference_layer.hide()
	var expected := 0.0
	ability.advance(0.01,false,true)
	check(ability.active and is_equal_approx(Engine.time_scale,starting_scale*ability.tuning.focus_time_scale),"public actual ability activates focus with the unchanged scale")
	for fading_out: bool in [false,true]:
		if fading_out: ability.stop()
		for delta: float in [0.003,0.009,0.018]:
			var target := 0.0 if fading_out else 1.0
			var seconds := vignette.fade_in_seconds if target > expected else vignette.fade_out_seconds
			expected = move_toward(expected,target,delta/maxf(Engine.time_scale,0.001)/maxf(seconds,0.001))
			# Deliberate deterministic sampling of presentation only. The actual
			# focus activation above came from public ability.advance/stop.
			vignette._process(delta)
			check(is_equal_approx(float(vignette.get("_strength")),expected) and rect.visible == (expected > 0.0001),"actual vignette retains original real-time fade and visibility formula")
			if gpu:
				await focus_render_frames(1,true)
				var actual_pixels := root.get_texture().get_image()
				vignette.hide()
				reference_material.set_shader_parameter("strength",expected)
				reference_material.set_shader_parameter("tint",vignette.tint)
				reference_material.set_shader_parameter("opacity",clampf(vignette.opacity,0.0,1.0))
				reference_material.set_shader_parameter("edge_width",clampf(vignette.edge_width,0.01,0.49))
				reference_rect.visible = expected > 0.0001
				reference_layer.show()
				await focus_render_frames(1,true)
				var expected_pixels := root.get_texture().get_image()
				check(focus_image_valid(actual_pixels,root_size) and focus_image_valid(expected_pixels,root_size) and Vector2i(root.get_texture().get_size()) == root_size and actual_pixels.get_data() == expected_pixels.get_data(),"actual GPU vignette equals unchanged shader at independent expected fade strength")
				if expected > 0.0001 and focus_image_valid(actual_pixels,root_size) and focus_image_valid(before,root_size):
					positive_changed = positive_changed or actual_pixels.get_data() != before.get_data()
				reference_layer.hide()
				vignette.show()
	if gpu: check(positive_changed,"positive focus strength actually changes root pixels relative to hidden baseline")
	vignette._process(1.0)
	check(not rect.visible and float(vignette.get("_strength")) == 0.0 and Engine.time_scale == starting_scale,"public focus stop and original fade return to hidden without changing restored time")
	# A real parent is removed immediately, before any process/post-draw yield.
	var cancelled_parent := Node.new()
	root.add_child(cancelled_parent)
	var cancelled := FocusVignette.new()
	cancelled.ability = ability
	cancelled_parent.add_child(cancelled)
	var cancelled_ref: WeakRef = weakref(cancelled)
	var observed_before_free := warm_refs.size()
	if gpu:
		check(normal_warm_count > 0 and observed_before_free > normal_warm_count,"candidate creates actual warm viewports for normal and immediate-free lifecycles")
	cancelled_parent.free()
	check(cancelled_ref.get_ref() == null,"freeing parent synchronously destroys vignette before first warm frame")
	await focus_render_frames(3,gpu)
	live_warm = false
	for reference: WeakRef in warm_refs:
		if reference.get_ref() != null: live_warm = true
	check(not live_warm,"no viewport survives normal completion or parent removal before warm draw")
	node_added.disconnect(observe_viewport)
	ability.stop()
	host.free()
	await focus_render_frames(2,gpu)
	check(Engine.time_scale == starting_scale,"isolated vignette fixture leaves global time unchanged for original input tests")
	ledger.append({"scope":"isolated focus presentation lifecycle","gpu_pixels":"checked" if gpu else "unverified_headless","normal_observed_viewports":normal_warm_count,"total_observed_before_cancel":observed_before_free,"private_gameplay_calls":false})
