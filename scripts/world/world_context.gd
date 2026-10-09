class_name WorldContext
extends Node

signal respawned
signal checkpoint_changed(location: Vector2)
var session_id := 0
var clock := 0.0
var actor_registry: Array[PlayerController] = []
var objects: Array[Node] = []
var checkpoint := Vector2.ZERO
var respawn_delay := 0.15
var _remaining := -1.0

func register_actor(controller: PlayerController, spawn: Vector2) -> void:
	actor_registry.append(controller)
	controller.tree_exiting.connect(func() -> void: actor_registry.erase(controller), CONNECT_ONE_SHOT)
	checkpoint = spawn
	controller.died.connect(_on_death)

func register_object(object: Node) -> void:
	objects.append(object)
	object.tree_exiting.connect(func() -> void: objects.erase(object), CONNECT_ONE_SHOT)

func set_checkpoint(location: Vector2) -> void:
	checkpoint = location
	checkpoint_changed.emit(location)

func _physics_process(delta: float) -> void:
	clock += delta
	if _remaining >= 0.0:
		_remaining -= delta
		if _remaining <= 0.0:
			respawn()

func _on_death() -> void:
	_remaining = respawn_delay

func respawn() -> void:
	_remaining = -1.0
	session_id += 1
	clock = 0.0
	for object: Node in objects:
		if is_instance_valid(object):
			object.reset(&"life")
	for actor: PlayerController in actor_registry:
		if is_instance_valid(actor):
			actor.reset_at(checkpoint)
	respawned.emit()

func restart(spawn: Vector2) -> void:
	checkpoint = spawn
	respawn()
