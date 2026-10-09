class_name MetaProgression
extends RefCounted

# P4 in-memory home fixture: no currency conversion, save or unlock promises.
var _settled: Dictionary = {}
var _completed_runs := 0
var _failed_runs := 0
var _last_summary: Dictionary = {}

func settle(end_id: StringName, success: bool, summary: Dictionary) -> bool:
	if end_id.is_empty():
		return false
	if _settled.has(end_id):
		return _settled[end_id] == {"success": success, "summary": summary}
	_settled[end_id] = {"success": success, "summary": summary.duplicate(true)}
	if success:
		_completed_runs += 1
	else:
		_failed_runs += 1
	_last_summary = summary.duplicate(true)
	return true

func snapshot() -> Dictionary:
	return {"completed_runs": _completed_runs, "failed_runs": _failed_runs, "meta_currency": 0, "last_summary": _last_summary.duplicate(true)}
