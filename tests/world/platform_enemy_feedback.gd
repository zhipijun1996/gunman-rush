extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
 print("PLATFORM FEEDBACK ",ok," ",label)
 if not ok: failures+=1
func ticks(count:int) -> void:
 for i:int in count: await physics_frame
func run() -> void:
 var room:=Node2D.new()
 var platforms:Array[Rect2]=[Rect2(0,200,96,32)]
 root.add_child(room)
 var floor_body:=StaticBody2D.new();floor_body.position=Vector2(48,216)
 var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(96,32);shape.shape=box;floor_body.add_child(shape);room.add_child(floor_body)
 await ticks(2)
 var body:=EnemyFactory.create_for_behavior(&"patrol")
 body.position=Vector2(48,184);room.add_child(body)
 var actor:=body.get_node("Actor") as EnemyActor
 var min_x:=48.0;var max_x:=48.0;var supported:=true
 for i:int in 360:
  await ticks(1)
  min_x=minf(min_x,body.position.x);max_x=maxf(max_x,body.position.x)
  supported=supported and body.supported_at(body.position)
 check(supported and min_x>=13 and max_x<=83 and max_x-min_x>40,"patrol turns at both actual lips for six seconds")
 var goal:=body.supported_ground_goal(Vector2(48,184),Vector2(200,184))
 check(goal.x<=83 and goal.x>60,"hopper rejects an unsupported landing beyond ledge")
 var flyer:=EnemyFactory.create_for_behavior(&"patrol",{&"aerial":true})
 flyer.position=Vector2(48,184);room.add_child(flyer);await ticks(60)
 check(flyer.position.x>96,"aerial motion is not restricted by ground lips")
 var art:=WorldSpikeArt.new();room.add_child(art)
 art.setup([{"bounds":[0,176,48,24],"facing":"up"},{"bounds":[48,176,48,24],"facing":"up"}],platforms)
 check(art.bands.size()==1 and (art.bands[0].rect as Rect2).size.x==96,"touching thorn strips form one continuous run")
 var plan:=UnderworldHazardTiles.surface_plan(art.bands[0].rect,PlatformThornDefinition.Face.TOP,platforms[0])
 check(plan.size()==3 and plan[0].variant=="start" and plan[1].variant=="middle" and plan[2].variant=="end","thorns retain tips, middle and end caps")
 room.queue_free();await ticks(2)
 print("PLATFORM FEEDBACK failures=",failures);quit(0 if failures==0 else 1)
