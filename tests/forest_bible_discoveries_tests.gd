extends SceneTree
## Local transaction/reader contract only; no claim of Motor route admission.
const GEAR := preload("res://tests/gear_inventory_support.gd")
const READER := preload("res://scripts/world/forest_bible_discoveries.gd")
const CATALOG := preload("res://scripts/world/forest_bible_discovery_catalog.gd")
var assertions := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func frames(count := 3) -> void:
	for index: int in count: await process_frame

func wire(reader: ForestBibleDiscoveries) -> void:
	reader.opened.connect(func() -> void: paused = true)
	reader.closed.connect(func() -> void: paused = false)
	reader.confirm_requested.connect(func() -> void: paused = false)

func _rows() -> Array:
	var rows: Array = []
	for index: int in CATALOG.IDS.size():
		var id: String = CATALOG.IDS[index]
		rows.append({"id":"forest_discovery/" + id, "definition_id":id, "position":[100.0 + index * 200.0, 100.0], "area_id":"test_area", "support_id":"test_support", "approach_route":"test_out", "return_route":"test_back"})
	return rows

func _point(index: int) -> Vector2:
	return Vector2(100.0 + index * 200.0, 100.0)

func _confirm(reader: ForestBibleDiscoveries) -> void:
	await frames()
	var button: Button = reader._confirm
	check(button != null and button.is_visible_in_tree(), "actual reader confirm button is visible")
	if button == null: return
	var presses: Array = []
	button.pressed.connect(func() -> void: presses.append(true))
	var point := button.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(point), "real confirm hit center lies inside viewport")
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	Input.parse_input_event(move)
	for pressed: bool in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = point
		mouse.global_position = point
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		Input.parse_input_event(mouse)
		await frames(2)
	check(presses.size() == 1, "actual native mouse press/release reaches the intended confirm button exactly once")

