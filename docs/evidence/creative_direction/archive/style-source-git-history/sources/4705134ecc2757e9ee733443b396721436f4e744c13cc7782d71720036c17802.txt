class_name ItemEffectView
extends Node2D
## World-local observer of accepted ItemRuntime receipts. Never owns gameplay.
## The stage owns this node, so stage freeze and teardown also own its clock.
const CONFIG := "res://config/item_v5_feedback.json"
const SUPPORTED: Array[StringName] = [&"arc", &"item_arc", &"cloud", &"ring", &"mark", &"echo", &"item_blast", &"item_throw_burst", &"item_clock_pulse", &"item_active_cast", &"active", &"item_drone_fire", &"coin", &"item_guard_evolved", &"item_large_guard_summoned", &"synergy_bell", &"time_refund", &"skill_credit_ready", &"defense_active", &"projectile_intercept", &"barrier", &"heal"]
var _runtime_ref: WeakRef
var _build_ref: WeakRef
var _settings: Dictionary = {}
var _entries: Array[Dictionary] = []
var _cast_frames: Dictionary = {}
var _sequence := 0
var _dropped := 0
var _pruned := 0
var _draws := 0

func _ready() -> void:
	# INHERIT is deliberate: PAUSABLE would override a DISABLED frozen parent.
	process_mode = Node.PROCESS_MODE_INHERIT
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 5
	set_process(_runtime_ref != null and not _settings.is_empty())

func configure(runtime: RefCounted) -> bool:
	_disconnect()
	clear()
	set_process(false)
	_settings = _read_settings()
	if runtime == null or _settings.is_empty() or not runtime.has_signal("effect_cued"): return false
	_runtime_ref = weakref(runtime)
	runtime.connect("effect_cued", _on_effect_cued)
	if runtime.has_method("build"):
		var build := runtime.call("build") as RefCounted
		if build != null and build.has_signal("changed"):
			_build_ref = weakref(build)
			build.connect("changed", _on_build_changed)
	set_process(true)
	return true

func clear() -> void:
	_entries.clear()
	_cast_frames.clear()
	if is_inside_tree(): queue_redraw()

func snapshot() -> Dictionary:
	_prune_sources()
	var counts: Dictionary = {}
	var entries: Array[Dictionary] = []
	for row: Dictionary in _entries:
		counts[row.kind] = int(counts.get(row.kind,0))+1
		entries.append({"kind":row.kind,"origin":row.origin,"point":row.point,"age":row.age,"duration":row.duration})
	return {"count":_entries.size(),"counts":counts,"entries":entries,"dropped":_dropped,"source_pruned":_pruned,"draw_calls":_draws,"world_clock":"inherited_stage_process_delta","connected":_runtime()!=null}

func _runtime() -> RefCounted:
	return _runtime_ref.get_ref() as RefCounted if _runtime_ref != null else null

func _disconnect() -> void:
	var runtime := _runtime()
	if runtime != null and runtime.is_connected("effect_cued",_on_effect_cued): runtime.disconnect("effect_cued",_on_effect_cued)
	var build := _build_ref.get_ref() as RefCounted if _build_ref != null else null
	if build != null and build.is_connected("changed",_on_build_changed): build.disconnect("changed",_on_build_changed)
	_runtime_ref = null
	_build_ref = null

func _exit_tree() -> void:
	_disconnect()
	_entries.clear()
	_cast_frames.clear()

func _process(delta: float) -> void:
	advance_visual(delta)

func advance_visual(world_delta: float) -> void:
	_prune_sources()
	var runtime := _runtime()
	if runtime == null:
		clear()
		set_process(false)
		return
	if runtime.has_method("is_live") and not bool(runtime.call("is_live")): return
	if not is_finite(world_delta) or world_delta <= 0: return
	for i: int in range(_entries.size()-1,-1,-1):
		_entries[i].age = float(_entries[i].age)+world_delta
		if bool(_entries[i].magnet_bonus) and _entries[i].get("target") is WeakRef:
			var target := (_entries[i].target as WeakRef).get_ref() as Node2D
			if is_instance_valid(target):
				var start: Vector2 = _entries[i].point
				_entries[i].finish = start+(target.global_position-start).limit_length(float(_settings.max_coin_arc_distance_px))
		if float(_entries[i].age) >= float(_entries[i].duration): _entries.remove_at(i)
	queue_redraw()

