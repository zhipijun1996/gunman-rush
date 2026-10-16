class_name PlainsBackground
extends CanvasLayer
## Sky plus two independently drifting painted pasture layers.
## Finite panorama: no claim that source atlas edges are seamless.
static var TEXTURES: Array[Texture2D] = [
	preload("res://assets/plains_v3/background_layers/sky.png"),
	_layer("hills", 280.0),
	_layer("meadow", 410.0),
]
static func _layer(id: String, top: float) -> AtlasTexture:
	var image := load("res://assets/plains_v3/background_layers/" + id + ".png") as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = image
	atlas.region = Rect2(0, top, image.get_width(), image.get_height() - top)
	atlas.filter_clip = true
	return atlas
const DISTANCE_SHADER: Shader = preload("res://scripts/art/distant_plains.gdshader")
const SCROLL: Array[float] = [0.03, 0.16, 0.38]
const OVERSCAN: Array[float] = [1.35, 1.65, 1.95]
@export var shared_environment_enabled := true
static var wind_seconds := 0.0
var wind_enabled := true
const RIDGE := preload("res://assets/region_production_v3/spaces/distant_limestone_ridge_v1/source.png")
@export var atmospheric_effects := true
@export var continuous_panorama := true
const PANORAMA:=preload("res://assets/plains_v4/spatial/panorama.png")
var region_layers := false
var surface: Node2D
var panels: Array[Sprite2D] = []
var _last_transform := Transform2D()
var _last_size := Vector2.ZERO
var _origin := Vector2.ZERO
var _has_origin := false
var _materials: Array[ShaderMaterial] = []
func _ready() -> void:
	layer = -100
	shared_environment_enabled = shared_environment_enabled and OS.get_environment("PLAINS_SHARED_ENVIRONMENT") != "0"
	wind_enabled = OS.get_environment("PLAINS_SHARED_WIND") != "0"
	wind_seconds = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	surface = Node2D.new()
	add_child(surface)
	if shared_environment_enabled:
		_build_shared_environment()
		_update_panels()
		return
	if continuous_panorama:
		var panel:=Sprite2D.new()
		panel.texture=PANORAMA
		if atmospheric_effects:
			var material:=ShaderMaterial.new()
			material.shader=DISTANCE_SHADER
			material.set_shader_parameter("saturation",.38)
			material.set_shader_parameter("mist",.38)
			material.set_shader_parameter("softness",2.4)
			material.set_shader_parameter("mist_color",Color("9faf98"))
			panel.material=material
		surface.add_child(panel)
		panels.append(panel)
		_update_panels()
		return
	for index: int in TEXTURES.size():
		var panel := Sprite2D.new()
		panel.texture = TEXTURES[index]
		if atmospheric_effects:
			var material := ShaderMaterial.new()
			material.shader = DISTANCE_SHADER
			material.set_shader_parameter("saturation", [0.70, 0.50, 0.58][index])
			material.set_shader_parameter("mist", [0.18, 0.40, 0.30][index])
			material.set_shader_parameter("softness", [1.0, 1.8, 1.1][index])
			material.set_shader_parameter("mist_color", Color("aebaa4"))
			material.set_shader_parameter("ground_color", [Color("aebaa4"), Color("9ba58d"), Color("929674"), Color("717d59")][index])
			panel.material = material
			_materials.append(material)
		surface.add_child(panel)
		panels.append(panel)
	_update_panels()
func use_region_layers() -> void:
	# Panorama remains the admitted extreme-far world-scale backdrop. It alone
	# does not establish local depth; real finite landscape nodes supply that.
	# Failed waterworks architecture is a separate, retired consumer.
	region_layers = true
	_update_panels()

func measured_nodes() -> Array[Dictionary]:
	if shared_environment_enabled: return _shared_measurements()
	var result: Array[Dictionary] = []
	for panel: Sprite2D in panels:
		result.append({"node_path":str(panel.get_path()), "layer":"extreme_far", "semantic":"world_scale_panorama" if continuous_panorama else "legacy_pasture_layer", "spatial_use":"extreme_far_backdrop_behind_independent_world_landscape" if region_layers else "legacy_background_diagnostic", "screen_bounds":[panel.get_rect().position.x*panel.scale.x+panel.position.x,panel.get_rect().position.y*panel.scale.y+panel.position.y,panel.get_rect().size.x*panel.scale.x,panel.get_rect().size.y*panel.scale.y], "texture_path":panel.texture.resource_path,"texture_sha256":FileAccess.get_sha256(panel.texture.resource_path),"canvas_layer":layer,"region_layers":region_layers,"visible_in_tree":panel.is_visible_in_tree()})
	return result

