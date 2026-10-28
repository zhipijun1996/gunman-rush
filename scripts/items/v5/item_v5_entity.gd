class_name ItemV5Entity
extends Node2D
## Presentation only. Item modules own the accepted attack and world-clock step.
## This node never moves an actor, queries damage, spends energy or ticks itself.
var kind: StringName
var direction := Vector2.RIGHT
var age := 0.0
var radius := 10.0
var progress := 0.0
var evolved := 0
var beam_remaining := 0.0
var beam_end := Vector2.ZERO
var cone_half_angle := 0.65
var marked := false
var _step_position := Vector2.ZERO
var _has_visual_step := false
var _art_draws := 0
var _art_missing := 0

static func read_tuning() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/item_v5_entities.json"))
	if not parsed is Dictionary or parsed.get("schema_version") != 1: return {}
	var fields := {
		"projection":["speed","flywheel_lifetime_s","throw_range_px","throw_lifetime_s","throw_main_acquire_radius_px","throw_chain_radius_px","split_half_angle_rad","collision_radius_px"],
		"trap":["ground_probe_px","half_base_width_px","ground_tolerance_px","floor_normal_min_up_dot","surface_offset_px"],
		"pulse":["interval_s","half_angle_rad","visual_duration_s"],
		"companion":["acquire_radius_px","orbit_radius_px","large_orbit_radius_px","orbit_height_px","orbit_speed_rad_s","follow_speed","temporary_attack_interval_s","beam_visible_s"],
		"visual":["flywheel_radius_px","throw_radius_px","trap_radius_px","drone_radius_px","large_drone_radius_px"]
	}
	for section: String in fields:
		if not parsed.get(section) is Dictionary: return {}
		for field: String in fields[section]:
			var value: Variant = parsed[section].get(field)
			if not value is float and not value is int: return {}
			if not is_finite(float(value)) or (field != "orbit_height_px" and float(value) <= 0): return {}
	if float(parsed.trap.floor_normal_min_up_dot) > 1 or float(parsed.projection.split_half_angle_rad) >= PI*0.5 or float(parsed.pulse.half_angle_rad) >= PI: return {}
	return parsed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 6
	set_process(false)
	set_physics_process(false)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func step_visual(world_delta: float) -> void:
	# Modules move the visual immediately after this call; draw reads only the
	# resulting displacement to orient an authored trail on the real path.
	_step_position = global_position
	_has_visual_step = true
	age += world_delta
	beam_remaining = maxf(0.0, beam_remaining-world_delta)
	queue_redraw()

func _draw() -> void:
	if _draw_art_body(): return
	var brass := Color("d4ac64")
	var dark := Color("19272c")
	var glow := Color("77d3d1")
	if kind == &"pulse":
		var angle := direction.angle()
		draw_arc(Vector2.ZERO, radius*clampf(progress, 0.05, 1.0), angle-cone_half_angle, angle+cone_half_angle, 22, Color(0.83, 0.67, 0.39, (1.0-progress)*0.6), 2.0, false)
		return
	if kind == &"flywheel":
		draw_set_transform(Vector2.ZERO, age*14.0)
		_gear(radius, brass, dark)
		draw_line(Vector2(-radius*0.7, 0), Vector2(radius*0.7, 0), glow, 2, false)
		draw_set_transform(Vector2.ZERO)
	elif kind == &"throw":
		draw_circle(Vector2.ZERO, radius, dark)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 12, brass, 2, false)
		draw_rect(Rect2(-4, -radius-3, 8, 4), brass)
		draw_polyline(PackedVector2Array([Vector2(-3,-5), Vector2(2,-1), Vector2(-2,2), Vector2(3,6)]), glow, 2, false)
	elif kind == &"trap":
		draw_rect(Rect2(-radius, -3, radius*2, 5), dark)
		draw_line(Vector2(-radius, 1), Vector2(radius, 1), brass, 2, false)
		for i: int in 3:
			var x := float(i-1)*radius*0.7
			draw_colored_polygon(PackedVector2Array([Vector2(x-3,-2), Vector2(x,-radius), Vector2(x+3,-2)]), brass)
		draw_circle(Vector2(0,-3), 2, glow)
	else:
		var armor := Color("93a0a7") if kind == &"growth_drone" else brass
		var wing := radius*1.7
		draw_line(Vector2(-wing, 1), Vector2(wing, 1), armor, 3, false)
		for side: int in [-1,1]:
			draw_rect(Rect2(float(side)*wing-3, -4, 6, 10), dark)
			draw_line(Vector2(float(side)*wing-3,-5), Vector2(float(side)*wing+3,-5), glow, 2, false)
		_gear(radius, armor, dark)
		draw_line(Vector2.ZERO, Vector2.UP*(radius*0.6), glow, 2, false)
		draw_line(Vector2.ZERO, Vector2.RIGHT*(radius*0.4), glow, 2, false)
		for i: int in evolved:
			draw_circle(Vector2(float(i)*5-2.5, radius+4), 1.5, brass)
		if marked:
			draw_arc(Vector2.ZERO, radius+4, -PI*0.8, -PI*0.2, 8, glow, 1, false)
	if beam_remaining > 0:
		draw_line(Vector2.ZERO, to_local(beam_end), Color(0.46,0.83,0.82,0.75), 1.5, false)