func _on_build_changed() -> void:
	_prune_sources()
	queue_redraw()

func _prune_sources() -> void:
	var runtime := _runtime()
	if runtime == null: return
	for i: int in range(_entries.size()-1,-1,-1):
		var row: Dictionary = _entries[i]
		if row.kind in [&"cloud",&"ring"] and not StringName(row.origin).is_empty() and not bool(runtime.call("has",row.origin)):
			_entries.remove_at(i)
			_pruned += 1

func _on_effect_cued(kind: StringName, point: Vector2, detail: Dictionary) -> void:
	if kind not in SUPPORTED or not point.is_finite() or _settings.is_empty(): return
	var origin := StringName(str(detail.get("origin",detail.get("definition_id",detail.get("item",&"")))))
	var frame := Engine.get_process_frames()
	if kind == &"active" and int(_cast_frames.get(origin,-1)) == frame: return
	if kind in [&"item_active_cast",&"defense_active",&"item_large_guard_summoned"]: _cast_frames[origin] = frame
	var duration := float(_settings.short_duration_s)
	if kind in [&"arc",&"item_arc",&"item_drone_fire"]: duration = float(_settings.arc_duration_s)
	elif kind == &"mark": duration = float(_settings.mark_confirm_duration_s)
	elif kind == &"coin": duration = float(_settings.coin_duration_s)
	elif kind in [&"cloud",&"ring"]: duration = _number(detail.get("duration"),duration)
	duration = clampf(duration,0.01,float(_settings.max_visual_duration_s))
	var radius := clampf(_number(detail.get("radius"),float(_settings.default_radius_px)),1.0,float(_settings.max_visual_radius_px))
	var endpoint: Variant = detail.get("finish",detail.get("end",point))
	var finish: Vector2 = endpoint if endpoint is Vector2 else point
	if not finish.is_finite(): finish = point
	var aiming: Variant = detail.get("direction",Vector2.RIGHT)
	var direction: Vector2 = aiming if aiming is Vector2 else Vector2.RIGHT
	if not direction.is_finite() or direction.is_zero_approx(): direction = Vector2.RIGHT
	_sequence += 1
	var row := {"kind":kind,"point":point.round(),"finish":finish.round(),"direction":direction.normalized(),"origin":origin,"age":0.0,"duration":duration,"radius":radius,"sequence":_sequence,"magnet_bonus":kind==&"coin" and bool(detail.get("magnet_bonus",false)),"amount":clampi(int(detail.get("amount",1)),1,int(_settings.max_coin_glyphs)),"evolution":clampi(int(detail.get("evolution",0)),0,2)}
	if bool(row.magnet_bonus):
		var runtime := _runtime()
		var actor := runtime.call("actor") as PlayerController if runtime != null else null
		if is_instance_valid(actor):
			var offset := actor.motor.global_position-point
			row.finish = point+offset.limit_length(float(_settings.max_coin_arc_distance_px))
			row["target"] = weakref(actor.motor)
		else: row.magnet_bonus = false
	if kind in [&"cloud",&"ring"]:
		var count := 0
		for active: Dictionary in _entries:
			if active.kind in [&"cloud",&"ring"]: count += 1
		if count >= int(_settings.max_long_entries):
			for i: int in _entries.size():
				if _entries[i].kind in [&"cloud",&"ring"]:
					_entries.remove_at(i)
					_dropped += 1
					break
	if _entries.size() >= int(_settings.max_entries):
		_entries.pop_front()
		_dropped += 1
	_entries.append(row)
	_prune_sources()
	queue_redraw()

