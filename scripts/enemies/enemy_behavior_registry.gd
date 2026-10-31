class_name EnemyBehaviorRegistry
extends RefCounted
## Finite gameplay construction registry. Resources/AI algorithms stay unchanged.
## String script paths deliberately avoid preloading the Actor -> Behavior graph.
# Historical v11 records this exact resource revision. The logical source path
# remains in its Manifest; only the finite resolver selects retained bytes.
const CHARGER_V2_REVISION := "1afd5e34d497e3850d794b028fd5fe5407d3722fcd451d862f4c14a67ca98fc0"
const BEHAVIORS := {
	&"patrol": {"family":&"base", "script":"", "definition":"res://resources/enemies/patrol_drone.tres", "scene":"res://scenes/enemies/patrol_drone.tscn"},
	&"charger": {"strategy":"res://scripts/enemies/charger_attack_strategy.gd", "family":&"base", "script":"res://scripts/enemies/enemy_attack_behavior.gd", "definition":"res://resources/enemies/plains_charger.tres", "revisions":{CHARGER_V2_REVISION:"res://resources/enemies/legacy/plains_charger_v2.tres"}, "scene":"res://scenes/enemies/patrol_drone.tscn"},
	&"diver": {"strategy":"res://scripts/enemies/diver_attack_strategy.gd", "family":&"base", "script":"res://scripts/enemies/enemy_attack_behavior.gd", "definition":"res://resources/enemies/plains_diver.tres", "scene":"res://scenes/enemies/patrol_drone.tscn"},
	&"hopper": {"strategy":"res://scripts/enemies/hopper_attack_strategy.gd", "family":&"base", "script":"res://scripts/enemies/enemy_attack_behavior.gd", "definition":"res://resources/enemies/plains_hopper.tres", "scene":"res://scenes/enemies/patrol_drone.tscn"},
	&"sentry": {"strategy":"res://scripts/enemies/sentry_attack_strategy.gd", "family":&"base", "script":"res://scripts/enemies/enemy_attack_behavior.gd", "definition":"res://resources/enemies/plains_sentry.tres", "scene":"res://scenes/enemies/patrol_drone.tscn"},
	&"fan_sentry": {"strategy":"res://scripts/enemies/fan_sentry_attack_strategy.gd", "family":&"base", "script":"res://scripts/enemies/enemy_attack_behavior.gd", "definition":"res://resources/enemies/plains_fan_sentry.tres", "scene":"res://scenes/enemies/patrol_drone.tscn"},
	&"root_bell": {"family":&"base", "script":"res://scripts/enemies/root_bell_behavior.gd", "definition":"res://resources/enemies/plains_root_bell.tres", "scene":"res://scenes/enemies/patrol_drone.tscn"},
	&"forest_lantern": {"family":&"base", "script":"res://scripts/enemies/forest_lantern_behavior.gd", "definition":"res://resources/enemies/forest_lantern.tres", "scene":"res://scenes/enemies/forest_lantern.tscn"},
	&"forest_seed_sentry": {"family":&"base", "script":"res://scripts/enemies/forest_seed_sentry_behavior.gd", "definition":"res://resources/enemies/forest_seed_sentry.tres", "scene":"res://scenes/enemies/forest_seed_sentry.tscn"},
	&"forest_bark_beetle": {"family":&"forest", "script":"res://scripts/enemies/forest_bark_beetle_behavior.gd", "definition":"res://resources/enemies/forest_bark_beetle.tres", "scene":"res://scenes/enemies/forest_bark_beetle.tscn"},
	&"forest_swing_pod": {"family":&"forest", "script":"res://scripts/enemies/forest_swing_pod_behavior.gd", "definition":"res://resources/enemies/forest_swing_pod.tres", "scene":"res://scenes/enemies/forest_swing_pod.tscn"},
	&"forest_thread_spider": {"family":&"forest", "script":"res://scripts/enemies/forest_thread_spider_behavior.gd", "definition":"res://resources/enemies/forest_thread_spider.tres", "scene":"res://scenes/enemies/forest_thread_spider.tscn"},
	&"forest_crossbranch": {"family":&"forest", "script":"res://scripts/enemies/forest_crossbranch_behavior.gd", "definition":"res://resources/enemies/forest_crossbranch.tres", "scene":"res://scenes/enemies/forest_crossbranch.tscn"},
	&"forest_bible_weaver": {"family":&"weaver", "script":"res://scripts/enemies/forest_bible_weaver_behavior.gd", "definition":"res://resources/enemies/forest_bible_weaver.tres", "scene":"res://scenes/enemies/forest_bible_weaver.tscn"},
}
const CANDIDATES := {
	&"candidate_lure_guard": {"behavior":&"charger", "script":"res://scripts/enemies/enemy_attack_behavior.gd"},
	&"candidate_crosswind_moth": {"behavior":&"sentry", "script":"res://scripts/enemies/prototype_moth_behavior.gd"},
}

