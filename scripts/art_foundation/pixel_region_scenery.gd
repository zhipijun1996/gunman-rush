class_name PixelRegionScenery
extends Node2D
## Supported original props. Independent coordinate hash, no gameplay RNG.
const PIXELS := preload("res://assets/pixel_plains/props.svg")
var placements: Array[Dictionary] = []
var protected_regions: Array[Rect2] = []
var supports: Array[Rect2] = []
var clock := 0.0

func configure(stage: PlainsRegionStage) -> void:
	supports = PlainsRegionScenery.solid_supports(stage)
	protected_regions = PlainsRegionScenery.protection(stage)
	var plan := PixelFormalTerrain.geometry_plan(supports)
	var seed_text := str(stage.generated.manifest.manifest_hash)
	for edge: Vector4 in plan.edges:
		if edge.y!=edge.w or edge.z<=edge.x: continue
		for x: int in range(ceili((edge.x+24)/48)*48,int(edge.z-24),48):
			var roll := posmod((seed_text+":pixel-scenery:"+str(x)+":"+str(edge.y)).hash(),1000)
			if roll>480: continue
			var kind := 0 if roll<220 else 1 if roll<330 else 5 if roll<410 else 4 if roll<455 else 3
			var at := Vector2(x,edge.y)
			var bounds := Rect2(at-Vector2(18,64),Vector2(36,64))
			var valid := true
			for blocked: Rect2 in protected_regions:
				if bounds.grow(6).intersects(blocked): valid=false;break
			# Do not draw through another ledge above the selected support.
			for solid: Rect2 in supports:
				if bounds.grow(-.01).intersects(solid): valid=false;break
			if valid: placements.append({"position":at,"kind":kind,"bounds":bounds})
	set_meta("presentation_only",true)

func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	var view := Rect2(camera.get_screen_center_position()-Vector2(800,500),Vector2(1600,1000)) if camera!=null else Rect2(-10000,-10000,20000,20000)
	for item: Dictionary in placements:
		if not view.intersects(item.bounds):continue
		var p: Vector2 = item.position
		var sway := 2*roundf(sin(clock*1.4+p.x*.012)) if int(item.kind) in [0,1,5] else 0.0
		draw_texture_rect_region(PIXELS,Rect2(p-Vector2(16,24),Vector2(32,24)),Rect2(int(item.kind)*64,80,64,48))
		draw_texture_rect_region(PIXELS,Rect2(p-Vector2(16-sway,64),Vector2(32,40)),Rect2(int(item.kind)*64,0,64,80))