func _draw() -> void:
	_draws += 1
	for row: Dictionary in _entries:
		var phase := clampf(float(row.age)/float(row.duration),0,1)
		var alpha := float(_settings.max_opacity)*(1.0-phase)
		var center := _point(row.point)
		var radius := float(row.radius)
		var brass := _fade(UnderworldUI.BRASS,alpha)
		var cool := _fade(UnderworldUI.COOL,alpha)
		match row.kind:
			&"arc", &"item_arc": _arc(row,alpha)
			&"cloud": _cloud(row,phase)
			&"ring":
				draw_arc(center,radius,0,TAU,32,cool,1,false)
				_ticks(center,radius,phase,8,brass)
			&"mark", &"echo":
				_gear(center,8.0+phase*10.0,cool)
				draw_arc(center,12.0+phase*12.0,0,TAU,16,brass,1,false)
			&"coin": _coin(row,phase,alpha)
			&"item_blast", &"item_throw_burst":
				draw_arc(center,radius*(0.3+phase*0.7),0,TAU,24,cool,1,false)
				_ticks(center,radius*(0.2+phase*0.8),phase,8,brass)
			&"item_clock_pulse":
				var angle: float = (row.direction as Vector2).angle()
				draw_arc(center,float(_settings.pulse_confirm_radius_px)*(0.2+phase*0.8),angle-0.55,angle+0.55,14,brass,1,false)
			&"item_drone_fire":
				_ticks(center,3.0+phase*4,phase,4,cool)
				_ticks(_point(row.finish),3.0+phase*4,phase,4,brass)
			&"item_guard_evolved", &"item_large_guard_summoned":
				_gear(center,12.0+phase*12.0,brass)
				for i: int in int(row.evolution): draw_circle(center+Vector2(float(i)*6-3,-18),1.5,cool)
			&"synergy_bell":
				var top := center+Vector2.UP*(14+phase*12)
				draw_arc(top,7,PI,TAU,12,brass,2,false)
				draw_line(top+Vector2(-8,1),top+Vector2(8,1),brass,1,false)
				draw_circle(top+Vector2(0,4),1.5,cool)
			&"time_refund":
				var point := center+Vector2.UP*phase*18
				draw_arc(point,8,PI*0.4,PI*1.8,12,cool,1,false)
				draw_line(point,point+Vector2.UP*5,brass,1,false)
			&"skill_credit_ready":
				var pivot := center+Vector2.UP*(22.0+phase*8.0)
				var bob := pivot+Vector2(sin(phase*TAU)*7.0,12.0)
				draw_line(pivot,bob,brass,1,false)
				_gear(bob,4.0,cool)
			&"projectile_intercept": _ticks(center,6.0+phase*10.0,phase,8,cool)
			&"defense_active", &"barrier":
				if row.origin == &"P27": _heal_mark(center,alpha)
				else:
					var points := PackedVector2Array([center+Vector2(-12,-15),center+Vector2(12,-15),center+Vector2(11,9),center+Vector2(0,19),center+Vector2(-11,9),center+Vector2(-12,-15)])
					draw_polyline(points,cool,1,false)
					_gear(center,6.0+phase*3.0,brass)
			&"heal": _heal_mark(center,alpha)
			_: _gear(center,5.0+phase*8.0,brass)

func _arc(row: Dictionary, alpha: float) -> void:
	var start: Vector2 = row.point
	var finish: Vector2 = row.finish
	var normal := (finish-start).normalized().orthogonal()
	var points := PackedVector2Array()
	var count := int(_settings.arc_segments)
	for i: int in count+1:
		var t := float(i)/float(count)
		var shift := sin(float(i*5+int(row.sequence)))*float(_settings.arc_offset_px)*sin(t*PI)
		points.append(_point(start.lerp(finish,t)+normal*shift))
	draw_polyline(points,_fade(UnderworldUI.COOL,alpha),1,false)

