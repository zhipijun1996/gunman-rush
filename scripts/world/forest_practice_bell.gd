class_name ForestPracticeBell
extends GrappleAnchor
## Harmless moving practice target. The shared grapple owns contact and movement.
const SNAPSHOT_VERSION := 1
const SNAPSHOT_FIELDS: Array[String] = ["version", "authored_row", "clock", "phase", "position", "accepted_kicks"]
const SERIALIZATION_EPSILON := 0.000000001
const MAX_EXACT_JSON_INTEGER := 9007199254740991
var _center := Vector2.ZERO
var _radius := Vector2.ZERO
var _period := 3.2
var _clock := 0.0
var _tether_root := Vector2.ZERO
var accepted_kicks := 0
var _authored_row: Dictionary = {}
var _configured := false

func configure(row: Dictionary) -> bool:
	if _configured: return false
	for key: String in ["id", "host_support_id", "route_id"]:
		if not row.get(key) is String or str(row[key]).is_empty(): return false
	if not _finite_pair(row.get("position")) or not _finite_pair(row.get("tether_root")): return false
	if not row.get("motion") is Dictionary: return false
	var motion: Dictionary = row.motion
	if motion.get("kind") != "pendulum" or not _finite_pair(motion.get("center")) or not _finite_pair(motion.get("radius")): return false
	if not _finite_number(motion.get("period")) or float(motion.period) <= 0.0: return false
	var center: Vector2 = Vector2(row.position[0], row.position[1])
	var radius: Vector2 = Vector2(motion.radius[0], motion.radius[1])
	var tether: Vector2 = Vector2(row.tether_root[0], row.tether_root[1])
	if not center.is_finite() or not radius.is_finite() or not tether.is_finite() or not (center+radius).is_finite() or not (center-radius).is_finite(): return false
	if Vector2(motion.center[0], motion.center[1]) != center or radius.x < 0.0 or radius.y < 0.0: return false
	if not row.get("damage") is bool or row.damage or not row.get("reward") is bool or row.reward: return false
	_center = center
	_radius = radius
	_period = float(motion.period)
	_tether_root = tether
	_authored_row = {"id":str(row.id), "position":[_center.x,_center.y], "motion":{"kind":"pendulum", "center":[_center.x,_center.y], "radius":[_radius.x,_radius.y], "period":_period}, "tether_root":[_tether_root.x,_tether_root.y], "host_support_id":str(row.host_support_id), "route_id":str(row.route_id)}
	_clock = 0.0
	accepted_kicks = 0
	position = _center
	_configured = true
	return true

func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _physics_process(delta: float) -> void:
	if not _configured or not is_finite(delta) or delta <= 0.0: return
	var next_clock: float = _clock + delta
	var next_position: Vector2 = _position_at(next_clock)
	if not next_position.is_finite(): return
	_clock = next_clock
	position = next_position

func accepted_contact() -> void:
	if not _configured: return
	accepted_kicks += 1
	GameAudio.cue(self, &"bell")
	print("FOREST_UI_EVENT ", JSON.stringify({"event":"practice_bell_contact","source":"accepted_hook_kick","id":str(name),"harmless":true,"reward":false}))

func snapshot_state() -> Dictionary:
	if not _configured: return {}
	return {"version":SNAPSHOT_VERSION, "authored_row":_authored_row.duplicate(true), "clock":_clock, "phase":fposmod(_clock * TAU / _period, TAU), "position":[position.x,position.y], "accepted_kicks":accepted_kicks}

func restore_state(saved: Dictionary) -> bool:
	# Own mechanism payload only; the existing RegionState save version is unchanged.
	if not _configured or saved.size() != SNAPSHOT_FIELDS.size(): return false
	for key: String in SNAPSHOT_FIELDS:
		if not saved.has(key): return false
	if not _whole_counter(saved.version) or int(saved.version) != SNAPSHOT_VERSION: return false
	if not saved.authored_row is Dictionary or saved.authored_row != _authored_row: return false
	if not _finite_number(saved.clock) or float(saved.clock) < 0.0 or not _finite_number(saved.phase): return false
	if not _finite_pair(saved.position) or not _whole_counter(saved.accepted_kicks): return false
	var next_clock: float = float(saved.clock)
	var raw_phase: float = next_clock * TAU / _period
	if not is_finite(raw_phase) or not is_finite(raw_phase * 2.0): return false
	var phase: float = float(saved.phase)
	if phase < 0.0 or phase >= TAU or absf(wrapf(phase-fposmod(raw_phase,TAU),-PI,PI)) > SERIALIZATION_EPSILON: return false
	var next_position: Vector2 = _position_at(next_clock)
	if not next_position.is_finite() or next_position.distance_to(Vector2(saved.position[0],saved.position[1])) > SERIALIZATION_EPSILON: return false
	# No live field changes until every identity, geometry and phase check passed.
	_clock = next_clock
	accepted_kicks = int(saved.accepted_kicks)
	position = next_position
	queue_redraw()
	return true

func _position_at(at_clock: float) -> Vector2:
	var phase: float = at_clock * TAU / _period
	if not is_finite(phase) or not is_finite(phase*2.0): return Vector2.INF
	return _center + Vector2(sin(phase)*_radius.x,sin(phase*2.0)*_radius.y)

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _finite_pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _finite_number(value[0]) and _finite_number(value[1])

static func _whole_counter(value: Variant) -> bool:
	# JSON numeric values are floats. Admit exact whole values without coercing
	# strings, booleans, fractions or integers that JSON cannot represent exactly.
	if value is int: return value >= 0
	return value is float and is_finite(value) and value >= 0.0 and value <= MAX_EXACT_JSON_INTEGER and value == floorf(value)

func _draw() -> void:
	draw_line(_tether_root-position, Vector2(0,-12), Color("887b52"), 2.0)
	ForestBiblePresentation.draw_bell(self, 12.0, false)
