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
  check(is_equal_approx(clip.get_animation_speed(&"default"),60),"preserved frame rate "+str(key))
  bytes+=int(texture.atlas.get_width()*texture.atlas.get_height()*4)
 check(bytes<8*1024*1024,"all project VFX atlases fit an eight MiB decoded budget: "+str(bytes))
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
