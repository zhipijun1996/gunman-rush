extends SceneTree
## A protocol integration fixture, not an authored P04 level. The explicit test
## binding uses the existing patrol component to verify the imported drop rate.
var failures := 0

class TestStore extends WorldSaveService:
	var payload := {}
	var revision := 0
	func commit(candidate: Dictionary, next_revision: int) -> bool:
		payload = candidate.duplicate(true)
		revision = next_revision
		return true
	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":payload.duplicate(true),"revision":revision}

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func ticks(count: int) -> void:
	for frame: int in count: await physics_frame

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var catalog := WorldContentCatalog.new()
	check(catalog.load_locked().ok, "locked channel loads")
	check(not catalog.load_bindings("res://tests/content_channel_bindings.json").ok, "test binding is not a formal room")
	check(catalog.load_bindings("res://tests/content_channel_bindings.json", true).ok, "explicit test binding accepted")
	var document := WorldRoomDocument.read("res://tests/content_channel_room.json")
	var expected_drop := int(catalog.enemy_drop_profile(document.content_bindings.enemy_instances.patrol.drop_profile_id).coin_each)
	var invalid := document.duplicate(true)
	invalid.content_bindings.enemy_instances.patrol.drop_profile_id = "missing.profile"
	check(not WorldContentRoomBridge.prepare(invalid, catalog).ok, "unknown drop profile rejected")
	invalid = document.duplicate(true)
	invalid.entities.patrol.definition_id = "enemy.chime_target"
	check(not WorldContentRoomBridge.prepare(invalid, catalog).ok, "unmapped species rejected")
	await check_authored_roster(document, catalog)
	var unbound := OrdinaryRoomSession.new()
	root.add_child(unbound)
	check(unbound.open(document) == "content_catalog_required", "bound document cannot silently use default drop rules")
	unbound.free()
	var store := TestStore.new()
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var opened := session.open_content("P04", WorldContentCatalog.DEFAULT_LOCK, "res://tests/content_channel_bindings.json", store, true)
	check(opened.is_empty(), "content-bound actual room opens: " + opened)
	if not opened.is_empty():
		session.free()
		quit(1)
		return
	check(session.content_enemy_gold.patrol == expected_drop, "enemy amount comes from source bundle")
	check(session.content_catalog.bundle_sha256 == catalog.bundle_sha256, "session pins catalog identity")
	var cloned := WorldRoomDocument.instantiate(document)
	var packed := PackedScene.new()
	check(packed.pack(cloned.room) == OK, "bound document packs")
	cloned.room.free()
	var extracted := WorldRoomDocument.extract(packed)
	check(extracted.get("content_bindings") == document.content_bindings, "editor round trip preserves content references")
	await ticks(4)
	session.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
	await ticks(36)
	check(session.room.element_runtime.nodes.gate.active, "real shot opens gate")
	var actor: EnemyActor = session.room.enemies.patrol
	session.player.reset_at(actor.motor.position - Vector2(72, 0))
	await ticks(4)
	session.controller.router.request_action(&"shoot_release", (actor.motor.position-session.player.position-Vector2(0,-6)).normalized())
	await ticks(32)
	check(actor.health.terminal, "real projectile defeats bound enemy")
	var available := int(session.services.ledger().gold)
	for drop: Dictionary in session.services.ledger().drops.values(): available += int(drop.amount)
	check(available == expected_drop, "defeat generates only the imported per-enemy amount")
	for step: int in 150:
		if session.services.ledger().gold == expected_drop: break
		for pickup: Dictionary in session.room.loot.pickups:
			if not pickup.claimed:
				session.player.reset_at(pickup.position)
				break
		await ticks(1)
	check(session.services.ledger().gold == expected_drop, "physical pickup credits imported amount once")
	await ticks(12)
	check(session.services.ledger().gold == expected_drop, "no group completion bonus duplicates the drop")
	var identity := str(session.state.content.data.content_version)
	check(await session.audio_service.shutdown(), "content room audio released")
	session.free()
	var restored := OrdinaryRoomSession.new()
	root.add_child(restored)
	opened = restored.open_content("P04", WorldContentCatalog.DEFAULT_LOCK, "res://tests/content_channel_bindings.json", store, true)
	check(opened.is_empty(), "same pinned room restores")
	if opened.is_empty():
		check(restored.state.content.data.content_version == identity, "save identity includes the same content package")
		check(restored.services.ledger().gold == expected_drop and restored.room.enemies.patrol.health.terminal, "restore preserves gold and defeated enemy")
		check(await restored.audio_service.shutdown(), "restored audio released")
	restored.free()
	var different := TestStore.new()
	different.payload = store.payload.duplicate(true)
	different.payload.content_version = "different_content_package"
	different.revision = store.revision
	var before := different.payload.duplicate(true)
	var incompatible := OrdinaryRoomSession.new()
	root.add_child(incompatible)
	opened = incompatible.open_content("P04", WorldContentCatalog.DEFAULT_LOCK, "res://tests/content_channel_bindings.json", different, true)
	check(opened == "room_content_save_version_mismatch", "different content save is not silently reinterpreted")
	check(different.payload == before and different.revision == store.revision, "rejected save is unchanged")
	incompatible.free()
	print("CONTENT CHANNEL ROOM failures=", failures)
	quit(1 if failures else 0)

