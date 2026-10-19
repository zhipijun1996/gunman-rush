class_name PlainsRegionAssembler
extends RandomStageAssembler
## Explicit region assembler, leaves the eight-room regression assembler intact.
var region_state: PlainsRegionState
var shortcut_bodies: Dictionary = {}
var shortcut_shapes: Dictionary = {}

func build(recorded: Dictionary, tuning: PlayerTuning) -> Dictionary:
	if not is_inside_tree() or not modules.is_empty() or not PlainsRegionGenerator.new().validate(recorded, tuning):
		return {"ok": false, "error": "Invalid connected region manifest"}
	manifest = recorded.duplicate(true)
	var r: Array = manifest.world_bounds
	bounds = Rect2(r[0],r[1],r[2],r[3])
	for n: Dictionary in manifest.nodes:
		var module := PlatformingModule.new()
		module.name = str(n.id).replace("/", "_")
		module.definition = PlainsRegionGenerator.definition(n)
		module.position = Vector2(n.offset[0],n.offset[1])
		module.authoring_debug = false
		modules.append(module)
		if region_state != null: module.clock = float(region_state.clocks.get(n.id, 0.0))
		add_child(module)
	# All original modules exist before explicit cross-module ownership transfer.
	for index: int in manifest.nodes.size():
		var recorded_node: Dictionary=manifest.nodes[index]
		if recorded_node.has("joint_recoil") and not _install_joint_banks(modules[index],recorded_node.joint_recoil):
			return {"ok":false,"error":"Joint recoil physical bank installation failed"}
	if not manifest.ground_supports.is_empty():
		ground_supports=PlainsGroundSupports.new()
		add_child(ground_supports)
		var columns: Array[Rect2]=[]
		for support: Array in manifest.ground_supports: columns.append(Rect2(support[0],support[1],support[2],support[3]))
		ground_supports.install(columns)
	if is_instance_valid(ground_supports):ground_supports.configure_edges(modules)
	PlainsTerrainSkin.configure_ground_edges(modules,ground_supports.columns if is_instance_valid(ground_supports) else [])
	for e: Dictionary in manifest.connections:
		if e.condition != "backside": continue
		var gate: Array = e.gate
		var body := StaticBody2D.new()
		body.position = Vector2(gate[0]+gate[2]/2.0,gate[1]+gate[3]/2.0)
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(gate[2],gate[3])
		shape.shape = rect
		shape.disabled = region_state != null and region_state.opened.has(e.id)
		body.add_child(shape)
		add_child(body)
		shortcut_bodies[e.id] = body
		shortcut_shapes[e.id] = shape
	return {"ok": true}

func open_shortcut(id: String, location: Vector2) -> bool:
	for e: Dictionary in manifest.connections:
		if e.id != id or e.condition != "backside" or region_state.opened.has(id): continue
		if location.distance_to(Vector2(e.control[0],e.control[1])) > 90: return false
		region_state.opened[id] = true
		(shortcut_shapes[id] as CollisionShape2D).set_deferred("disabled", true)
		queue_redraw()
		return true
	return false

func world_entry() -> Vector2:
	return Vector2(manifest.spawn[0],manifest.spawn[1])

func world_exits() -> Array[Dictionary]: return []

func world_anchors() -> Array[Vector2]:
	var result: Array[Vector2] = [world_entry()]
	for a: Dictionary in manifest.areas:
		if a.role == "boss": continue
		result.append(Vector2(a.position[0],a.position[1]))
	return result

func _draw() -> void:
	for id: String in shortcut_bodies:
		if region_state.opened.has(id): continue
		var body := shortcut_bodies[id] as StaticBody2D
		var shape := shortcut_shapes[id] as CollisionShape2D
		var rect := (shape.shape as RectangleShape2D).size
		if manifest.get("regional_art_profile", "").is_empty() and not manifest.get("joint_recoil_profile",false):
			PixelFormalTerrain.draw_gate(self,Rect2(body.position-rect/2,rect))
		else:
			PlainsTerrainSkin.draw_moving_platform(self,Rect2(body.position-rect/2,rect))

