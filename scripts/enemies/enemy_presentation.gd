class_name EnemyPresentation
extends Node2D
## Original generated acorn beetle skin; AI and collision remain independent.
@export var actor: EnemyActor
var _size := Vector2.ZERO
var _clock := 0.0
var _hurt_time := 0.0
var _death_time := 0.0
var _frame_weights: Dictionary = {}
var _weight := Vector2.ONE
var _lean := 0.0
static var _action_manifest: Dictionary = {}
static var _action_textures: Dictionary = {}
var feedback_sample: EnemyFeedback01
var feedback_frames: EnemyFeedback01Frames
var feedback_frame_index := -1
var feedback_anchor := Vector2.ZERO
var feedback_body: EnemyFeedback01Body
var feedback_particles: EnemyFeedback01Particles
var feedback_remains: EnemyFeedback01Remains
var hit_template: EnemyHitTemplate
var body_motion := PlainsMotion02.new(&"legacy")
var revision_visual: PlainsRevisionVisual
var lifecycle := EnemyPresentationLifecycle.new()
func _ready() -> void:
	if EnemyPresentationBinding.bind_existing(actor,self,_presentation_profile()).is_empty(): return
	_size = actor.definition.collision_size
	if PlainsRevisionSkin.supports(actor.definition):
		revision_visual = PlainsRevisionVisual.install(self,actor,body_motion)
		feedback_sample = revision_visual.sample
		feedback_particles = revision_visual.particles
		feedback_remains = revision_visual.remains
		lifecycle.bind(actor,self,_presentation_initialized,_health_changed,body_motion,feedback_sample,true)
		return
	if EnemyFeedback01.supports(actor.definition):
		feedback_sample = EnemyFeedback01.new(actor.health, actor.definition)
		body_motion.sample = feedback_sample
		feedback_frames = EnemyFeedback01Frames.new(&"legacy", actor.definition.stable_id, _feedback_body_size())
		feedback_frames.horizontal_offset = feedback_anchor.x
		feedback_body = EnemyFeedback01Body.new()
		feedback_body.configure_motion(body_motion, actor)
		feedback_body.name = "AcceptedHitBody"
		feedback_body.show_behind_parent = true
		feedback_body.visible = false
		add_child(feedback_body)
		feedback_particles = EnemyFeedback01Particles.new()
		feedback_particles.name = "AcceptedHitChips"
		feedback_particles.z_index = 1
		add_child(feedback_particles)
		feedback_particles.bind(feedback_sample, actor.damageable)
		feedback_remains = EnemyFeedback01Remains.new()
		feedback_remains.name = "AcceptedEnemyRemains"
		var stage := actor.motor.get_parent()
		stage.add_child(feedback_remains)
		stage.move_child(feedback_remains, 0)
		feedback_remains.bind(feedback_sample, actor.damageable, actor.health, actor.motor, self, actor.definition.aerial, _remains_view)
	else:
		hit_template = EnemyHitTemplate.install(actor, self)
		body_motion.sample = hit_template.sample
	lifecycle.bind(actor,self,_presentation_initialized,_health_changed,_presentation_motion(),feedback_sample,feedback_sample!=null)
	if hit_template != null: lifecycle.own_cleanup(hit_template.dispose)
	queue_redraw()

func _presentation_profile() -> StringName:
	return &"scene"

func _presentation_motion() -> RefCounted:
	return body_motion

func _exit_tree() -> void:
	if is_instance_valid(feedback_remains): feedback_remains.dispose()
	lifecycle.dispose()

func presentation_remains() -> EnemyFeedback01Remains:
	return feedback_remains if is_instance_valid(feedback_remains) else null

func synchronize_presentation() -> void:
	lifecycle.synchronize()
	if feedback_sample != null: _sync_feedback_body()

func _presentation_initialized() -> void:
	_hurt_time = 0.0
	_death_time = 0.0 if feedback_sample != null or not actor.health.terminal else 1.0
	_weight = Vector2.ONE
	_lean = 0.0
	if feedback_sample != null:
		feedback_particles.clear_for_epoch()
		_sync_feedback_body()
	queue_redraw()