func visual_snapshot() -> Dictionary:
	return {"kind":kind,"origin":get_meta("item_definition_id",&""),"age":age,"art_draws":_art_draws,"art_missing":_art_missing,"clip":ItemArtLibrary.entity_clip(kind,StringName(get_meta("item_definition_id",&"")))}

func _draw_art_body() -> bool:
	var origin := StringName(get_meta("item_definition_id",&""))
	var clip := ItemArtLibrary.entity_clip(kind,origin)
	if clip.is_empty(): return false # Unproduced families retain explicit old art.
	var point := Vector2.ZERO
	var sample_age := age
	var angle := 0.0
	var tint := Color.WHITE
	if kind == &"pulse":
		sample_age = ItemArtLibrary.clip_duration(clip)*clampf(progress,0,0.99999)
		point = direction*radius*clampf(progress,0.05,1)
		angle = direction.angle()
		tint.a = (1.0-progress)*0.6
	var trail := ItemArtLibrary.entity_clip(StringName(String(kind)+"_trail"),origin)
	if not trail.is_empty() and _has_visual_step:
		var displacement := global_position-_step_position
		if not displacement.is_zero_approx():
			if ItemArtLibrary.draw_clip(self,trail,age,Vector2.ZERO,displacement.angle()): _art_draws += 1
	if not ItemArtLibrary.draw_clip(self,clip,sample_age,point,angle,tint):
		_art_missing += 1
		return false # Library has diagnosed the missing registered resource.
	_art_draws += 1
	# The thin delivery beam is owned here exactly once; muzzle and committed
	# receiver flashes are separate effect-view clips, never a fabricated hit.
	if beam_remaining > 0:
		draw_line(Vector2.ZERO,to_local(beam_end),Color(0.46,0.83,0.82,0.75),1.5,false)
	if marked:
		draw_arc(Vector2.ZERO,radius+4,-PI*0.8,-PI*0.2,8,Color("77d3d1"),1,false)
	for i: int in evolved:
		draw_circle(Vector2(float(i)*5-2.5,radius+4),1.5,Color("d4ac64"))
	return true

func _gear(size: float, edge: Color, inside: Color) -> void:
	for i: int in 8:
		var unit := Vector2.from_angle(TAU*float(i)/8.0)
		var side := unit.orthogonal()*2.0
		draw_colored_polygon(PackedVector2Array([unit*(size-2)-side, unit*(size+2)-side, unit*(size+2)+side, unit*(size-2)+side]), edge)
	draw_circle(Vector2.ZERO, size, edge)
	draw_circle(Vector2.ZERO, maxf(1,size-2), inside)
	draw_circle(Vector2.ZERO, 2, edge)