func _cloud(row: Dictionary, phase: float) -> void:
	var center := _point(row.point)
	var radius := float(row.radius)
	var opacity := float(_settings.cloud_opacity)*minf(1,phase*10)*(1.0-phase)
	for i: int in int(_settings.cloud_wisps):
		var angle := TAU*float(i)/float(_settings.cloud_wisps)+float(row.age)*0.25
		var point := (center+Vector2.from_angle(angle)*radius*0.65).round()
		draw_arc(point,radius*0.18,angle+0.4,angle+2.0,7,_fade(UnderworldUI.MOSS,opacity),1,false)
	draw_arc(center,radius,0,TAU,32,_fade(UnderworldUI.MOSS,opacity*0.5),1,false)

func _coin(row: Dictionary, phase: float, alpha: float) -> void:
	var start: Vector2 = row.point
	var finish: Vector2 = row.finish
	for i: int in int(row.amount):
		var point: Vector2
		if bool(row.magnet_bonus):
			var delay := float(i)*0.05
			var t := clampf((phase-delay)/(1.0-delay),0,1)
			point = start.lerp(finish,t)+Vector2.UP*sin(t*PI)*float(_settings.max_coin_arc_height_px)
		else: point = start+Vector2(float(i)*5-5,-phase*18)
		var center := _point(point)
		draw_circle(center,float(_settings.coin_glyph_radius_px),_fade(UnderworldUI.BRASS,alpha))
		draw_line(center+Vector2.UP,center+Vector2.DOWN,_fade(UnderworldUI.INK,alpha),1,false)

func _ticks(center: Vector2, radius: float, phase: float, count: int, color: Color) -> void:
	for i: int in count:
		var direction := Vector2.from_angle(TAU*float(i)/float(count))
		draw_line((center+direction*radius).round(),(center+direction*(radius+3*(1.0-phase))).round(),color,1,false)

func _heal_mark(center: Vector2, alpha: float) -> void:
	var color := _fade(UnderworldUI.MOSS,alpha)
	draw_line(center+Vector2(-6,0),center+Vector2(6,0),color,2,false)
	draw_line(center+Vector2(0,-6),center+Vector2(0,6),color,2,false)

func _gear(center: Vector2, radius: float, color: Color) -> void:
	draw_arc(center,radius,0,TAU,16,color,1,false)
	_ticks(center,radius,0,int(_settings.gear_teeth),color)
	draw_arc(center,maxf(1,radius*0.35),0,TAU,12,color,1,false)

func _point(world_point: Vector2) -> Vector2:
	return to_local(world_point.round()).round()

func _fade(color: Color, alpha: float) -> Color:
	color.a = clampf(alpha,0,1)
	return color

func _number(value: Variant, fallback: float) -> float:
	return float(value) if (value is float or value is int) and is_finite(float(value)) and float(value)>0 else fallback

func _read_settings() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if not parsed is Dictionary or parsed.get("schema_version") != 1: return {}
	var fields: Array[String] = ["max_entries","max_long_entries","max_visual_duration_s","max_visual_radius_px","default_radius_px","short_duration_s","arc_duration_s","mark_confirm_duration_s","coin_duration_s","max_opacity","cloud_opacity","arc_segments","arc_offset_px","cloud_wisps","gear_teeth","max_coin_glyphs","coin_glyph_radius_px","max_coin_arc_distance_px","max_coin_arc_height_px","pulse_confirm_radius_px"]
	for field: String in fields:
		var value: Variant = parsed.get(field)
		if not value is float and not value is int: return {}
		if not is_finite(float(value)) or float(value)<=0: return {}
	for field: String in ["max_entries","max_long_entries","arc_segments","cloud_wisps","gear_teeth","max_coin_glyphs"]:
		if float(parsed[field]) != floor(float(parsed[field])): return {}
	if int(parsed.max_entries)>64 or int(parsed.max_long_entries)>8 or int(parsed.arc_segments)>16 or int(parsed.cloud_wisps)>8 or int(parsed.gear_teeth)>16 or int(parsed.max_coin_glyphs)>3 or float(parsed.max_opacity)>0.75 or float(parsed.cloud_opacity)>0.25: return {}
	return parsed