static func behavior_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in BEHAVIORS: result.append(id)
	return result

static func candidate_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in CANDIDATES: result.append(id)
	return result

static func candidate_behavior(identity: StringName) -> StringName:
	return CANDIDATES[identity].behavior if CANDIDATES.has(identity) else &""

static func supports_behavior(id: StringName) -> bool:
	return BEHAVIORS.has(id)

static func validation_family(id: StringName) -> StringName:
	return BEHAVIORS[id].family if BEHAVIORS.has(id) else &""

static func definition_path(id: StringName, revision: String = "") -> String:
	if not BEHAVIORS.has(id): return ""
	if revision.is_empty(): return BEHAVIORS[id].definition
	var revisions: Dictionary=BEHAVIORS[id].get("revisions",{})
	var path: String=revisions.get(revision,"")
	# Unknown revisions and changed retained bytes fail closed, never current.
	return path if not path.is_empty() and FileAccess.get_sha256(path)==revision else ""

static func scene_path(id: StringName) -> String:
	return BEHAVIORS[id].scene if BEHAVIORS.has(id) else ""

static func definition_error(behavior: StringName, stable_id: StringName) -> String:
	if not supports_behavior(behavior): return "unknown_behavior"
	if CANDIDATES.has(stable_id) and CANDIDATES[stable_id].behavior != behavior: return "candidate_behavior_mismatch"
	return ""

static func behavior_script_path(behavior: StringName, stable_id: StringName = &"") -> String:
	if not definition_error(behavior,stable_id).is_empty(): return ""
	return CANDIDATES[stable_id].script if CANDIDATES.has(stable_id) else BEHAVIORS[behavior].script

static func create_behavior(definition: Resource) -> EnemyAttackBehavior:
	if definition == null or not definition.has_method("is_valid") or definition.call("is_valid") != true: return null
	var raw_behavior: Variant = definition.get("behavior_id")
	var raw_identity: Variant = definition.get("stable_id")
	if not (raw_behavior is String or raw_behavior is StringName) or not (raw_identity is String or raw_identity is StringName): return null
	var behavior := StringName(raw_behavior)
	var identity := StringName(raw_identity)
	if not definition_error(behavior,identity).is_empty(): return null
	var path := behavior_script_path(behavior,identity)
	# Patrol intentionally has no attack behavior. Unknown IDs are refused above.
	if path.is_empty(): return null
	var source := load(path) as Script
	return source.new() as EnemyAttackBehavior if source != null else null

static func create_attack_strategy(behavior: StringName) -> EnemyAttackStrategy:
	if not supports_behavior(behavior): return null
	var path: String = BEHAVIORS[behavior].get("strategy", "res://scripts/enemies/enemy_attack_strategy.gd")
	var source := load(path) as Script
	return source.new() as EnemyAttackStrategy if source != null else null
