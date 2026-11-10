extends "res://tests/world/plains35_fixture.gd"
## GPU check: same world-surface samples across real camera pans, then indoor emitters.
func image_at(name:String) -> Image:
 await process_frame
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 image.save_png("res://build/world-feedback/"+name+".png")
 return image
func samples(image:Image) -> Array[Color]:
 var result:Array[Color]=[]
 for point:Vector2 in [Vector2(1080,1290),Vector2(1140,1290),Vector2(1180,1300)]:
  var screen:Vector2=app.room.get_global_transform_with_canvas()*point
  result.append(image.get_pixelv(Vector2i(screen.round())))
 return result
func run() -> void:
 root.size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute("res://build/world-feedback")
 app=preload("res://game/application/world/fixed_world.tscn").instantiate()
 app.save_path="user://lighting_composition.json";root.add_child(app);app.workbench.enabled=true
 await load_room("P-R01");await fixture(Vector2(1120,1262));await ticks(45)
 var art:=app.room.get_node("RegionalArt") as PlainsRoomArt
 var color:=art.ambient.color
 var view:=Rect2(0,512,2176,1024)
 app.camera.begin_takeover(app,Vector2(1100,1136),view,.1);await ticks(90)
 var baseline:=samples(await image_at("daylight-center"))
 for center:Vector2 in [Vector2(950,1136),Vector2(1250,1080)]:
  app.camera.begin_takeover(app,center,view,.1);await ticks(90)
  var current:=samples(await image_at("daylight-"+str(int(center.x))))
  for i:int in current.size():
   var difference:=maxf(absf(current[i].r-baseline[i].r),maxf(absf(current[i].g-baseline[i].g),absf(current[i].b-baseline[i].b)))
   check(difference<=2.0/255.0,"fixed world surface lighting survives camera pan: "+str(difference))
  check(art.ambient.color==color,"camera pan never animates global ambient")
 await load_room("P-R26");await fixture(Vector2(600,1518));await ticks(90)
 art=app.room.get_node("RegionalArt") as PlainsRoomArt
 check(art.indoor and art.daylight==null,"mill has interior ambient and visible lamps, no outdoor sun")
 var emitters:=0
 for child:Node in art.get_children():
  if not child is Sprite2D:continue
  for lamp:Node in child.get_children():
   if lamp is PointLight2D:
    emitters+=1;check(lamp.position==Vector2(8,-69),"lamp light registered on actual amber bulb")
 check(emitters==2,"mill has both visible authored lamp sources")
 await image_at("mill-lamps")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
 print("LIGHTING COMPOSITION: ",failures," failures");quit(failures)
