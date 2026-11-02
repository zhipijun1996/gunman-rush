class_name PlainsLandscapeObserver
extends Node
## Read-only observer of the actual default consumer; no input, camera or pixels.
const OBSERVER_PATH := "game/presentation/world/art/plains_landscape_observer.gd"
var stage: PlainsRegionStage
var landscape: PlainsSemanticLandscape
var _output := ""
var _samples: Array[Dictionary] = []
var _last_frame := -120

func configure(source: PlainsRegionStage, consumer: PlainsSemanticLandscape) -> void:
	stage = source
	landscape = consumer

func _ready() -> void:
	process_priority = 100
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-composition-output="):
			_output = validated_output_path(arg.trim_prefix("--visual-composition-output="))
	set_process(not _output.is_empty())

static func validated_output_path(value: String) -> String:
	var full := ProjectSettings.globalize_path(value).simplify_path()
	var build_root := ProjectSettings.globalize_path("res://build").simplify_path().trim_suffix("/")+"/"
	return full if full.begins_with(build_root) and full.get_extension()=="json" else ""

static func shape_bounds(body: Node2D) -> Rect2:
	for child: Node in body.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var size := (child.shape as RectangleShape2D).size
			return child.global_transform*Rect2(-size*.5,size)
	return Rect2()

func protected_bounds() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for module: PlatformingModule in stage.assembler.modules:
		for index: int in module.definition.platforms.size():
			var body := module.get_node_or_null("Platform"+str(index)) as Node2D
			if body == null: continue
			var bounds := shape_bounds(body)
			result.append({"id":str(body.get_path()),"bounds":PlainsSemanticLandscape.rect_values(bounds),"semantic":"one_way_landing" if index in module.definition.one_way_platform_indices else "solid_standing_edge","measurement":"actual global RectangleShape2D; complete body, not inferred alpha"})
		for ferry: ModuleMovingPlatform in module.moving_platforms:
			result.append({"id":str(ferry.get_path()),"bounds":PlainsSemanticLandscape.rect_values(shape_bounds(ferry)),"semantic":"actual_moving_platform"})
	var app := stage.get_parent() as DemoApp
	if app != null and is_instance_valid(app.player):
		result.append({"id":"actual_player","bounds":PlainsSemanticLandscape.rect_values(shape_bounds(app.player)),"semantic":"actual_player"})
	for enemy: EnemyMotor in stage.enemies:
		if is_instance_valid(enemy):
			result.append({"id":str(enemy.get_path()),"bounds":PlainsSemanticLandscape.rect_values(shape_bounds(enemy)),"semantic":"actual_live_enemy","measurement":"Actual moving enemy RectangleShape2D, not static spawn AABB"})
	if is_instance_valid(stage.boss):
		result.append({"id":str(stage.boss.get_path()),"bounds":PlainsSemanticLandscape.rect_values(shape_bounds(stage.boss)),"semantic":"actual_boss_body","measurement":"Actual Boss RectangleShape2D; attack telegraph shape is not inferred from this body"})
	for index: int in landscape.protected_regions.size():
		result.append({"id":"declared_route_hazard_clearance_"+str(index),"bounds":PlainsSemanticLandscape.rect_values(landscape.protected_regions[index]),"semantic":"formal_scenery_protection_candidate","measurement":"Existing scenery-protected AABB declaration; alpha occlusion requires pixels"})
	return result

func measure() -> Dictionary:
	var camera := get_viewport().get_camera_2d()
	var nodes := landscape.measured_nodes()
	var background_nodes: Array[Dictionary] = []
	var app := stage.get_parent() as DemoApp
	if app != null:
		var background := app.get_node_or_null("PlainsBackground") as PlainsBackground
		if background != null: background_nodes = background.measured_nodes()
	var issues := landscape.actual_issues()
	var connected:=stage.find_child("ConnectedLandscape",true,false) as PlainsConnectedLandscape
	var connected_measurements:Dictionary={}
	if connected!=null:
		connected_measurements=connected.measured_nodes()
		issues.append_array(connected.actual_issues())
	if stage.find_child("CreekWaterworksSpace",true,false)!=null: issues.append("rejected_waterworks_in_default")
	return {"engine_physics_frame":Engine.get_physics_frames(),"manifest_hash":stage.generated.manifest.manifest_hash,"nodes":nodes,"protected_world_bounds":protected_bounds(),"background_nodes":background_nodes,"camera_center":PlainsSemanticLandscape.pair(camera.get_screen_center_position()) if camera != null else [],"camera_zoom":PlainsSemanticLandscape.pair(camera.zoom) if camera != null else [],"connected_landscape":connected_measurements,"semantic_landscape":{"nodes":nodes,"omitted":landscape.omitted.duplicate(true),"issues":issues,"camera_center":PlainsSemanticLandscape.pair(landscape._last_camera)},"issues":issues,"consumer_mode":"default_semantic_landscape"}

func _process(_delta: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame-_last_frame < 120: return
	_last_frame=frame
	_samples.append(measure())

func _exit_tree() -> void:
	if _output.is_empty() or _samples.is_empty() or validated_output_path(_output).is_empty(): return
	var last: Dictionary = _samples[-1]
	var result := last.duplicate(true)
	result.merge({"schema_version":1,"artifact_kind":"actual_scene_composition_measurements","observer":{"path":OBSERVER_PATH,"sha256":FileAccess.get_sha256("res://"+OBSERVER_PATH)},"samples":_samples,"scope":"Actual default scene Nodes sampled every120 enginephysicsframes; complete native source binding performed after capture. AABB visibility/depth/labels are not opaque pixel, beauty, traversal or device acceptance."},true)
	DirAccess.make_dir_recursive_absolute(_output.get_base_dir())
	var file := FileAccess.open(_output,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result)+"\n")
		file.close()
