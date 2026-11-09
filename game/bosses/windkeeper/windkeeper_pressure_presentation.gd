class_name WindkeeperPressurePresentation
extends Node2D
## PR142 authored guardian; all attack/death/phase clocks belong to encounter.
@export var encounter: WindkeeperEncounter
var body: PlainsBossBody
var hit_template: EnemyHitTemplate
var _hurt_remaining := 0.0
var _armour_remaining := 0.0
var _armour_point := Vector2.ZERO


func _ready() -> void:
	PlainsBossTween.warm("windkeeper")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://game/presentation/actors/art/plains_actor_separation.gdshader")
	material = surface
	body=PlainsBossBody.new()
	add_child(body)
	if encounter == null:
		encounter = get_parent().get_node_or_null("Encounter") as WindkeeperEncounter
	if encounter == null:
		return
	var wind:=PlainsWindField.new()
	wind.encounter=encounter as WindkeeperPressureEncounter
	add_child(wind)
	move_child(wind,0)
	hit_template = EnemyHitTemplate.install_boss(encounter,self)
	encounter.health.changed.connect(_health_changed)
	encounter.armour_hit.connect(_armour_hit)
	encounter.presentation_event.connect(_attack_effect)


func _attack_effect(event: Dictionary) -> void:
	if event.get("event",&"") in [&"windkeeper_stomp_strike",&"windkeeper_platform_impact",&"windkeeper_lunge_land"]:
		PlainsBossEffects.spawn(encounter.motor.get_parent(),encounter,event.get("point",encounter.motor.global_position+Vector2(0,65)),&"wind",2,.32,Vector2(1.6,.8))

func _health_changed(result: ActorResourceResult) -> void:
	if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED:
		_hurt_remaining = .12 if not encounter.health.terminal else 0.0


func _armour_hit(point: Vector2) -> void:
	_armour_point = encounter.motor.to_local(point)
	_armour_remaining = .10


func _process(delta: float) -> void:
	if not is_instance_valid(encounter) or get_tree().paused:
		return
	_hurt_remaining = maxf(0,_hurt_remaining-delta)
	_armour_remaining = maxf(0,_armour_remaining-delta)
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(encounter) or not encounter.has_method("rig_pose"): return
	var pose: Dictionary = encounter.call("rig_pose")
	if not pose.has("authored"): return
	body.present(pose.authored,hit_template.sample.flash_strength())
	(material as ShaderMaterial).set_shader_parameter("hit_flash", hit_template.sample.flash_strength())
	# The short ivory cutting trail follows the physical blade exactly; the
	# authored forelimb supplies the body action, this is the active edge cue.
	if pose.mode == &"sweep" and not pose.dead:
		draw_line(pose.blade_start, pose.blade_end, Color(1.0, .87, .61, .8), 3.0, false)
	if _armour_remaining > 0.0:
		for index: int in 4:
			var axis := Vector2.from_angle(float(index) * PI * .5 + .4)
			var at := (_armour_point + axis * (7 + (1 - _armour_remaining / .1) * 8)).round()
			draw_rect(Rect2(at, Vector2(2, 2)), Color("ded8ad"))


func _exit_tree() -> void:
	if is_instance_valid(hit_template): hit_template.dispose()
