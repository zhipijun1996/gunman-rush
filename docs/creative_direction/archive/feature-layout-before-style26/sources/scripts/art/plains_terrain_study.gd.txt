class_name PlainsTerrainStudy
extends Node2D
signal geometry_changed
## Selected Underworld production material. Historical class name retained for UID stability.
## Optional comparison controls are development-only; never changes physics/RNG.
var stage:PlainsRegionStage
var art:Node2D
var enabled:=false
var toggle:Button
var authored_solids:Array[Rect2]=[]
func collect_solids()->Array[Rect2]:
	var solids:Array[Rect2]=[]
	for module:PlatformingModule in stage.assembler.modules:
		for i:int in module.definition.platforms.size():
			if i not in module.definition.one_way_platform_indices:
				var rect:=module.definition.platforms[i]
				solids.append(Rect2(module.position+rect.position,rect.size))
	if is_instance_valid(stage.assembler.ground_supports):solids.append_array(stage.assembler.ground_supports.columns)
	return solids
func refresh_geometry()->void:
	var solids:=collect_solids()
	if solids==authored_solids:return
	var was_enabled:=enabled
	set_candidate(false)
	if is_instance_valid(art):art.free()
	authored_solids=solids
	var started:=Time.get_ticks_msec()
	art=UnderworldTerrain.build(solids)
	if art==null:push_warning("Terrain study refused unsupported local boundary density; baseline preserved");return
	print("TERRAIN STUDY: solids=%s pieces=%s setup_ms=%s"%[solids.size(),art.get_child_count(),Time.get_ticks_msec()-started])
	art.z_index=-1;add_child(art)
	set_candidate(was_enabled)
	geometry_changed.emit()
func _process(_delta:float)->void:
	# Observer catches committed geometry, including deferred
	# arena breakage and restored snapshots; no new gameplay event dependency.
	refresh_geometry()
func _ready()->void:
	refresh_geometry()
	set_candidate(true)

func enable_comparison()->void:
	if is_instance_valid(toggle):return
	var ui:=CanvasLayer.new();ui.layer=12;add_child(ui)
	toggle=Button.new();toggle.position=Vector2(16,657);toggle.pressed.connect(func()->void:set_candidate(not enabled));ui.add_child(toggle)
	set_candidate(enabled)
func set_candidate(value:bool)->void:
	if not is_instance_valid(art):return
	enabled=value;art.visible=value
	for module:PlatformingModule in stage.assembler.modules:
		module.terrain_candidate_preview=value;module.queue_redraw()
		for child:Node in module.get_children():
			if child is ModuleMovingPlatform:child.set_painted_enabled(value)
	if is_instance_valid(stage.assembler.ground_supports):stage.assembler.ground_supports.visible=not value
	if is_instance_valid(toggle):toggle.text="ART STUDY: CANDIDATE / SHOW BASELINE" if value else "ART STUDY: BASELINE / SHOW CANDIDATE"
