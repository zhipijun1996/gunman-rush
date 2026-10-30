extends RefCounted
## Fixed delivery consumer. No original PackedScene is instantiated.
const IDENTITY = preload("res://scripts/mapgen/delivery_identity.gd")
const ROOT = IDENTITY.ROOT
const MANIFEST_SHA256 = IDENTITY.MANIFEST_SHA256
const SEAL = preload("res://scripts/mapgen/gear_seal.gd")
const ADAPTERS = {
	"module_loader-17439d47c98c.gd": preload("res://scripts/mapgen/adapters/module_loader.gd"),
	"module_loader_ideas_v2-14f1ba7244c3.gd": preload("res://scripts/mapgen/adapters/module_loader_ideas_v2.gd"),
	"module_loader_review_air_v1-8a5d8fb0ad55.gd": preload("res://scripts/mapgen/adapters/module_loader_review_air_v1.gd"),
	"module_loader_review_first30_v2-68914af37f2b.gd": preload("res://scripts/mapgen/adapters/module_loader_review_first30_v2.gd"),
	"module_loader_review_refresh_v2-ce8c7ffc86d7.gd": preload("res://scripts/mapgen/adapters/module_loader_review_refresh_v2.gd"),
	"module_loader_revision058_v3-604c78fe2c16.gd": preload("res://scripts/mapgen/adapters/module_loader_revision058_v3.gd"),
	"module_loader_revision059_v2-a30ecc5d56af.gd": preload("res://scripts/mapgen/adapters/module_loader_revision059_v2.gd"),
	"module_loader_revision060_v1-8364160d1204.gd": preload("res://scripts/mapgen/adapters/module_loader_revision060_v1.gd"),
	"module_loader_revision061_v2-daa7e5eceb9f.gd": preload("res://scripts/mapgen/adapters/module_loader_revision061_v2.gd"),
	"module_loader_v3-1d72f57d63dd.gd": preload("res://scripts/mapgen/adapters/module_loader_v3.gd"),
	"module_loader_v5-23b4208b9323.gd": preload("res://scripts/mapgen/adapters/module_loader_v5.gd"),
}
var manifest: Dictionary = {}
var map_data: Dictionary = {}
var catalog: Dictionary = {}
var instances: Dictionary = {}
var receipts: Array[Dictionary] = []
var _policies: Dictionary = {}
var _bindings: Dictionary = {}
var _saved_states: Dictionary = {}
const SAW_STATE_FIELDS = ["enabled", "_previous_saw", "_previous_actor", "_actor_epoch", "_touching", "_exposure", "_pulse", "_next_pulse"]
const CONTACT_STATE_FIELDS = ["enabled", "_was_touching", "_exposure", "_pulse", "_next_pulse", "_last_actor_epoch", "_previous_relative"]

func open_delivery() -> Dictionary:
	if not instances.is_empty(): return _failure("live_map_already_open")
	if FileAccess.get_sha256(ROOT.path_join("manifest.json")) != MANIFEST_SHA256:
		return _failure("delivery_manifest_sha256_mismatch")
	manifest = _read("manifest.json")
	if manifest.get("schema") != "mapgen/delivery-manifest/v1" or manifest.get("version") != "0.1.0":
		return _failure("unsupported_delivery_schema")
	# Verify every pinned source, not a rewritten module hash or scene variable.
	for path: String in manifest.files:
		if FileAccess.get_sha256(ROOT.path_join(path)) != manifest.files[path]:
			return _failure("delivery_file_sha256_mismatch/" + path)
	map_data = _read(manifest.map_ref)
	if map_data.get("schema") != "mapgen/runtime-map/v1" or map_data.get("seed") != 930001:
		return _failure("unsupported_fixed_map")
	catalog = _read("module_pack/catalog.json")
	return {"ok": true, "map_id": map_data.map_id, "seed": map_data.seed, "files_checked": manifest.files.size()}