# Environment-first entities own their derived physics. Definition rectangles
# are compatibility contacts only; source ownership explicitly retires them.
func _install_joint_banks(module: PlatformingModule, local: Dictionary) -> bool:
	if local.get("module_id", "") != str(module.definition.module_id): return false
	var bodies: Array = local.get("terrain_bodies", [])
	var context: Dictionary = local.get("region_context", {})
	var ownership: Array = context.get("owned_slabs", [])
	if bodies.is_empty() or ownership.is_empty(): return false
	var originals: Array[CollisionShape2D] = []
	var original_paths: Array[String] = []
	for owned: Dictionary in ownership:
		var node_id := str(owned.get("node_id", ""))
		var platform_index := int(owned.get("platform_index", -1))
		if node_id.is_empty() or platform_index < 0: return false
		var owner_module := get_node_or_null(node_id.replace("/", "_")) as PlatformingModule
		if owner_module == null: return false
		var original := owner_module.get_node_or_null("Platform%d/CollisionShape2D" % platform_index) as CollisionShape2D
		if original == null or original.disabled or original.one_way_collision: return false
		var original_path := str(original.get_path())
		if original_path in original_paths: return false
		originals.append(original)
		original_paths.append(original_path)
	# Validate the complete source before changing any live collision owner.
	var prepared: Array[Dictionary] = []
	var roles: Array[String] = []
	for entity: Dictionary in bodies:
		var role := str(entity.get("source_role", ""))
		if role.is_empty() or role in roles or not role.is_valid_identifier(): return false
		roles.append(role)
		var points := PackedVector2Array()
		for point: Array in entity.get("points", []):
			if point.size() != 2: return false
			var vector := Vector2(float(point[0]), float(point[1]))
			if not vector.is_finite(): return false
			points.append(vector)
		if points.size() < 3 or Geometry2D.triangulate_polygon(points).is_empty(): return false
		prepared.append({"source": entity, "points": points})
	for original: CollisionShape2D in originals: original.disabled = true
	for item: Dictionary in prepared:
		var entity: Dictionary = item.source
		var body := StaticBody2D.new()
		body.name = "JointBank_" + str(entity.source_role)
		body.collision_layer = 1
		body.set_meta("joint_bank_source", entity.duplicate(true))
		body.set_meta("joint_owned_originals", original_paths.duplicate())
		var shape := CollisionPolygon2D.new()
		shape.name = "JointBankCollision"
		shape.build_mode = CollisionPolygon2D.BUILD_SOLIDS
		shape.polygon = item.points
		body.add_child(shape)
		module.add_child(body)
	return true

func joint_collision_snapshot() -> Array:
	var rows: Array=[]
	for module: PlatformingModule in modules:
		for child: Node in module.get_children():
			if not child.has_meta("joint_bank_source"): continue
			var shape := child.get_node("JointBankCollision") as CollisionPolygon2D
			var points: Array=[]
			for point: Vector2 in shape.polygon: points.append([shape.to_global(point).x,shape.to_global(point).y])
			rows.append({"module":str(module.name),"node_path":str(child.get_path()),"shape_path":str(shape.get_path()),"source":child.get_meta("joint_bank_source"),"world_points":points,"collision_layer":child.collision_layer,"disabled":shape.disabled,"one_way":shape.one_way_collision,"build_mode":shape.build_mode,"replaced_slabs":_joint_originals_snapshot(child.get_meta("joint_owned_originals",[]))})
	return rows

func _joint_originals_snapshot(paths: Array) -> Array:
	var rows: Array=[]
	for path: String in paths:
		var shape:=get_node_or_null(path) as CollisionShape2D
		if shape==null:rows.append({"path":path,"missing":true});continue
		var rectangle:=shape.shape as RectangleShape2D
		rows.append({"path":path,"disabled":shape.disabled,"one_way":shape.one_way_collision,"size":[rectangle.size.x,rectangle.size.y] if rectangle!=null else [],"world_center":[shape.global_position.x,shape.global_position.y]})
	return rows
