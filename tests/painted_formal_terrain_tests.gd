extends SceneTree
## Geometry/mesh checks only. No artistic or formal-pool acceptance.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var adapter := load("res://scripts/art/painted_formal_terrain_sample.gd").new() as Node2D
	assert(not adapter.call("candidate_complete",{},2),"Missing source produces no completed banks; baseline must remain")
	assert(not adapter.call("candidate_complete",{"banks":[{"coverage":{"all_samples_match_actual_solid":true}}]},2),"One exhausted bank cannot commit a two-bank replacement")
	assert(not adapter.call("candidate_complete",{"banks":[{"coverage":{"all_samples_match_actual_solid":false}}]},1),"Coverage failure cannot hide baseline")
	var a := Rect2(0,0,485,40)
	var b := Rect2(0,40,465,112)
	var faces := PlainsTerrainFamilySampler.boundary([a,b])
	var outline: Array=adapter.call("_outline",faces)
	assert(outline.size()==6,"Real undercut must retain all six corners")
	var polygon := PackedVector2Array()
	for p: Array in outline:polygon.append(Vector2(p[0],p[1]))
	assert(Geometry2D.is_point_in_polygon(Vector2(475,20),polygon))
	assert(not Geometry2D.is_point_in_polygon(Vector2(475,100),polygon),"Undercut cannot be filled")
	var separated := faces.duplicate()
	separated.append_array(PlainsTerrainFamilySampler.boundary([Rect2(600,0,100,100)]))
	assert((adapter.call("_outline",separated) as Array).is_empty(),"Disconnected contour must refuse")
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/visual_development/painted_terrain_candidate.json"))
	var spec: Dictionary=catalog.terrain.grammar.duplicate(true)
	spec.source_x_offsets={"probe_shore":40};spec.face_patches=[]
	spec.visible_underside=catalog.formal_second_space.visible_underside.duplicate(true)
	var grammar := load("res://scripts/art/painted_terrain_grammar.gd").new() as Node2D
	grammar.call("configure",{"solid_polygons":[{"id":"probe_shore","points":outline}],"top_polylines":[{"id":"probe_grass","points":[[0,0],[485,0]]}]},spec)
	root.add_child(grammar)
	var facts: Dictionary=grammar.call("measured_nodes")
	assert(facts.banks.size()==1)
	assert(facts.banks[0].coverage.all_samples_match_actual_solid,"Thin cropped mesh must retain actual undercut")
	var underside := load(str(spec.visible_underside.texture)) as Texture2D
	var raw := underside.get_image()
	var profile := (grammar.call("_bottom_profile",underside) as Texture2D).get_image()
	for column: int in [768,896]:
		var actual_bottom := 0
		for y: int in range(raw.get_height()-1,-1,-1):
			if raw.get_pixel(column,y).a>=128.0/255.0:actual_bottom=y;break
		var encoded := profile.get_pixel(column,0)
		var decoded := roundi(encoded.r*255)*256+roundi(encoded.g*255)
		assert(actual_bottom==(617 if column==768 else 640),"Frozen source's actual deepest alpha128 column must remain bound")
		assert(decoded==actual_bottom,"Runtime sampling metadata must match actual original source, avoiding hidden ceiling")
	for child: Node in grammar.get_children():
		if str(child.name).begins_with("PaintedContinuousFace"):
			var mesh := child.mesh as ArrayMesh
			for vertex: Vector2 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				assert(vertex.y>=-.001 and vertex.y<=152.001,"Shallow bank mesh cannot extend past true depth")
	grammar.free();adapter.free()
	print("PASS: painted formal six-corner undercut retained; disconnected boundary refused; 152-depth mesh cropped without extending or filling collision void")
	quit()
