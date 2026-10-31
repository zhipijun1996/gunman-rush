extends SceneTree
const OUT := "res://build/item_art_01/independent-shader-probe/stable-02/"
class Fixture extends Node2D:
 var texture: Texture2D
 var label := ""
 var draw_size := 32.0
 var angle := 0.0
 func _draw() -> void:
  draw_set_transform(Vector2(20,20),angle)
  draw_texture_rect(texture,Rect2(-draw_size/2,-draw_size/2,draw_size,draw_size),false)
func metrics(image: Image, start: Vector2i) -> Dictionary:
 var best := {"uniform_fraction":-1.0}
 var bg := image.get_pixel(0,0)
 for py: int in 4:
  for px: int in 4:
   var active := 0
   var uniform := 0
   for y: int in range(start.y+8+py,start.y+120,4):
    for x: int in range(start.x+8+px,start.x+120,4):
     var ref := image.get_pixel(x,y)
     var same := true
     var visible := false
     for dy: int in 4:
      for dx: int in 4:
       var c := image.get_pixel(x+dx,y+dy)
       if c!=ref:same=false
       if c!=bg:visible=true
     if visible:
      active+=1
      if same:uniform+=1
   var ratio := float(uniform)/active if active>0 else 0.0
   if ratio>float(best.uniform_fraction):best={"active":active,"uniform":uniform,"uniform_fraction":ratio,"phase":[px,py]}
 return best
func atlas(source: Texture2D, region: Rect2, clip: bool = true) -> AtlasTexture:
 var t := AtlasTexture.new();t.atlas=source;t.region=region;t.filter_clip=clip;return t
func material(code: String) -> ShaderMaterial:
 var s := Shader.new();s.code=code;var m := ShaderMaterial.new();m.shader=s;return m
