extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)
func union_at(point: Vector2, pieces: Array[Rect2]) -> bool:
	for rect: Rect2 in pieces:
		if rect.has_point(point): return true
	return false
func case_check(solids: Array[Rect2]) -> void:
	var art := PixelFormalTerrain.build(solids)
	check(art != null, "exact union accepts authored narrow geometry")
	if art == null: return
	check(art.get_child_count() > 0, "actual shader draw present")
	var plan := PixelFormalTerrain.geometry_plan(solids)
	var reverse := solids.duplicate()
	reverse.reverse()
	check(plan == PixelFormalTerrain.geometry_plan(reverse), "order invariant union")
	for rect: Rect2 in solids:
		for u: float in [.01,.25,.5,.75,.99]:
			for v: float in [.01,.25,.5,.75,.99]:
				var point := rect.position + rect.size * Vector2(u,v)
				check(union_at(point,art.union_pieces), "all physical occupancy is drawn")
	for piece: Rect2 in art.union_pieces:
		for u: float in [.01,.25,.5,.75,.99]:
			for v: float in [.01,.25,.5,.75,.99]:
				check(union_at(piece.position + piece.size * Vector2(u,v),solids), "drawing remains inside exact union")
	for quad: ColorRect in art.get_children():
		check(quad.material.shader == PixelFormalTerrain.MATERIAL, "new shader owns actual quad")
		check(quad.get_meta("exact_union_piece") == Rect2(quad.position,quad.size), "no draw snapping")
		check(quad.find_children("*","CollisionObject2D",true,false).is_empty(), "art owns no collisions")
	art.free()
func run() -> void:
	for height: float in [.125,8.5,18,24,32]:
		for width: float in [.25,24,31.5,64,383.5,640]:
			case_check([Rect2(-17.25,3.5,width,height)])
	case_check([Rect2(-32,-24,96,24),Rect2(-32,0,24,120),Rect2(40,0,24,120),Rect2(-32,96,96,24)])
	case_check([Rect2(-13.25,-9.5,44,18),Rect2(5,-5,90,38),Rect2(94.75,-5,.5,64)])
	var gap: Array[Rect2] = [Rect2(-12.5,-3,12,24),Rect2(-.375,-3,24,24)]
	var gap_plan := PixelFormalTerrain.geometry_plan(gap)
	var gap_pieces: Array[Rect2] = []
	gap_pieces.assign(gap_plan.pieces)
	check(not union_at(Vector2(-.4375,0),gap_pieces), "subpixel empty gap is preserved")
	var hole: Array[Rect2] = [Rect2(0,0,100,12),Rect2(0,12,12,76),Rect2(88,12,12,76),Rect2(0,88,100,12)]
	var hole_pieces: Array[Rect2] = []
	hole_pieces.assign(PixelFormalTerrain.geometry_plan(hole).pieces)
	check(not union_at(Vector2(50,50),hole_pieces), "interior hole is never painted over")
	var whole: Array[Rect2] = [Rect2(-8.5,-9.25,340,48)]
	var partitioned: Array[Rect2] = [Rect2(-8.5,-9.25,70,48),Rect2(61.5,-9.25,270,48)]
	check(PixelFormalTerrain.geometry_plan(whole) == PixelFormalTerrain.geometry_plan(partitioned), "partition invariant")
	var duplicated := partitioned.duplicate()
	duplicated.append(partitioned[0])
	check(PixelFormalTerrain.geometry_plan(whole) == PixelFormalTerrain.geometry_plan(duplicated), "duplicate overlap invariant")
	var module := PlatformingModule.new()
	module.definition = load("res://resources/generation/modules/plains_ferry_gears.tres")
	if module.definition == null:
		module.free()
	else:
		root.add_child(module)
		await physics_frame
		check(module.pixel_mechanism_art, "normal module defaults to new pixel mechanism family")
		var painted_one_way := 0
		for child: Node in module.get_children():
			if child.has_meta("platform_index"):
				painted_one_way += 1
				check(child is PlainsWoodPlatformArt.PixelOneWayPaint, "actual one-way consumer uses new renderer")
		check(painted_one_way == module.definition.one_way_platform_indices.size(), "every one-way physical surface owns one visual")
		for index: int in module.definition.one_way_platform_indices:
			var body := module.get_node("Platform%d" % index)
			var shape := body.get_node("CollisionShape2D") as CollisionShape2D
			check(shape.one_way_collision and shape.shape.size == module.definition.platforms[index].size, "module one-way physics unchanged")
		var old_clock := module.clock
		for ferry: ModuleMovingPlatform in module.moving_platforms:
			var old_position := ferry.position
			var shape := ferry.get_child(0) as CollisionShape2D
			var old_size: Vector2 = shape.shape.size
			ferry.set_painted_enabled(true)
			check(ferry.pixel_art_enabled and is_instance_valid(ferry.painted_art) and ferry.painted_art.visible, "formal ferry uses pixel draw by default")
			check(ferry.position == old_position and shape.shape.size == old_size and module.clock == old_clock, "style toggle changes no carrier state")
		module.free()
	print("PIXEL_FORMAL_TERRAIN checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
