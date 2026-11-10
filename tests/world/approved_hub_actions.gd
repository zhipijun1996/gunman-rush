extends "res://tests/world/approved_draft_actions.gd"
## r74 local approaches, real Router/Motor; not an uninterrupted campaign.
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 if selected("P-R01"):
  await load_room("P-R01")
  var state:=app.state.value.duplicate(true);state.flags.append("station_rest_taught");app.state.commit(state,app.state.revision)
  await ride("P01","UpperStationLift")
 if selected("P-R02"):
  await load_room("P-R02")
  await ride("P02","RoofWinch",Vector2(848,816),Vector2(768,878))
  await hop(Vector2(816,1166),Vector2(512,1038),Vector2.RIGHT,"P02 cache returns to shelter step")
 if selected("P-R06"):
  await load_room("P-R06")
  await hop(Vector2(1152,1678),Vector2(880,1454),Vector2(.65,.76),"P06 rising choice from low bank")
  await hop(Vector2(752,1134),Vector2(448,942),Vector2(.75,.66),"P06 west branch recoil")
 if selected("P-R08"):
  await load_room("P-R08")
  await ride("P08","WellLift",Vector2(736,2896),Vector2(656,2926))
  await ride("P08","ServiceLift",Vector2(624,2256),Vector2(560,2286))
  await ride("P08","UpperLift",Vector2(944,1408),Vector2(880,1438))
  (app.room.get_node("WellLift") as WorldMovingPlatform).restore_motion(6,false)
  (app.room.get_node("ServiceLift") as WorldMovingPlatform).restore_motion(0,false)
  await hop(Vector2(864,2228),Vector2(576,2020),Vector2(.65,.76),"P08 first recoil transfer")
  (app.room.get_node("ServiceLift") as WorldMovingPlatform).restore_motion(6.5,false)
  (app.room.get_node("UpperLift") as WorldMovingPlatform).restore_motion(0,false)
  await hop(Vector2(576,1380),Vector2(896,1156),Vector2(-.65,.76),"P08 second recoil transfer")
 if selected("P-R26"):
  await load_room("P-R26")
  await ride("P26","Carrier0",Vector2(672,1320),Vector2(736,1390))
  await ride("P26","Carrier1",Vector2(1760,624),Vector2(1712,686))
  await hop(Vector2(960,836),Vector2(1328,686),Vector2(-.8,.6),"P26 west hoist to inspection bank")
  await hop(Vector2(2192,356),Vector2(2112,142),Vector2(.3,.95),"P26 east hoist to shelter entrance")
 if selected("P-R27"):
  await load_room("P-R27")
  await hop(Vector2(704,718),Vector2(864,558),Vector2.DOWN,"P27 from receiving bank to rest")
 if selected("P-R32"):
  await load_room("P-R32")
  await hop(Vector2(736,1006),Vector2(1056,942),Vector2.LEFT,"P32 first broken bridge")
  await ride("P32","BridgeInspectionLift",Vector2(1952,744),Vector2(2096,814))
  await hop(Vector2(2336,612),Vector2(2496,622),Vector2.ZERO,"P32 moving deck to safe vista")
  await hop(Vector2(2144,1038),Vector2(2240,1006),Vector2.ZERO,"P32 cache returns to lower junction")
 if selected("P-R33"):
  await load_room("P-R33")
  await hop(Vector2(1152,910),Vector2(1024,814),Vector2.ZERO,"P33 lower return step")
  await hop(Vector2(1024,814),Vector2(1024,558),Vector2.DOWN,"P33 recoil returns to forecourt")
 if selected("P-R35"):
  await load_room("P-R35")
  await ride("P35","JunctionLift")
  await hop(Vector2(1568,622),Vector2(1264,750),Vector2.RIGHT,"P35 upper return across wide banks")
  await hop(Vector2(984,750),Vector2(672,750),Vector2.RIGHT,"P35 return west across gap")
  await hop(Vector2(512,750),Vector2(512,558),Vector2.DOWN,"P35 shoulder restores west ascent")
  await hop(Vector2(512,558),Vector2(256,398),Vector2(.7,.7),"P35 back to long-bridge receiving bank")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("APPROVED HUB ACTIONS: ",failures," failures");quit(failures)
