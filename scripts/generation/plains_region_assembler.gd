class_name PlainsRegionAssembler
extends RandomStageAssembler
## Explicit region assembler, leaves the eight-room regression assembler intact.
var region_state: PlainsRegionState
var shortcut_bodies: Dictionary = {}
var shortcut_shapes: Dictionary = {}
var attack_shortcuts: Array[BacksideShotLatch] = []
signal attack_shortcut_opened(id: String)

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

func install_attack_shortcuts(player: PlayerController, lifetime: DemoLifetime) -> void:
	if not attack_shortcuts.is_empty(): return
	for edge: Dictionary in manifest.connections:
		if edge.condition != "backside": continue
		var latch := BacksideShotLatch.new()
		latch.shortcut_id = edge.id
		latch.upper_control = Vector2(edge.control[0],edge.control[1])
		latch.formal_presentation = true
		latch.gate_visual_enabled = false
		latch.region_presentation = true
		latch.link_id = str(edge.id)
		add_child(latch)
		latch.setup(player,lifetime,latch.upper_control+Vector2(0,-45),Rect2(edge.gate[0],edge.gate[1],edge.gate[2],edge.gate[3]))
		# Existing assembler owns the only shortcut wall. Latch is its accepted
		# attack actuator; its duplicate wall is disabled immediately.
		latch.gate_body.collision_layer = 0
		latch.gate_shape.set_deferred("disabled",true)
		if region_state.opened.has(edge.id):
			latch.is_open = true
			latch.bell_body.collision_layer = 0
		latch.opened.connect(_commit_attack_shortcut.bind(latch))
		attack_shortcuts.append(latch)

func _commit_attack_shortcut(latch: BacksideShotLatch) -> void:
	if open_shortcut(latch.shortcut_id,latch.upper_control):
		GameAudio.cue(self,&"door")
		attack_shortcut_opened.emit(latch.shortcut_id)

func cancel_attack_shortcuts(permanent: bool = false) -> void:
	for latch: BacksideShotLatch in attack_shortcuts:
		if permanent: latch.cancel()
		else: latch.cancel_pending()

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
		if UnderworldActors.enabled(self): UnderworldTerrain.draw_mechanism_beam(self,Rect2(body.position-rect/2,rect),1.0)
		else: PixelFormalTerrain.draw_gate(self,Rect2(body.position-rect/2,rect))
