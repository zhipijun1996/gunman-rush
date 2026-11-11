extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R27")
 var art:=app.room.get_node("RegionalArt") as PlainsRoomArt
 check(not art.has_node("Threshold_WEST-P26-P27_P-R27") and not art.has_node("Threshold_WEST-P27-P05_P-R27"),"authored cutaways replace both generic threshold facades")
 var courtyard:Sprite2D
 var shaft:Sprite2D
 for node:Node in art.get_children():
  if node is Sprite2D and node.texture.resource_path.ends_with("shelter_courtyard.png") and not node.region_enabled:courtyard=node
  if node is Sprite2D and node.texture.resource_path.ends_with("shelter_shaft.png"):shaft=node
 check(courtyard!=null and shaft!=null,"both room-specific architectural plates installed")
 check(shaft.region_enabled and shaft.position==Vector2(448,736) and shaft.region_rect.size==Vector2(128,106),"shaft rear lies only inside actual downward aperture")
 var at:=courtyard.global_position
 var cloud:=art.sky_layers.clouds[0].material as ShaderMaterial
 var clock:float=cloud.get_shader_parameter("cloud_time")
 await ticks(20)
 check(float(cloud.get_shader_parameter("cloud_time"))>clock,"cloud layer drifts independently")
 clock=cloud.get_shader_parameter("cloud_time")
 app.toggle_pause();await ticks(20)
 check(is_equal_approx(float(cloud.get_shader_parameter("cloud_time")),clock),"cloud layer freezes with pause")
 app.toggle_pause()
 await fixture(Vector2(1488,558));await ticks(10)
 check(courtyard.global_position==at,"courtyard feet do not drift during camera travel")
 check(app.room.enemies.is_empty(),"safe rest room keeps no combat encounter")
 var source:=load("res://game/world/regions/P/rooms/P-R27.tscn").instantiate() as FixedWorldRoom
 check(WorldRoomDraft.validate(source,WorldRoomDraft.extract(source)).is_empty(),"final art rows pass scene codec")
 source.free()
 await WorldAudioLifecycle.drain_world(app);quit(failures)
