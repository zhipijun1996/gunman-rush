class_name FoundryEncounter
extends Node2D
## Opt-in combat preview; geometry replay does not certify enemy-mode traversal.
var actors: Array[EnemyActor] = []
var spawn_records: Array = []
func setup(lab: FoundryLab) -> void:
	for module: PlatformingModule in lab.stage.modules:
		for platform: Rect2 in module.definition.platforms:
			if platform.size.x < 240: continue
			var position_world := module.position + Vector2(platform.get_center().x, platform.position.y - 16)
			var unsafe := false
			for anchor: Vector2 in lab.stage.anchors():
				if anchor.distance_to(position_world) < 150: unsafe = true
			var body := Rect2(position_world - Vector2(64, 20), Vector2(128, 40))
			for danger: Rect2 in lab.stage.danger_envelopes():
				if body.intersects(danger): unsafe = true
			if unsafe: continue
			var motor: EnemyMotor = preload("res://game/enemies/scenes/patrol_drone.tscn").instantiate()
			var actor: EnemyActor = motor.get_node("Actor")
			actor.definition = preload("res://resources/enemies/patrol_drone.tres").duplicate(true)
			actor.definition.patrol_half_width = 40
			motor.position = position_world
			add_child(motor)
			var id := StringName("foundry_enemy_%d" % actors.size())
			lab.policy.bind_damageable(id, actor.damageable, actor.health)
			var contact := DemoContactEmitter.new()
			contact.controller = lab.controller
			contact.policy = lab.policy
			contact.source_id = id
			contact.half_size = actor.definition.collision_size / 2
			motor.add_child(contact)
			actor.defeated.connect(func(_actor: EnemyActor) -> void: contact.enabled = false)
			actors.append(actor)
			spawn_records.append({"id": str(id), "module_id": str(module.definition.module_id), "position": [position_world.x, position_world.y], "definition": str(actor.definition.stable_id), "version": actor.definition.definition_version})
			break
		if actors.size() >= 3: break