func _process(delta: float) -> void:
	if not lifecycle.advance(delta): return
	_clock += delta
	if feedback_sample != null:
		_hurt_time = feedback_sample.hurt_remaining
		_death_time = feedback_sample.death_elapsed
		_sync_feedback_body()
	else:
		if actor.health.terminal: _death_time += delta
		_hurt_time = maxf(0, _hurt_time - delta)
	if feedback_sample == null or not actor.health.terminal:
		_advance_body_pose(delta)
	if revision_visual != null: revision_visual.refresh(delta)
	queue_redraw()

func _advance_body_pose(delta: float) -> void:
	var state: StringName = lifecycle.snapshot.get("state",&"idle")
	var desired := Vector2(1.12,.9) if state in [&"telegraph",&"attack"] else Vector2(.97,1.025) if state == &"recovery" else Vector2.ONE
	if actor.health.terminal: desired = Vector2(1.12,.45)
	if feedback_sample != null:
		desired = feedback_sample.pose() if actor.health.terminal else desired * feedback_sample.pose()
	elif hit_template != null and not actor.health.terminal:
		desired *= hit_template.pose()
	_weight = _weight.lerp(desired,1-exp(-delta/.075))
	_lean = lerpf(_lean,clampf(actor.motor.velocity.x/350,-1,1)*.09,1-exp(-delta/.07))
	_update_frame_weights(state,delta)

func _health_changed(result: ActorResourceResult) -> void:
	if feedback_sample != null: return
	if result.status == ActorResourceResult.Status.APPLIED and result.amount_applied < 0:
		_hurt_time = 0.14
	queue_redraw()
func _draw() -> void:
	if not lifecycle.is_bound(): return
	if actor == null:
		return
	if revision_visual != null: return
	if feedback_sample != null and actor.health.terminal: return
	var texture := PlainsRefreshAssets.object_texture(&"enemy_left" if actor.brain.direction < 0 else &"enemy_right")
	var state: StringName = actor.attack_behavior.state if actor.attack_behavior != null else &"idle"
	var facing := float(actor.brain.direction)
	var size := Vector2(_size.x * 1.45, _size.y * 1.45)
	var bob := sin(_clock * 7) * 1.2 if not actor.health.terminal else 0.0
	size *= _weight
	var tint := Color(1.0, 0.50, 0.43) if _hurt_time > 0 else Color.WHITE
	if feedback_sample != null: tint = feedback_sample.tint()
	elif hit_template != null: tint = hit_template.tint()
	if actor.health.terminal:
		tint = Color(0.65, 0.62, 0.51, maxf(0.18, 0.8 - _death_time * 0.5))
		if feedback_sample != null: tint.a = .8 * maxf(0, 1 - _death_time / EnemyFeedback01.DEATH_SECONDS)
		for mote: int in 6:
			var angle := TAU * float(mote) / 6.0
			var alpha := maxf(0, 1.0 - _death_time / EnemyFeedback01.DEATH_SECONDS) if feedback_sample != null else maxf(0, 1.0 - _death_time * 1.6)
			draw_circle(Vector2(cos(angle), sin(angle)) * minf(_death_time * 35, 25), 2, Color(0.95, 0.80, 0.48, alpha))

	if feedback_body != null:
		pass # One coherent body child owns live and hurt.
	elif ForestBibleActors.draw_enemy_body(self, actor, _clock): return
	elif EnemyPresentationBinding.view(self).get("scene_body") == &"aerial":
		var atlas := preload("res://assets/plains_v4/spatial/actors.png")
		var tilt := _lean + sin(_clock*2)*.035 + (feedback_sample.tilt() if feedback_sample != null else 0.0)
		draw_set_transform(Vector2(0,bob),tilt,Vector2(-facing,1))
		draw_texture_rect_region(atlas,Rect2(-size.x*.6,-size.y*.65,size.x*1.2,size.y*1.3),Rect2(935,570,580,445),tint)
		draw_set_transform(Vector2.ZERO)
	else:
		if actor.definition.behavior_id in [&"charger", &"sentry",&"hopper",&"fan_sentry",&"patrol"]:
			_draw_action_frame(state, facing, tint)
		else:
			draw_texture_rect(texture, Rect2(Vector2(-size.x / 2, -size.y / 2 + bob), size), false, tint)
	draw_set_transform(Vector2.ZERO)

