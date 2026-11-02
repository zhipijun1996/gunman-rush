class_name ForestBibleWeaverBehavior
extends ForestThreadSpiderBehavior
## v15 only: one rooted spider alternates two authored entrances. The original
## finite-line damage sweep/policy and old single-line content remain unchanged.
const SNAPSHOT_VERSION := 15
const PHASES: Array[StringName] = [&"idle", &"telegraph", &"extend", &"hold", &"retract", &"recovery"]
var strand_rows: Array[Dictionary] = []
var strand_index := 0
var _cycle_completed := false

func configure_strands(rows: Array) -> bool:
	cancel()
	strand_rows.clear()
	line_configured = false
	if not is_instance_valid(actor) or rows.size() != 2: return false
	var accepted: Array[Dictionary] = []
	for index: int in 2:
		var raw: Variant = rows[index]
		if not raw is Dictionary or raw.get("id") != ("upper" if index == 0 else "lower"): return false
		var start: Variant = raw.get("start")
		var finish: Variant = raw.get("end")
		if not _pair_valid(start) or not _pair_valid(finish): return false
		var a := Vector2(start[0],start[1])
		var b := Vector2(finish[0],finish[1])
		if not super.configure_line(a,b): return false
		accepted.append({"id":raw.id,"start":[a.x,a.y],"end":[b.x,b.y]})
		line_configured = false
	# Distinct heights are physical entrance data, not two names for one line.
	if (Vector2(accepted[0].start[0],accepted[0].start[1])+Vector2(accepted[0].end[0],accepted[0].end[1])).y >= (Vector2(accepted[1].start[0],accepted[1].start[1])+Vector2(accepted[1].end[0],accepted[1].end[1])).y:
		line_configured = false
		return false
	strand_rows = accepted
	strand_index = 0
	_cycle_completed = false
	_hit_this_cycle = false
	_select_strand()
	_set_state(&"idle")
	return true

