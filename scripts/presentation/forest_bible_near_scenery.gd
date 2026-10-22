class_name ForestBibleNearScenery
extends Node2D
## One-source, first-golden candidate. Complete Plains tree pixels are rooted on
## real exposed static tops. No collisions, RNG, camera, save, audio or actor writes.
const LAYOUT: String = "forest-bible-world-v15"
const SOURCE_PATH: String = "res://assets/underworld_plains/decor/chime_props.png"
const SOURCE_METADATA: String = "res://assets/underworld_plains/decor/chime_props.json"
const SOURCE: Texture2D = preload("res://assets/underworld_plains/decor/chime_props.png")
const FIRST_GOLDEN_LIMIT: int = 1
const MAX_OPACITY: float = 0.22
const ROOT_MARGIN: float = 8.0
const QUIET_HOSTS: Array[String] = ["hollow__inner_root", "hollow__outer_root", "bible_backbranch__recovery", "broken_arch__root_arch"]
var placements: Array[Dictionary] = []
var omitted: Array[Dictionary] = []
var _solids: Array[Rect2] = []
var _blockers: Array[Dictionary] = []
var _actor: WeakRef
var _source_rect: Rect2
var _source_foot: Vector2
var _scale: float = 0.0
var _enabled: bool = false
var _reduced: bool = false
var _audit: Dictionary = {}
var _draw_audit: Array[Dictionary] = []

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func configure(manifest: Dictionary, player: Node2D, reduced: bool = false) -> bool:
	_enabled = false
	set_process(false)
	placements.clear()
	omitted.clear()
	_solids.clear()
	_blockers.clear()
	_draw_audit.clear()
	_actor = weakref(player) if is_instance_valid(player) else null
	_reduced = reduced
	_audit = {"scope":"one quiet support candidate, not accepted three-layer art", "layout":str(manifest.get("layout_version", "")), "manifest_hash":str(manifest.get("manifest_hash", "")), "source":SOURCE_PATH, "metadata":SOURCE_METADATA, "current_placement_limit":FIRST_GOLDEN_LIMIT, "maximum_requested_instances":2, "world_fixed":true, "screen_motion_per_camera_delta":[-1.0,-1.0], "root_motion_wu":0.0, "dynamic_motion":"none; existing ForestBibleAmbience owns local leaf tips", "collision":false, "standing_edge":false}
	if not ForestBiblePresentation.enabled(manifest) or not is_instance_valid(player):
		_audit.rejected = "wrong_layout_or_missing_actor"
		queue_redraw()
		return false
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_METADATA))
	if not metadata is Dictionary or not metadata.get("regions") is Dictionary or not metadata.regions.get("tree") is Dictionary:
		_audit.rejected = "missing_existing_plain_tree_metadata"
		return false
	var tree: Dictionary = metadata.regions.tree
	if not _valid_rect(tree.get("region")) or not _valid_point(tree.get("foot")):
		_audit.rejected = "invalid_existing_plain_source_bounds"
		return false
	_source_rect = _rect(tree.region)
	_source_foot = _point(tree.foot)
	_scale = float(tree.get("world_height", 0.0))/_source_rect.size.y
	if not is_finite(_scale) or _scale <= 0.0 or _source_foot.x < 0.0 or _source_foot.x > _source_rect.size.x or _source_foot.y <= 0.0 or _source_foot.y > _source_rect.size.y:
		_audit.rejected = "invalid_existing_plain_scale_or_root"
		return false
	_audit.source_region = tree.region.duplicate()
	_audit.source_foot = tree.foot.duplicate()
	_audit.source_scale = _scale
	_audit.declared_source_sha256 = str(metadata.get("source_sha256", ""))
	_audit.raw_source_sha256 = FileAccess.get_sha256(SOURCE_PATH) if FileAccess.file_exists(SOURCE_PATH) else "unavailable_in_imported_host"
	var hosts: Dictionary = {}
	for row: Dictionary in manifest.get("platforms", []):
		if bool(row.get("one_way", false)) or row.has("motion") or not _valid_rect(row.get("rect")): continue
		var solid: Rect2 = _rect(row.rect)
		_solids.append(solid)
		if str(row.get("id", "")) in QUIET_HOSTS: hosts[str(row.id)] = solid
	_build_protection(manifest)
	var plan: Dictionary = PixelFormalTerrain.geometry_plan(_solids)
	for host_id: String in QUIET_HOSTS:
		if placements.size() >= FIRST_GOLDEN_LIMIT: break
		if not hosts.has(host_id):
			omitted.append({"host":host_id,"reason":"no_static_solid_host"})
			continue
		var host: Rect2 = hosts[host_id]
		var has_top: bool = false
		for edge: Vector4 in plan.edges:
			if not is_equal_approx(edge.y, edge.w) or edge.z <= edge.x or not is_equal_approx(edge.y, host.position.y): continue
			var left: float = maxf(edge.x, host.position.x)
			var right: float = minf(edge.z, host.end.x)
			if right <= left: continue
			has_top = true
			_try_edge(host_id, Vector4(left, edge.y, right, edge.y))
			if placements.size() >= FIRST_GOLDEN_LIMIT: break
		if not has_top: omitted.append({"host":host_id,"reason":"no_exposed_static_top"})
	_enabled = true
	set_process(true)
	queue_redraw()
	return true

