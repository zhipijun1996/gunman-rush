class_name ItemEffectView
extends Node2D
## World-local observer of accepted ItemRuntime receipts. Never owns gameplay.
## The stage owns this node, so stage freeze and teardown also own its clock.
const CONFIG := "res://config/item_v5_feedback.json"
const SUPPORTED: Array[StringName] = [&"arc", &"item_arc", &"cloud", &"ring", &"mark", &"echo", &"item_blast", &"item_throw_burst", &"item_clock_pulse", &"item_active_cast", &"active", &"item_drone_fire", &"coin", &"item_guard_evolved", &"item_large_guard_summoned", &"synergy_bell", &"time_refund", &"skill_credit_ready", &"defense_active", &"projectile_intercept", &"barrier", &"heal", &"item_committed_impact",&"item_echo_armed",&"item_guard_active",&"item_rescue_committed",&"item_motion_path",&"item_break_bell_committed"]
var _runtime_ref: WeakRef
var _build_ref: WeakRef
var _settings: Dictionary = {}
var _entries: Array[Dictionary] = []
var _cast_frames: Dictionary = {}
var _accepted_art_frames: Dictionary = {}
var _sequence := 0
var _dropped := 0
var _pruned := 0
var _draws := 0
var _art_draws := 0
var _art_missing := 0
var _impact_events: Dictionary = {}
var _impact_order: Array[StringName] = []
var _bound_world_id := 0

func _ready() -> void:
	# INHERIT is deliberate: PAUSABLE would override a DISABLED frozen parent.
	process_mode = Node.PROCESS_MODE_INHERIT
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = ItemArtLibrary.world_material()
	z_index = 5
	set_process(_runtime_ref != null and not _settings.is_empty())

func configure(runtime: RefCounted) -> bool:
	_disconnect()
	clear()
	set_process(false)
	_settings = _read_settings()
	if runtime == null or _settings.is_empty() or not runtime.has_signal("effect_cued"): return false
	_runtime_ref = weakref(runtime)
	if runtime.has_method("world_root"):
		var world := runtime.call("world_root") as Node2D
		if is_instance_valid(world): _bound_world_id = world.get_instance_id()
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
	_accepted_art_frames.clear()
	_impact_events.clear()
	_impact_order.clear()
	if is_inside_tree(): queue_redraw()

func snapshot() -> Dictionary:
	_prune_sources()
	var counts: Dictionary = {}
	var entries: Array[Dictionary] = []
	for row: Dictionary in _entries:
		counts[row.kind] = int(counts.get(row.kind,0))+1
		entries.append({"kind":row.kind,"origin":row.origin,"point":row.point,"age":row.age,"duration":row.duration})
	return {"count":_entries.size(),"counts":counts,"entries":entries,"dropped":_dropped,"source_pruned":_pruned,"draw_calls":_draws,"art_draw_calls":_art_draws,"art_missing":_art_missing,"world_clock":"inherited_stage_process_delta","connected":_runtime()!=null}

func _runtime() -> RefCounted:
	return _runtime_ref.get_ref() as RefCounted if _runtime_ref != null else null

func _disconnect() -> void:
	var runtime := _runtime()
	if runtime != null and runtime.is_connected("effect_cued",_on_effect_cued): runtime.disconnect("effect_cued",_on_effect_cued)
	var build := _build_ref.get_ref() as RefCounted if _build_ref != null else null
	if build != null and build.is_connected("changed",_on_build_changed): build.disconnect("changed",_on_build_changed)
	_runtime_ref = null
	_build_ref = null
	_bound_world_id = 0

func _exit_tree() -> void:
	_disconnect()
	_entries.clear()
	_cast_frames.clear()
	_accepted_art_frames.clear()

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
		if _entries[i].has("mark_target"):
			var state := _mark_state(runtime,_entries[i])
			if state.is_empty():
				_entries.remove_at(i)
				continue
			_entries[i].point = (state.point as Vector2).round()
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
	if not _world_matches(runtime):
		_pruned += _entries.size()
		clear()
		return
	var identity := _visual_identity(runtime)
	for i: int in range(_entries.size()-1,-1,-1):
		var row: Dictionary = _entries[i]
		var artist_entry := not String(row.get("clip","")).is_empty()
		var tracked_source: bool = row.kind in [&"cloud",&"ring"] or artist_entry
		var source_removed: bool = tracked_source and not StringName(row.origin).is_empty() and not bool(runtime.call("has",row.origin))
		var context_changed: bool = artist_entry and row.get("identity",{}) != identity
		var mark_revoked: bool = row.has("mark_target") and _mark_state(runtime,row).is_empty()
		if (row.kind in [&"cloud",&"ring"] or artist_entry) and (source_removed or context_changed or mark_revoked):
			_entries.remove_at(i)
			_pruned += 1