func instantiate_materialized(spec: Dictionary, parent: Node2D, player: PlayerController, services: Dictionary, run_id: String) -> Dictionary:
	if run_id.is_empty() or instances.has(spec.id): return _failure("empty_run_or_duplicate_instance/" + str(spec.id))
	if not services.has_all(["policy", "lifetime", "wallet"]): return _failure("explicit_shared_host_services_required")
	var identity := run_id + "/" + str(map_data.map_id) + "/" + str(spec.id)
	var saved: Dictionary = _saved_states.get(identity, {})
	if not saved.is_empty():
		if saved.lifetime != services.lifetime or saved.wallet != services.wallet or saved.player_id != player.get_instance_id() or not services.lifetime.active or saved.run_epoch != services.lifetime.epoch or saved.stage_epoch != services.lifetime.stage_epoch:
			return _failure("saved_instance_scope_mismatch/" + str(spec.id))
		if saved.module_id != spec.module_id or saved.content_version != spec.content_version or saved.origin_pixels != Vector2(spec.origin_blocks[0], spec.origin_blocks[1]) * 128:
			return _failure("saved_instance_content_mismatch/" + str(spec.id))
	if not spec.transform.content_is_materialized: return _failure("materialized_content_required")
	if not parent.global_transform.is_equal_approx(Transform2D.IDENTITY): return _failure("map_root_must_be_world_identity")
	var entry: Dictionary = {}
	for candidate: Dictionary in catalog.modules:
		if candidate.id == spec.module_id: entry = candidate; break
	if entry.is_empty() or entry.contentVersion != spec.content_version: return _failure("module_content_version_mismatch/" + str(spec.id))
	var packed := load(ROOT.path_join(spec.source_scene_ref)) as PackedScene
	if packed == null: return _failure("source_behavior_scene_unreadable/" + str(spec.id))
	# Inspect the source script only; do not instantiate its original terrain.
	var state := packed.get_state()
	var native_script: Script
	for index: int in state.get_node_property_count(0):
		if state.get_node_property_name(0, index) == &"script": native_script = state.get_node_property_value(0, index)
	if native_script == null or not ADAPTERS.has(native_script.resource_path.get_file()):
		return _failure("unsupported_native_behavior/" + str(spec.id) + "/" + str(spec.module_id))
	var content := _read(spec.content_ref)
	var instance: Node2D = ADAPTERS[native_script.resource_path.get_file()].new()
	instance.name = spec.id
	instance.materialized_content = content
	instance.position = Vector2(spec.origin_blocks[0], spec.origin_blocks[1]) * 128
	if not saved.is_empty() and saved.native_reward_state.get("claimed", false):
		if not instance.has_method("provide_saved_state") or not instance.provide_saved_state(saved.native_reward_state):
			instance.free()
			return _failure("native_reward_restore_rejected/" + str(spec.id))
	parent.add_child(instance)
	if not instance.setup_error.is_empty():
		var reason: String = instance.setup_error
		instance.free()
		return _failure(str(spec.id) + "/" + str(spec.module_id) + "/" + reason)
	for closure: Dictionary in spec.seals:
		var seal := SEAL.new()
		seal.configure(closure)
		instance.add_child(seal)
	var args: Array = [player, services.policy, services.lifetime, services.wallet, null, identity]
	for method: Dictionary in instance.get_method_list():
		if method.name == "bind_player" and method.args.size() > 6:
			args.append(services.get("meta")); args.append(services.get("region_state")); break
	var bound: Dictionary = instance.callv("bind_player", args)
	if not bound.get("ok", false):
		instance.free()
		return _failure(str(spec.id) + "/" + str(spec.module_id) + "/" + str(bound.get("reason", "bind_failed")))
	if not saved.is_empty():
		var restored := _restore_saved_state(instance, saved)
		if not restored.ok:
			instance.free()
			return restored
	# Native consumer helpers inherit DemoApp's global menu input but do not
	# construct its outer menu. The map owns that input; chest modals retain UI.
	if instance.get("original_pickups") != null:
		instance.original_pickups.app.set_process_input(false)
	if instance.get("original_region_chests") != null:
		instance.original_region_chests.app.set_process_input(false)
	instances[spec.id] = instance
	_policies[spec.id] = services.policy
	_bindings[spec.id] = {"identity":identity, "module_id":spec.module_id, "content_version":spec.content_version, "origin_pixels":instance.position, "lifetime":services.lifetime, "wallet":services.wallet, "player_id":player.get_instance_id()}
	instance.tree_exiting.connect(_release_identity.bind(str(spec.id), identity))
	var receipt := {"ok": true, "instance_id": spec.id, "module_id": spec.module_id, "identity": identity, "origin_pixels": [instance.position.x, instance.position.y], "terrain_count": content.platforms.size(), "seals": spec.seals.size(), "enemies": content.enemies.size(), "rewards": content.reward_sites.size(), "player_spawned": false, "resources_reset": false, "same_run_state_restored":not saved.is_empty()}
	receipts.append(receipt)
	return receipt

func unload(instance_id: String) -> Dictionary:
	var instance: Variant = instances.get(instance_id)
	if not is_instance_valid(instance): return _failure("instance_not_loaded/" + instance_id)
	if instance.is_queued_for_deletion(): return _failure("instance_unload_pending/" + instance_id)
	var scope_error := _unsupported_reload_scope(instance)
	# The fixed map has no streaming requirement. Keep unsupported consumers live
	# rather than erasing enemy/complex mechanism/Boss state on a later rebuild.
	if not scope_error.is_empty(): return _failure("unload_rejected_state_not_serializable/" + instance_id + "/" + scope_error)
	var binding: Dictionary = _bindings[instance_id]
	if not binding.lifetime.active: return _failure("unload_rejected_inactive_run/" + instance_id)
	var saved := binding.duplicate()
	saved.run_epoch = binding.lifetime.epoch
	saved.stage_epoch = binding.lifetime.stage_epoch
	saved.native_reward_state = instance.export_saved_state() if instance.has_method("export_saved_state") else {}
	saved.rewards = {}
	for reward_id: String in instance.rewards.services:
		var reward: SimpleRoomReward = instance.rewards.services[reward_id]
		saved.rewards[reward_id] = {"claimed":reward.claimed, "stable_id":str(reward._definition.stable_id), "receipts":reward._receipts.duplicate(true)}
	saved.module_clock = instance.module.clock
	saved.saws = {}
	for saw: ModuleSawHazard in instance.module.hazards:
		saved.saws[str(saw.definition.source_id)] = _capture_fields(saw, SAW_STATE_FIELDS)
	saved.contacts = {}
	for emitter: DemoContactEmitter in _contacts(instance):
		saved.contacts[str(emitter.source_id)] = _capture_fields(emitter, CONTACT_STATE_FIELDS)
	_saved_states[binding.identity] = saved
	instance.queue_free()
	return {"ok":true, "identity":binding.identity, "same_run_state_saved":true, "native_reward_claimed":saved.native_reward_state.get("claimed", false)}