func set_reduced_effects(value: bool) -> void:
	# The tree source and root are static in both modes. All moving leaves stay
	# with the existing ambience service and its own reduced/pause lifecycle.
	_reduced = value
	queue_redraw()

func position_audit() -> Dictionary:
	var result: Dictionary = _audit.duplicate(true)
	result.configured = _enabled
	result.reduced = _reduced
	result.placements = placements.duplicate(true)
	result.omitted = omitted.duplicate(true)
	result.placed_count = placements.size()
	result.has_third_source_placement = not placements.is_empty()
	result.last_draw = _draw_audit.duplicate(true)
	result.blocker_count = _blockers.size()
	return result

func _try_edge(host_id: String, edge: Vector4) -> void:
	var size: Vector2 = _source_rect.size*_scale
	var anchor: Vector2 = _source_foot*_scale
	var minimum: float = edge.x+ROOT_MARGIN+anchor.x
	var maximum: float = edge.z-ROOT_MARGIN-(size.x-anchor.x)
	if maximum < minimum:
		omitted.append({"host":host_id,"reason":"full_original_root_span_not_supported","exposed_top":[edge.x,edge.y,edge.z,edge.w]})
		return
	# Two exterior sockets only. No unbounded search, random stream or shrinking
	# the original tree until it happens to fit a dangerous gameplay gap.
	for x: float in [minimum, maximum]:
		var foot: Vector2 = Vector2(x,edge.y)
		var bounds: Rect2 = Rect2(foot-anchor,size)
		var reason: String = _omission_reason(bounds,foot)
		if not reason.is_empty():
			omitted.append({"host":host_id,"foot":[foot.x,foot.y],"bounds":_array_rect(bounds),"reason":reason})
			continue
		placements.append({"host":host_id,"foot":[foot.x,foot.y],"bounds":_array_rect(bounds),"source_region":_array_rect(_source_rect),"source_foot":[_source_foot.x,_source_foot.y],"source_scale":_scale,"support_top":[edge.x,edge.y,edge.z,edge.w],"whole_root_span":[bounds.position.x,bounds.end.x],"collision":false,"standing_edge":false,"world_fixed":true})
		return

func _omission_reason(bounds: Rect2, foot: Vector2) -> String:
	for blocker: Dictionary in _blockers:
		var protected: Rect2 = blocker.rect
		if bounds.grow(8.0).intersects(protected): return str(blocker.reason)
	var aerial: Rect2 = Rect2(bounds.position,Vector2(bounds.size.x,maxf(0.0,foot.y-bounds.position.y-0.5)))
	for solid: Rect2 in _solids:
		if aerial.intersects(solid): return "overhead_or_side_solid"
	return ""

