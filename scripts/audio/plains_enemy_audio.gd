class_name PlainsEnemyAudio
extends RefCounted
## Material reaction of the seven plains bodies. Accepted events remain owned
## by Actor/Health; this helper never grants damage, drops or gameplay motion.
const MATERIALS := {
	&"patrol_drone": &"shell", &"graybox_patrol_drone": &"shell",
	&"plains_charger": &"shell", &"plains_hopper": &"shell",
	&"plains_diver": &"wing", &"plains_fan_sentry": &"wing",
	&"plains_sentry": &"plant", &"plains_root_bell": &"plant"
}
const CONTACT_PROGRESS := {
	&"patrol": .80, &"charger": .76, &"hopper": .63,
	&"sentry": .77, &"fan_sentry": .72, &"root_bell": .72
}
const STREAMS := {
	&"shell_hurt": preload("res://assets/audio/plains_feedback_02/shell_hurt.wav"),
	&"shell_death": preload("res://assets/audio/plains_feedback_02/shell_death.wav"),
	&"shell_land": preload("res://assets/audio/plains_feedback_02/shell_land.wav"),
	&"wing_hurt": preload("res://assets/audio/plains_feedback_02/wing_hurt.wav"),
	&"wing_death": preload("res://assets/audio/plains_feedback_02/wing_death.wav"),
	&"wing_land": preload("res://assets/audio/plains_feedback_02/wing_land.wav"),
	&"plant_hurt": preload("res://assets/audio/plains_feedback_02/plant_hurt.wav"),
	&"plant_death": preload("res://assets/audio/plains_feedback_02/plant_death.wav"),
	&"plant_land": preload("res://assets/audio/plains_feedback_02/plant_land.wav")
}
const RECEIPT_META := &"plains_material_feedback_receipts"

static func family(definition: EnemyDefinition) -> StringName:
	return MATERIALS.get(definition.stable_id, &"") if definition != null else &""

static func supports(actor: EnemyActor) -> bool:
	return is_instance_valid(actor) and not family(actor.definition).is_empty()

static func contact_progress(actor: EnemyActor) -> float:
	return float(CONTACT_PROGRESS.get(actor.definition.behavior_id, .72)) if supports(actor) else 1.0

static func _receipts(actor: EnemyActor) -> Dictionary:
	var value: Variant = actor.get_meta(RECEIPT_META, {})
	var result: Dictionary = value if value is Dictionary else {}
	if int(result.get("epoch", -1)) != actor.health.epoch:
		result = {"epoch": actor.health.epoch, "hurt": [], "death": false}
		actor.set_meta(RECEIPT_META, result)
	return result

static func _service(origin: Node) -> GameAudio:
	if not is_instance_valid(origin) or not origin.is_inside_tree(): return null
	return origin.get_tree().get_first_node_in_group(&"game_audio") as GameAudio

static func hurt(actor: EnemyActor, context: Dictionary) -> void:
	if not supports(actor) or actor.health.terminal: return
	var event := StringName(context.get("event_id", ""))
	if event.is_empty() or int(context.get("target_epoch", -1)) != actor.health.epoch: return
	var receipt := _receipts(actor)
	var seen: Array = receipt.hurt
	if seen.has(event): return
	seen.append(event)
	if seen.size() > 16: seen.pop_front()
	var audio := _service(actor)
	if audio != null:
		audio.play_enemy_material(&"hurt", STREAMS[StringName(String(family(actor.definition)) + "_hurt")], actor, actor.definition.stable_id)

static func defeated(actor: EnemyActor) -> void:
	if not supports(actor) or not actor.health.terminal: return
	var receipt := _receipts(actor)
	if bool(receipt.death): return
	receipt.death = true
	var audio := _service(actor)
	if audio != null:
		# Finish the same body's short hurt tail before its distinct death cue.
		audio.stop_director_family(actor.get_instance_id(), &"enemy_material")
		audio.play_enemy_material(&"death", STREAMS[StringName(String(family(actor.definition)) + "_death")], actor, actor.definition.stable_id)

static func landed(origin: Node, actor: EnemyActor, stream_override: AudioStream = null) -> void:
	if not supports(actor) or not actor.health.terminal: return
	var audio := _service(origin)
	if audio != null:
		var stream: AudioStream = stream_override if stream_override != null else STREAMS[StringName(String(family(actor.definition)) + "_land")]
		audio.play_enemy_material(&"land", stream, origin, actor.definition.stable_id)
