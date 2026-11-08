extends "res://tests/world/plains_first_loop.gd"
## Shared real-input freight routes. No placement, phase, health or state writes.
func ride_up(node_name: String,mechanism: String,bell_point: Vector2,release_y: float) -> bool:
 var room_id:=app.room.room_id
 var carrier:=app.room.get_node(node_name) as WorldMovingPlatform
 var latch:=app.room.mechanisms[mechanism] as WorldShotLatch
 if carrier.motion_running:
  printerr("Carrier route expects parked preparation: ",node_name);return false
 app.controller.router.request_action(&"shoot_release",(bell_point-app.player.position).normalized());await ticks(12)
 if not carrier.motion_running:return false
 if not await board_carrier(carrier):return false
 var arrived:=false
 for i: int in 1100:
  await ticks(1)
  var dx:=carrier.position.x-app.player.position.x
  app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>3 else 0)
  if i%180==0:print("RIDE ",node_name," player=",app.player.position," carrier=",carrier.position," running=",carrier.motion_running)
  if app.busy or app.room.room_id!=room_id:break
  if app.player.position.y<=release_y and app.player.is_on_floor():arrived=true;break
  if app.busy:break
 app.controller.router.clear("freight_arrived")
 print("RIDE END ",node_name," ",arrived," at ",app.player.position)
 return arrived and latch.motion_target==carrier
func market_cross() -> bool:
 var ferry:=app.room.get_node("MarketFerry") as WorldMovingPlatform
 app.controller.router.request_action(&"shoot_release",(Vector2(1696,360)-app.player.position).normalized());await ticks(12)
 if not ferry.motion_running or not await walk(Vector2(1744,398),"P-R34") or not await board_carrier(ferry):return false
 for i: int in 300:
  await ticks(1)
  var dx:=ferry.position.x-app.player.position.x
  app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>3 else 0)
  if ferry.position.x>2040 and app.player.is_on_floor():break
 app.controller.router.clear("ferry_endpoint")
 await full_jump(Vector2(2200,398))
 return app.player.is_on_floor() and absf(app.player.position.y-398)<8

func board_carrier(carrier: WorldMovingPlatform) -> bool:
 var room_id:=app.room.room_id
 app.controller.router.set_jump_held(&"keyboard_mouse",false)
 app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for i: int in 150:
  await ticks(1)
  if app.busy or app.room.room_id!=room_id:return false
  var dx:=carrier.position.x-app.player.position.x
  app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>3 else 0)
  if i==30:app.controller.router.set_jump_held(&"keyboard_mouse",false)
  if i>8 and app.player.is_on_floor():
   app.controller.router.clear("carrier_boarded")
   print("BOARD FREIGHT ",app.player.position," on ",carrier.position)
   return absf(dx)<carrier.platform_size.x*.5+12 and absf(app.player.position.y-carrier.position.y+28)<8
 app.controller.router.clear("boarding_failed");return false
