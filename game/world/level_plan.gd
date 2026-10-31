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
	var node_names: Dictionary = {}
	for placement: LevelModulePlacement in modules:
		if placement==null or placement.instance_id.is_empty() or identities.has(placement.instance_id) or placement.definition==null or not placement.definition.is_valid() or placement.template_id!=placement.definition.module_id or not placement.position.is_finite():
			return "Invalid or duplicate module placement"
		var node_name := placement.instance_id.replace("/","_")
		if node_name!=node_name.validate_node_name() or node_names.has(node_name): return "Invalid or conflicting module node name"
		node_names[node_name]=true
		identities[placement.instance_id]=placement
	var ownership_error := _ownership_error(identities)
	if not ownership_error.is_empty(): return ownership_error
	identities.clear()
	for edge: Dictionary in connections:
		if not LevelContentValidation.identity(edge.get("id")) or identities.has(edge.id) or not LevelContentValidation.identity(edge.get("condition")):
			return "Invalid or duplicate level connection"
		identities[edge.id]=true
		if edge.condition=="backside" and (not LevelContentValidation.rectangle(edge.get("gate")) or not LevelContentValidation.point(edge.get("control"))):
			return "Invalid backside connection geometry"
	identities.clear()
	for actor: Dictionary in actors:
		if not actor.get("id") is String or str(actor.id).is_empty() or identities.has(actor.id) or not actor.get("position") is Vector2 or not actor.position.is_finite() or not actor.get("overrides") is Dictionary:
			return "Invalid or duplicate actor placement"
		if not LevelContentValidation.identity(actor.get("behavior_id")) or EnemyFactory.definition_for_behavior(StringName(actor.behavior_id),actor.overrides)==null:
			return "Missing or invalid actor definition"
		identities[actor.id]=true
	if not boss.is_empty() and (not LevelContentValidation.identity(boss.get("definition_id")) or not BossFactory.RECORDS.has(StringName(boss.definition_id)) or not boss.get("position") is Vector2 or not boss.position.is_finite()):
		return "Missing or invalid Boss definition"
	if not merchant_position.is_finite() or not boss_arena.position.is_finite() or not boss_arena.size.is_finite(): return "Invalid encounter location"
	for records: Array in [pickups,caches]:
		identities.clear()
		for record: Dictionary in records:
			if not record.get("id") is String or str(record.id).is_empty() or identities.has(record.id) or not record.get("position") is Vector2 or not record.position.is_finite():
				return "Invalid or duplicate reward placement"
			identities[record.id]=true
	for pickup: Dictionary in pickups:
		if not LevelContentValidation.identity(pickup.get("kind")) or not LevelContentValidation.number(pickup.get("amount")):
			return "Invalid pickup kind or amount"
	return ""

func _ownership_error(placements: Dictionary) -> String:
	var owned_slabs: Dictionary = {}
	for placement: LevelModulePlacement in modules:
		var source := placement.terrain_ownership
		if source.is_empty(): continue
		if source.get("module_id")!=str(placement.template_id) or not source.get("terrain_bodies") is Array or not source.get("region_context") is Dictionary:
			return "Invalid terrain ownership source"
		var context: Dictionary=source.region_context
		if not context.get("owned_slabs") is Array or context.owned_slabs.is_empty() or source.terrain_bodies.is_empty(): return "Missing terrain ownership declarations"
		for row: Variant in context.owned_slabs:
			if not row is Dictionary or not LevelContentValidation.identity(row.get("node_id")) or not LevelContentValidation.number(row.get("platform_index")) or float(row.platform_index)!=floorf(float(row.platform_index)): return "Invalid terrain slab reference"
			var owner: LevelModulePlacement=placements.get(str(row.node_id))
			var index := int(row.platform_index)
			if owner==null or index<0 or index>=owner.definition.platforms.size() or index in owner.definition.one_way_platform_indices: return "Missing or unsupported terrain slab"
			var key := "%s/%s" % [row.node_id,index]
			if owned_slabs.has(key): return "Terrain slab has multiple collision owners"
			owned_slabs[key]=true
		var roles: Dictionary = {}
		for row: Variant in source.terrain_bodies:
			if not row is Dictionary or not row.get("source_role") is String or not str(row.source_role).is_valid_identifier() or roles.has(row.source_role) or not row.get("points") is Array:
				return "Invalid terrain body source"
			roles[row.source_role]=true
			var points := PackedVector2Array()
			for point: Variant in row.points:
				if not LevelContentValidation.point(point): return "Invalid terrain polygon point"
				points.append(Vector2(point[0],point[1]))
			if points.size()<3 or Geometry2D.triangulate_polygon(points).is_empty(): return "Invalid terrain polygon"
	return ""
