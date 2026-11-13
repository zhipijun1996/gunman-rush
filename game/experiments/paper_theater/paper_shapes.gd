extends RefCounted
## Small experiment helper. Builds once; never writes room geometry or collisions.
const WASH = preload("res://game/experiments/paper_theater/paper.gdshader")
static var shared_noise: Texture2D
static var inks: Dictionary = {}
var noise: Texture2D
var bold := false
var sheet_count := 0

func _init() -> void:
	if shared_noise != null:
		noise=shared_noise
		return
	var field := FastNoiseLite.new()
	field.seed = 41027
	field.frequency = .018
	field.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.noise = field
	texture.seamless = true
	noise = texture
	shared_noise = texture

func polygon(parent: Node, points: PackedVector2Array, color: Color, z := 0, wash := true) -> Polygon2D:
	var face := Polygon2D.new()
	face.polygon = points
	face.color = Color.WHITE if wash else color
	face.z_index = z
	face.light_mask = 2
	face.antialiased = true
	if wash:
		var key := color.to_html()+str(bold)
		if not inks.has(key):
			var ink := ShaderMaterial.new()
			ink.shader = WASH
			ink.set_shader_parameter("paper_noise",noise)
			ink.set_shader_parameter("pigment",color)
			ink.set_shader_parameter("strength",.16 if bold else .07)
			ink.set_shader_parameter("seed",float(color.to_rgba32()%37))
			inks[key] = ink
		face.material = inks[key]
	parent.add_child(face)
	sheet_count += 1
	return face

func rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

func ellipse(center: Vector2, radius: Vector2, phase := 0.0, count := 48) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in count:
		var angle := TAU*i/count
		var cut := 1.0 + (.016 if bold else .006)*sin(angle*7+phase)
		points.append(center+Vector2(cos(angle),sin(angle))*radius*cut)
	return points

func line(parent: Node, points: PackedVector2Array, color: Color, width := 1.0, z := 0) -> Line2D:
	var stroke := Line2D.new()
	stroke.points = points
	stroke.default_color = color
	stroke.width = width
	stroke.antialiased = true
	stroke.z_index = z
	stroke.light_mask = 2
	parent.add_child(stroke)
	return stroke

func sheet(parent: Node, points: PackedVector2Array, color: Color, z := 0, thickness := 4.0) -> Polygon2D:
	# Small puppet pieces need one paper ply, not five full shadow passes.
	# Only large sheets receive a separate soft contact silhouette.
	if thickness > 2:
		var shade := polygon(parent,points,Color("233f46",.16),z,false)
		shade.position = Vector2(4,7)*thickness/4
	var ply := polygon(parent,points,color.darkened(.23),z,false)
	ply.position = Vector2(1.5,thickness)
	return polygon(parent,points,color,z)

func union_rectangles(rects: Array[Rect2]) -> Array[PackedVector2Array]:
	var outlines: Array[PackedVector2Array] = []
	for rect: Rect2 in rects:
		var candidate := rect_points(rect)
		var i := 0
		while i < outlines.size():
			var merged := Geometry2D.merge_polygons(candidate,outlines[i])
			# A closed ring returns an outer and a hole. Keep its component sheets
			# instead of filling the playable chamber with its outer contour.
			if merged.size() == 1:
				candidate = merged[0]
				outlines.remove_at(i)
				i = 0
			else: i += 1
		outlines.append(candidate)
	return outlines