func _draw_action_frame(state: StringName, facing: float, tint: Color) -> void:
	var root := "res://assets/plains_v3/enemies/meadow_actions/"
	if _action_manifest.is_empty():
		_action_manifest = JSON.parse_string(FileAccess.get_file_as_string(root + "manifest.json"))
	var species := "sentry" if actor.definition.behavior_id in [&"sentry",&"fan_sentry"] else "beetle"
	var data: Dictionary = _action_manifest.species[species]
	# Keep one live identity. State-specific movement comes from its limbs and
	# load/release joints, rather than dissolving unrelated whole-body drawings.
	_draw_named_frame(data,species,"death" if actor.health.terminal else "idle_a",facing,tint)

func _remains_view() -> Dictionary:
	var facing := float(actor.brain.direction)
	if feedback_frames != null:
		var bob := sin(body_motion.clock*7.0)*1.2 if actor.definition.aerial else 0.0
		return {"frames": feedback_frames, "contact_foot": global_transform * Vector2(0, _size.y*.5), "texture": feedback_frames.texture(4), "bounds": feedback_frames.bounds(4), "transform": global_transform * Transform2D(0, Vector2(facing, 1), 0, Vector2(0, feedback_anchor.y+bob)), "face": facing, "angle": global_rotation, "readable_material": false}
	if EnemyPresentationBinding.view(self).get("scene_body") == &"aerial":
		var texture := AtlasTexture.new()
		texture.atlas = preload("res://assets/plains_v4/spatial/actors.png")
		texture.region = Rect2(935, 570, 580, 445)
		var size := _size * 1.45 * _weight
		var bob := sin(_clock * 7) * 1.2
		var angle := _lean + sin(_clock * 2) * .035
		return {"texture": texture, "bounds": Rect2(-size.x*.6, -size.y*.65, size.x*1.2, size.y*1.3), "transform": global_transform * Transform2D(angle, Vector2(-facing, 1), 0, Vector2(0, bob)), "face": -facing, "angle": global_rotation + angle, "rest_size": _size * 1.45 * Vector2(1.2, 1.3) * global_scale.abs()}
	var folder := "res://assets/plains_v3/enemies/meadow_actions/"
	if _action_manifest.is_empty(): _action_manifest = JSON.parse_string(FileAccess.get_file_as_string(folder + "manifest.json"))
	var data: Dictionary = _action_manifest.species.beetle
	var canonical := _remains_named_frame(data, "death")
	var weights := _frame_weights.duplicate()
	if weights.is_empty(): weights["idle_a"] = 1.0
	var total := 0.0
	for value: float in weights.values(): total += value
	var packets: Array[Dictionary] = []
	var primary: Dictionary = {}
	var highest := -1.0
	var pose := global_transform * Transform2D(Vector2(facing*_weight.x, 0), Vector2(_lean, _weight.y), Vector2(0, _size.y*.5*(1-_weight.y)))
	for id: String in weights:
		var packet := _remains_named_frame(data, id)
		packet.transform = pose
		packet.alpha = float(weights[id]) / maxf(total, .001)
		packets.append(packet)
		if float(weights[id]) > highest:
			highest = float(weights[id])
			primary = packet.duplicate()
	primary.face = facing
	primary.angle = global_rotation
	primary.layers = packets
	primary.rest_texture = canonical.texture
	primary.rest_size = (canonical.bounds as Rect2).size * global_scale.abs()
	return primary

func _feedback_body_size() -> Vector2:
	if EnemyPresentationBinding.view(self).get("scene_body") == &"aerial":
		var source := AtlasTexture.new()
		source.atlas = preload("res://assets/plains_v4/spatial/actors.png")
		source.region = Rect2(935, 570, 580, 445)
		var size := _size*1.45
		var air_visible := EnemyFeedback01Frames.visible_bounds(source, Rect2(-size.x*.6, -size.y*.65, size.x*1.2, size.y*1.3))
		# Original region faces left, while the new authored frames face right.
		feedback_anchor = Vector2(-air_visible.get_center().x, air_visible.end.y)
		return air_visible.size
	var folder := "res://assets/plains_v3/enemies/meadow_actions/"
	if _action_manifest.is_empty(): _action_manifest = JSON.parse_string(FileAccess.get_file_as_string(folder + "manifest.json"))
	var data: Dictionary = _action_manifest.species.beetle
	var frame := _remains_named_frame(data, "idle_a")
	var visible_body := EnemyFeedback01Frames.visible_bounds(frame.texture, frame.bounds)
	feedback_anchor = Vector2(visible_body.get_center().x, visible_body.end.y)
	return visible_body.size

