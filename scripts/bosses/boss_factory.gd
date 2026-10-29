class_name BossFactory
extends RefCounted
## Finite creation boundary, without parenting/activation/health initialization.
## Definitions keep their existing PackedScene/shared Resource semantics.
const RECORDS := {
	&"clockwork_guardian":["res://scenes/bosses/clockwork_guardian.tscn","res://resources/bosses/clockwork_guardian.tres"],
	&"bellstrider":["res://scenes/bosses/bellstrider.tscn","res://resources/bosses/bellstrider.tres"],
	&"windkeeper":["res://scenes/bosses/windkeeper.tscn","res://resources/bosses/windkeeper.tres"],
	&"windkeeper_storm":["res://scenes/bosses/windkeeper.tscn","res://resources/bosses/windkeeper_storm.tres"],
	&"thorn_guardian":["res://scenes/bosses/thorn_guardian.tscn","res://resources/bosses/thorn_guardian.tres"],
	&"thorn_queen":["res://scenes/bosses/thorn_queen.tscn","res://resources/bosses/thorn_queen.tres"],
	&"rootbell_guardian_v2":["res://scenes/bosses/rootbell_guardian_v2.tscn","res://resources/bosses/rootbell_guardian_v2.tres"],
	&"thorn_queen_v2":["res://scenes/bosses/thorn_queen_v2.tscn","res://resources/bosses/thorn_queen_v2.tres"],
	&"thorn_queen_canopy":["res://scenes/bosses/thorn_queen_canopy.tscn","res://resources/bosses/thorn_queen_canopy.tres"]
}

static func create(identity: StringName) -> BossMotor:
	if not RECORDS.has(identity): return null
	var record: Array = RECORDS[identity]
	var scene_path: String = record[0]
	var packed := load(scene_path) as PackedScene
	if packed == null: return null
	var body := packed.instantiate() as BossMotor
	if identity == &"windkeeper_storm":
		var definition_path: String = record[1]
		(body.get_node("Encounter") as BossEncounter).definition = load(definition_path) as BossDefinition
	return body

static func create_recorded(scene_path: String, definition_path: String) -> BossMotor:
	# Empty definition means the exact scene default. A custom lab Definition
	# can still be assigned by its existing owner after factory creation.
	for identity: StringName in RECORDS:
		var record: Array = RECORDS[identity]
		if record[0] != scene_path: continue
		if definition_path.is_empty():
			if identity == &"windkeeper_storm": continue
			return create(identity)
		if record[1] == definition_path: return create(identity)
	return null
