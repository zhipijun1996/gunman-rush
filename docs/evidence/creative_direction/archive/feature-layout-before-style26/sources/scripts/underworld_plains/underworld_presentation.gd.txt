class_name UnderworldPresentation
extends Node2D
## Selected production fine-pixel and warm-light presentation. No gameplay writes.
const SPRITE_SHADER := preload("res://shaders/underworld_fine_sprite.gdshader")
const SURFACE_SHADER := preload("res://shaders/formal_fine_lit.gdshader")
const MAX_VISIBLE_LIGHTS := 8
var world: Node
var actor: PlayerMotor
var emitters: Array[Dictionary]=[]
var _materials: Array[ShaderMaterial]=[]
var _seen: Dictionary={}
var _latches: Array[WeakRef]=[]
var _terrain_materials: Array[ShaderMaterial]=[]
var _clock := 0.0
var _sprite_material: ShaderMaterial
var _surface_material: ShaderMaterial
var _light_texture: GradientTexture2D
var foreground: Node

static func attach(owner: Node,context: Node,player: PlayerMotor) -> UnderworldPresentation:
	var prior:=owner.get_node_or_null("FineWorldPresentation") as UnderworldPresentation
	if prior!=null: return prior
	var result:=UnderworldPresentation.new()
	result.name="FineWorldPresentation";result.world=context;result.actor=player
	owner.add_child(result)
	return result

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_material=ShaderMaterial.new();_sprite_material.shader=SPRITE_SHADER
	_surface_material=ShaderMaterial.new();_surface_material.shader=SURFACE_SHADER
	install_item(world)
	if not world.is_ancestor_of(actor): install_item(actor)
	install_lights()
	install_occluders(world)
	var ambient:=CanvasModulate.new();ambient.color=Color(.98,.98,1)
	add_child(ambient)
	get_tree().node_added.connect(_node_added)
	# Optional foreground has no collision and independently protects gameplay/UI.
	var script:=load("res://scripts/underworld_plains/underworld_foreground.gd") as Script
	if script!=null: foreground=script.attach(get_parent(),world,actor)
	refresh()

func _node_added(node: Node) -> void:
	if node==self or is_ancestor_of(node): return
	if world.is_ancestor_of(node) or (is_instance_valid(actor) and actor.is_ancestor_of(node)):
		install_item.call_deferred(node)

func install_item(node: Node) -> void:
	if not is_instance_valid(node) or node==self or node is CanvasLayer or node is Control: return
	if not _seen.has(node.get_instance_id()):
		_seen[node.get_instance_id()]=true
		if node is CanvasItem:
			var item:=node as CanvasItem
			item.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			if item.material==null:
				if item is Sprite2D or item is UnderworldPlayer or item is UnderworldEnemy:
					item.material=_sprite_material
				elif item is PlainsWoodPlatformArt.PixelOneWayPaint or item is ShotLatch:
					item.material=_surface_material
			if item.material is ShaderMaterial and item.get_parent() is UnderworldTerrain:
				var material:=item.material as ShaderMaterial
				if "wind_clock" in material.shader.code and material not in _terrain_materials:
					_terrain_materials.append(material)
		if node is ShotLatch:
			node.set_meta("fine_space_presentation",true)
			_latches.append(weakref(node))
	for child: Node in node.get_children(): install_item(child)

func install_lights() -> void:
	if world is UnderworldHomeWorld:
		var home:=world as UnderworldHomeWorld
		var sockets: Dictionary={"character":[Vector2(168,381),Vector2(462,354)],"upgrade":[Vector2(829,425),Vector2(975,341)],"achievements":[Vector2(1197,370),Vector2(1098,377)]}
		for slot: Dictionary in home.specification.slots:
			var id:=str(slot.id)
			if not sockets.has(id): continue
			var sprite:=home.get_node_or_null(id+"_building") as Sprite2D
			if sprite==null: continue
			var atlas:=sprite.texture as AtlasTexture
			for pixel: Vector2 in sockets[id]:
				add_lamp(sprite.to_global(pixel-atlas.region.position),150.0,id+"_window")
	collect_lamps(world)

func collect_lamps(node: Node) -> void:
	if node is UnderworldScenery:
		var props: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/decor/chime_props.json")).regions
		for row: Dictionary in (node as UnderworldScenery).placements:
			var kind:=str(row.kind)
			var region: Dictionary=props.get(kind,{})
			if not region.has("light_anchor"): continue
			var sprite:=node.get_node_or_null(str(row.node)) as Sprite2D
			if sprite==null: continue
			add_lamp(sprite.to_global(Vector2(region.light_anchor[0],region.light_anchor[1])),135.0,kind+"_lantern")
			if kind=="tower":
				var script:=load("res://scripts/underworld_plains/underworld_windmill.gd") as Script
				if script!=null: script.attach(sprite,row.position)
	if node is ShotLatch:
		var latch:=node as ShotLatch
		add_lamp(latch.to_global(latch.bell_position),120.0,"functional_bell")
		if not latch.sequence_offset.is_zero_approx(): add_lamp(latch.to_global(latch.bell_position+latch.sequence_offset),100.0,"sequence_bell")
	for child: Node in node.get_children():
		if child!=self: collect_lamps(child)

