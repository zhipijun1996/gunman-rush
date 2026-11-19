class_name ForestBibleActors
extends RefCounted
## User continuity correction: independent ecology atlas is withdrawn.
## Native forest bodies are candidates for scoped v15 composition review.
## Other bodies remain pending; accepted-state cues stay with their consumers.
const METADATA := &"forest_bible_actor_art"
const SHARED_OBJECT_METADATA := &"forest_bible_shared_objects"
const TETHER_ATTACHMENT_METADATA := &"forest_bible_tether_attachment"
const WEAVER_BODY: Texture2D = preload("res://assets/forest_bible_v2/native/weaver_silk_bell_v5.png")
const WEAVER_BOUNDS: Rect2 = Rect2(-16.0, -16.0, 32.0, 32.0)
const GUARDIAN_BODY: Texture2D = preload("res://assets/forest_bible_v2/native/fine_32/guardian.png")
# Fine source foot(36,94) at1wu aligns with unchanged collision foot y=48.
const GUARDIAN_BOUNDS: Rect2 = Rect2(-36.0, -46.0, 72.0, 96.0)
const QUEEN_BODY: Texture2D = preload("res://assets/forest_bible_v2/native/fine_32/queen.png")
# Crown is non-hurt decoration. Body collision and living knot Nodes stay external.
const QUEEN_BOUNDS: Rect2 = Rect2(-36.0, -39.0, 72.0, 68.0)
const BEETLE_BODY: Texture2D = preload("res://assets/forest_bible_v2/native/fine_32/beetle.png")
# Fine source foot(24,30)*.75 maps to unchanged collision foot y=12.
const BEETLE_BOUNDS: Rect2 = Rect2(-18.0, -10.5, 36.0, 24.0)
# Four concrete biological body consumers, retaining their real physics/cues.
const ECOLOGY_BODIES := {
	&"forest_lantern": {"texture": preload("res://assets/forest_bible_v2/native/fine_32/lantern.png"), "bounds": Rect2(-18.0, -15.0, 36.0, 30.0), "collision": Vector2(24.0, 24.0), "mirror": true},
	&"forest_swing_pod": {"texture": preload("res://assets/forest_bible_v2/native/fine_32/swing_pod.png"), "bounds": Rect2(-13.5, -16.5, 27.0, 33.0), "collision": Vector2(26.0, 30.0), "mirror": false},
	&"forest_seed_sentry": {"texture": preload("res://assets/forest_bible_v2/native/fine_32/seed_sentry.png"), "bounds": Rect2(-16.5, -19.5, 33.0, 39.0), "collision": Vector2(30.0, 36.0), "mirror": false},
	&"forest_crossbranch": {"texture": preload("res://assets/forest_bible_v2/native/fine_32/crossbranch.png"), "bounds": Rect2(-18.0, -18.5, 36.0, 36.0), "collision": Vector2(28.0, 32.0), "mirror": true}
}
const WEAVER_TERMINAL_TINT: Color = Color(0.42, 0.46, 0.43, 1.0)

static func draw_tether_attachment(canvas: Node2D, actor: EnemyActor) -> void:
	if not active(canvas) or not is_instance_valid(actor): return
	if not canvas.has_meta(TETHER_ATTACHMENT_METADATA): return
	var attachment: Variant = canvas.get_meta(TETHER_ATTACHMENT_METADATA, null)
	if not attachment is Dictionary or attachment.get("actor_id") != actor.get_instance_id(): return
	# A thin descending woody stalk, with no horizontal standable-looking cap.
	canvas.draw_line(canvas.to_local(attachment.support_top), canvas.to_local(attachment.tether_root), Color("745631"), 2.0, false)

static func active(canvas: Node) -> bool:
	var cursor := canvas
	while cursor != null:
		if cursor.has_meta(METADATA): return bool(cursor.get_meta(METADATA))
		cursor = cursor.get_parent()
	return false

