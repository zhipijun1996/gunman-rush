extends "res://tests/world/plains_intro.gd"
## Current tutorial decision views and actual thorn-pit recovery.
## Safe lift returns are covered by approved_hub_actions/station_arrival.
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_readability.json";root.add_child(app)
 for rid: String in ["P-R03","P-R21","P-R22","P-R23","P-R24","P-R01"]:
  await app.review.begin(rid,"","base")
  for door: Dictionary in app.room.doors.duplicate():
   if app.content.room(door.target_room).is_empty():continue
   await app.review.begin(rid,door.id,"base");await ticks(10)
   var half:=Vector2(root.size)/2.0/app.camera.zoom
   var center:=app.camera.get_screen_center_position()
   var portal:=FixedWorldProvider.point(door.position_candidate.local_world_units)
   var error:=0.0
   match str(door.direction):
    "up":error=absf(center.y-half.y-portal.y)
    "down":error=absf(center.y+half.y-portal.y)
    "left":error=absf(center.x-half.x-portal.x)
    "right":error=absf(center.x+half.x-portal.x)
   check(error<2,rid+" exit axis at screen edge "+str(door.direction)+" error="+str(error))
 for fixture: Array in [
  ["P-R21",Vector2(240,238),[Vector2(352,544)]],
  ["P-R21",Vector2(736,526),[Vector2(848,704)]],
  ["P-R21",Vector2(848,686),[Vector2(1008,864)]],
  ["P-R22",Vector2(832,142),[Vector2(912,352)]],
  ["P-R22",Vector2(880,334),[Vector2(736,544)]],
  ["P-R22",Vector2(608,526),[Vector2(416,800)]],
  ["P-R22",Vector2(448,782),[Vector2(544,1056)]],
  ["P-R22",Vector2(416,1038),[Vector2(256,1280)]],
  ["P-R22",Vector2(288,1262),[Vector2(544,1504)]],
  ["P-R22",Vector2(800,1486),[Vector2(1120,1408),Vector2(944,1664)]],
  ["P-R22",Vector2(1824,1390),[Vector2(2200,1344),Vector2(1990,1664)]],
  ["P-R22",Vector2(2528,1294),[Vector2(2768,1152),Vector2(2608,1440)]],
  ["P-R23",Vector2(1040,534),[Vector2(1344,624)]],
  ["P-R23",Vector2(1584,526),[Vector2(1380,336)]],
  ["P-R23",Vector2(1320,318),[Vector2(1232,256)]],
  ["P-R23",Vector2(1232,238),[Vector2(1088,160)]],
  ["P-R24",Vector2(1984,1486),[Vector2(1856,1456)]],
  ["P-R01",Vector2(448,1678),[Vector2(544,1744)]]]:
  await app.review.begin(fixture[0],"","base");app.player.reset_at(fixture[1]);(app.camera as WorldCamera).reset_view();await ticks(70)
  var half:=Vector2(root.size)/2.0/app.camera.zoom
  var view:=Rect2(app.camera.get_screen_center_position()-half,half*2).grow(-12)
  check(app.player.is_on_floor(),fixture[0]+" real preparation support "+str(fixture[1]))
  check(view.has_point(app.player.position-Vector2(0,28)) and view.has_point(app.player.position+Vector2(0,18)),"actor fits decision view")
  check(app.camera.zoom==Vector2(1.6,1.6),"ordinary zoom unchanged")
  for point: Vector2 in fixture[2]:check(view.has_point(point),fixture[0]+" next landing / recovery visible BEFORE commitment "+str(point)+" view="+str(view))
 # These tutorial floors are now deliberate spike beds, not climbable safe pits.
 for pit:Array in [["P-R22",Vector2(944,1646)],["P-R22",Vector2(1990,1646)],["P-R23",Vector2(1100,720)]]:
  await app.review.begin(pit[0],"","base")
  var hp:=app.controller.actor_resources.health.current
  var entry:=app.entry_anchor
  app.player.reset_at(pit[1]);(app.camera as WorldCamera).reset_view()
  await ticks(90)
  check(app.controller.actor_resources.health.current==hp-1,"actual thorn fall costs one hit "+str(pit[0]))
  check(app.player.is_on_floor() and app.player.position.distance_to(entry)<8 and app.controller.active,"thorn fall returns to safe controllable entry "+str(pit[0]))
 await finish()
