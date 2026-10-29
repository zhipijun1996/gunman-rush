class_name BossPresentation
extends Node2D

@export var encounter: BossEncounter
var _death := 0.0
var hit_template: EnemyHitTemplate
var motion := BossMotionPresentation.new()
func _ready() -> void:
	hit_template = EnemyHitTemplate.install_boss(encounter, self)
	motion.bind(encounter)

func _process(delta: float) -> void:
	motion.sample(encounter,delta)
	if encounter.health.terminal: _death += delta
	queue_redraw()

func _draw() -> void:
	if encounter == null or encounter.definition == null:
		return
	var size := encounter.definition.collision_size
	var observed := encounter.presentation_state()
	var alive := not observed.terminal
	var key: StringName = &"boss_dead" if not alive else (&"boss_phase_1" if observed.phase == 1 else &"boss_phase_2")
	# Shared 390px foot anchor keeps the phase swap planted. No collision or
	# attack range is inferred from the painted shoulder cannons.
	var scale_factor := minf(size.x * 1.20 / 429.0, size.y * 1.10 / 381.0)
	var destination := PlainsActorAssets.anchored_rect("enemies", key, Vector2(0, size.y * 0.5), scale_factor)
	var tint := hit_template.tint()
	if not alive: tint.a = maxf(.18,1-_death*.8)
	if alive:
		motion.draw_body(self,PlainsActorAssets.texture("enemies",key),destination,&"clockwork",tint)
	else:
		# Keep the original authored dead key and its existing retained fade.
		draw_texture_rect(PlainsActorAssets.texture("enemies",key),destination,false,tint)
	draw_set_transform(Vector2.ZERO)
	if alive and observed.telegraphing:
		draw_arc(Vector2.ZERO, size.length() * 0.6, 0, TAU, 40, Color(1.0, 0.45, 0.18, 0.5 + observed.warning_progress * 0.5), 3.0)
	var bar := Rect2(-size.x * 0.5, -size.y * 0.5 - 15, size.x, 6)
	draw_rect(bar, Color(0.15, 0.15, 0.18))
	bar.size.x *= encounter.health.current / maxf(1.0, encounter.health.capacity)
	draw_rect(bar, Color(1.0, 0.55, 0.32))

func _exit_tree() -> void:
	motion.dispose(encounter)

func synchronize_presentation() -> void:
	motion.synchronize(encounter)
