class_name ForestLevelGeometry
extends RefCounted
## Concrete hook/support/gate content, independent of the generating algorithm.
var platforms: Array[Dictionary] = []
var hook_anchors: Array[Dictionary] = []
var training_bells: Array[Dictionary] = []
var vine_gate: Dictionary = {}
var reward_shortcuts: Array[Dictionary] = []
var dangers: Array[Rect2] = []
var danger_presentations: Array = []
var target_hosts: Dictionary = {}
var fruit_presentation := false
var bible_presentation := false
var merge_solid_supports := false

func validation_error() -> String:
	var identities: Dictionary = {}
	for row: Dictionary in platforms:
		if str(row.get("id","")).is_empty() or identities.has(row.id) or not _valid_rect(row.get("rect")) or not row.get("one_way") is bool:
			return "Invalid or duplicate forest support"
		identities[row.id]=true
	identities.clear()
	for row: Dictionary in hook_anchors:
		if str(row.get("id","")).is_empty() or identities.has(row.id) or not _valid_point(row.get("position")):
			return "Invalid or duplicate hook anchor"
		identities[row.id]=true
	for row: Dictionary in training_bells:
		if str(row.get("id","")).is_empty() or identities.has(row.id): return "Invalid or duplicate practice bell"
		identities[row.id]=true
	if not _valid_rect(vine_gate.get("rect")) or not identities.has(vine_gate.get("key_anchor")):
		return "Invalid vine gate or missing hook anchor"
	for row: Dictionary in reward_shortcuts:
		if str(row.get("id","")).is_empty() or not _valid_rect(row.get("rect")) or str(row.get("opened_key","")).is_empty(): return "Invalid reward shortcut"
		if row.has("unlock_reward_id") and str(row.get("reward_source_id","")).is_empty(): return "Missing reward shortcut source"
	for danger: Rect2 in dangers:
		if not danger.position.is_finite() or not danger.size.is_finite() or danger.size.x<=0 or danger.size.y<=0: return "Invalid forest danger"
	return ""

static func _valid_point(value: Variant) -> bool:
	return value is Array and value.size()==2 and _finite_number(value[0]) and _finite_number(value[1])

static func _valid_rect(value: Variant) -> bool:
	return value is Array and value.size()==4 and _finite_number(value[0]) and _finite_number(value[1]) and _finite_number(value[2]) and _finite_number(value[3]) and float(value[2])>0 and float(value[3])>0

static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
