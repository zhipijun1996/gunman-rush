class_name BellstriderPresentation
extends Node2D
## Authored PR142 carriage frames, sampled from the real encounter clock.
const AUDIO := preload("res://game/presentation/audio/bellstrider_audio.gd")
@export var encounter: BellstriderEncounter
var pixel_style := false
var hit_template: EnemyHitTemplate
# Preserve accepted-event lifecycle; the old mesh deformation is never drawn.
var motion := BossMotionPresentation.new()
var _armour_point := Vector2(44, 8)
var mortar: PlainsMortarArt


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://game/presentation/actors/art/plains_actor_separation.gdshader")
	material = surface
	mortar=PlainsMortarArt.new()
	add_child(mortar)
	hit_template = EnemyHitTemplate.install_boss(encounter, self)
	motion.bind(encounter)
	encounter.armour_hit.connect(_armour_impact)
	encounter.objective_changed.connect(_objective_changed)
	var service := AUDIO.new()
	service.name = "BellstriderAudio"
	add_child(service)
	service.bind(encounter)
	var arrival := BossArrivalPresentation.new()
	arrival.configure(encounter, self, true)
	get_parent().add_child.call_deferred(arrival)


func _objective_changed(_text: String) -> void:
	# Arrival alone offsets this CanvasItem while damage is disabled. Exiting or
	# skipping intro must settle immediately, before the bell becomes shootable.
	if encounter.mode != &"intro":
		position = Vector2.ZERO


func synchronize_presentation() -> void:
	# The complete region restore owns epoch replacement. Rebind once here,
	# without replaying any past cue; an unfinished saved death keeps only its
	# future mechanical-failure layers eligible.
	if not is_instance_valid(encounter):
		return
	motion.synchronize(encounter)
	_objective_changed("")
	var service := get_node_or_null("BellstriderAudio") as BellstriderAudio
	if service != null:
		service.bind(encounter, null, encounter.health.terminal)
	queue_redraw()


func _process(delta: float) -> void:
	if get_tree().paused or not is_instance_valid(encounter):
		return
	motion.sample(encounter, delta)
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(encounter): return
	var pose := encounter.rig_pose()
	var surface:=material as ShaderMaterial
	var flash:=hit_template.sample.flash_strength()
	var cutout:=Vector4.ZERO
	mortar.visible=false
	if String(pose.authored.sheet).trim_suffix("_flow")=="bellstrider_lob":
		cutout=mortar.present(pose.authored,pose.barrel_angle,flash)
	surface.set_shader_parameter("part_cutout",cutout)
	PlainsBossFrames.draw(self, pose.authored)
	if motion.hurt > 0.0:
		(material as ShaderMaterial).set_shader_parameter("hit_flash", motion.hurt * .45)
	else:
		(material as ShaderMaterial).set_shader_parameter("hit_flash", 0.0)


func _armour_impact(point: Vector2) -> void:
	if is_instance_valid(encounter.motor):
		_armour_point = encounter.motor.to_local(point)


func _exit_tree() -> void:
	motion.dispose(encounter)
	if is_instance_valid(encounter) and encounter.armour_hit.is_connected(_armour_impact):
		encounter.armour_hit.disconnect(_armour_impact)