func _process(delta: float) -> void:
	if shared_environment_enabled:
		if wind_enabled and not get_tree().paused: wind_seconds += delta
		_update_panels()
		return
	var current := get_viewport().get_canvas_transform()
	var size := get_viewport().get_visible_rect().size
	if current != _last_transform or size != _last_size:
		_update_panels()
static func panel_rect(size: Vector2, offset: Vector2, index: int) -> Rect2:
	var source_size := (TEXTURES[index] as AtlasTexture).atlas.get_size() if TEXTURES[index] is AtlasTexture else TEXTURES[index].get_size()
	var factor := maxf(size.x / source_size.x, size.y / source_size.y) * OVERSCAN[index]
	var extent := source_size * factor
	var margin := (extent - size) * 0.5
	var desired := offset * SCROLL[index]
	var drift := Vector2(desired.x / sqrt(1.0 + pow(desired.x / maxf(1.0, margin.x), 2.0)), desired.y / sqrt(1.0 + pow(desired.y / maxf(1.0, margin.y), 2.0)))
	return Rect2(-margin - drift, extent)
static func landscape_rect(size: Vector2, offset: Vector2, index: int) -> Rect2:
	var coverage := panel_rect(size, offset, index)
	# Pin silhouettes to screen horizon, rather than centering alpha-heavy source
	# canvases: high world cameras retain recognizable meadow/ruin layers.
	var height: float = size.y * [1.0, 0.63, 0.54][index]
	var bottom: float = size.y * [1.0, 0.90, 1.34][index]
	var vertical_drift := clampf(offset.y * SCROLL[index] * 0.10, -size.y * 0.035, size.y * 0.035)
	return Rect2(Vector2(coverage.position.x, bottom - height - vertical_drift), Vector2(coverage.size.x, height))
func _update_panels() -> void:
	_last_transform = get_viewport().get_canvas_transform()
	_last_size = get_viewport().get_visible_rect().size
	if _last_size.x <= 0.0 or _last_size.y <= 0.0:
		return
	var center := _last_transform.affine_inverse() * (_last_size / 2.0)
	if shared_environment_enabled:
		_update_shared_environment(center)
		return
	if not _has_origin:
		_origin = center
		_has_origin = true
	if continuous_panorama:
		var app := get_parent() as DemoApp
		if panels[0].material is ShaderMaterial and app != null:
			(panels[0].material as ShaderMaterial).set_shader_parameter("mist",.52 if app.connected_region else .38)
		var source:=PANORAMA.get_size()
		var factor:=maxf(_last_size.x/source.x,_last_size.y/source.y)*1.2
		var extent:=source*factor
		var margin:=(extent-_last_size)/2
		var drift:=(center-_origin)*.045
		drift=Vector2(margin.x*tanh(drift.x/maxf(margin.x,1)),margin.y*tanh(drift.y/maxf(margin.y,1)))
		panels[0].position=_last_size/2-drift
		panels[0].scale=Vector2.ONE*factor
		return
	for index: int in panels.size():
		var rect := panel_rect(_last_size, center - _origin, index) if index == 0 else landscape_rect(_last_size, center - _origin, index)
		panels[index].position = rect.get_center()
		if index > 0 and atmospheric_effects:
			var content_height := rect.size.y
			rect.size.y = maxf(content_height, _last_size.y * 1.42 - rect.position.y)
			var atlas := TEXTURES[index] as AtlasTexture
			var region := atlas.region
			var atlas_size := atlas.atlas.get_size()
			_materials[index].set_shader_parameter("texture_region", Vector4(region.position.x / atlas_size.x, region.position.y / atlas_size.y, region.size.x / atlas_size.x, region.size.y / atlas_size.y))
			_materials[index].set_shader_parameter("content_fraction", content_height / rect.size.y)
			_materials[index].set_shader_parameter("bottom_fade", 0.12)
			panels[index].position = rect.get_center()
		panels[index].scale = rect.size / TEXTURES[index].get_size()

