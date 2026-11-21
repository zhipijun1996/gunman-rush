class_name EnemyFactory
extends RefCounted
## Gameplay construction only: returns an unparented Motor. Caller retains
## placement, encounter binding and the explicit presentation/style installer.
const INSTANCE_FIELDS := [&"patrol_half_width",&"aerial",&"dive_depth",&"initial_direction",&"patrol_speed"]
static func scene_path_for_behavior(behavior: StringName) -> String:
	return EnemyBehaviorRegistry.scene_path(behavior)

static func definition_path_for_behavior(behavior: StringName, revision: String = "") -> String:
	return EnemyBehaviorRegistry.definition_path(behavior,revision)

static func override_error(overrides: Dictionary) -> String:
	for raw: Variant in overrides:
		if not raw is String and not raw is StringName: return "invalid_override_key"
		var key := StringName(raw)
		if key not in INSTANCE_FIELDS: return "unsupported_instance_override:" + String(key)
		var value: Variant = overrides[raw]
		if key == &"aerial":
			if not value is bool: return "invalid_aerial_override"
		elif key == &"initial_direction":
			if not value is int or value not in [-1,1]: return "invalid_direction_override"
		elif not (value is int or value is float) or not is_finite(float(value)) or float(value)<0.0:
			return "invalid_numeric_override:" + String(key)
	return ""

static func definition_for_behavior(behavior: StringName, overrides: Dictionary = {}, revision: String = "") -> EnemyDefinition:
	var path := definition_path_for_behavior(behavior,revision)
	if path.is_empty() or not override_error(overrides).is_empty(): return null
	var original := load(path) as EnemyDefinition
	if original == null: return null
	var definition := original.duplicate(true) as EnemyDefinition
	# External .tres references are not necessarily detached by duplicate(true).
	# The factory returns mutable instance configuration; isolate HealthDefinition
	# explicitly just as for inline forest health, without changing any values.
	if original.health_definition != null:
		definition.health_definition = original.health_definition.duplicate(true) as HealthDefinition
	for key: Variant in overrides: definition.set(key,overrides[key])
	return definition if definition.is_valid() else null

static func create_for_behavior(behavior: StringName, overrides: Dictionary = {}, revision: String = "") -> EnemyMotor:
	var definition := definition_for_behavior(behavior,overrides,revision)
	var path := scene_path_for_behavior(behavior)
	if definition == null or path.is_empty(): return null
	var scene := load(path) as PackedScene
	if scene == null: return null
	var motor := scene.instantiate() as EnemyMotor
	if motor == null: return null
	var actor := motor.get_node_or_null("Actor") as EnemyActor
	if actor == null:
		motor.free()
		return null
	actor.definition = definition
	return motor
