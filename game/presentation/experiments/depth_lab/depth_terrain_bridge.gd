class_name DepthTerrainBridge
extends RefCounted
## Rasterize the production composer at native scale; extrude only union edges.
static func build(host: Node, solids: Array[Rect2], material_id: String, flat: Node, spatial: Node, depth: float, units: float) -> Dictionary:
	var plan := TerrainGeometry.plan(solids,[] as Array[Dictionary])
	var groups: Array[Dictionary] = [{"material_id":material_id,"bare":false,"solids":solids,"polygons":[] as Array[Dictionary]}]
	var composed := TerrainComposer.compose({"geometry":plan,"groups":groups})
	var bounds := solids[0]
	for rect: Rect2 in solids: bounds = bounds.merge(rect)
	bounds = bounds.grow(16)
	var bake := SubViewport.new(); bake.name = "Native47Bake"; bake.size = Vector2i(bounds.size); bake.disable_3d = true; bake.transparent_bg = true; bake.world_2d = World2D.new(); bake.render_target_update_mode = SubViewport.UPDATE_ALWAYS; host.add_child(bake)
	composed.position = -bounds.position; bake.add_child(composed)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := bake.get_texture().get_image()
	var texture := ImageTexture.create_from_image(image)
	var front2 := Sprite2D.new(); front2.name = "Production47Front"; front2.texture = texture; front2.position = bounds.get_center(); front2.z_index = -1; front2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; flat.add_child(front2)
	var front3 := Sprite3D.new(); front3.name = "Production47Front"; front3.texture = texture; front3.pixel_size = 1.0/units; front3.position = Vector3(bounds.get_center().x/units,-bounds.get_center().y/units,0); front3.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; front3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD; front3.shaded = true; spatial.add_child(front3)
	var spec := UnderworldTerrain.specification()
	var coords: Array = spec.mask_to_atlas["255"]
	var atlas: Texture2D = load(TerrainMaterialRegistry.definition(material_id).atlas)
	var core := ImageTexture.create_from_image(atlas.get_image().get_region(Rect2i(int(coords[0])*32,int(coords[1])*32,32,32)))
	var material := StandardMaterial3D.new(); material.albedo_texture = core; material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; material.roughness = 1; material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for edge: Vector4 in plan.edges:
		var a := Vector2(edge.x,edge.y); var b := Vector2(edge.z,edge.w); var d := b-a
		var vertices := [Vector3(a.x/units,-a.y/units,0),Vector3(b.x/units,-b.y/units,0),Vector3(b.x/units,-b.y/units,-depth/units),Vector3(a.x/units,-a.y/units,-depth/units)]
		var uv := [Vector2(0,0),Vector2(d.length()/32,0),Vector2(d.length()/32,depth/32),Vector2(0,depth/32)]
		var normal := Vector3(d.y,d.x,0).normalized()
		for index: int in [0,1,2,0,2,3]: tool.set_normal(normal); tool.set_uv(uv[index]); tool.add_vertex(vertices[index])
	var sides := MeshInstance3D.new(); sides.name = "ExposedUnionSides"; sides.mesh = tool.commit(); sides.material_override = material; spatial.add_child(sides)
	var cells := 0
	for child: Node in composed.get_children():
		if child is UnderworldTerrain: cells += child.core_cells.size()
	var result := {"renderer":"TerrainComposer","material":material_id,"world_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"native_pixels":[image.get_width(),image.get_height()],"core_cells":cells,"union_edges":plan.edges.size(),"side_density_wu":32,"sides":sides,"front":front3}
	image.save_png(str(host.get("output"))+"/terrain-front.png")
	bake.queue_free()
	return result
