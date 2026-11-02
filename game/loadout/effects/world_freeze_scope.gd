class_name WorldFreezeScope
extends RefCounted
## Stops world simulation without setting the engine clock to zero. The player
## and its input/UI retain their own clock. Every changed property is restored.
var _world: WeakRef
var _player: WeakRef
var _records: Dictionary = {}
var frozen := false

func bind(world: Node, player: Node) -> void:
	var previous := _world.get_ref() as Node if _world != null else null
	var previous_player := _player.get_ref() as Node if _player != null else null
	if previous == world and previous_player == player: return
	release()
	_world = weakref(world) if is_instance_valid(world) else null
	_player = weakref(player) if is_instance_valid(player) else null

func set_frozen(value: bool) -> void:
	if not value:
		release()
		return
	var world := _world.get_ref() as Node if _world != null else null
	var player := _player.get_ref() as Node if _player != null else null
	if not is_instance_valid(world) or not is_instance_valid(player):
		release()
		return
	frozen = true
	_capture_tree(world, player)
	# Player shots and some existing Boss projectiles are siblings of Stage.
	var parent := player.get_parent()
	if is_instance_valid(parent): _capture_external(parent, world, player)

func _capture_external(node: Node, world: Node, player: Node) -> void:
	if node == player or node == world: return
	if _is_world_entity(node):
		_capture_tree(node, player)
		return
	for child: Node in node.get_children(): _capture_external(child, world, player)

func _is_world_entity(node: Node) -> bool:
	if bool(node.get_meta(&"item_v5_world_entity", false)): return true
	var script := node.get_script() as Script
	if script == null: return false
	var path := script.resource_path
	return path in ["res://game/combat/projectiles/player_projectile.gd", "res://game/combat/weapons/weapon_entity.gd", "res://game/enemies/projectiles/enemy_attack_projectile.gd", "res://game/enemies/projectiles/forest_seed_projectile.gd", "res://game/bosses/encounter/boss_projectile.gd", "res://game/bosses/thorn_forest/thorn_seed_projectile.gd", "res://game/bosses/bellstrider/bellstrider_bell_projectile.gd"]

func _capture_tree(node: Node, player: Node) -> void:
	if node == player or player.is_ancestor_of(node): return
	var key := node.get_instance_id()
	if not _records.has(key):
		var row: Dictionary = {"node":weakref(node), "mode":node.process_mode}
		if node is CollisionObject2D:
			row["disable_mode"] = (node as CollisionObject2D).disable_mode
			# Disabled simulation must not remove floors, hurtboxes or bodies.
			(node as CollisionObject2D).disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		if node is CharacterBody2D:
			row["velocity"] = (node as CharacterBody2D).velocity
			(node as CharacterBody2D).velocity = Vector2.ZERO
		if node is StaticBody2D:
			row["linear"] = (node as StaticBody2D).constant_linear_velocity
			row["angular"] = (node as StaticBody2D).constant_angular_velocity
			(node as StaticBody2D).constant_linear_velocity = Vector2.ZERO
			(node as StaticBody2D).constant_angular_velocity = 0.0
		if node is RigidBody2D:
			row["rigid_freeze"] = (node as RigidBody2D).freeze
			row["rigid_linear"] = (node as RigidBody2D).linear_velocity
			row["rigid_angular"] = (node as RigidBody2D).angular_velocity
			(node as RigidBody2D).freeze = true
		_records[key] = row
	# These observers follow the player, not world motion. Their source's
	# transform/module clock remains frozen and their own PAUSABLE mode keeps
	# pause/focus cancellation intact, without granting P06 invulnerability.
	node.process_mode = Node.PROCESS_MODE_PAUSABLE if node is DemoContactEmitter or node is ModuleSawHazard else Node.PROCESS_MODE_DISABLED
	for child: Node in node.get_children(): _capture_tree(child, player)

func advance_contacts() -> void:
	if not frozen: return
	# This explicit interface observes entry into a stationary hostile shape;
	# no projectile motion, lifetime, animation age or attack timer is advanced.
	for row: Dictionary in _records.values():
		var node := (row.node as WeakRef).get_ref() as Node
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.has_method("advance_frozen_contact"):
			node.call("advance_frozen_contact")

func release() -> void:
	for row: Dictionary in _records.values():
		var node := (row.node as WeakRef).get_ref() as Node
		if not is_instance_valid(node): continue
		node.process_mode = int(row.mode)
		if node is CollisionObject2D and row.has("disable_mode"): (node as CollisionObject2D).disable_mode = int(row.disable_mode)
		if node is CharacterBody2D and row.has("velocity"): (node as CharacterBody2D).velocity = row.velocity
		if node is StaticBody2D and row.has("linear"):
			(node as StaticBody2D).constant_linear_velocity = row.linear
			(node as StaticBody2D).constant_angular_velocity = row.angular
		if node is RigidBody2D and row.has("rigid_freeze"):
			(node as RigidBody2D).freeze = bool(row.rigid_freeze)
			(node as RigidBody2D).linear_velocity = row.rigid_linear
			(node as RigidBody2D).angular_velocity = row.rigid_angular
	_records.clear()
	frozen = false

func snapshot() -> Dictionary:
	return {"frozen":frozen, "frozen_nodes":_records.size()}
