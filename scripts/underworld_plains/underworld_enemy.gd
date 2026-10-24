class_name UnderworldEnemy
extends PixelPlainsEnemy
## Genuine new body art. Original state-based telegraphs remain authoritative.
var feedback: DamageFeedbackDefinition = preload("res://resources/damage/feedback.tres")
var accepted_hurt_count := 0
var feedback_sample: EnemyFeedback01
var feedback_frames: EnemyFeedback01Frames
var feedback_frame_index := -1
var feedback_anchor := Vector2.ZERO
var feedback_body: EnemyFeedback01Body
var feedback_particles: EnemyFeedback01Particles
var feedback_remains: EnemyFeedback01Remains
var hit_template: EnemyHitTemplate

func _ready() -> void:
	if EnemyFeedback01.supports(actor.definition):
		# Do not install WindchimeEnemyVisual's legacy anonymous HP listener too.
		feedback_sample = EnemyFeedback01.new(actor.health, actor.definition)
		var original: Texture2D = SPRITES["aerial" if actor.definition.aerial else String(actor.definition.behavior_id)]
		var dimensions := _original_body_size(original)
		var visible_body := EnemyFeedback01Frames.visible_bounds(original, Rect2(-dimensions.x*.5, actor.definition.collision_size.y*.5-dimensions.y, dimensions.x, dimensions.y))
		feedback_anchor = Vector2(visible_body.get_center().x, visible_body.end.y)
		feedback_frames = EnemyFeedback01Frames.new(&"underworld", actor.definition.stable_id, visible_body.size)
		feedback_frames.horizontal_offset = feedback_anchor.x
		feedback_body = EnemyFeedback01Body.new()
		feedback_body.configure_underworld_palette(actor.definition.aerial)
		feedback_body.name = "AcceptedHitBody"
		# Keep the actor's world layer; only put its own HP/telegraphs above it.
		feedback_body.show_behind_parent = true
		add_child(feedback_body)
		feedback_particles = EnemyFeedback01Particles.new()
		feedback_particles.name = "AcceptedHitChips"
		feedback_particles.z_index = 1
		add_child(feedback_particles)
		feedback_particles.bind(feedback_sample, actor.damageable)
		actor.health.changed.connect(_feedback_initialized)
		_sync_feedback_body()
		feedback_remains = EnemyFeedback01Remains.new()
		feedback_remains.name = "AcceptedEnemyRemains"
		# Stage sibling: the formal reload path may hide the entire dead Motor.
		var stage := actor.motor.get_parent()
		stage.add_child(feedback_remains)
		stage.move_child(feedback_remains, 0)
		feedback_remains.bind(feedback_sample, actor.damageable, actor.health, actor.motor, self, actor.definition.aerial, _remains_view)
	else:
		super._ready()
		actor.health.changed.connect(_accepted_damage)
		hit_template = EnemyHitTemplate.install(actor, self)

func _process(delta: float) -> void:
	if get_tree().paused: return
	# Parent retains exclusive ownership of death timing, alpha and visibility.
	super._process(delta)
	if feedback_sample != null:
		feedback_sample.advance(delta)
		_hurt = feedback_sample.hurt_remaining
		accepted_hurt_count = feedback_sample.accepted_hit_count
		_sync_feedback_body()

