class_name PlainsRevisionVisual
extends Node2D
## Child drawing leaf; its parent lifecycle owns the only motion/sample clocks.
var actor: EnemyActor
var motion: PlainsMotion02
var sample: EnemyFeedback01
var rig: PlainsRevisionSkin
var pose: Dictionary = {}
var _face := 1
var _requested_face := 1
var _turn_age := 1.0
var remains: PlainsRevisionRemains
var particles: EnemyFeedback01Particles

static func install(host: Node2D, owner_actor: EnemyActor, body_motion: PlainsMotion02) -> PlainsRevisionVisual:
	var visual := PlainsRevisionVisual.new()
	visual.name = "ArticulatedBody"
	var accepted := EnemyFeedback01.new(owner_actor.health,owner_actor.definition)
	body_motion.sample = accepted
	host.add_child(visual)
	visual.configure(owner_actor,body_motion,accepted)
	visual.particles = EnemyFeedback01Particles.new()
	visual.particles.name = "AcceptedHitChips"
	visual.particles.z_index = 1
	host.add_child(visual.particles)
	visual.particles.bind(accepted,owner_actor.damageable)
	visual.remains = PlainsRevisionRemains.new()
	visual.remains.name = "ArticulatedRemains"
	var stage := owner_actor.motor.get_parent()
	stage.add_child(visual.remains)
	stage.move_child(visual.remains,0)
	visual.remains.bind(accepted,owner_actor.damageable,owner_actor.health,owner_actor.motor,host,owner_actor.definition.aerial,visual.remains_view)
	return visual

func remains_view() -> Dictionary:
	# Saved health initializes before the stage applies its recorded facing.
	# A hidden terminal body no longer refreshes its live turn cache; reconcile
	# saved corpses from the authoritative brain while accepted deaths retain
	# the last visible facing for a continuous lethal handoff.
	var face := float(actor.brain.direction) if sample.restored_terminal else float(_face)
	return {"rig":rig,"pose":pose.duplicate(true),"transform":global_transform,"contact_foot":actor.motor.global_position+Vector2(0,actor.definition.collision_size.y*.5),"face":face,"persistent":actor.definition.behavior_id==&"charger","death_seconds":1.1}

func _exit_tree() -> void:
	if is_instance_valid(remains): remains.dispose()

func configure(owner_actor: EnemyActor, body_motion: PlainsMotion02, accepted: EnemyFeedback01) -> void:
	actor = owner_actor
	motion = body_motion
	sample = accepted
	rig = PlainsRevisionSkin.new(actor.definition.behavior_id)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://scripts/enemies/plains_revision_skin.gdshader")
	material = shader_material
	_face = actor.brain.direction
	_requested_face = _face
	refresh(0.0)

func refresh(delta: float) -> void:
	if actor == null: return
	visible = not actor.health.terminal
	(material as ShaderMaterial).set_shader_parameter("hit_flash",sample.flash_strength() if visible else 0.0)
	if not visible: return # Preserve the last live joints for lethal handoff.
	if _requested_face != actor.brain.direction:
		_requested_face = actor.brain.direction
		_turn_age = 0.0
	_turn_age += delta
	# Head probes first, then the trunk follows; AI facing is unchanged.
	if actor.definition.behavior_id!=&"patrol" or _turn_age>=.10: _face = _requested_face
	var state := actor.presentation_state()
	var foot := actor.motor.global_position+Vector2(0,actor.definition.collision_size.y*.5)
	var air := false
	if is_inside_tree():
		var query := PhysicsRayQueryParameters2D.create(foot-Vector2(0,2),foot+Vector2(0,5),1,[actor.motor.get_rid()])
		query.collide_with_areas = false
		air = get_world_2d().direct_space_state.intersect_ray(query).is_empty()
	pose = {"clock":motion.clock,"stride":motion.stride,"travel":motion.travel,"load":motion.tension,"strike":motion.release,"recovery":motion.recovery,"hurt":sample.hurt_remaining/maxf(sample.tuning.hurt_seconds,.001),"turn":1.0-smoothstep(0,.18,_turn_age),"air":air,"vertical":(state.velocity as Vector2).y,"dead":false,"death":0.0}
	if _face!=_requested_face: pose["turn"] = -float(pose.turn)
	var aim: Vector2 = state.get("aim_direction",Vector2(float(_face),0))
	pose["aim"] = clampf(atan2(aim.y,absf(aim.x)),-1.1,1.1)
	position = Vector2(0,actor.definition.collision_size.y*.5)
	scale = Vector2(float(_face),1)
	queue_redraw()

func _draw() -> void:
	if rig == null or not visible: return
	rig.draw_pose(self,pose,Color.WHITE)