func _on_effect_cued(kind: StringName, point: Vector2, detail: Dictionary) -> void:
	if kind not in SUPPORTED or not point.is_finite() or _settings.is_empty(): return
	if not _world_matches(_runtime()):
		clear()
		return
	var origin := StringName(str(detail.get("origin",detail.get("definition_id",detail.get("item",&"")))))
	origin = ItemArtLibrary.cue_source(kind,origin)
	var clip := ItemArtLibrary.cue_clip(kind,origin)
	# Legacy cast confirmations also belong to the original live source. Their
	# empty clip must not bypass a callback's equipment/session cancellation.
	if kind in [&"active",&"defense_active"] and not _impact_receipt_current(origin,detail): return
	# Once dedicated accepted-HP art exists, the older G01 detonation request
	# cannot also draw a receiver glyph before its damage has committed.
	if kind == &"echo" and origin == &"G01" and not ItemArtLibrary.cue_clip(&"item_committed_impact",origin).is_empty(): return
	if kind == &"synergy_bell" and StringName(detail.get("synergy",&"")) == &"S15" and not ItemArtLibrary.cue_clip(&"item_break_bell_committed",&"B14").is_empty(): return
	# Dedicated receiver art observes committed HP receipts, never a fire request.
	var guarded_receipt: bool = kind == &"item_committed_impact" or not clip.is_empty()
	if guarded_receipt:
		var incoming_event: Variant = detail.get("event_id",&"")
		if not (incoming_event is String or incoming_event is StringName): return
		var event := StringName(incoming_event)
		if event.is_empty() or origin.is_empty() or clip.is_empty() or _impact_events.has(event) or not _impact_receipt_current(origin,detail): return
		_impact_events[event] = true
		_impact_order.append(event)
		if _impact_order.size() > int(_settings.max_entries)*2: _impact_events.erase(_impact_order.pop_front())
	var frame := Engine.get_process_frames()
	if kind == &"defense_active" and int(_accepted_art_frames.get(origin,-1)) == frame: return
	if not clip.is_empty() and kind in [&"barrier",&"heal",&"item_guard_active"]: _accepted_art_frames[origin] = frame
	if kind == &"active" and (int(_cast_frames.get(origin,-1)) == frame or int(_accepted_art_frames.get(origin,-1)) == frame): return
	if kind in [&"item_active_cast",&"defense_active",&"item_large_guard_summoned"]: _cast_frames[origin] = frame
	var duration := float(_settings.short_duration_s)
	if kind in [&"arc",&"item_arc",&"item_drone_fire"]: duration = float(_settings.arc_duration_s)
	elif kind == &"mark": duration = float(_settings.mark_confirm_duration_s)
	elif kind == &"coin": duration = float(_settings.coin_duration_s)
	elif kind in [&"cloud",&"ring"]: duration = _number(detail.get("duration"),duration)
	if not clip.is_empty() and kind not in [&"cloud",&"ring"] and not ItemArtLibrary.clip_uses_event_timing(clip):
		duration = ItemArtLibrary.clip_duration(clip)
	var persistent_mark: bool = not clip.is_empty() and kind in [&"mark",&"item_echo_armed"] and detail.get("target") is WeakRef
	if persistent_mark: duration = _number(detail.get("duration"),duration)
	duration = clampf(duration,0.01,float(_settings.max_visual_duration_s))
	var radius := clampf(_number(detail.get("radius"),float(_settings.default_radius_px)),1.0,float(_settings.max_visual_radius_px))
	var endpoint: Variant = detail.get("finish",detail.get("end",point))
	var finish: Vector2 = endpoint if endpoint is Vector2 else point
	if not finish.is_finite(): finish = point
	var aiming: Variant = detail.get("direction",Vector2.RIGHT)
	var direction: Vector2 = aiming if aiming is Vector2 else Vector2.RIGHT
	if kind == &"item_drone_fire" and not detail.has("direction") and not finish.is_equal_approx(point): direction = finish-point
	if not direction.is_finite() or direction.is_zero_approx(): direction = Vector2.RIGHT
	_sequence += 1
	var row := {"kind":kind,"point":point.round(),"finish":finish.round(),"direction":direction.normalized(),"origin":origin,"age":0.0,"duration":duration,"radius":radius,"sequence":_sequence,"magnet_bonus":kind==&"coin" and bool(detail.get("magnet_bonus",false)),"amount":clampi(int(detail.get("amount",1)),1,int(_settings.max_coin_glyphs)),"evolution":clampi(int(detail.get("evolution",0)),0,2)}
	row["clip"] = clip
	row["observed_radius"] = _number(detail.get("radius"),-1.0)>0.0
	row["long"] = kind in [&"cloud",&"ring"] or persistent_mark
	if persistent_mark:
		row["mark_target"] = detail.target
		row["mark_receipt"] = detail.get("mark_receipt",&"")
	if not clip.is_empty(): row["identity"] = _visual_identity(_runtime())
	if bool(row.magnet_bonus):
		var runtime := _runtime()
		var actor := runtime.call("actor") as PlayerController if runtime != null else null
		if is_instance_valid(actor):
			var offset := actor.motor.global_position-point
			row.finish = point+offset.limit_length(float(_settings.max_coin_arc_distance_px))
			row["target"] = weakref(actor.motor)
		else: row.magnet_bonus = false
	if bool(row["long"]):
		var count := 0
		for active: Dictionary in _entries:
			if bool(active.get("long",active.kind in [&"cloud",&"ring"])): count += 1
		if count >= int(_settings.max_long_entries):
			for i: int in _entries.size():
				if bool(_entries[i].get("long",_entries[i].kind in [&"cloud",&"ring"])):
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
		var artist_clip := StringName(row.get("clip",&""))
		if not artist_clip.is_empty():
			if row.kind == &"coin":
				if _coin_art(row,phase,alpha,artist_clip): continue
			else:
				var art_alpha := float(_settings.cloud_opacity)*minf(1,phase*10)*(1.0-phase) if row.kind == &"cloud" else alpha
				var finish := _point(row.finish)
				var observed_radius := radius if bool(row.get("observed_radius",false)) else NAN
				if ItemArtLibrary.draw_recipe(self,artist_clip,float(row.age),center,row.direction,finish-center,observed_radius,finish,Color(1,1,1,art_alpha),(row.direction as Vector2).angle()):
					_art_draws += 1
					continue
			_art_missing += 1
			# Missing artist art is diagnosed by the library. A committed impact
			# never falls back to a generic hit glyph that pretends to be authored.
			if row.kind == &"item_committed_impact": continue
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

