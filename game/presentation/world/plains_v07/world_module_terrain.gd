class_name WorldModuleTerrain
extends Node2D
## Presentation observes committed arena geometry; physics stays with PlatformingModule.
var module: PlatformingModule
var terrain: TerrainComposer
var surfaces: Array[Rect2] = []
var hazard_signature := ""

func _ready() -> void:
	module = get_parent() as PlatformingModule
	module.set_meta("underworld_formal_style", true)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	var current: Array[Rect2] = []
	for i: int in module.definition.platforms.size():
		if i not in module.definition.one_way_platform_indices:
			current.append(module.definition.platforms[i])
	var hazards: Array[Dictionary] = []
	for thorn: PlatformThornDefinition in module.definition.surface_thorns:
		if thorn == null or not thorn.is_valid(module.definition.platforms): continue
		var bounds := thorn.danger(module.definition.platforms)
		hazards.append({"id":str(thorn.surface_id),"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"facing":["up","left","right","down"][thorn.face]})
	var signature := JSON.stringify(hazards)
	if terrain != null and current == surfaces and signature==hazard_signature: return
	var groups: Array[Dictionary] = [{"material_id":"windchime_plains","solids":current,"polygons":[] as Array[Dictionary],"bare":false}]
	var replacement := TerrainComposer.compose({"groups":groups,"geometry":TerrainGeometry.plan(current,[])},{},hazards)
	if replacement == null:
		push_error("Formal arena terrain could not render its committed geometry")
		return
	if terrain != null: terrain.free()
	surfaces = current
	hazard_signature = signature
	terrain = replacement
	add_child(terrain)
	module.terrain_candidate_preview = true
	module.queue_redraw()
