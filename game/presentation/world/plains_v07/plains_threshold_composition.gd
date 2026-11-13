class_name PlainsThresholdComposition
extends RefCounted
## A grounded entrance bay: the approved doorway, sill, retaining base and light share one site.
static func outside(art: PlainsRoomArt, at: Vector2, side: int, connection: String) -> void:
	var floor_y:=at.y
	var approach:=Rect2()
	for solid: Rect2 in art.room.platforms:
		if solid.has_point(at-Vector2(side*48,-2)) and absf(solid.position.y-at.y)<48:
			approach=solid;floor_y=solid.position.y;break
	var doorway:=Vector2(at.x-side*24,floor_y)
	var facade:=art.sprite("building_threshold",doorway,-3)
	facade.scale.x=side;facade.set_meta("connection",connection)
	# The sill follows the actual supporting bank; no hovering apron over a void.
	if approach.has_area():
		var x0:=maxf(approach.position.x,at.x-(224 if side>0 else 0))
		var x1:=minf(approach.end.x,at.x+(224 if side<0 else 0))
		if x1-x0>=48:
			var base:=UnderworldTerrain.build([Rect2(x0,floor_y, x1-x0,minf(32,approach.size.y))])
			TerrainMaterialRegistry.install_on(base,"mill_masonry");base.z_index=1;art.add_child(base)
			# Small rooted growth softens only the outside masonry/soil seam.
			art.sprite("plains_grass",Vector2(x0+12 if side>0 else x1-12,floor_y),-1)
	var emitter:Dictionary=art.light_settings.emitters.building_threshold
	var glow:=art.add_lamp(FixedWorldProvider.point(emitter.offset))
	glow.color=Color(emitter.color);glow.energy=float(emitter.energy);glow.texture_scale=float(emitter.radius)/64
	glow.reparent(facade,false)
