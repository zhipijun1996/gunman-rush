extends SceneTree
var map_index:=1
var point:="spawn"
var app:DemoApp
var samples:Array[Dictionary]=[]
var accepted_jumps:=0
var accepted_shots:=0
func _initialize()->void:run.call_deferred()
func p(v:Vector2)->Array:return [v.x,v.y]
func run()->void:
 root.size=Vector2i(1280,720)
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--map="):map_index=int(arg.trim_prefix("--map="))
  if arg.begins_with("--point="):point=arg.trim_prefix("--point=")
 app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
 app.start_plains("underworld-independent-motion/0")
 for i:int in 8:await physics_frame
 if map_index==2:
  app.director.stage_index=2;app._load_stage()
  for i:int in 8:await physics_frame
 var stage:=app.stage as PlainsRegionStage
 var manifest_hash:=str(stage.generated.manifest.manifest_hash)
 if point=="boss":app.controller.return_to_segment(Vector2(stage.boss_arena.position.x+180,stage.boss_arena.end.y-18))
 app._run_camera.snap_to_target();app._run_camera.force_update_scroll()
 for a:String in ["KeyboardMouseAdapter","GamepadAdapter"]:
  var node:=app.player.get_node_or_null(a)
  if node!=null:node.process_mode=Node.PROCESS_MODE_DISABLED
 app.controller.jump_ability.jumped.connect(func()->void:accepted_jumps+=1)
 app.controller.shoot_ability.shot_fired.connect(func(_d:Vector2,_id:int)->void:accepted_shots+=1)
 var initial_epoch:=app.lifetime.actor_epoch
 var frames:=0
 var jump_held:=false
 for frame:int in 600:
  await RenderingServer.frame_post_draw
  frames+=1
  if not is_instance_valid(app.controller) or not is_instance_valid(app.player):break
  var direction:=0.0
  if frame>=120:
   if point=="spawn":direction=1.0 if frame<330 else -1.0
   else:direction=1.0 if frame%200<100 else -1.0
  app.controller.router.set_move_axis(direction)
  if frame%90==25 and frame>=120:jump_held=true
  elif frame%90==40:jump_held=false
  app.controller.router.set_jump_held(&"independent_movie",jump_held)
  if frame%70==50 and frame>=120:app.controller.router.request_action(&"shoot",Vector2(-direction,.2).normalized())
  if frame%15==0:
   var boss:=stage.boss.get_node("Encounter") as WindkeeperEncounter
   samples.append({"video_driver_frame":frame,"player":p(app.player.global_position),"camera":p(app._run_camera.get_screen_center_position()),"health":app.controller.actor_resources.health.current,"actor_epoch":app.lifetime.actor_epoch,"normal_velocity":p(app.player.normal_velocity),"on_floor":app.player.is_on_floor(),"boss_motor":p(boss.motor.global_position),"boss_mode":str(boss.mode),"boss_active":boss.active,"boss_phase":boss.stage_phase,"parallax":(app.get_node("PixelPlainsParallax") as UnderworldParallax).measured_nodes()})
 var result:={"map":map_index,"point":point,"seed":"underworld-independent-motion/0","manifest_hash":manifest_hash,"frames_driven":frames,"accepted_jumps":accepted_jumps,"accepted_shots":accepted_shots,"same_actor_epoch":app.lifetime.actor_epoch==initial_epoch,"samples":samples,"scope":"Actual accepted Router -> Motor after optional ONE positioned boss entry. No transform writes during driver. Ten-second native 60fps recording; not route completion, device fps or user approval."}
 var out:="res://build/underworld_plains/independent_review/motion_map%d_%s.json"%[map_index,point]
 FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("UNDERWORLD_INDEPENDENT_MOTION ",map_index," ",point," frames=",frames," jumps=",accepted_jumps," shots=",accepted_shots)
 await load("res://tests/audio_teardown.gd").drain_world(app)
 app.free()
 for i:int in 4:await process_frame
 quit(0)
