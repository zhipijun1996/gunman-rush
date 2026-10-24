class_name EnemyHitTemplate
extends Node2D
## Common accepted-hit feedback. The host keeps its body, AI and death renderer.
## Body callers opt in to the shared tint; materials, HP and world cues stay
## entirely host-owned. Idle instances do no polling or extra texture sampling.
const METADATA := &"accepted_enemy_hit_template"
var sample: EnemyFeedback01
var particles: EnemyFeedback01Particles
var actor: EnemyActor
var health: HealthState
var receiver: Damageable
var host: Node2D
var _last_serial := 0

static func install(owner_actor: EnemyActor, presentation: Node2D) -> EnemyHitTemplate:
	var template := _install(owner_actor.health, owner_actor.damageable, presentation, owner_actor.definition)
	template.actor = owner_actor
	return template

static func install_boss(encounter: BossEncounter, presentation: Node2D) -> EnemyHitTemplate:
	# Boss weakpoints/phase motion keep their exact authored locations. The same
	# accepted-hit state, flash and contact fan apply without ordinary-body squash.
	return _install(encounter.health, encounter.damageable, presentation)

static func _install(owner_health: HealthState, damageable: Damageable, presentation: Node2D, definition: EnemyDefinition = null) -> EnemyHitTemplate:
	var existing := presentation.get_meta(METADATA) as EnemyHitTemplate if presentation.has_meta(METADATA) else null
	if is_instance_valid(existing): return existing
	var template := EnemyHitTemplate.new()
	template.name = "AcceptedEnemyHit"
	template.health = owner_health
	template.receiver = damageable
	template.host = presentation
	template.sample = EnemyFeedback01.new(owner_health, definition)
	presentation.set_meta(METADATA, template)
	presentation.add_child(template)
	return template

static func body_pose(canvas: Node2D) -> Vector2:
	var template := canvas.get_meta(METADATA) as EnemyHitTemplate if canvas.has_meta(METADATA) else null
	return template.pose() if is_instance_valid(template) else Vector2.ONE

static func body_tint(canvas: CanvasItem, base: Color = Color.WHITE) -> Color:
	var template := canvas.get_meta(METADATA) as EnemyHitTemplate if canvas.has_meta(METADATA) else null
	return template.tint(base) if is_instance_valid(template) else base

func _ready() -> void:
	set_process(false)
	particles = EnemyFeedback01Particles.new()
	particles.name = "AcceptedHitChips"
	particles.z_index = 1
	add_child(particles)
	particles.bind(sample, receiver)
	health.changed.connect(_health_changed)

func _health_changed(result: ActorResourceResult) -> void:
	if result == null or result.snapshot == null or result.snapshot.epoch != health.epoch: return
	if result.operation == &"initialize":
		_finish()
		particles.clear_for_epoch()
		return
	if result.event_id != sample.last_event_id or sample.impact_serial == _last_serial: return
	_last_serial = sample.impact_serial
	_sync()
	set_process(sample.hurt_remaining > 0 or sample.impact_remaining > 0)

func _process(delta: float) -> void:
	if get_tree().paused: return
	sample.advance(delta)
	_sync()
	if sample.hurt_remaining <= 0 and sample.impact_remaining <= 0: _finish()

func _sync() -> void:
	host.queue_redraw()

func _finish() -> void:
	set_process(false)
	host.queue_redraw()

func tint(base: Color = Color.WHITE) -> Color:
	if health.terminal: return base
	# Multiplicative highlights retain the real body silhouette/material; this
	# color is supplied only to body commands, never to warnings, HP or a core.
	var highlight := Color.WHITE.lerp(Color(2.2, 2.088, 1.544), sample.flash_strength())
	var lit := base * highlight
	lit.a = base.a
	return lit

func pose() -> Vector2:
	return Vector2.ONE if health.terminal or actor == null else sample.pose()

func begin_body(canvas: Node2D) -> void:
	var deformation := pose()
	var foot := Vector2.ZERO if actor.definition.aerial else Vector2(0, actor.definition.collision_size.y*.5)
	canvas.draw_set_transform(foot*(Vector2.ONE-deformation), 0, deformation)

func _exit_tree() -> void:
	if health != null and health.changed.is_connected(_health_changed): health.changed.disconnect(_health_changed)
	if is_instance_valid(host):
		if host.has_meta(METADATA): host.remove_meta(METADATA)
	if sample != null: sample.dispose()