func _world_matches(runtime: RefCounted) -> bool:
	if runtime == null: return false
	if _bound_world_id == 0: return true # Compatibility host without a world API.
	var world := runtime.call("world_root") as Node2D
	return is_instance_valid(world) and world.get_instance_id() == _bound_world_id

func _mark_state(runtime: RefCounted, row: Dictionary) -> Dictionary:
	if runtime == null or not runtime.has_method("presentation_mark") or not row.get("mark_target") is WeakRef: return {}
	var receiver := (row.mark_target as WeakRef).get_ref() as Damageable
	if not is_instance_valid(receiver): return {}
	var state: Dictionary = runtime.call("presentation_mark",StringName(row.origin),receiver)
	if state.is_empty() or state.get("receipt",&"") != row.get("mark_receipt",&"") or not state.get("point") is Vector2 or not (state.point as Vector2).is_finite(): return {}
	return state

# Reuse the original accepted-wallet glyph count and exact magnet path. Artist
# pixels replace each glyph without introducing another target/path authority.
func _coin_art(row: Dictionary, phase: float, alpha: float, clip: StringName) -> bool:
	var start: Vector2 = row.point
	var finish: Vector2 = row.finish
	for i: int in int(row.amount):
		var point: Vector2
		if bool(row.magnet_bonus):
			var delay := float(i)*0.05
			var t := clampf((phase-delay)/(1.0-delay),0,1)
			point = start.lerp(finish,t)+Vector2.UP*sin(t*PI)*float(_settings.max_coin_arc_height_px)
		else: point = start+Vector2(float(i)*5-5,-phase*18)
		if not ItemArtLibrary.draw_recipe(self,clip,float(row.age),_point(point),row.direction,finish-start,NAN,_point(finish),Color(1,1,1,alpha),(row.direction as Vector2).angle()): return false
		_art_draws += 1
	return true

func _visual_identity(runtime: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	if runtime == null: return result
	if runtime.has_method("map_key"): result["map_key"] = String(runtime.call("map_key"))
	if runtime.has_method("world_root"):
		var world := runtime.call("world_root") as Node2D
		if is_instance_valid(world): result["world_id"] = world.get_instance_id()
	if runtime.has_method("actor"):
		var player := runtime.call("actor") as PlayerController
		if is_instance_valid(player):
			result["session"] = player.session_id
			result["active"] = player.active and not player.actor_resources.health.terminal
			if player.shoot_ability != null: result["weapon_epoch"] = player.shoot_ability.weapon_epoch
	var owner_build := _build_ref.get_ref() as BuildState if _build_ref != null else null
	if owner_build != null:
		result["equipment_revision"] = int(owner_build.equipment.snapshot().revision)
		var scope := owner_build.equipment.lifetime
		if scope != null:
			result["run_epoch"] = scope.epoch
			result["stage_epoch"] = scope.stage_epoch
			result["actor_epoch"] = scope.actor_epoch
	return result

func _impact_receipt_current(origin: StringName, detail: Dictionary) -> bool:
	var runtime := _runtime()
	if runtime == null or not runtime.has_method("is_live") or not bool(runtime.call("is_live")): return false
	var identity := _visual_identity(runtime)
	for field: String in ["session","run_epoch","stage_epoch","actor_epoch","weapon_epoch","equipment_revision","world_id"]:
		# Live receipts carry integer identities. JSON or caller coercion cannot
		# turn a stale/malformed identity into a newly accepted presentation.
		if not detail.get(field) is int or not identity.has(field) or detail[field] != identity[field]: return false
	var map: Variant = detail.get("map_key")
	if not (map is String or map is StringName) or String(map) != String(identity.get("map_key","")): return false
	var owner_build := _build_ref.get_ref() as BuildState if _build_ref != null else null
	if owner_build == null or owner_build.inventory == null: return false
	var source := owner_build.inventory.instance_for_definition(origin)
	return source != null and source.instance_id in owner_build.equipment.equipped_ids() and not bool(source.effect_state.get("broken",false))

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