func check_authored_roster(document: Dictionary, catalog: WorldContentCatalog) -> void:
	var original := WorldContentRoomBridge.prepare(document, catalog)
	check(original.ok, "baseline explicit bindings accepted")
	if not original.ok: return
	var planned_species := {}
	for group: Dictionary in original.room_context.enemy_groups:
		for enemy: Dictionary in group.enemies: planned_species[enemy.species_id] = true
	var foreign_profile: Dictionary = {}
	for profile: Dictionary in catalog.table("enemy_drop_profiles").rows:
		if not planned_species.has(profile.species_id):
			foreign_profile = profile
			break
	check(not foreign_profile.is_empty(), "fixture has a registered species outside this room's candidate groups")
	if foreign_profile.is_empty(): return
	var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/content_channel_bindings.json"))
	# This alias exists only in a test binding; it does not declare the final art or AI.
	bindings.enemy_species[foreign_profile.species_id] = {"definition_id":"enemy.patrol"}
	var path := "user://content_channel_roster_bindings.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(bindings))
	file.close()
	var author_catalog := WorldContentCatalog.new()
	check(author_catalog.load_locked().ok and author_catalog.load_bindings(path, true).ok, "explicit test species binding loads")
	var edited := document.duplicate(true)
	var target_count := maxi(3, int(original.room_context.enemy_budget_review.planned_enemy_count) + 1)
	var expected_total := int(original.enemy_gold.patrol)
	for index: int in range(1, target_count):
		var id := "patrol_" + str(index)
		var entity: Dictionary = document.entities.patrol.duplicate(true)
		entity.id = id
		entity.properties.id = id
		entity.properties.point = [516 + index * 48, 366]
		edited.entities[id] = entity
		edited.content_bindings.enemy_instances[id] = {"species_id":foreign_profile.species_id,"drop_profile_id":foreign_profile.id}
		expected_total += int(foreign_profile.coin_each)
	var accepted := WorldContentRoomBridge.prepare(edited, author_catalog)
	check(accepted.ok, "extra enemies and an unrelated registered species are allowed")
	if accepted.ok:
		var budget: Dictionary = accepted.room_context.enemy_budget_review
		check(budget.authored_enemy_count == target_count and budget.count_delta > 0, "candidate count is advisory")
		check(budget.authored_coin_total == expected_total and budget.coin_delta == expected_total - budget.planned_coin_total, "budget difference reports actual authored drops")
	var invalid := document.duplicate(true)
	invalid.content_bindings.enemy_instances.patrol.drop_profile_id = foreign_profile.id
	check(not WorldContentRoomBridge.prepare(invalid, author_catalog).ok, "profile must match its species")
	var empty := document.duplicate(true)
	empty.entities.erase("patrol")
	empty.content_bindings.enemy_instances.clear()
	check(WorldContentRoomBridge.prepare(empty, author_catalog).ok, "room author may remove all candidate enemies")
	var unsupported := document.duplicate(true)
	unsupported.entities.local_reward = {"id":"local_reward","definition_id":"equipment.reward","definition_version":1,"properties":{}}
	check(WorldContentRoomBridge.prepare(unsupported, author_catalog).get("error", "").begins_with("content_reward_binding_unsupported"), "unadapted local reward cannot bypass imported purchase rules")
	var authored := OrdinaryRoomSession.new()
	root.add_child(authored)
	var error := authored.open(edited, null, null, author_catalog)
	check(error.is_empty(), "real room opens with changed roster and count: " + error)
	if error.is_empty():
		check(authored.room.enemies.size() == target_count, "actual actors follow room document")
		await ticks(2)
		check(await authored.audio_service.shutdown(), "edited room audio released")
	authored.free()
	DirAccess.remove_absolute(path)
