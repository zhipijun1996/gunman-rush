class_name UnderworldEnemy
extends PixelPlainsEnemy
## Genuine new body art. Original state-based telegraphs remain authoritative.
var feedback: DamageFeedbackDefinition = preload("res://game/combat/damage/feedback.tres")
var accepted_hurt_count := 0
var feedback_sample: EnemyFeedback01
var feedback_frames: EnemyFeedback01Frames
var feedback_frame_index := -1
var feedback_anchor := Vector2.ZERO
var feedback_body: EnemyFeedback01Body
var feedback_particles: EnemyFeedback01Particles
var feedback_remains: EnemyFeedback01Remains
var hit_template: EnemyHitTemplate
var body_motion := PlainsMotion02.new(&"underworld")
var revision_visual: PlainsRevisionVisual

func _ready() -> void:
	if EnemyPresentationBinding.bind_existing(actor,self,&"underworld").is_empty(): return
	if actor.definition.behavior_id==&"root_bell": RootBellPulseArt.configure(self)
	if PlainsRevisionSkin.supports(actor.definition):
		revision_visual = PlainsRevisionVisual.install(self,actor,body_motion)
		feedback_sample = revision_visual.sample
		feedback_particles = revision_visual.particles
		feedback_remains = revision_visual.remains
		lifecycle.bind(actor,self,_presentation_initialized,_presentation_health_changed,body_motion,feedback_sample,true)
		return
	if EnemyFeedback01.supports(actor.definition):
		# Do not install WindchimeEnemyVisual's legacy anonymous HP listener too.
		feedback_sample = EnemyFeedback01.new(actor.health, actor.definition)
		body_motion.sample = feedback_sample
		var original: Texture2D = SPRITES[String(EnemyPresentationBinding.view(self).body_key)]
		var dimensions := _original_body_size(original)
		var visible_body := EnemyFeedback01Frames.visible_bounds(original, Rect2(-dimensions.x*.5, actor.definition.collision_size.y*.5-dimensions.y, dimensions.x, dimensions.y))
		feedback_anchor = Vector2(visible_body.get_center().x, visible_body.end.y)
		feedback_frames = EnemyFeedback01Frames.new(&"underworld", actor.definition.stable_id, visible_body.size)
		feedback_frames.horizontal_offset = feedback_anchor.x
		feedback_body = EnemyFeedback01Body.new()
		feedback_body.configure_motion(body_motion, actor)
		feedback_body.configure_underworld_palette(EnemyPresentationBinding.view(self).body_key == &"aerial")
		feedback_body.name = "AcceptedHitBody"
		# Keep the actor's world layer; only put its own HP/telegraphs above it.
		feedback_body.show_behind_parent = true
		add_child(feedback_body)
		feedback_particles = EnemyFeedback01Particles.new()
		feedback_particles.name = "AcceptedHitChips"
		feedback_particles.z_index = 1
		add_child(feedback_particles)
		feedback_particles.bind(feedback_sample, actor.damageable)
		_sync_feedback_body()
		feedback_remains = EnemyFeedback01Remains.new()
		feedback_remains.name = "AcceptedEnemyRemains"
		# Stage sibling: the formal reload path may hide the entire dead Motor.
		var stage := actor.motor.get_parent()
		stage.add_child(feedback_remains)
		stage.move_child(feedback_remains, 0)
		feedback_remains.bind(feedback_sample, actor.damageable, actor.health, actor.motor, self, actor.definition.aerial, _remains_view)
	else:
		hit_template = EnemyHitTemplate.install(actor, self)
		body_motion.sample = hit_template.sample
	lifecycle.bind(actor,self,_presentation_initialized,_presentation_health_changed,body_motion,feedback_sample,feedback_sample!=null)
	if hit_template != null: lifecycle.own_cleanup(hit_template.dispose)

func _advance_presentation(delta: float) -> void:
	# Pixel parent retains exactly its existing death/visibility/clock policy.
	super._advance_presentation(delta)
	if feedback_sample != null:
		_hurt = feedback_sample.hurt_remaining
		accepted_hurt_count = feedback_sample.accepted_hit_count
		_sync_feedback_body()
	if revision_visual != null: revision_visual.refresh(delta)