func _sync_feedback_body() -> void:
	if revision_visual != null:
		revision_visual.refresh(0.0)
		return
	feedback_frame_index = feedback_frames.hurt_index(feedback_sample)
	feedback_body.visible = not actor.health.terminal
	if not feedback_body.visible:
		feedback_body.flash_material.set_shader_parameter("hit_flash", 0.0)
		feedback_body.flash_material.set_shader_parameter("authored_palette", 0.0)
		feedback_body.flash_material.set_shader_parameter("frame_uv_rect", Vector4(0, 0, 1, 1))
		return
	# The exact H3 source/scale/anchor continues into live articulation. The
	# motion object never restarts when an accepted hurt pose enters or exits.
	var source := feedback_frames.texture(feedback_frame_index) if feedback_frame_index >= 0 else feedback_frames.canonical_live_texture()
	var bounds := feedback_frames.bounds(feedback_frame_index) if feedback_frame_index >= 0 else feedback_frames.canonical_live_bounds()
	var bob := sin(body_motion.clock*7.0)*1.2 if actor.definition.aerial else 0.0
	feedback_body.present(source,bounds,Vector2(0,feedback_anchor.y+bob),0.0,Vector2(float(actor.brain.direction),1.0),Color.WHITE,feedback_sample.flash_strength())

func _remains_named_frame(data: Dictionary, id: String) -> Dictionary:
	for frame: Dictionary in data.frames:
		if frame.id != id: continue
		var texture := AtlasTexture.new()
		texture.atlas = load("res://assets/plains_v3/enemies/meadow_actions/" + str(data.texture)) as Texture2D
		texture.region = Rect2(frame.region_xywh[0], frame.region_xywh[1], frame.region_xywh[2], frame.region_xywh[3])
		var factor := float(data.uniform_scale_at_default_actor) * _size.y / 32.0
		var origin := Vector2(0, _size.y*.5) - Vector2(frame.anchor_px[0], frame.anchor_px[1]) * factor
		return {"texture": texture, "bounds": Rect2(origin, Vector2(frame.region_xywh[2], frame.region_xywh[3])*factor)}
	return {}

func _draw_named_frame(data: Dictionary, species: String, frame_id: String, facing: float, tint: Color) -> void:
	var root := "res://assets/plains_v3/enemies/meadow_actions/"
	for frame: Dictionary in data.frames:
		if frame.id != frame_id: continue
		var key := species + ":" + frame_id
		if not _action_textures.has(key):
			var atlas := AtlasTexture.new()
			atlas.atlas = load(root + str(data.texture)) as Texture2D
			atlas.region = Rect2(frame.region_xywh[0], frame.region_xywh[1], frame.region_xywh[2], frame.region_xywh[3])
			_action_textures[key] = atlas
		var factor := float(data.uniform_scale_at_default_actor) * _size.y / 32.0
		var origin := Vector2(0, _size.y / 2) - Vector2(frame.anchor_px[0], frame.anchor_px[1]) * factor
		if actor.health.terminal:
			draw_set_transform_matrix(Transform2D(Vector2(facing*_weight.x,0),Vector2(_lean,_weight.y),Vector2(0,_size.y/2*(1-_weight.y))))
			draw_texture_rect(_action_textures[key],Rect2(origin,Vector2(frame.region_xywh[2],frame.region_xywh[3])*factor),false,tint)
		else:
			draw_set_transform(Vector2.ZERO,0.0,Vector2(facing,1.0))
			body_motion.draw_body(self,actor,_action_textures[key],Rect2(origin,Vector2(frame.region_xywh[2],frame.region_xywh[3])*factor),tint)
		draw_set_transform(Vector2.ZERO)
		return

func _update_frame_weights(state: StringName, delta: float) -> void:
	var frame_id := "death" if actor.health.terminal else "idle_a" if state == &"idle" and int(_clock*7)%2==0 else "idle_b" if state==&"idle" else "recovery" if state==&"blocked" else str(state)
	if _frame_weights.is_empty(): _frame_weights[frame_id]=1.0
	for id: String in _frame_weights.keys():
		_frame_weights[id]=move_toward(float(_frame_weights[id]),1.0 if id==frame_id else 0.0,delta/.075)
		if float(_frame_weights[id])<=0: _frame_weights.erase(id)
	if not _frame_weights.has(frame_id): _frame_weights[frame_id]=minf(1,delta/.075)
