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

static func install(stage: Node2D, manifest: Dictionary, enemies: Array[EnemyMotor], enemy_manifest: Array[Dictionary]) -> void:
	# The owning App checks the concrete region. Shared enemy presentation is
	# loaded by DemoStage, so it must not depend back on a derived region class.
	if not ForestBiblePresentation.enabled(manifest): return
	stage.set_meta(METADATA, true)
	stage.set_meta(SHARED_OBJECT_METADATA, true)
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Reuse the complete formal renderer only for the already assembled charger.
	for index: int in enemies.size():
		var body: EnemyMotor = enemies[index]
		var actor := body.get_node_or_null("Actor") as EnemyActor
		if actor != null:
			var host := body.get_node_or_null("Presentation")
			if host != null: EnemyPresentationBinding.bind_existing(actor, host, &"forest", &"forest_bible")
		if actor != null and actor.definition != null and actor.definition.behavior_id == &"forest_swing_pod":
			_install_tether_attachment(stage, manifest, enemy_manifest, index, actor)
		if actor == null or actor.definition == null or actor.definition.behavior_id != &"charger": continue
		EnemyPresentationBinding.replace(actor, &"underworld")

static func _install_tether_attachment(stage: Node2D, manifest: Dictionary, enemy_manifest: Array[Dictionary], index: int, actor: EnemyActor) -> void:
	# Exact serialized placement/host binding; never search the nearest branch.
	var rows: Array = manifest.get("enemies", [])
	if index >= enemy_manifest.size() or index >= rows.size(): return
	var row: Dictionary = enemy_manifest[index]
	if rows[index] != row or row.get("stable_id") != String(actor.definition.stable_id): return
	var origin_row: Variant = row.get("tether_origin")
	if not origin_row is Array or origin_row.size() != 2: return
	var host_id: String = str(row.get("tether_host_support_id", ""))
	if host_id.is_empty(): return
	for host: Dictionary in manifest.get("platforms", []):
		if host.get("id") != host_id: continue
		var rect_row: Variant = host.get("rect")
		if not rect_row is Array or rect_row.size() != 4: return
		for value: Variant in origin_row + rect_row:
			if not (value is int or value is float) or not is_finite(float(value)): return
		var origin := Vector2(origin_row[0], origin_row[1])
		var support := Rect2(rect_row[0], rect_row[1], rect_row[2], rect_row[3])
		if support.size.x <= 0.0 or support.size.y <= 0.0: return
		if origin.x < support.position.x or origin.x > support.end.x or origin.y < support.position.y or origin.y > support.end.y: return
		var art := actor.motor.get_node_or_null("Presentation") as Node2D
		if art == null: return
		var attachment := {"actor_id": actor.get_instance_id(), "placement_id": str(row.id), "host_id": host_id, "support_top": stage.to_global(Vector2(origin.x, support.position.y)), "tether_root": stage.to_global(origin)}
		attachment.make_read_only()
		art.set_meta(TETHER_ATTACHMENT_METADATA, attachment)
		return

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

static func draw_boss_body(canvas: Node2D, encounter: ThornForestEncounter) -> bool:
	if not active(canvas) or not is_instance_valid(encounter) or encounter.definition == null: return false
	if encounter is ThornQueenCanopyEncounter:
		if encounter.definition.stable_id != &"thorn_queen_canopy_v3" or encounter.definition.collision_size != Vector2(48.0, 54.0): return false
		canvas.draw_texture_rect(QUEEN_BODY, QUEEN_BOUNDS, false, EnemyHitTemplate.body_tint(canvas))
		return true
	if not encounter is RootbellGuardianV2: return false
	if encounter.definition.stable_id != &"rootbell_guardian_v2": return false
	if encounter.definition.collision_size != Vector2(72.0, 96.0): return false
	canvas.draw_texture_rect(GUARDIAN_BODY, GUARDIAN_BOUNDS, false, EnemyHitTemplate.body_tint(canvas))
	if not encounter.core_open:
		# Dim only the authored heart pixels; armor/feet stay at their real anchors.
		canvas.draw_texture_rect_region(GUARDIAN_BODY,Rect2(-6,-10,16,10),Rect2(30,36,16,10),Color(0.30,0.55,0.38))
	return true

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