static func _pair_valid(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true

func _select_strand() -> void:
	var row: Dictionary = strand_rows[strand_index]
	line_start = Vector2(row.start[0],row.start[1])
	line_end = Vector2(row.end[0],row.end[1])
	line_configured = true
	line_active = false

func _host_present() -> bool:
	# A displaced/unloaded host cannot leave detached danger in an old doorway.
	return is_instance_valid(actor.motor) and actor.motor.is_inside_tree() and actor.motor.global_position.distance_to(home) <= 1.0

func advance(delta: float) -> bool:
	if not _active() or not line_configured or strand_rows.size() != 2 or not _host_present():
		cancel()
		return true
	if _actor_epoch != lifetime.actor_epoch:
		_actor_epoch = lifetime.actor_epoch
		cancel()
		return true
	var d := actor.definition as ForestEnemyDefinition
	state_time += delta
	cooldown = maxf(0,cooldown-delta)
	match state:
		&"idle":
			if cooldown <= 0 and _can_engage() and _clear_line() and _safe_line():
				_serial += 1
				_token = lifetime.token()
				_hit_this_cycle = false
				_cycle_completed = false
				_set_state(&"telegraph")
		&"telegraph":
			if not _clear_line() or not _safe_line(): cancel()
			elif state_time >= d.telegraph_duration: _set_state(&"extend")
		&"extend":
			if not _clear_line() or not _safe_line(): cancel()
			elif state_time >= d.line_extend_seconds:
				_previous_player = controller.motor.global_position
				line_active = true
				_set_state(&"hold")
		&"hold":
			if not _clear_line() or not _safe_line(): cancel()
			elif state_time >= d.line_hold_seconds:
				line_active = false
				_cycle_completed = true
				_set_state(&"retract")
			else: _damage_line()
		&"retract":
			if state_time >= d.line_retract_seconds: _set_state(&"recovery")
		&"recovery":
			if state_time >= d.recovery_duration:
				if _cycle_completed:
					strand_index = 1-strand_index
					_select_strand()
				_cycle_completed = false
				_hit_this_cycle = false
				cooldown = d.rest_cooldown
				_set_state(&"idle")
	return true

func cancel() -> void:
	_cycle_completed = false
	super.cancel()

func depth_snapshot() -> Dictionary:
	# The stage stores these clocks too. Bind both representations so a damaged
	# inner record cannot be combined with an unrelated outer phase/serial.
	return {"version":SNAPSHOT_VERSION,"configured":line_configured,"strands":strand_rows.duplicate(true),"strand_index":strand_index,"selected_id":strand_rows[strand_index].id if strand_rows.size() == 2 else "","start":[line_start.x,line_start.y],"end":[line_end.x,line_end.y],"phase":String(state),"state_time":state_time,"cooldown":cooldown,"serial":_serial,"home":[home.x,home.y],"cycle_completed":_cycle_completed,"completion_serial":_serial if _cycle_completed else 0,"hit_this_cycle":_hit_this_cycle,"hit_serial":_serial if _hit_this_cycle else 0}

func restore_depth_state(saved: Dictionary) -> bool:
	# Geometry belongs to the pinned Manifest. A save cannot move an entrance.
	if not saved.get("version") is int or saved.version != SNAPSHOT_VERSION or not saved.get("configured") is bool or not saved.configured or not line_configured or strand_rows.size() != 2 or saved.get("strands") != strand_rows: return false
	if not saved.get("strand_index") is int or saved.strand_index not in [0,1]: return false
	var selected: Dictionary = strand_rows[saved.strand_index]
	if saved.get("selected_id") != selected.id or saved.get("start") != selected.start or saved.get("end") != selected.end: return false
	if not saved.get("cycle_completed") is bool or not saved.get("hit_this_cycle") is bool: return false
	if state not in PHASES or not is_finite(state_time) or state_time < 0 or not is_finite(cooldown) or cooldown < 0 or _serial < 0 or not home.is_finite(): return false
	if not saved.get("phase") is String or saved.phase != String(state): return false
	if not _nonnegative_number(saved.get("state_time")) or saved.state_time != state_time: return false
	if not _nonnegative_number(saved.get("cooldown")) or saved.cooldown != cooldown: return false
	if not saved.get("serial") is int or saved.serial != _serial: return false
	if not _pair_valid(saved.get("home")) or saved.home != [home.x,home.y]: return false
	var d := actor.definition as ForestEnemyDefinition
	var phase_limits := {&"telegraph":d.telegraph_duration,&"extend":d.line_extend_seconds,&"hold":d.line_hold_seconds,&"retract":d.line_retract_seconds,&"recovery":d.recovery_duration}
	if phase_limits.has(state) and state_time > float(phase_limits[state]): return false
	var completed: bool = saved.cycle_completed
	var hit: bool = saved.hit_this_cycle
	if not saved.get("completion_serial") is int or saved.completion_serial != (_serial if completed else 0): return false
	if not saved.get("hit_serial") is int or saved.hit_serial != (_serial if hit else 0): return false
	if (state == &"retract" and not completed) or (state not in [&"retract",&"recovery"] and completed): return false
	if hit and state in [&"idle",&"telegraph",&"extend"]: return false
	if state in [&"telegraph",&"extend",&"hold",&"retract"] and _serial == 0: return false
	if actor.health.terminal and state not in [&"idle",&"recovery"]: return false
	if state in [&"telegraph",&"extend",&"hold",&"retract"] and (not _active() or not _host_present()): return false
	strand_index = saved.strand_index
	_select_strand()
	_cycle_completed = completed
	_hit_this_cycle = hit
	line_active = state == &"hold" and _active()
	_previous_player = controller.motor.global_position
	_token = lifetime.token() if state in [&"telegraph",&"extend",&"hold"] and _active() else null
	_actor_epoch = lifetime.actor_epoch
	return true

static func _nonnegative_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0