func _sync_feedback_body() -> void:
	feedback_frame_index = feedback_frames.hurt_index(feedback_sample)
	feedback_body.visible = not actor.health.terminal
	if not feedback_body.visible:
		# Keep the accepted flash receipt, while the sibling now owns the pixels.
		feedback_body.flash_material.set_shader_parameter("hit_flash", 0.0 if feedback_sample.restored_terminal else feedback_sample.flash_strength())
		feedback_body.flash_material.set_shader_parameter("authored_palette", 0.0)
		feedback_body.flash_material.set_shader_parameter("frame_uv_rect", Vector4(0, 0, 1, 1))
		return
	if feedback_frame_index >= 0:
		# The new poses use the same shell/stone/brass family as this live body.
		feedback_body.configure_underworld_palette(actor.definition.aerial)
		var hurt_state: StringName = actor.attack_behavior.state if actor.attack_behavior != null else &"idle"
		var hurt_dip := 3.0 if hurt_state == &"telegraph" else 1.0 if hurt_state == &"recovery" else 0.0
		var hurt_flutter := 2 * roundf(sin(_clock * 12)) if actor.definition.aerial else 0.0
		var anchor := Vector2(0, feedback_anchor.y+hurt_dip+hurt_flutter)
		feedback_body.present(feedback_frames.texture(feedback_frame_index), feedback_frames.bounds(feedback_frame_index), anchor, 0, Vector2(float(actor.brain.direction), 1), Color.WHITE, feedback_sample.flash_strength())
		return
	feedback_body.configure_underworld_palette(actor.definition.aerial)
	var behavior := String(actor.definition.behavior_id)
	var source: Texture2D = SPRITES["aerial" if actor.definition.aerial else behavior]
	var size := actor.definition.collision_size
	var width := maxf(size.x + 8, 28)
	var height := width * source.get_height() / source.get_width()
	if height > size.y + 14:
		width *= (size.y + 14) / height
		height = size.y + 14
	var state: StringName = actor.attack_behavior.state if actor.attack_behavior != null else &"idle"
	var floor_y := size.y * .5
	var dip := 3.0 if state == &"telegraph" else 1.0 if state == &"recovery" else 0.0
	if actor.health.terminal: dip += _death * 18
	var pose := Vector2(1.06, .94) if state == &"telegraph" else Vector2(.96, 1.04) if state == &"attack" else Vector2.ONE
	pose *= feedback_sample.pose()
	var flutter := 2 * roundf(sin(_clock * 12)) if actor.definition.aerial else 0.0
	var origin := Vector2(0, dip + flutter + floor_y * (1 - pose.y))
	feedback_body.present(source, Rect2(-width*.5, floor_y-height, width, height), origin, feedback_sample.tilt(), Vector2(float(actor.brain.direction)*pose.x, pose.y), feedback_sample.tint(), feedback_sample.flash_strength())

func _original_body_size(texture: Texture2D) -> Vector2:
	var size := actor.definition.collision_size
	var width := maxf(size.x + 8, 28)
	var height := width * texture.get_height() / texture.get_width()
	if height > size.y + 14:
		width *= (size.y + 14) / height
		height = size.y + 14
	return Vector2(width, height)

func _remains_view() -> Dictionary:
	var face := float(actor.brain.direction)
	var flutter := 2 * roundf(sin(_clock * 12)) if actor.definition.aerial else 0.0
	return {"frames": feedback_frames, "contact_foot": global_transform * Vector2(0, actor.definition.collision_size.y*.5), "texture": feedback_frames.texture(4), "bounds": feedback_frames.bounds(4), "transform": global_transform * Transform2D(0, Vector2(face, 1), 0, Vector2(0, feedback_anchor.y+flutter)), "face": face, "angle": global_rotation, "readable_material": true}

func _feedback_initialized(result: ActorResourceResult) -> void:
	if result == null or result.operation != &"initialize" or result.snapshot.epoch != actor.health.epoch: return
	# Initialization can happen while paused. Clear cached drawing immediately;
	# do not depend on the next pausable process tick or touch parent death clocks.
	_hurt = 0
	feedback_particles.clear_for_epoch()
	_sync_feedback_body()
	queue_redraw()

func _exit_tree() -> void:
	if is_instance_valid(feedback_remains): feedback_remains.dispose()
	if feedback_sample != null: feedback_sample.dispose()
	if is_instance_valid(actor) and actor.health.changed.is_connected(_accepted_damage): actor.health.changed.disconnect(_accepted_damage)
	if is_instance_valid(actor) and actor.health.changed.is_connected(_feedback_initialized): actor.health.changed.disconnect(_feedback_initialized)