func synthetic(w: int,h: int) -> Texture2D:
 var i := Image.create(w,h,false,Image.FORMAT_RGBA8)
 for y: int in h:
  for x: int in w:i.set_pixel(x,y,Color(1,0,0) if (x+y)%2==0 else Color(0,0,1))
 return ImageTexture.create_from_image(i)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
 root.canvas_transform=Transform2D(0,Vector2.ZERO).scaled(Vector2.ONE*4)
 var shared := load("res://shaders/underworld_fine_sprite.gdshader") as Shader
 var code := shared.code
 var stable_code := code.replace("COLOR=texture(TEXTURE,at)*source_vertex_color;", "at=clamp(at+TEXTURE_PIXEL_SIZE*.001,REGION_RECT.xy+TEXTURE_PIXEL_SIZE*.5,REGION_RECT.xy+REGION_RECT.zw-TEXTURE_PIXEL_SIZE*.5);\nCOLOR=texture(TEXTURE,at)*source_vertex_color;")
 var sf:=FileAccess.open(OUT+"item-stable-candidate.gdshader",FileAccess.WRITE);sf.store_string(stable_code);sf.close()
 var old := material(stable_code)
 var bias := material(code.replace("COLOR=texture(TEXTURE,at)*source_vertex_color;","COLOR=texture(TEXTURE,at+TEXTURE_PIXEL_SIZE*.001)*source_vertex_color;"))
 var center := material(code.replace("COLOR=texture(TEXTURE,at)*source_vertex_color;","at=(floor(at/TEXTURE_PIXEL_SIZE+vec2(.001))+.5)*TEXTURE_PIXEL_SIZE;\nCOLOR=texture(TEXTURE,at)*source_vertex_color;"))
 var debug_uv := material(code.replace("COLOR=texture(TEXTURE,at)*source_vertex_color;","COLOR=vec4(fract(at/TEXTURE_PIXEL_SIZE),0.,1.);"))
 var actual := ItemArtLibrary.frame_texture(&"p24.rotor",0)
 var raw_image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/items/v5/vfx/p24-01.source.png"))
 var raw := ImageTexture.create_from_image(raw_image)
 var s768 := synthetic(2048,768)
 var s256 := synthetic(256,256)
 var cases: Array[Dictionary] = [
 {"name":"P24_actual_shared","texture":actual,"mat":old},
 {"name":"P24_actual_nearest","texture":actual,"mat":null},
 {"name":"P24_actual_bias_diagnostic","texture":actual,"mat":bias},
 {"name":"P24_actual_center_diagnostic","texture":actual,"mat":center},
 {"name":"P24_actual_UV_debug","texture":actual,"mat":debug_uv},
 {"name":"P24_raw_shared","texture":atlas(raw,Rect2(0,0,256,256)),"mat":old},
 {"name":"P24_raw_half_pixel_ROI_diagnostic","texture":atlas(raw,Rect2(.5,.5,256,256)),"mat":old},
 {"name":"synthetic2048x768_ratio8_shared","texture":atlas(s768,Rect2(0,0,256,256)),"mat":old},
 {"name":"synthetic256square_ratio8_shared","texture":atlas(s256,Rect2(0,0,256,256)),"mat":old},
 {"name":"synthetic2048x768_ratio8_bias","texture":atlas(s768,Rect2(0,0,256,256)),"mat":bias},
 {"name":"synthetic2048x768_ratio8_center","texture":atlas(s768,Rect2(0,0,256,256)),"mat":center}]
 var adjacent := Image.create(256,128,false,Image.FORMAT_RGBA8);adjacent.fill(Color.GREEN)
 for y: int in 128:
  for x: int in 128:adjacent.set_pixel(x,y,Color.RED)
 var adj := ImageTexture.create_from_image(adjacent)
 for mode: int in 3:
  for ai: int in 3:
   cases.append({"name":"neighbor_ratio15.42_mode%d_angle%d"%[mode,ai],"texture":atlas(adj,Rect2(0,0,136 if mode==2 else 128,128),mode!=1),"mat":old,"size":8.3,"angle":[0.,.37,.79][ai],"neighbor_case":true,"mode":mode})
 var nodes: Array[Node2D] = []
 for index: int in cases.size():
  var c: Dictionary=cases[index]
  var n:=Fixture.new();n.texture=c.texture;n.material=c.mat;n.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  n.position=Vector2((index%8)*40+.25,(index/8)*50+.25);n.draw_size=c.get("size",32.0);n.angle=c.get("angle",0.0)
  root.add_child(n);nodes.append(n)
 for unused: int in 8:await process_frame
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image();image.save_png(ProjectSettings.globalize_path(OUT+"actual.png"))
 var rows: Array[Dictionary] = []
 for index: int in cases.size():
  var c: Dictionary=cases[index]
  var r: Dictionary={"name":c.name,"screen_tile":[index%8,index/8]}
  if c.get("neighbor_case",false):
   var green:=0
   var ctr:=Vector2i((index%8)*160+80,(index/8)*200+80)
   for y: int in range(ctr.y-32,ctr.y+32):
    for x: int in range(ctr.x-32,ctr.x+32):
     var p:=image.get_pixel(x,y)
     if p.g>.8 and p.r<.2 and p.b<.2:green+=1
   r["opaque_green_pixels"]=green
  else:r["metrics"]=metrics(image,Vector2i((index%8)*160+16,(index/8)*200+16))
  rows.append(r)
 var report:={"scope":"Independent item-specific candidate diagnostic only; production/sharedshader unchanged; .95 gate retained", "actual_sampling_variant":"unchanged sharedvertex/light, fragmentsourcebias .001texel plus clamp to actual per-drawREGION_RECT halfsourcepixel inset","shared_shader_sha256":FileAccess.get_sha256("res://shaders/underworld_fine_sprite.gdshader"),"source_sha256":FileAccess.get_sha256("res://assets/items/v5/vfx/p24-01.source.png"),"screen_zoom":4,"rows":rows,"diagnostic_variants":"Shader code copies for UVdebug/bias/centers and halfsourcepixel ROI are ignored experiments, no production shader or source PNG edited."}
 var f:=FileAccess.open(OUT+"receipt.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 for n: Node2D in nodes:n.free()
 ItemArtLibrary.clear_cache()
 await process_frame
 print("INDEPENDENT SHADER DIAGNOSTIC COMPLETE "+str(rows.size()))
 quit()
