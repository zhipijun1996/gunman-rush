extends SceneTree
var checks:=0
var failures:Array[String]=[]
var sample:PixelPlainsPreview
var room:PixelPlainsRoom
var trace:Array[Dictionary]=[]
func _init() -> void:_run.call_deferred()
func expect(value:bool,message:String) -> void:
 checks+=1
 if not value:failures.append(message);printerr("FAIL: "+message)
func _run() -> void:
 sample=preload("res://experiments/terrain/entries/pixel_plains_preview.tscn").instantiate()
 root.add_child(sample)
 room=sample.room
 for adapter:String in ["KeyboardMouseAdapter","GamepadAdapter"]:room.player.get_node(adapter).process_mode=Node.PROCESS_MODE_DISABLED
 for i:int in 20:await physics_frame
 expect(sample.viewport.size==Vector2i(640,360),"actual fixed logical viewport")
 expect(room.camera.zoom==Vector2(.5,.5),"logical viewport preserves world and physics scale")
 expect(room.player.is_on_floor(),"actual spawn supported")
 expect(room._enemy_motors.size()==1 and room.policy._targets.size()==2,"actual existing enemy registered")
 var source:=room.terrain.tile_set.get_source(0) as TileSetAtlasSource
 expect(source.get_tiles_count()==141 and source.texture==PixelPlainsRoom.STONE,"real new47x3atlas consumed")
 var before:=room.layout.duplicate(true)
 var initial_epoch:=room.lifetime.epoch
 var f:Dictionary=await _drive(1.0,1200)
 expect(f.reached,"actual main route forward: "+str(f))
 var r:Dictionary=await _drive(-1.0,80)
 expect(r.reached,"same real actor returns: "+str(r))
 expect(room.lifetime.epoch==initial_epoch,"route never reset/teleported actor")
 expect(not room.controller.traversal.hook_enabled and not room.controller.traversal.wall_enabled and not room.controller.traversal.double_enabled,"no ungranted movement abilities")
 room.set_light(false);room.set_effects(false)
 room._toggle_catalog()
 expect(paused and room._catalog.visible,"catalog pauses actual world")
 var token:=room.lifetime.token()
 room.restart()
 expect(not paused and not room._catalog.visible,"restart clears catalog")
 expect(not room.lifetime.accepts(token),"old token rejected")
 expect(not (room.scenery as PixelPlainsScenery).light_enabled and not (room.decoration as PixelPlainsDecoration).effects_enabled,"restart preserves chosen visual switches")
 expect(room.layout==before,"cosmetics do not mutate topology")
 for i:int in 180:await physics_frame
 expect(room.controller.shoot_ability.try_fire(Vector2.RIGHT,true),"real accepted shot")
 var bullets:=room.controller.shoot_ability.get_projectiles()
 expect(not bullets.is_empty() and bullets[0].presentation is PixelPlainsProjectile,"actual new projectile skin")
 room._toggle_pause()
 expect(paused,"pause actual subviewport world")
 room.restart()
 expect(not paused,"restart resumes manual pause")
 sample.queue_free()
 for i:int in 12:await process_frame
 expect(not paused,"exit clears global pause")
 var file:=FileAccess.open("res://build/pixel-plains/route-trace.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"consumer":"PixelPlainsRoom","spawn_only_initial":true,"granted_abilities":[],"frames":trace}))
 print("PIXEL_PLAINS checks=%d failures=%d" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
func _drive(direction:float,finish:float) -> Dictionary:
 var held:=0
 for tick:int in 1100:
  room.controller.router.set_move_axis(direction)
  var probe:=room.player.position+Vector2(direction*32,30)
  var edge:=true
  for drop:int in [0,32,64]:
   if room.layout.cells.has(Vector2i(floori(probe.x/Blob47Rules.CELL),floori((probe.y+drop)/Blob47Rules.CELL))):edge=false
  var enemy_close:=false
  for enemy:EnemyMotor in room._enemy_motors:
   if absf(enemy.position.x-room.player.position.x)<85:enemy_close=true
  if room.player.is_on_floor() and (edge or room.player.is_on_wall() or enemy_close) and held==0:
   room.controller.router.set_jump_held(&"pixel_route",true);held=11
  elif held>0:
   held-=1
   if held==0:room.controller.router.set_jump_held(&"pixel_route",false)
  await physics_frame
  trace.append({"tick":trace.size(),"x":room.player.position.x,"y":room.player.position.y,"axis":direction,"jump_held":held>0,"motion_steps":room.player.motion_steps,"health":room.controller.actor_resources.health.current,"epoch":room.lifetime.epoch})
  if room.player.position.y>720:return {"reached":false,"reason":"fell","tick":tick}
  if (direction>0 and room.player.position.x>=finish) or (direction<0 and room.player.position.x<=finish):
   room.controller.router.clear("pixel_route_end")
   for i:int in 12:await physics_frame
   return {"reached":true,"tick":tick,"position":room.player.position}
 return {"reached":false,"reason":"timeout","position":room.player.position}