func run() -> void:
	root.size = Vector2i(960, 540)
	# Input.parse_input_event is window-coordinate input. Keep this reduced-size
	# UI fixture at 1:1 rather than inheriting the project's 1280x720 stretch.
	root.content_scale_size = Vector2i(960, 540)
	print("FOREST READER VIEWPORT ", JSON.stringify({"window_size":[root.size.x, root.size.y], "content_scale_size":[root.content_scale_size.x, root.content_scale_size.y]}))
	var tree: SceneTree = self
	var fixture := preload("res://tests/combat_tests.gd").new()
	fixture.tree = tree
	await fixture.fixture()
	var health: HealthState = fixture.controller.actor_resources.health
	var lifetime := DemoLifetime.new()
	var wallet := RunWallet.new()
	var build := BuildState.new()
	build.configure(fixture.controller, lifetime)
	var rewards := RewardService.new()
	rewards.configure(lifetime, build)
	var state := PlainsRegionState.new()
	state.bind_map("forest_discovery_test_map")
	var reader := READER.new()
	fixture.world.add_child(reader)
	wire(reader)
	check(reader.configure(_rows(), state, lifetime, health, wallet, rewards), "forest reader binds existing run state and services")
	check(not reader.configure(_rows(), state, lifetime, health, wallet, rewards), "reader reconfigure cannot reset discovery claims")
	var bad := _rows()
	bad.append(bad[0].duplicate(true))
	check(not CATALOG.valid_rows(bad), "duplicate discovery source rejected")
	bad = _rows(); bad[0].return_route = bad[0].approach_route
	check(not CATALOG.valid_rows(bad), "same-route reward excursion rejected at local row boundary")
	bad = _rows(); bad[0].position[0] = NAN
	check(not CATALOG.valid_rows(bad), "nonfinite discovery point rejected")
	bad = _rows(); bad[0].definition_id = "not_a_discovery"
	check(not CATALOG.valid_rows(bad) and not CATALOG.valid_rows([]), "unknown definitions and empty discovery setups are rejected")
	check(reader.nearby(Vector2(NAN, 0)).is_empty() and not reader.interact(Vector2(-9999, -9999), lifetime.token()), "nonfinite and remote points cannot open discoveries")
	for pair: Array in [["old_badge", "field_medic"], ["spiral_core", "region_damage_purple"]]:
		var equipment: ItemDefinition = CATALOG.item(pair[0])
		var existing := load("res://resources/items/%s.tres" % pair[1]) as ItemDefinition
		check(equipment.is_valid() and equipment.rarity == existing.rarity and equipment.stack_limit == existing.stack_limit and equipment.icon_key == existing.icon_key, "new forest item reuses existing rarity, stacking and icon")
		check(equipment.modifiers.size() == 1 and equipment.modifiers[0].stat_id == existing.modifiers[0].stat_id and equipment.modifiers[0].value == existing.modifiers[0].value and equipment.modifiers[0].operation == existing.modifiers[0].operation, "new item keeps the established legal effect and numerical value")
	var kinds: Array = []
	for id: String in CATALOG.IDS: kinds.append(CATALOG.definition(id).kind)
	check(kinds == ["coin", "heart", "item", "item", "story", "story"], "six Bible finds carry four distinct benefits and two readable fragments")
	var events: Array = []
	var requests: Array = []
	reader.acquired.connect(func(receipt: Dictionary) -> void: events.append(receipt))
	reader.confirm_requested.connect(func() -> void: requests.append(true))
	check(not reader.commit_pending(_point(4)) and state.claimed.is_empty(), "bare story commit cannot substitute for reading")
	check(reader.interact(_point(4), lifetime.token()), "letter opens through actual reader UI")
	await tree.process_frame
	check(paused and reader._body.is_visible_in_tree() and reader._body.text == CATALOG.definition("unsent_letter").text, "actual visible Label contains the full optional letter")
	check(not reader.commit_pending(_point(4)) and state.claimed.is_empty(), "opening a page alone does not count as obtaining story")
	reader._body.text = "replaced"
	await _confirm(reader)
	check(not reader.commit_pending(_point(4)) and state.claimed.is_empty(), "replaced story text cannot be marked read")
	reader.interact(_point(4), lifetime.token())
	await tree.process_frame
	var request_count := requests.size()
	await _confirm(reader); reader._request_confirmation()
	check(reader.commit_pending(_point(4)) and not reader.commit_pending(_point(4)) and requests.size() == request_count + 1 and events.size() == 1, "same-frame duplicate confirm creates one acquisition")
	check(state.claimed.has("forest_discovery/unsent_letter") and events[0].story_read and wallet.balance == 0, "story confirmation shares claimed ledger and creates no money")
	reader.interact(_point(4), lifetime.token()); await _confirm(reader)
	check(events.size() == 1 and not reader.is_open(), "repeat reading closes without acquiring or rewarding again")
	reader.interact(_point(0), lifetime.token())
	await tree.process_frame
	await _confirm(reader)
	check(not paused and reader.commit_pending(_point(0)) and wallet.balance == 10, "voiceless bell grants real run coins once")
	reader.interact(_point(0), lifetime.token()); await _confirm(reader)
	check(wallet.balance == 10, "repeat bell cannot grant again")
	reader.interact(_point(1), lifetime.token())
	await tree.process_frame
	await _confirm(reader)
	check(paused and not reader.commit_pending(_point(1)) and not state.claimed.has("forest_discovery/root_cache"), "full-health supplies stay unclaimed for return")
	reader.close()
	health.apply_damage(ActorResourceRequest.new(&"discovery_heal_setup", health.epoch, 3.0, health.get_instance_id()))
	var current_before := health.current
	reader.interact(_point(1), lifetime.token())
	await tree.process_frame
	await _confirm(reader)
	check(reader.commit_pending(_point(1)) and is_equal_approx(health.current, current_before + 2.0), "root cache applies current-health healing through SupplyHealEffect")
	var max_before := health.capacity
	current_before = health.current
	var jumps_before: int = fixture.motor.tuning.max_jumps
	var shots_before: int = fixture.motor.tuning.max_air_shots
	reader.interact(_point(2), lifetime.token())
	await tree.process_frame
	await _confirm(reader)
	lifetime.invalidate_actor()
	check(not reader.commit_pending(_point(2)) and build.count_item(&"forest_old_badge") == 0 and not state.claimed.has("forest_discovery/old_badge"), "stale actor cancels pending badge without partial item grant")
	reader.interact(_point(2), lifetime.token())
	await frames()
	lifetime.invalidate_actor()
	await frames()
	check(not reader.is_open() and not paused and build.count_item(&"forest_old_badge") == 0, "stale actor automatically closes a paused reader without needing commit")
	reader.interact(_point(2), lifetime.token())
	await tree.process_frame
	await _confirm(reader)
	check(reader.commit_pending(_point(2)) and health.capacity == max_before and build.count_item(&"forest_old_badge") == 1, "old badge first enters the backpack without automatic effects")
	check(GEAR.equip_all(build) and is_equal_approx(health.capacity, max_before + 2.0) and health.current == current_before, "old badge uses actual modifier with no implicit heal")
	var damage_before: float = fixture.motor.tuning.projectile_damage
	reader.interact(_point(3), lifetime.token())
	await tree.process_frame
	await _confirm(reader)
	check(reader.commit_pending(_point(3)) and fixture.motor.tuning.projectile_damage == damage_before, "spiral core ownership does not change projectile damage")
	check(GEAR.equip_all(build) and is_equal_approx(fixture.motor.tuning.projectile_damage, damage_before + 1.5), "spiral core increases real projectile damage")
	check(fixture.motor.tuning.max_jumps == jumps_before and fixture.motor.tuning.max_air_shots == shots_before, "discovery equipment grants no extra jumps or shots")
	for id: String in ["forest_old_badge", "forest_spiral_core"]:
		var item := load("res://resources/items/%s.tres" % id) as ItemDefinition
		for modifier: BuildModifier in item.modifiers:
			check(modifier.stat_id in [&"max_health", &"projectile_damage"], "forest discovery modifier cannot grant unearned movement abilities")
	reader.interact(_point(5), lifetime.token())
	await _confirm(reader)
	check(not reader.commit_pending(_point(5) + Vector2(300, 0)) and not state.claimed.has("forest_discovery/branch_ring_map"), "moving away before queued commit cancels the claim")
	reader.interact(_point(5), lifetime.token())
	await frames()
	reader._root.hide()
	reader._request_confirmation()
	check(not reader.commit_pending(_point(5)) and not state.claimed.has("forest_discovery/branch_ring_map"), "hidden reading page cannot grant a story discovery")
	reader.interact(_point(5), lifetime.token())
	await tree.process_frame
	await _confirm(reader); reader.close()
	check(not reader.commit_pending(_point(5)) and not state.claimed.has("forest_discovery/branch_ring_map"), "closing page cancels uncommitted story")
	reader.interact(_point(5), lifetime.token())
	await tree.process_frame
	await _confirm(reader)
	reader.free()
	check(not state.claimed.has("forest_discovery/branch_ring_map"), "destroying reader cannot claim queued story")
	var restored := PlainsRegionState.new()
	check(restored.restore(state.snapshot(), state.manifest_hash), "existing region snapshot restores discovery ledger without schema changes")
	var restored_reader := READER.new()
	fixture.world.add_child(restored_reader)
	wire(restored_reader)
	check(restored_reader.configure(_rows(), restored, lifetime, health, wallet, rewards), "new reader consumes restored claimed ledger")
	restored_reader.interact(_point(0), lifetime.token()); await _confirm(restored_reader)
	check(wallet.balance == 10 and restored_reader.is_claimed("forest_discovery/voiceless_bell"), "unload/restore cannot grant claimed bell again")
	restored_reader.interact(_point(5), lifetime.token())
	await _confirm(restored_reader)
	check(restored_reader.commit_pending(_point(5)) and restored.claimed.size() == 6, "second real readable fragment completes six separate map-local claims")
	# A different map can reject a full item stack without consuming its source.
	var rejected_state := PlainsRegionState.new()
	rejected_state.bind_map("stack_limit_map")
	var rejected_reader := READER.new()
	fixture.world.add_child(rejected_reader)
	wire(rejected_reader)
	var badge := CATALOG.item("old_badge")
	check(build.add_item(&"stack_limit_setup", badge), "existing build can reach the declared item stack limit")
	check(rejected_reader.configure(_rows(), rejected_state, lifetime, health, wallet, rewards), "second map reader binds shared build without resetting it")
	var capacity_at_limit := health.capacity
	rejected_reader.interact(_point(2), lifetime.token())
	await _confirm(rejected_reader)
	check(not rejected_reader.commit_pending(_point(2)) and rejected_reader.is_open() and paused and rejected_state.claimed.is_empty() and health.capacity == capacity_at_limit, "rejected item grant keeps page paused and source unclaimed without partial effects")
	# This isolated fixture clears ownership explicitly; normal unequip never frees a holding limit.
	check(build.clear() and build.inventory.instances().is_empty(), "isolated ownership reset releases the temporary full-stack setup")
	await _confirm(rejected_reader)
	check(rejected_reader.commit_pending(_point(2)) and rejected_state.claimed.has("forest_discovery/old_badge"), "failed item can be retried when build becomes legal")
	rejected_reader.interact(_point(4), lifetime.token())
	await _confirm(rejected_reader)
	health.apply_damage(ActorResourceRequest.new(&"discovery_fatal", health.epoch, 999.0, health.get_instance_id()))
	check(not rejected_reader.commit_pending(_point(4)) and not rejected_state.claimed.has("forest_discovery/unsent_letter"), "same-frame terminal actor wins over queued story acquisition")
	restored_reader.close()
	rejected_reader.close()
	check(not paused, "closing/death restores app pause ownership")
	check(await preload("res://tests/audio_teardown.gd").drain_world(fixture.world), "discovery test fixture releases audio ownership")
	fixture.world.free()

	await frames(3)
	print("FOREST BIBLE DISCOVERIES: %d assertions, %d failures" % [assertions, failures])
	print("FOREST BIBLE DISCOVERIES CLEANUP: released=true")
	quit(0 if failures == 0 else 1)