# These two finite planes have different source and motion responsibilities.
# The actual Manifest bounds size the overscan; no wrap/seamless claim or tanh.
func _build_shared_environment() -> void:
	for index: int in 2:
		var sprite := Sprite2D.new()
		sprite.name = "IndependentSky" if index == 0 else "DistantLimestoneRidge"
		sprite.centered = false
		sprite.texture = TEXTURES[0] if index == 0 else RIDGE
		var material := ShaderMaterial.new()
		material.shader = DISTANCE_SHADER
		material.set_shader_parameter("saturation",0.45 if index == 0 else 0.38)
		material.set_shader_parameter("mist",0.08 if index == 0 else 0.16)
		material.set_shader_parameter("contrast",0.35 if index == 0 else 0.72)
		material.set_shader_parameter("softness",0.0)
		material.set_shader_parameter("mist_color",Color("b7cbd3") if index == 0 else Color("9bafb9"))
		material.set_shader_parameter("tone_tint",Vector3(0.96,0.99,1.03) if index == 0 else Vector3(0.91,0.98,1.05))
		sprite.material = material
		surface.add_child(sprite)
		panels.append(sprite)

func _shared_domain() -> Rect2:
	var app := get_parent() as DemoApp
	if app != null and app.stage is PlainsRegionStage:
		var b: Array = (app.stage as PlainsRegionStage).generated.manifest.world_bounds
		return Rect2(b[0]-180.0,b[1]-180.0,b[2]+360.0,b[3]+360.0)
	return Rect2(-6000,-4000,16000,10000)

static func shared_projection(size: Vector2, center: Vector2, domain: Rect2) -> Array[Rect2]:
	var relative := center-domain.get_center()
	var sky_source := TEXTURES[0].get_size()
	var sky_factor := 1.55*maxf((size.x*1.18+domain.size.x*0.008)/sky_source.x,(size.y*1.18+domain.size.y*0.004)/sky_source.y)
	var sky_extent := sky_source*sky_factor
	var sky := Rect2((size-sky_extent)*0.5-relative*Vector2(0.008,0.004),sky_extent)
	var ridge_source := RIDGE.get_size()
	# Source alpha128 skyline top336, original full lower landmass to1024.
	# Uniform scale keeps its painting; lower coverage is actual source pixels.
	var ridge_factor := maxf((size.x*1.30+domain.size.x*0.07)/ridge_source.x,(size.y*0.85+domain.size.y*0.018)/(ridge_source.y-336.0))
	var extent := ridge_source*ridge_factor
	var ridge := Rect2(Vector2((size.x-extent.x)*0.5-relative.x*0.07,size.y*0.50-336.0*ridge_factor-relative.y*0.018),extent)
	return [sky,ridge]

func _update_shared_environment(center: Vector2) -> void:
	var rects := shared_projection(_last_size,center,_shared_domain())
	for index: int in panels.size():
		panels[index].position = rects[index].position
		panels[index].scale = rects[index].size/panels[index].texture.get_size()

func _shared_measurements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var domain := _shared_domain()
	for index: int in panels.size():
		var panel := panels[index]
		result.append({"node_path":str(panel.get_path()),"layer":"extreme_far" if index==0 else "far","semantic":"independent_air_cloud_sky" if index==0 else "pure_distant_geology","spatial_use":"sky_without_geography" if index==0 else "finite_low_frequency_ridge_no_gameplay_support","screen_bounds":[panel.position.x,panel.position.y,panel.texture.get_width()*panel.scale.x,panel.texture.get_height()*panel.scale.y],"texture_path":panel.texture.resource_path,"texture_sha256":FileAccess.get_sha256(panel.texture.resource_path),"canvas_layer":layer,"region_layers":region_layers,"visible_in_tree":panel.is_visible_in_tree(),"world_domain":[domain.position.x,domain.position.y,domain.size.x,domain.size.y],"camera_coefficient":[0.008,0.004] if index==0 else [0.07,0.018],"uniform_source_scale":panel.scale.x,"wind_seconds":wind_seconds,"wind_enabled":wind_enabled,"shared_environment":true})
	return result
