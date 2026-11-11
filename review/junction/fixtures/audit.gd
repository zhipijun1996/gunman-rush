extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R06")
 app.set_physics_process(false);app.story.set_process(false);app.controller.active=false
 var art:=app.room.get_node("RegionalArt") as PlainsRoomArt
 check(app.room.get_node_or_null("UnderworldForeground")==null,"authored foreground replaces procedural canvas, without stacking")
 var normal_low:=0.0
 for viewport_size:Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1280,960),Vector2i(720,1280)]:
  root.size=viewport_size
  for at:Vector2 in [Vector2(1216,1934),Vector2(416,1678),Vector2(1216,1294),Vector2(752,1134),Vector2(976,654),Vector2(704,142)]:
   app.player.reset_at(at);app.camera.reset_view();await ticks(12)
   var span:=app.get_viewport_rect().size/app.camera.zoom
   var view:=Rect2(app.camera.get_screen_center_position()-span*.5,span)
   var sky_size:=(art.sky_layers.get_node("SkyWash") as Sprite2D).texture.get_size()*art.sky.scale
   var fill:=Rect2(art.sky_layers.global_position-sky_size*.5,sky_size).grow(2)
   check(fill.encloses(view),"sky covers final viewport "+str(viewport_size)+" at "+str(at))
   if viewport_size==Vector2i(1280,720):
    var relative:float=(art.sky.global_position.y-app.camera.get_screen_center_position().y)/span.y
    if at.y==1934:normal_low=relative
    if at.y==142:check(relative>normal_low+.20,"same horizon recedes below screen while climbing")
 var gate_id:="room-link-144:P-R06"
 check(not app.room.door_open[gate_id] and app.room.door_blocks[gate_id].collision_layer==1,"unopened shortcut keeps its actual blocker")
 var state:=app.state.value.duplicate(true);state.flags.append("shortcut_p02")
 app.state.commit(state,app.state.revision);app.room.refresh_doors(app.state,app.content);await ticks(3)
 check(app.room.door_open[gate_id] and app.room.door_blocks[gate_id].collision_layer==0,"same shortcut state removes gate art and blocker")
 var clock_before:=art.clock
 paused=true
 for i:int in 8:await process_frame
 check(is_equal_approx(art.clock,clock_before),"paused world freezes cloud animation clock")
 paused=false
 await WorldAudioLifecycle.drain_world(app);quit(failures)