func _sync_feedback_body() -> void:
	if revision_visual != null:
		revision_visual.refresh(0.0)
		return
	feedback_frame_index = feedback_frames.hurt_index(feedback_sample)
	feedback_body.visible = not actor.health.terminal
	if not feedback_body.visible:
		# Keep the accepted flash receipt, while the sibling now owns the pixels.
		feedback_body.flash_material.set_shader_parameter("hit_flash", 0.0 if feedback_sample.restored_terminal else feedback_sample.flash_strength())
		feedback_body.flash_material.set_shader_parameter("authored_palette", 0.0)
		feedback_body.flash_material.set_shader_parameter("frame_uv_rect", Vector4(0, 0, 1, 1))
		return
	feedback_body.configure_underworld_palette(EnemyPresentationBinding.view(self).body_key == &"aerial")
	# H0..H3 and the live neutral share one family/anchor and the same ongoing
	# wing/leg joints. No old SPRITES body is swapped in at hurt exit.
	var source := feedback_frames.texture(feedback_frame_index) if feedback_frame_index >= 0 else feedback_frames.canonical_live_texture()
	var bounds := feedback_frames.bounds(feedback_frame_index) if feedback_frame_index >= 0 else feedback_frames.canonical_live_bounds()
	var bob := body_motion.body_bob(actor.definition.behavior_id) if actor.definition.aerial else 0.0
	var lean := (body_motion.tension*.15+body_motion.release*.12-body_motion.recovery*.10)*float(actor.brain.direction) if actor.definition.behavior_id==&"diver" else 0.0
	feedback_body.present(source, bounds, Vector2(0, feedback_anchor.y+bob), lean, Vector2(float(actor.brain.direction), 1.0), Color.WHITE, feedback_sample.flash_strength())

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
	# Handoff uses the exact same locomotion clock and bob as the live body.
	var flutter := body_motion.body_bob(actor.definition.behavior_id) if actor.definition.aerial else 0.0
	return {"frames": feedback_frames, "contact_foot": global_transform * Vector2(0, actor.definition.collision_size.y*.5), "texture": feedback_frames.texture(4), "bounds": feedback_frames.bounds(4), "transform": global_transform * Transform2D(0, Vector2(face, 1), 0, Vector2(0, feedback_anchor.y+flutter)), "face": face, "angle": global_rotation, "readable_material": true}

func _presentation_initialized() -> void:
	super._presentation_initialized()
	if feedback_sample != null:
		feedback_particles.clear_for_epoch()
		_sync_feedback_body()
	queue_redraw()

func synchronize_presentation() -> void:
	lifecycle.synchronize()
	if feedback_sample != null: _sync_feedback_body()

func presentation_remains() -> EnemyFeedback01Remains:
	return feedback_remains if is_instance_valid(feedback_remains) else null

func _exit_tree() -> void:
	if is_instance_valid(feedback_remains): feedback_remains.dispose()
	lifecycle.dispose()

func _presentation_health_changed(result: ActorResourceResult) -> void:
	if feedback_sample != null: return
	if result.operation != &"damage" or result.status != ActorResourceResult.Status.APPLIED or result.amount_applied >= 0 or result.snapshot.terminal: return
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
	if not lifecycle.is_bound(): return
	if actor == null: return
	if feedback_sample != null and actor.health.terminal: return
	var behavior := String(actor.definition.behavior_id)
	var state: StringName = actor.attack_behavior.state if actor.attack_behavior!=null else &"idle"
	if not actor.health.terminal: _telegraph(state,StringName(behavior))
	if revision_visual != null: return
	var key := String(EnemyPresentationBinding.view(self).body_key)
	if not SPRITES.has(key): return
	var source: Texture2D = SPRITES[key]
	var size := actor.definition.collision_size
	var width := maxf(size.x+8,28)
	var height := width*source.get_height()/source.get_width()
	if height>size.y+14:
		width *= (size.y+14)/height
		height = size.y+14
	var floor_y := size.y*.5
	var tint := hit_template.tint() if hit_template != null else Color.WHITE
	if feedback_body == null:
		# The old terminal fade and vertical fall remain owned by the parent.
		var offset := Vector2(0, _death*18.0) if actor.health.terminal else Vector2.ZERO
		draw_set_transform(offset, 0.0, Vector2(float(actor.brain.direction),1.0))
		body_motion.draw_body(self, actor, source, Rect2(-width*.5,floor_y-height,width,height), tint)

	draw_set_transform(Vector2.ZERO)
	if actor.health.terminal: return