func _build_protection(manifest: Dictionary) -> void:
	for danger: Variant in manifest.get("dangers", []): _protect_rect(danger,32.0,"danger_signal")
	_protect_rect(manifest.get("boss_arena"),64.0,"battle_arena")
	var gate: Dictionary = manifest.get("vine_gate", {})
	_protect_rect(gate.get("rect"),48.0,"gate_signal")
	var practice: Dictionary = manifest.get("practice_bell_contract", {})
	_protect_rect(practice.get("complete_motion_sweep"),32.0,"practice_bell_motion_sweep")
	var cast: Variant = practice.get("gate_cast_segment")
	if cast is Array and cast.size() == 2: _protect_segment(cast[0],cast[1],32.0,"practice_bell_cast")
	for structure: Dictionary in manifest.get("scene_structures", []):
		for window: Variant in structure.get("open_voids", []): _protect_rect(window,32.0,"real_cavity_or_cross_window")
	for anchor: Dictionary in manifest.get("hook_anchors", []): _protect_point(anchor.get("position"),Vector2(96,112),"functional_hook_signal")
	for site: Dictionary in manifest.get("forest_discoveries", []): _protect_point(site.get("position"),Vector2(192,208),"discovery_reader_and_prop")
	for reward: Dictionary in manifest.get("rewards", []): _protect_point(reward.get("position"),Vector2(160,176),"reward_signal")
	for shortcut: Dictionary in manifest.get("forest_shortcuts", []): _protect_rect(shortcut.get("rect"),32.0,"shortcut_window")
	_protect_point(manifest.get("merchant_position"),Vector2(192,208),"merchant_and_reader")
	_protect_point(manifest.get("spawn"),Vector2(160,160),"spawn_readability")
	for connection: Dictionary in manifest.get("connections", []):
		_protect_point(connection.get("landing"),Vector2(128,144),"actual_airborne_receiver")
		for step: Dictionary in connection.get("steps", []):
			_protect_point(step.get("takeoff"),Vector2(96,112),"actual_takeoff")
			_protect_point(step.get("landing"),Vector2(128,144),"actual_landing")
	for enemy: Dictionary in manifest.get("enemies", []):
		if _valid_rect(enemy.get("authored_body_sweep")):
			_protect_rect(enemy.authored_body_sweep,40.0,"enemy_patrol_and_telegraph")
		elif _valid_point(enemy.get("position")):
			var at: Vector2 = _point(enemy.position)
			var radius: float = maxf(0.0,float(enemy.get("patrol_radius",0.0)))
			_blockers.append({"rect":Rect2(at-Vector2(radius+64,96),Vector2(radius*2+128,192)),"reason":"enemy_fallback_patrol"})
		_protect_segment(enemy.get("line_start"),enemy.get("line_end"),40.0,"enemy_thread_warning")
		for strand: Dictionary in enemy.get("web_strands", []): _protect_segment(strand.get("start"),strand.get("end"),40.0,"weaver_window_and_warning")
	var crossbranch: Dictionary = manifest.get("crossbranch_contract", {})
	var cross_sweep: Rect2 = Rect2()
	for shore: Dictionary in crossbranch.get("shore_rows", []):
		if not _valid_rect(shore.get("rect")): continue
		var rect: Rect2 = _rect(shore.rect)
		cross_sweep = cross_sweep.merge(rect) if cross_sweep.has_area() else rect
	if cross_sweep.has_area(): _blockers.append({"rect":cross_sweep.grow(96.0),"reason":"crossbranch_flight_between_shores"})

func _protect_point(value: Variant, size: Vector2, reason: String) -> void:
	if not _valid_point(value): return
	_blockers.append({"rect":Rect2(_point(value)-size*0.5,size),"reason":reason})

func _protect_rect(value: Variant, margin: float, reason: String) -> void:
	if not _valid_rect(value): return
	_blockers.append({"rect":_rect(value).grow(margin),"reason":reason})

func _protect_segment(start: Variant, finish: Variant, margin: float, reason: String) -> void:
	if not _valid_point(start) or not _valid_point(finish): return
	var a: Vector2 = _point(start)
	var b: Vector2 = _point(finish)
	_blockers.append({"rect":Rect2(a.min(b),a.max(b)-a.min(b)).grow(margin),"reason":reason})

func _process(_delta: float) -> void:
	# Redraw for real actor/camera readability only. There is no independent
	# wind clock or whole-tree movement to drift from the ambience service.
	queue_redraw()

func _draw() -> void:
	_draw_audit.clear()
	if not _enabled or not is_inside_tree(): return
	var player: Node2D = _actor.get_ref() as Node2D if _actor != null else null
	if player == null: return
	var inverse: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var view_size: Vector2 = get_viewport_rect().size
	var view: Rect2 = Rect2(inverse*Vector2.ZERO,inverse*view_size-inverse*Vector2.ZERO)
	for placement: Dictionary in placements:
		var bounds: Rect2 = _rect(placement.bounds)
		if not view.intersects(bounds): continue
		var nearest: Vector2 = player.global_position.clamp(bounds.position,bounds.end)
		var actor_distance: float = player.global_position.distance_to(nearest)
		var opacity: float = MAX_OPACITY*smoothstep(64.0,128.0,actor_distance)
		var foot: Vector2 = _point(placement.foot)
		var screen_foot: Vector2 = get_viewport().get_canvas_transform()*foot
		_draw_audit.append({"host":placement.host,"world_foot":placement.foot.duplicate(),"screen_foot":[screen_foot.x,screen_foot.y],"opacity":opacity,"actor_distance_to_bounds":actor_distance,"actor_suppressed":opacity <= 0.0,"source":SOURCE_PATH})
		if opacity <= 0.0: continue
		draw_texture_rect_region(SOURCE,Rect2(to_local(bounds.position),bounds.size),_source_rect,Color(0.42,0.48,0.43,opacity))

static func _valid_point(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for number: Variant in value:
		if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)): return false
	return true

static func _valid_rect(value: Variant) -> bool:
	if not value is Array or value.size() != 4: return false
	for number: Variant in value:
		if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)): return false
	return float(value[2]) > 0.0 and float(value[3]) > 0.0

static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))

static func _array_rect(rect: Rect2) -> Array[float]:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func _exit_tree() -> void:
	_enabled = false
	set_process(false)
	_actor = null
	placements.clear()
	omitted.clear()
	_solids.clear()
	_blockers.clear()
	_draw_audit.clear()