func _unsupported_reload_scope(instance: Node2D) -> String:
	var content: Dictionary = instance.content
	if str(content.stable_id) == "game-plains-boss-arena": return "boss_lifecycle"
	for field: String in ["enemies", "moving_platforms", "hooks", "latches", "original_pickups", "original_region_chests"]:
		if not content.get(field, []).is_empty(): return field
	# Only these authored reward consumers have a complete bounded restore path.
	for field: String in content:
		if field.ends_with("_cells") and field != "approved_hq_cells" and not content[field].is_empty(): return field
	for cell: Dictionary in content.get("approved_hq_cells", []):
		if cell.get("kind") != "reward_pair": return "approved_hq_cells/" + str(cell.get("kind"))
	if not content.get("approved_hq_cells", []).is_empty() and not str(content.stable_id).contains("hq04"):
		return "native_reward_restore_module_scope"
	return ""

func _restore_saved_state(instance: Node2D, saved: Dictionary) -> Dictionary:
	instance.module.clock = saved.module_clock
	for saw: ModuleSawHazard in instance.module.hazards:
		var key := str(saw.definition.source_id)
		if not saved.saws.has(key): return _failure("saved_saw_identity_mismatch/" + key)
		for field: String in SAW_STATE_FIELDS: saw.set(field, saved.saws[key][field])
		saw.position = saw.definition.at_time(instance.module.clock)
		saw.rotation = TAU * (instance.module.clock / saw.definition.period + saw.definition.initial_phase)
	for emitter: DemoContactEmitter in _contacts(instance):
		var key := str(emitter.source_id)
		if not saved.contacts.has(key): return _failure("saved_contact_identity_mismatch/" + key)
		for field: String in CONTACT_STATE_FIELDS: emitter.set(field, saved.contacts[key][field])
	for reward_id: String in saved.rewards:
		var state: Dictionary = saved.rewards[reward_id]
		if not instance.rewards.services.has(reward_id):
			# Native HQ restore intentionally suppresses fresh reward services and
			# recreates the claimed chest presentation plus its persisted pair.
			if state.claimed and saved.native_reward_state.get("claimed", false): continue
			return _failure("saved_reward_service_missing/" + reward_id)
		var reward: SimpleRoomReward = instance.rewards.services[reward_id]
		if str(reward._definition.stable_id) != state.stable_id: return _failure("saved_reward_identity_mismatch/" + reward_id)
		# Trusted registry-owned state, same live wallet/lifetime and exact scope.
		# No grant, claim call or committed signal is replayed during restoration.
		reward._claimed = bool(state.claimed)
		reward._receipts = state.receipts.duplicate(true)
		for spec: Dictionary in instance.rewards.specs:
			if str(spec.id) == reward_id:
				UnderworldObjects.place_chest(instance.rewards.sprites[reward_id], Vector2(spec.position[0], spec.position[1] + 18), reward.claimed)
	return {"ok":true}

func _capture_fields(object: Object, fields: Array) -> Dictionary:
	var state: Dictionary = {}
	for field: String in fields: state[field] = object.get(field)
	return state

func _contacts(node: Node) -> Array[DemoContactEmitter]:
	var result: Array[DemoContactEmitter] = []
	for child: Node in node.get_children():
		if child is DemoContactEmitter: result.append(child)
		result.append_array(_contacts(child))
	return result

func _release_identity(instance_id: String, identity: String) -> void:
	var policy: FrameDamagePolicy = _policies.get(instance_id)
	var prefix := "module/" + identity.uri_encode() + "/"
	if is_instance_valid(policy):
		for key: Variant in policy._targets.keys():
			if str(key).begins_with(prefix): policy._targets.erase(key)
		policy._queue = policy._queue.filter(func(request: DamageRequest) -> bool: return not str(request.target_id).begins_with(prefix) and not str(request.source_id).begins_with(prefix))
		for key: Variant in policy._seen.keys():
			if str(key).begins_with(prefix) or str(key).contains("/" + prefix): policy._seen.erase(key)
	_policies.erase(instance_id)
	_bindings.erase(instance_id)
	instances.erase(instance_id)

func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT.path_join(path)))
	return parsed if parsed is Dictionary else {}

func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
