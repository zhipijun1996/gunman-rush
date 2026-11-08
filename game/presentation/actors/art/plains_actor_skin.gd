class_name PlainsActorSkin
extends RefCounted
## PR142 approved models; the actor and accepted feedback own all phase clocks.
const ANIMATIONS := {
	&"patrol": preload("res://assets/plains_actors_142/atlases/patrol.tres"),
	&"charger": preload("res://assets/plains_actors_142/atlases/charger.tres"),
	&"hopper": preload("res://assets/plains_actors_142/atlases/hopper.tres"),
	&"sentry": preload("res://assets/plains_actors_142/atlases/sentry.tres"),
	&"fan_sentry": preload("res://assets/plains_actors_142/atlases/fan_sentry.tres"),
	&"root_bell": preload("res://assets/plains_actors_142/atlases/root_bell.tres"),
	&"diver": preload("res://assets/plains_actors_142/atlases/diver.tres")
}
var kind: StringName
var animation: PlainsActorAnimation
var texture: Texture2D
var bounds: Rect2

static func supports(definition: EnemyDefinition) -> bool:
	return definition != null and definition.stable_id in [&"patrol_drone", &"graybox_patrol_drone", &"plains_charger", &"plains_hopper", &"plains_sentry", &"plains_fan_sentry", &"plains_root_bell", &"plains_diver"]

func _init(behavior: StringName = &"patrol") -> void:
	kind = behavior
	animation = ANIMATIONS[kind]
	texture = animation.atlas
	bounds = Rect2(-animation.pivot, Vector2(animation.frame_size))

func frame_selection(pose: Dictionary) -> Dictionary:
	if bool(pose.get("dead", false)):
		return {"clip": &"death", "progress": float(pose.get("death", 0.0))}
	var hurt := float(pose.get("hurt", 0.0))
	if hurt > 0.0: return {"clip": &"hurt", "progress": 1.0 - hurt}
	var state: StringName = pose.get("state", &"idle")
	var progress := clampf(float(pose.get("state_time", 0.0)) / maxf(.001, float(pose.get("phase_duration", 1.0))), 0.0, 1.0)
	if state == &"telegraph": return {"clip": &"anticipation", "progress": progress}
	if state == &"attack": return {"clip": &"attack", "progress": progress}
	if state in [&"recovery", &"blocked"]: return {"clip": &"recovery", "progress": progress}
	if float(pose.get("travel", 0.0)) > .06:
		return {"clip": &"move", "progress": fposmod(float(pose.get("stride", 0.0)) / (TAU * 2.6), 1.0)}
	return {"clip": &"idle", "progress": fposmod(float(pose.get("clock", 0.0)) / .84, 1.0)}

func draw_pose(canvas: CanvasItem, pose: Dictionary, tint: Color) -> void:
	var selected := frame_selection(pose)
	animation.draw_frame(canvas, selected.clip, selected.progress, tint)
