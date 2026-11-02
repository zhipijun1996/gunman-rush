class_name EnemyPresentationBinding
extends RefCounted
## Final render binding. Movement traits never select art. The existing asset
## manifests remain authoritative; these keys only select existing render paths.
const METADATA := &"enemy_presentation_binding"
const PROFILES := [&"scene", &"windchime", &"pixel", &"underworld", &"forest", &"prototype"]
const RENDERERS := {
	&"pixel": "res://game/presentation/actors/art_foundation/pixel_plains_enemy.gd",
	&"underworld": "res://game/presentation/actors/underworld_plains/underworld_enemy.gd"
}
const BODY_KEYS := {
	&"patrol": &"patrol", &"charger": &"charger", &"diver": &"aerial",
	&"hopper": &"hopper", &"sentry": &"sentry", &"fan_sentry": &"aerial",
	&"root_bell": &"root_bell",
	&"forest_lantern": &"aerial", &"forest_swing_pod": &"aerial",
	&"forest_seed_sentry": &"patrol", &"forest_bark_beetle": &"patrol",
	&"forest_thread_spider": &"patrol", &"forest_crossbranch": &"patrol",
	&"forest_bible_weaver": &"patrol"
}
const CANDIDATE_BODY_KEYS := {&"candidate_lure_guard": &"charger", &"candidate_crosswind_moth": &"aerial"}

static func bind_existing(actor: Node, host: Node, profile: StringName, body_theme: StringName = &"") -> Dictionary:
	if not can_bind(actor, host, profile):
		push_error("Enemy presentation binding requires an actor and a supported profile")
		return {}
	var definition: Resource = actor.definition
	var previous := view(host)
	var body_key: StringName = CANDIDATE_BODY_KEYS.get(definition.stable_id, BODY_KEYS.get(definition.behavior_id, &""))
	var binding := {
		"version": 1, "actor_id": actor.get_instance_id(),
		"species": definition.stable_id, "behavior": definition.behavior_id,
		"profile": profile, "renderer": host.get_script().resource_path,
		"body_theme": body_theme if not body_theme.is_empty() else previous.get("body_theme", &"scene"),
		"body_key": body_key,
		"scene_body": &"aerial" if body_key == &"aerial" else &"ground",
		"collision_size": definition.collision_size
	}
	binding.make_read_only()
	host.set_meta(METADATA, binding)
	return binding

static func can_bind(actor: Node, host: Node, profile: StringName) -> bool:
	return binding_error(actor, host, profile).is_empty()

static func binding_error(actor: Node, host: Node, profile: StringName) -> String:
	if not is_instance_valid(actor) or not is_instance_valid(host): return "missing_owner_or_host"
	if profile not in PROFILES: return "unknown_profile"
	var definition: Resource = actor.get("definition")
	if definition == null or host.get_script() == null: return "missing_definition_or_renderer"
	if not BODY_KEYS.has(definition.get("behavior_id")): return "unknown_body_route"
	if host.get("actor") != actor: return "host_actor_mismatch"
	if host.is_inside_tree() and host.get_parent() != actor.get("motor"): return "host_motor_mismatch"
	var previous := view(host)
	if not previous.is_empty() and previous.get("actor_id") != actor.get_instance_id(): return "already_bound_to_another_actor"
	return ""

static func view(host: Node) -> Dictionary:
	if host == null: return {}
	var result: Variant = host.get_meta(METADATA, {})
	return result if result is Dictionary else {}

static func replace(actor: Node, profile: StringName) -> bool:
	if actor == null or not RENDERERS.has(profile): return false
	var motor: Node = actor.motor
	var old := motor.get_node_or_null("Presentation")
	# Underworld is the final skin layered over the pixel telegraph renderer.
	# Reapplying the earlier installer must not downgrade that final binding.
	if old != null and profile == &"pixel" and old.get_script().resource_path == RENDERERS[&"underworld"]:
		return false
	if old != null and old.get_script().resource_path == RENDERERS[profile]:
		bind_existing(actor, old, profile)
		return false
	# Load one-way here: renderers use the binding contract too. Keeping the
	# concrete factory out of their static class graph avoids circular loading.
	var renderer := load(RENDERERS[profile]) as Script
	if renderer == null: return false
	var art := renderer.new() as Node2D
	art.set("actor", actor)
	art.name = "Presentation"
	if old != null:
		motor.remove_child(old)
		old.queue_free()
	bind_existing(actor, art, profile)
	motor.add_child(art)
	return true

static func remains(host: Node) -> EnemyFeedback01Remains:
	if host == null or not host.has_method("presentation_remains"): return null
	return host.call("presentation_remains") as EnemyFeedback01Remains

static func synchronize(owner: Node) -> void:
	# Called at the end of the complete restore transaction, after position,
	# facing and behavior. A zero-delta sync cannot replay accepted damage.
	if owner == null or not is_instance_valid(owner.get("motor")): return
	var motor: Node = owner.get("motor")
	var host := motor.get_node_or_null("Presentation")
	if host != null and host.has_method("synchronize_presentation"):
		host.call("synchronize_presentation")
