extends "res://tests/world/plains_intro.gd"
## Real Camera2D at the decision point, plus legal local fall/recovery fixtures.
## Fixtures establish approach positions once; recovery uses normal input only.
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
  ["P-R23",Vector2(1056,526),[Vector2(1190,448)]],
  ["P-R23",Vector2(1190,430),[Vector2(1380,352)]],
  ["P-R23",Vector2(1380,334),[Vector2(1232,256)]],
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
 for fixture: Array in [
  ["P-R03",Vector2(1088,1806),[Vector2(992,1710)]],
  ["P-R03",Vector2(1728,1774),[Vector2(1632,1646)]],
  ["P-R22",Vector2(944,1646),[Vector2(864,1582),Vector2(784,1486)]],
  ["P-R22",Vector2(1990,1646),[Vector2(1888,1518),Vector2(1808,1390)]],
  ["P-R22",Vector2(2448,1518),[Vector2(2608,1422),Vector2(2528,1294)]],
  ["P-R23",Vector2(1600,334),[Vector2(1380,334),Vector2(1232,238)]],
  ["P-R24",Vector2(1280,1166),[Vector2(1152,1102)]],
  ["P-R24",Vector2(1728,1550),[Vector2(1984,1486)]]]:
  await app.review.begin(fixture[0],"","base");app.player.reset_at(fixture[1]);(app.camera as WorldCamera).reset_view();await ticks(3)
  var hp:=app.controller.actor_resources.health.current
  check(app.player.is_on_floor(),"legal low floor "+str(fixture[1]))
  check(await path(fixture[2],fixture[0]),fixture[0]+" recover with current base abilities "+str(fixture[1]))
  check(app.controller.actor_resources.health.current==hp,"safe recovery does not charge hidden height damage")
 await app.review.begin("P-R01","","base");app.player.reset_at(Vector2(1008,1454));(app.camera as WorldCamera).reset_view();await ticks(3)
 check(await walk(Vector2(1536,1486),"P-R01"),"station missed lift follows maintenance floor to shaft")
 check(await ride("StationLift",Vector2(1536,1440),1344,Vector2(1328,1262)),"station lower corridor can reboard and return to service hall")
 await finish()