static func draw_enemy_body(canvas: Node2D, actor: EnemyActor, age: float = 0.0) -> bool:
	if not is_instance_valid(actor) or actor.definition == null: return false
	var binding := EnemyPresentationBinding.view(canvas)
	if binding.get("body_theme") != &"forest_bible" or binding.get("actor_id") != actor.get_instance_id(): return false
	var behavior_id: StringName = actor.definition.behavior_id
	var hit_pose := EnemyHitTemplate.body_pose(canvas)
	var hit_origin := Vector2.ZERO if actor.definition.aerial else Vector2(0, actor.definition.collision_size.y*.5*(1.0-hit_pose.y))
	if ECOLOGY_BODIES.has(behavior_id):
		var body: Dictionary = ECOLOGY_BODIES[behavior_id]
		if actor.definition.stable_id != behavior_id or actor.definition.collision_size != body.collision: return false
		var facing: float = 1.0
		if bool(body.mirror):
			if not is_instance_valid(actor.brain) or actor.brain.direction not in [-1, 1]: return false
			facing = float(actor.brain.direction)
		var tint: Color = WEAVER_TERMINAL_TINT if actor.health != null and actor.health.terminal else Color.WHITE
		var state: StringName = actor.attack_behavior.state if actor.attack_behavior != null else &"idle"
		if actor.health != null and not actor.health.terminal:
			if behavior_id == &"forest_swing_pod" and state == &"blocked": tint = Color("a38e74")
			elif behavior_id == &"forest_crossbranch" and state == &"telegraph": tint = Color(1.15,0.94,0.58)
			elif behavior_id == &"forest_crossbranch" and state == &"blocked": tint = Color(0.74,0.43,0.43)
		tint = EnemyHitTemplate.body_tint(canvas, tint)
		canvas.draw_set_transform(hit_origin, 0.0, Vector2(facing*hit_pose.x, hit_pose.y))
		if not ForestMotion02.draw_body(canvas, actor, body.texture as Texture2D, body.bounds, facing, tint):
			if behavior_id == &"forest_lantern":
				_draw_lantern(canvas, body.texture as Texture2D, age, actor.health.terminal, tint)
			else:
				canvas.draw_texture_rect(body.texture as Texture2D, body.bounds, false, tint)
		canvas.draw_set_transform(Vector2.ZERO)
		return true
	if behavior_id == &"forest_bark_beetle":
		if actor.definition.stable_id != &"forest_bark_beetle" or actor.definition.collision_size != Vector2(36.0, 24.0): return false
		if not is_instance_valid(actor.brain) or actor.brain.direction not in [-1, 1]: return false
		# Mirror only the body. Restore local drawing before real shield/aim cues.
		canvas.draw_set_transform(hit_origin, 0.0, Vector2(float(actor.brain.direction)*hit_pose.x, hit_pose.y))
		if not ForestMotion02.draw_body(canvas, actor, BEETLE_BODY, BEETLE_BOUNDS, float(actor.brain.direction), EnemyHitTemplate.body_tint(canvas)):
			canvas.draw_texture_rect(BEETLE_BODY, BEETLE_BOUNDS, false, EnemyHitTemplate.body_tint(canvas))
		canvas.draw_set_transform(Vector2.ZERO)
		return true
	if behavior_id != &"forest_thread_spider" and behavior_id != &"forest_bible_weaver": return false
	var body_tint: Color = Color.WHITE
	if actor.health != null and actor.health.terminal: body_tint = WEAVER_TERMINAL_TINT
	body_tint = EnemyHitTemplate.body_tint(canvas, body_tint)
	canvas.draw_set_transform(hit_origin, 0.0, hit_pose)
	if not ForestMotion02.draw_body(canvas, actor, WEAVER_BODY, WEAVER_BOUNDS, 1.0, body_tint):
		canvas.draw_texture_rect(WEAVER_BODY, WEAVER_BOUNDS, false, body_tint)
	canvas.draw_set_transform(Vector2.ZERO)
	return true

static func _draw_lantern(canvas: Node2D, texture: Texture2D, age: float, terminal: bool, tint: Color) -> void:
	# Fine48x40 body, mapped to unchanged36x30 world bounds. Only remapped
	# real wing regions move; age14 frequency and 3/6/9wu poses remain unchanged.
	canvas.draw_texture_rect_region(texture,Rect2(-18,-15,36,9),Rect2(0,0,48,12),tint)
	canvas.draw_texture_rect_region(texture,Rect2(-6,-6,12,9),Rect2(16,12,16,12),tint)
	canvas.draw_texture_rect_region(texture,Rect2(-18,3,36,12),Rect2(0,24,48,16),tint)
	var height := 3.0 if terminal else 6.0+roundf(sin(age*14.0))*3.0
	canvas.draw_texture_rect_region(texture,Rect2(-18,-1.5-height*0.5,12,height),Rect2(0,12,16,12),tint)
	canvas.draw_texture_rect_region(texture,Rect2(6,-1.5-height*0.5,12,height),Rect2(32,12,16,12),tint)

static func draw_mobile_bell(canvas: Node2D, radius: float, counter_active: bool) -> bool:
	var cursor: Node = canvas
	while cursor != null:
		if bool(cursor.get_meta(SHARED_OBJECT_METADATA, false)):
			var texture := UnderworldTerrain.mechanism_bell_texture()
			var diameter := maxf(1.0, radius*2.0)
			var size := Vector2(texture.get_size())*diameter/maxf(texture.get_width(), texture.get_height())
			canvas.draw_texture_rect(texture, Rect2(-size*0.5, size), false, Color(1.15, 1.05, 0.80, 1.0) if counter_active else Color.WHITE)
			return true
		cursor = cursor.get_parent()
	return false
