class_name EnemyFactory
extends RefCounted
## Gameplay construction only: returns an unparented Motor. Caller retains
## placement, encounter binding and the explicit presentation/style installer.
const INSTANCE_FIELDS := [&"patrol_half_width",&"aerial",&"dive_depth",&"initial_direction",&"patrol_speed"]
const CANDIDATE_RECIPES := {
	&"candidate_lure_guard": {
		"guard":true,
		"common":{&"stable_id":&"candidate_lure_guard",&"aerial":false,&"collision_size":Vector2(32,36),&"telegraph_duration":0.8,&"attack_duration":0.65,&"recovery_duration":1.1},
		"lab":{&"patrol_half_width":120.0,&"activation_range":360.0},
		"studio":{&"patrol_half_width":100.0},
	},
	&"candidate_crosswind_moth": {
		"guard":false,
		"common":{&"stable_id":&"candidate_crosswind_moth",&"aerial":true,&"collision_size":Vector2(32,36),&"telegraph_duration":0.8,&"attack_duration":1.1,&"recovery_duration":1.1},
		"lab":{&"patrol_half_width":120.0,&"patrol_speed":45.0,&"activation_range":360.0},
		# Studio keeps sentry's original zero speed and default activation range.
		"studio":{&"patrol_half_width":100.0},
	},
}

static func scene_path_for_behavior(behavior: StringName) -> String:
	return EnemyBehaviorRegistry.scene_path(behavior)

static func definition_path_for_behavior(behavior: StringName) -> String:
	return EnemyBehaviorRegistry.definition_path(behavior)

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

static func definition_for_behavior(behavior: StringName, overrides: Dictionary = {}) -> EnemyDefinition:
	var path := definition_path_for_behavior(behavior)
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

static func create_for_behavior(behavior: StringName, overrides: Dictionary = {}) -> EnemyMotor:
	var definition := definition_for_behavior(behavior,overrides)
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

static func candidate_recipe(identity: StringName, context: StringName = &"lab") -> Dictionary:
	# Review uses the original Lab recipe; it never normalizes Studio values.
	var recipe_context := &"lab" if context == &"review" else context
	if not CANDIDATE_RECIPES.has(identity) or recipe_context not in [&"lab",&"studio"]: return {}
	var source: Dictionary = CANDIDATE_RECIPES[identity]
	var behavior := EnemyBehaviorRegistry.candidate_behavior(identity)
	var fields: Dictionary = source.common.duplicate(true)
	fields.merge(source[String(recipe_context)],true)
	return {"identity":identity,"context":context,"source_context":recipe_context,"behavior":behavior,"guard":source.guard,"definition_path":definition_path_for_behavior(behavior),"scene_path":scene_path_for_behavior(behavior),"overrides":fields,"admission":&"development_candidate"}

static func candidate_definition(identity: StringName, context: StringName = &"lab") -> EnemyDefinition:
	var recipe := candidate_recipe(identity,context)
	if recipe.is_empty(): return null
	var definition := definition_for_behavior(recipe.behavior)
	if definition == null: return null
	for key: Variant in recipe.overrides: definition.set(key,recipe.overrides[key])
	return definition if definition.is_valid() else null

static func configure_candidate(motor: EnemyMotor, identity: StringName, context: StringName = &"lab") -> bool:
	if motor == null or motor.is_inside_tree(): return false
	var recipe := candidate_recipe(identity,context)
	var definition := candidate_definition(identity,context)
	var actor := motor.get_node_or_null("Actor") as EnemyActor
	var old := motor.get_node_or_null("Damageable")
	if recipe.is_empty() or definition == null or actor == null or old == null: return false
	var receiver := load("res://scripts/enemies/prototype_enemy_damageable.gd").new() as Damageable
	receiver.set("guard",recipe.guard)
	motor.remove_child(old)
	old.free()
	receiver.name = "Damageable"
	motor.add_child(receiver)
	actor.definition = definition
	actor.damageable = receiver
	return true

static func create_candidate(identity: StringName, context: StringName = &"lab") -> EnemyMotor:
	var recipe := candidate_recipe(identity,context)
	if recipe.is_empty(): return null
	var motor := create_for_behavior(recipe.behavior)
	if motor == null: return null
	if not configure_candidate(motor,identity,context):
		motor.free()
		return null
	return motor
