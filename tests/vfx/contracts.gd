extends SceneTree
## Import/provenance and bounded deterministic atmosphere regressions.
var checks:=0
var failures:=0
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var bytes:=0
 for key:StringName in PixelVfx.CLIPS:
  var clip:SpriteFrames=PixelVfx.CLIPS[key]
  var count:=clip.get_frame_count(&"default")
  check(count>2,"animated imported resource "+str(key))
  var texture:=clip.get_frame_texture(&"default",0) as AtlasTexture
  var pivot:Vector2=clip.get_meta(&"pivot")
  check(texture!=null and pivot.x>=0 and pivot.y>=0 and pivot.x<=texture.region.size.x and pivot.y<=texture.region.size.y,"preserved anchor "+str(key))
  check(clip.get_animation_speed(&"default") in [30.0,60.0],"preserved frame rate "+str(key))
  bytes+=int(texture.atlas.get_width()*texture.atlas.get_height()*4)
 # Color silhouettes, not merely white light: catches unconverted painter palettes.
 for key:StringName in [&"muzzle",&"impact",&"focus-gather",&"focus-restore",&"boss-land",&"chest-rays",&"loot-spill",&"coin-turn"]:
  var frames:SpriteFrames=PixelVfx.CLIPS[key]
  var atlas:=frames.get_frame_texture(&"default",0 if key==&"coin-turn" else frames.get_frame_count(&"default")/4) as AtlasTexture
  var pixels:=atlas.atlas.get_image()
  var colors:Dictionary={}
  for y:int in range(int(atlas.region.position.y),int(atlas.region.end.y)):
   for x:int in range(int(atlas.region.position.x),int(atlas.region.end.x)):
    var color:=pixels.get_pixel(x,y)
    if color.a>.3 and (absf(color.r-color.g)>.07 or absf(color.g-color.b)>.07):colors[color.to_rgba32()]=true
  check(colors.size()>=6,"colored primary silhouette survives export: "+str(key))
 check(bytes<16*1024*1024,"all project VFX atlases fit a sixteen MiB decoded budget: "+str(bytes))
 var owner:=Node2D.new();root.add_child(owner)
 var leaf:=Node2D.new();owner.add_child(leaf)
 owner.set_meta(&"reduced_vfx",true)
 check(PixelVfx.reduced(leaf),"effect inherits live presentation preference")
 owner.set_meta(&"reduced_vfx",false)
 check(not PixelVfx.reduced(leaf),"preference changes do not retain an old cached setting")
 owner.free()
 var art:=PlainsRoomArt.new()
 var room:=FixedWorldRoom.new();room.room_id="P-R03"
 art.room=room;art.atmosphere={"density":4,"speed":[10,20]}
 var expected:Array=art._air_particles(0,0).duplicate(true)
 seed(413)
 var first:=randi()
 seed(413)
 for i:int in 100:art._air_particles(i,0)
 check(art._wind_cells.size()<=64,"camera movement has a bounded cell cache")
 check(expected==art._air_particles(0,0),"evicted world cell recreates identical positions, alpha and tails")
 check(randi()==first,"atmosphere never advances the gameplay random stream")
 art.free();room.free()
 print("VFX CONTRACTS: ",checks," checks, ",failures," failures; decoded_bytes=",bytes)
 quit(failures)
