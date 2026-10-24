class_name BossPresentation
extends Node2D

@export var encounter: BossEncounter
var _clock := 0.0
var _weight := Vector2.ONE
var _lean := 0.0
var _hurt := 0.0
var _death := 0.0
var _old_phase := 1
var _phase_age := 1.0
var hit_template: EnemyHitTemplate
func _ready() -> void:
	hit_template = EnemyHitTemplate.install_boss(encounter, self)

func _process(delta: float) -> void:
	_clock += delta
	_hurt = maxf(0,_hurt-delta)
	if encounter.health.terminal: _death += delta
	_phase_age += delta
	if encounter.phases.phase != _old_phase and _phase_age >= .12:
		_old_phase = encounter.phases.phase
		_phase_age = 0
	var warning := encounter.pattern.warning_progress
	var target := Vector2(1+.06*warning,1-.08*warning) if encounter.pattern.telegraphing else Vector2(1+sin(_clock*7)*.012,1-absf(sin(_clock*7))*.02)
	if encounter.health.terminal: target = Vector2(1.1,.6)
	_weight = _weight.lerp(target,1-exp(-delta/.08))
	_lean = lerpf(_lean,encounter.direction*.045,1-exp(-delta/.1))
	queue_redraw()

func _draw() -> void:
	if encounter == null or encounter.definition == null:
		return
	var size := encounter.definition.collision_size
	var alive := not encounter.health.terminal
	var key: StringName = &"boss_dead" if not alive else (&"boss_phase_1" if encounter.phases.phase == 1 else &"boss_phase_2")
	# Shared 390px foot anchor keeps the phase swap planted. No collision or
	# attack range is inferred from the painted shoulder cannons.
	var scale_factor := minf(size.x * 1.20 / 429.0, size.y * 1.10 / 381.0)
	var destination := PlainsActorAssets.anchored_rect("enemies", key, Vector2(0, size.y * 0.5), scale_factor)
	draw_set_transform_matrix(Transform2D(Vector2(_weight.x,0),Vector2(_lean,_weight.y),Vector2(-_lean*size.y*.5,size.y*.5*(1-_weight.y))))
	var tint := Color(1.2,1,.8) if _hurt > 0 else Color.WHITE
	tint = hit_template.tint(tint)
	if not alive: tint.a = maxf(.18,1-_death*.8)
	draw_texture_rect(PlainsActorAssets.texture("enemies",key),destination,false,tint)
	draw_set_transform(Vector2.ZERO)
	if alive and encounter.pattern.telegraphing:
		draw_arc(Vector2.ZERO, size.length() * 0.6, 0, TAU, 40, Color(1.0, 0.45, 0.18, 0.5 + encounter.pattern.warning_progress * 0.5), 3.0)
	var bar := Rect2(-size.x * 0.5, -size.y * 0.5 - 15, size.x, 6)
	draw_rect(bar, Color(0.15, 0.15, 0.18))
	bar.size.x *= encounter.health.current / maxf(1.0, encounter.health.capacity)
	draw_rect(bar, Color(1.0, 0.55, 0.32))
