class_name LevelPlan
extends RefCounted
## Resolved transient content, not a new save schema. Providers own any legacy
## Manifest conversion; the runtime never regenerates this plan or draws RNG.
var region_id: StringName
var map_index := 1
var source_id: StringName
var source_version := ""
var seed := ""
var map_hash := ""
var bounds := Rect2()
var spawn := Vector2.ZERO
var anchors: Array[Vector2] = []
var modules: Array[LevelModulePlacement] = []
var ground_supports: Array[Rect2] = []
var connections: Array[Dictionary] = []
var forest: ForestLevelGeometry
# Each actor row has id, behavior_id, position (Vector2) and approved overrides.
var actors: Array[Dictionary] = []
# A BossFactory identity and its resolved position, not an implicit map number.
var boss: Dictionary = {}
var boss_arena := Rect2()
var merchant_position := Vector2.ZERO
var pickups: Array[Dictionary] = []
var caches: Array[Dictionary] = []

func validation_error() -> String:
	if region_id.is_empty() or source_id.is_empty() or map_hash.is_empty() or not spawn.is_finite() or not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x<=0 or bounds.size.y<=0:
		return "Invalid level identity or bounds"
	for anchor: Vector2 in anchors:
		if not anchor.is_finite(): return "Invalid level anchor"
	for support: Rect2 in ground_supports:
		if not support.position.is_finite() or not support.size.is_finite() or support.size.x<=0 or support.size.y<=0: return "Invalid ground support"
	if forest!=null:
		var forest_error := forest.validation_error()
		if not forest_error.is_empty(): return forest_error
	var identities: Dictionary = {}
	for placement: LevelModulePlacement in modules:
		if placement==null or placement.instance_id.is_empty() or identities.has(placement.instance_id) or placement.definition==null or placement.template_id!=placement.definition.module_id or not placement.position.is_finite():
			return "Invalid or duplicate module placement"
		identities[placement.instance_id]=true
	identities.clear()
	for actor: Dictionary in actors:
		if not actor.get("id") is String or str(actor.id).is_empty() or identities.has(actor.id) or not actor.get("position") is Vector2 or not actor.position.is_finite() or not actor.get("overrides") is Dictionary:
			return "Invalid or duplicate actor placement"
		if EnemyFactory.definition_for_behavior(StringName(actor.get("behavior_id","")),actor.overrides)==null:
			return "Missing or invalid actor definition"
		identities[actor.id]=true
	if not boss.is_empty() and (not BossFactory.RECORDS.has(StringName(boss.get("definition_id",""))) or not boss.get("position") is Vector2 or not boss.position.is_finite()):
		return "Missing or invalid Boss definition"
	for records: Array in [pickups,caches]:
		identities.clear()
		for record: Dictionary in records:
			if not record.get("id") is String or str(record.id).is_empty() or identities.has(record.id) or not record.get("position") is Vector2 or not record.position.is_finite():
				return "Invalid or duplicate reward placement"
			identities[record.id]=true
	return ""
