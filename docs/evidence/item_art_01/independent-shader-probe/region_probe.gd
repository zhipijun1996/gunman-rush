extends SceneTree
class Fixture extends Node2D:
 var textures: Array[Texture2D]=[]
 func _draw() -> void:
  for i: int in textures.size(): draw_texture_rect(textures[i],Rect2(10+i*80,10,64,64),false)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(800,400);root.content_scale_size=root.size;DisplayServer.window_set_size(root.size)
 var code:=FileAccess.get_file_as_string("res://shaders/underworld_fine_sprite.gdshader")
 var image:=Image.create(256,128,false,Image.FORMAT_RGBA8);image.fill(Color.RED)
 var texture:=ImageTexture.create_from_image(image)
 var textures:Array[Texture2D]=[texture]
 for rect: Rect2 in [Rect2(0,0,128,128),Rect2(64,16,128,64),Rect2(128,0,128,128)]:
  var a:=AtlasTexture.new();a.atlas=texture;a.region=rect;a.filter_clip=true;textures.append(a)
 var nodes:Array[Node2D]=[]
 var samples:Array[Dictionary]=[]
 var expressions:Array[String]=["vec4(REGION_RECT.xyz,1.)","vec4(REGION_RECT.w,0.,0.,1.)","vec4(REGION_RECT.xyz/256.,1.)","vec4(REGION_RECT.w/256.,0.,0.,1.)"]
 for row: int in 4:
  var shader:=Shader.new();shader.code=code.replace("COLOR=texture(TEXTURE,at)*source_vertex_color;","COLOR="+expressions[row]+";")
  var mat:=ShaderMaterial.new();mat.shader=shader
  var fixture:=Fixture.new();fixture.textures=textures;fixture.material=mat;fixture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;fixture.position.y=row*90
  root.add_child(fixture);nodes.append(fixture)
 for unused: int in 8:await process_frame
 await RenderingServer.frame_post_draw
 var actual:=root.get_texture().get_image();actual.save_png(ProjectSettings.globalize_path("res://build/item_art_01/independent-shader-probe/region-actual.png"))
 for row: int in 4:
  var values:Array=[]
  for col: int in 4:
   var c:=actual.get_pixel(42+col*80,42+row*90);values.append([c.r,c.g,c.b,c.a])
  samples.append({"expression":expressions[row],"RGBA_samples_full_then3AtlasDraws":values})
 var f:=FileAccess.open("res://build/item_art_01/independent-shader-probe/region-receipt.json",FileAccess.WRITE);f.store_string(JSON.stringify({"scope":"ActualCanvasItem4drawcommands, builtinperdrawregion diagnostic only, source synthetic256x128; real artistPNG unchanged","region_inputs_pixels":[[0,0,256,128],[0,0,128,128],[64,16,128,64],[128,0,128,128]],"samples":samples},"  "));f.close()
 for n: Node2D in nodes:n.free()
 await process_frame
 print("INDEPENDENT REGION_RECT DIAGNOSTIC COMPLETE")
 quit()