func _accepted_damage(result: ActorResourceResult) -> void:
	if result == null or result.operation != &"damage" or result.status != ActorResourceResult.Status.APPLIED or result.amount_applied >= 0 or result.snapshot.terminal: return
	_hurt = feedback.hurt_seconds
	accepted_hurt_count += 1

const SPRITES := {
	"patrol":preload("res://assets/underworld_plains/actors/patrol.png"),
	"hopper":preload("res://assets/underworld_plains/actors/hopper.png"),
	"charger":preload("res://assets/underworld_plains/actors/charger.png"),
	"aerial":preload("res://assets/underworld_plains/actors/aerial.png"),
	"sentry":preload("res://assets/underworld_plains/actors/sentry.png"),
	"root_bell":preload("res://assets/underworld_plains/actors/root_bell.png")}

func _draw() -> void:
	if actor == null: return
	if feedback_sample != null and actor.health.terminal: return
	var behavior := String(actor.definition.behavior_id)
	var state: StringName = actor.attack_behavior.state if actor.attack_behavior!=null else &"idle"
	if not actor.health.terminal: _telegraph(state,StringName(behavior))
	var key := "aerial" if actor.definition.aerial else "sentry" if behavior in ["sentry","fan_sentry"] else behavior if SPRITES.has(behavior) else "patrol"
	var source: Texture2D = SPRITES[key]
	var size := actor.definition.collision_size
	var width := maxf(size.x+8,28)
	var height := width*source.get_height()/source.get_width()
	if height>size.y+14:
		width *= (size.y+14)/height
		height = size.y+14
	var floor_y := size.y*.5
	var dip := 3.0 if state==&"telegraph" else 1.0 if state==&"recovery" else 0.0
	if actor.health.terminal: dip += _death*18
	var pose := Vector2.ONE
	if state==&"telegraph": pose=Vector2(1.06,.94)
	elif state==&"attack": pose=Vector2(.96,1.04)
	if feedback_sample != null:
		pose *= feedback_sample.pose()
	elif hit_template != null and not actor.health.terminal:
		pose *= hit_template.pose()
	elif _hurt > 0 and not actor.health.terminal:
		var age := feedback.hurt_seconds-_hurt
		pose = Vector2(.86,1.10) if age < .10 else Vector2(1.06,.96)
		dip -= sin(age/feedback.hurt_seconds*PI)*3
	var flutter := 2*roundf(sin(_clock*12)) if actor.definition.aerial else 0.0
	var tilt := feedback_sample.tilt() if feedback_sample != null else 0.0
	# Keep the ground contact anchor while squashing; the flyer retains flutter.
	var origin := Vector2(0,dip+flutter+(floor_y*(1-pose.y) if feedback_sample != null or hit_template != null else 0.0))
	draw_set_transform(origin,tilt,Vector2(float(actor.brain.direction)*pose.x,pose.y))
	var tint := feedback_sample.tint() if feedback_sample != null else Color(1.4,.72,.48) if _hurt>0 and int(_hurt*feedback.flash_frequency)%2==0 else Color.WHITE
	if hit_template != null: tint = hit_template.tint()
	if feedback_body == null: draw_texture_rect(source,Rect2(-width*.5,floor_y-height,width,height),false,tint)
	draw_set_transform(Vector2.ZERO)
	if actor.health.terminal: return
	var top := -size.y*.5
	var half := maxf(12,size.x*.5)
	if actor.health.capacity>8:
		draw_rect(Rect2(-half,top-12,half*2,4),Color("111b17"))
		draw_rect(Rect2(-half,top-12,half*2*actor.health.current/actor.health.capacity,2),Color("d4c893"))
	else:
		for i: int in ceili(actor.health.current):draw_rect(Rect2(-8+i*6,top-12,4,2),Color("d4c893"))
