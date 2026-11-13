extends Node2D
## A real native-resolution 2D assembly. No 3D scene or perspective is involved.
const NATIVE := "res://assets/plains_v07/native/"
var ready_to_capture := false
var config: Dictionary
var terrain: TerrainComposer
var hero: Sprite2D
func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://config/art/orchard_static.json"))
	RenderingServer.set_default_clear_color(Color("263e45"))
	# Distant terrain has its own ground. It never overlaps the foreground bank top.
	background("longbridge_vista",Vector2(0,-130),Color(.46,.57,.59),-20)
	background("orchard",Vector2(0,20),Color(.5,.61,.58),-18)
	background("orchard",Vector2(820,20),Color(.5,.61,.58),-18)
	background("orchard_ridge",Vector2(-80,314),Color(.50,.62,.54),-14)
	background("opening_road_ridge",Vector2(450,355),Color(.65,.72,.66),-10)
	var polygons: Array[Dictionary] = [{"points":config.terrain}]
	var groups: Array[Dictionary] = [{"material_id":"windchime_plains","bare":false,"solids":[] as Array[Rect2],"polygons":polygons}]
	terrain = TerrainComposer.compose({"geometry":TerrainGeometry.plan([] as Array[Rect2],polygons),"groups":groups},{"version":1,"regions":[{"id":"mill-foundation","bounds":config.foundation,"material_id":"mill_masonry"}]})
	terrain.z_index = -2; add_child(terrain)
	# A new root/soil transition joins the existing tree into its bank, not a new tile skin.
	var connector := Sprite2D.new(); connector.texture = load("res://assets/depth_lab_2d/native/root_bank.png"); connector.centered = false; connector.position = Vector2(config.root_connector.position[0],config.root_connector.position[1]); connector.z_index = -1; connector.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; add_child(connector)
	for p: Dictionary in config.props:
		var sprite := Sprite2D.new(); sprite.texture = load(NATIVE+p.asset+".png"); sprite.centered = false; sprite.position = Vector2(p.foot[0]-p.anchor[0],p.foot[1]-p.anchor[1]); sprite.z_index = int(p.z); sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; add_child(sprite)
	# Sparse foot-level foregrounds have explicit hosts; they never form a global border.
	for item: Array in [[80,480],[995,480],[1230,480]]:
		var grass := Sprite2D.new(); grass.texture = load(NATIVE+"bank_moss.png"); grass.position = Vector2(item[0],item[1]+12); grass.z_index=5;grass.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(grass)
	var canvas := CanvasModulate.new(); canvas.color = Color(.86,.90,.94); add_child(canvas)
	# A local warm source belongs to the doorway, rather than tinting individual objects.
	var gradient := Gradient.new(); gradient.set_color(0,Color(1,1,1,.75));gradient.set_color(1,Color(1,1,1,0))
	var light_texture := GradientTexture2D.new();light_texture.gradient=gradient;light_texture.width=256;light_texture.height=256;light_texture.fill=GradientTexture2D.FILL_RADIAL;light_texture.fill_from=Vector2(.5,.5);light_texture.fill_to=Vector2(1,.5)
	var light := PointLight2D.new(); light.texture=light_texture;light.color=Color("edc78b");light.energy=.7;light.position=Vector2(config.lamp_point[0],config.lamp_point[1]);light.texture_scale=1.3;add_child(light)
	var kit: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/world-art-v2/assets/pixel/manifest.json"))
	var lamp_spec: Dictionary=kit.sprites.gear_lamp
	var lamp:=Sprite2D.new();lamp.texture=load("res://art/world-art-v2/"+lamp_spec.file);lamp.position=Vector2(config.lamp_foot[0]-lamp_spec.pivotX,config.lamp_foot[1]-lamp_spec.pivotY);lamp.centered=false;lamp.z_index=4;lamp.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(lamp)
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(UnderworldPlayer.BUILD_PATH))
	var tex:=AtlasTexture.new();tex.atlas=load("res://assets/underworld_plains/player_animation/states_sheet.png");tex.region=Rect2(0,0,80,64)
	hero=Sprite2D.new();hero.texture=tex;hero.position=Vector2(config.hero_foot[0],config.hero_foot[1]);hero.offset=Vector2(0,-26);hero.scale=Vector2.ONE*(44.0/float(spec.standing_body_source_height));hero.z_index=3;hero.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var material:=CanvasItemMaterial.new();material.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;hero.material=material;add_child(hero)
	await get_tree().process_frame
	await get_tree().process_frame
	ready_to_capture=true
	print("STATIC ORCHARD READY: native 1280x720 2D / production terrain / independent assets")
func background(asset: String,at: Vector2,tint: Color,layer: int) -> void:
	var sprite:=Sprite2D.new();sprite.texture=load(NATIVE+asset+".png");sprite.centered=false;sprite.position=at;sprite.modulate=tint;sprite.z_index=layer;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(sprite)