func lamp_texture() -> GradientTexture2D:
	if _light_texture!=null: return _light_texture
	_light_texture=GradientTexture2D.new();_light_texture.width=256;_light_texture.height=256
	_light_texture.fill=GradientTexture2D.FILL_RADIAL
	_light_texture.fill_from=Vector2(.5,.5);_light_texture.fill_to=Vector2(1,.5)
	var ramp:=Gradient.new();ramp.offsets=PackedFloat32Array([0,.12,.35,.7,1])
	ramp.colors=PackedColorArray([Color.WHITE,Color(.92,.92,.92,1),Color(.55,.55,.55,1),Color(.12,.12,.12,1),Color(0,0,0,1)])
	_light_texture.gradient=ramp
	return _light_texture

func add_lamp(point: Vector2,radius: float,kind: String) -> void:
	var lamp:=PointLight2D.new();lamp.position=to_local(point);lamp.texture=lamp_texture()
	lamp.texture_scale=radius/128.0;lamp.color=Color("ffbc69");lamp.energy=.85
	lamp.shadow_enabled=true;lamp.shadow_filter=Light2D.SHADOW_FILTER_PCF5;lamp.shadow_filter_smooth=1.0
	lamp.range_z_min=-100;lamp.range_z_max=100
	add_child(lamp)
	var bloom:=Sprite2D.new();bloom.texture=lamp_texture();bloom.position=lamp.position
	bloom.scale=Vector2.ONE*12.0/128.0;bloom.modulate=Color(1,.62,.28,.10)
	bloom.z_index=12
	var material:=CanvasItemMaterial.new();material.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	bloom.material=material;add_child(bloom)
	emitters.append({"light":lamp,"bloom":bloom,"world_position":point,"radius":radius,"kind":kind,"color":"ffbc69","energy":.85})

func install_occluders(node: Node) -> void:
	if node is UnderworldTerrain:
		for rect: Rect2 in (node as UnderworldTerrain).union_pieces:
			var polygon:=OccluderPolygon2D.new()
			polygon.polygon=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
			var shade:=LightOccluder2D.new();shade.occluder=polygon
			shade.position=to_local((node as Node2D).global_position)
			add_child(shade)
	for child: Node in node.get_children():
		if child!=self: install_occluders(child)

func _process(delta: float) -> void:
	_clock+=delta
	refresh(false)

func refresh(update_foreground: bool=true) -> void:
	var camera:=get_viewport().get_camera_2d()
	var center:=camera.get_screen_center_position() if camera!=null else Vector2.ZERO
	var size:=get_viewport_rect().size/(camera.zoom if camera!=null else Vector2.ONE)
	var view:=Rect2(center-size*.5,size).grow(180)
	var sorted: Array[Dictionary]=emitters.duplicate()
	sorted.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return (a.world_position as Vector2).distance_squared_to(center)<(b.world_position as Vector2).distance_squared_to(center))
	var live:=0
	for row: Dictionary in sorted:
		var shown:=live<MAX_VISIBLE_LIGHTS and view.has_point(row.world_position)
		(row.light as PointLight2D).visible=shown;(row.bloom as Sprite2D).visible=shown
		if shown:live+=1
	for material: ShaderMaterial in _terrain_materials: material.set_shader_parameter("wind_clock",_clock)
	for ref: WeakRef in _latches:
		var latch:=ref.get_ref() as CanvasItem
		if latch!=null and view.has_point((latch as Node2D).to_global((latch as ShotLatch).bell_position)): latch.queue_redraw()
	if update_foreground and is_instance_valid(foreground): foreground.call("refresh")

func receipt() -> Dictionary:
	var lights: Array[Dictionary]=[]
	for row: Dictionary in emitters:
		lights.append({"kind":row.kind,"position":[row.world_position.x,row.world_position.y],"radius":row.radius,"color":row.color,"energy":row.energy,"visible":(row.light as PointLight2D).visible})
	return {"style":"fine1wu_warm","world_art_step":1,"terrain_tile_px":32,"world_tile_wu":32,"scene":"formal_home" if world is UnderworldHomeWorld else "formal_region","light_budget":MAX_VISIBLE_LIGHTS,"lights":lights,"foreground":foreground.call("receipt") if is_instance_valid(foreground) else {},"time":_clock}
