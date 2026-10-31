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
	var supports: Dictionary = {}
	for row: Dictionary in platforms:
		if not LevelContentValidation.identity(row.get("id")) or supports.has(row.id) or not LevelContentValidation.rectangle(row.get("rect")) or not row.get("one_way") is bool:
			return "Invalid or duplicate forest support"
		supports[row.id]=true
	if not target_hosts.get("mounts",[]) is Array: return "Invalid target mounts"
	var mounts: Dictionary = {}
	for mount: Variant in target_hosts.get("mounts",[]):
		if not mount is Dictionary or not LevelContentValidation.identity(mount.get("target_id")) or mounts.has(mount.target_id): return "Invalid target mount identity"
		if mount.has("resolved") and not mount.resolved is bool: return "Invalid target mount resolution"
		if bool(mount.get("resolved",false)) and mount.get("presentation")=="runtime_rooted_fruit" and not LevelContentValidation.point(mount.get("stem_root")): return "Invalid resolved fruit stem"
		mounts[mount.target_id]=mount
	var identities: Dictionary = {}
	for row: Dictionary in hook_anchors:
		if not LevelContentValidation.identity(row.get("id")) or identities.has(row.id) or not LevelContentValidation.point(row.get("position")):
			return "Invalid or duplicate hook anchor"
		if row.has("hang_enabled") and not row.hang_enabled is bool: return "Invalid anchor hang setting"
		var mount: Dictionary=mounts.get(row.id,{})
		var runtime_fruit: bool=bool(mount.get("resolved",false)) and mount.get("presentation")=="runtime_rooted_fruit"
		if fruit_presentation and (row.get("fruit_presentation")=="rooted_fruit" or runtime_fruit):
			if not LevelContentValidation.identity(row.get("fruit_role")) or (not runtime_fruit and not LevelContentValidation.point(row.get("fruit_stem_root"))): return "Invalid fruit anchor content"
		identities[row.id]=true
	for id: Variant in mounts:
		if not identities.has(id): return "Missing target mount anchor"
	for row: Dictionary in training_bells:
		if not ForestPracticeBell.configuration_valid(row) or identities.has(row.id) or not supports.has(row.host_support_id): return "Invalid practice bell or missing support"
		identities[row.id]=true
	if not LevelContentValidation.rectangle(vine_gate.get("rect")) or not LevelContentValidation.identity(vine_gate.get("key_anchor")) or not identities.has(vine_gate.key_anchor):
		return "Invalid vine gate or missing hook anchor"
	var shortcuts: Dictionary = {}
	for row: Dictionary in reward_shortcuts:
		if not LevelContentValidation.identity(row.get("id")) or shortcuts.has(row.id) or not LevelContentValidation.rectangle(row.get("rect")) or not LevelContentValidation.identity(row.get("opened_key")): return "Invalid or duplicate reward shortcut"
		if row.has("unlock_reward_id") and not LevelContentValidation.identity(row.get("reward_source_id")): return "Missing reward shortcut source"
		if row.has("unlock_discovery_id") and not LevelContentValidation.identity(row.unlock_discovery_id): return "Invalid discovery shortcut source"
		shortcuts[row.id]=true
	for danger: Rect2 in dangers:
		if not danger.position.is_finite() or not danger.size.is_finite() or danger.size.x<=0 or danger.size.y<=0: return "Invalid forest danger"
	return ""
