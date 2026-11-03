class_name RuntimeMapShotLatchAdapter
extends RefCounted
## Admission of the one currently supported materialized v2 latch contract.
## Positions are already transformed by the SDK. This adapter never transforms
## content, creates nodes, chooses random values, or changes source geometry.
const MODULE_ID := "game-plains-windchime-lesson"
const CONTENT_VERSION := "sha256:b2ee44df5422a7b4dd9be1358a075c46cefb00992de802607389f6f94ecfa433"
const SOURCE_SHA256 := "0846f23881d9106d68032323b6278e4f79550e33f1cb73cf4e920323039da942"
const LATCH_ID := "windchime_plains_windchime_lesson"
const FIELDS: Array[String] = ["id","bell","gate","open_seconds","prompt","kind","link_color"]
const SNAPSHOT_FIELDS: Array[String] = ["clock","opened_at","is_open","sequence_step","open_count","motion_clock","motion_running"]

static func validation_error(content: Dictionary, instance: Dictionary) -> String:
	if not content.get("latches") is Array: return "latches: expected array"
	if content.latches.is_empty(): return ""
	if instance.get("module_id") != MODULE_ID or instance.get("content_version") != CONTENT_VERSION or instance.get("role") != "start":
		return "latches: unsupported module/content_version/role"
	if content.get("stable_id") != MODULE_ID or content.get("source_sha256") != SOURCE_SHA256:
		return "latches: source identity differs from supported module"
	if content.get("coordinate_frame") != "owned_rectangle_pixels" or not instance.get("transform") is Dictionary or instance.transform.get("content_is_materialized") != true:
		return "latches: expected SDK-materialized content"
	if content.latches.size() != 1: return "latches: expected the complete single safe_lesson"
	if not _rectangle(content.get("world_bounds")): return "latches: invalid content bounds"
	var bounds := rectangle(content.world_bounds)
	var value: Variant = content.latches[0]
	if not value is Dictionary: return "latches[0]: expected Dictionary"
	var raw: Dictionary = value
	for key: Variant in raw:
		if not key is String or key not in FIELDS: return "latches[0]."+str(key)+": unsupported field"
	for key: String in FIELDS:
		if not raw.has(key): return "latches[0]."+key+": missing field"
	if raw.id != LATCH_ID or raw.kind != "safe_lesson": return "latches[0].id/kind: unsupported latch"
	if not _pair(raw.bell) or not bounds.has_point(point(raw.bell)): return "latches[0].bell: invalid materialized point"
	if not _rectangle(raw.gate) or not bounds.encloses(rectangle(raw.gate)): return "latches[0].gate: invalid materialized rectangle"
	if not _number(raw.open_seconds) or float(raw.open_seconds) != 0.0: return "latches[0].open_seconds: only permanent safe_lesson is supported"
	if not raw.prompt is String or raw.prompt.is_empty(): return "latches[0].prompt: expected text"
	if not raw.link_color is String or raw.link_color.length() not in [6,8] or not raw.link_color.is_valid_hex_number(false):
		return "latches[0].link_color: expected source hex color"
	return ""

static func state_key(instance_id: String, latch_id: String) -> String:
	return instance_id+"/latches/"+latch_id

static func snapshot_error(value: Variant) -> String:
	if not value is Dictionary: return "expected Dictionary"
	var data: Dictionary = value
	for key: Variant in data:
		if not key is String or key not in SNAPSHOT_FIELDS: return str(key)+": unsupported saved field"
	for key: String in SNAPSHOT_FIELDS:
		if not data.has(key): return key+": missing saved field"
	if not _number(data.clock) or float(data.clock) < 0: return "clock: expected nonnegative finite value"
	if not _number(data.opened_at) or float(data.opened_at) < -1 or float(data.opened_at) > float(data.clock): return "opened_at: invalid saved clock"
	if not data.is_open is bool or not data.motion_running is bool: return "expected saved booleans"
	if not _number(data.sequence_step) or float(data.sequence_step) != 0 or not _number(data.motion_clock) or float(data.motion_clock) != 0 or data.motion_running:
		return "safe_lesson cannot restore a sequence or motion actuator"
	if not _number(data.open_count) or float(data.open_count) not in [0.0,1.0]: return "open_count: expected one-way settlement count"
	if not data.is_open and (float(data.open_count) != 0 or float(data.opened_at) != -1): return "closed safe_lesson has inconsistent settlement"
	# The existing permanent-open ledger can restore a gate without a detailed
	# mechanism snapshot. Its original ShotLatch snapshot then has count0/-1.
	if data.is_open and ((float(data.open_count)==1 and float(data.opened_at)<0) or (float(data.open_count)==0 and float(data.opened_at)!=-1)):
		return "opened safe_lesson has inconsistent settlement"
	return ""

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

static func rectangle(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _pair(value: Variant) -> bool:
	return value is Array and value.size()==2 and _number(value[0]) and _number(value[1])

static func _rectangle(value: Variant) -> bool:
	return value is Array and value.size()==4 and _number(value[0]) and _number(value[1]) and _number(value[2]) and _number(value[3]) and float(value[2])>0 and float(value[3])>0
