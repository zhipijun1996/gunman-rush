extends "res://tests/mapgen_full_pool_mechanisms_runner.gd"
## Real projectiles and a real collision body exercise pair anti-pinch guards.
## The blocker receives its initial fixture placement before the first input.
func include_binding(content:Dictionary)->bool:
 return not _target(content).is_empty() and not _target(content).get("turret",false) and RuntimeMapContentAdapter.mechanisms(content).any(func(row:Dictionary)->bool:return row.has("paired_gate"))
func exercise(stage:PlainsRegionStage,encounter:RuntimeMapShotLatchEncounter,controller:PlayerController,_lifetime:DemoLifetime,_policy:FrameDamagePolicy,_content:Dictionary,instance:Dictionary):
 var pair:RuntimeMapPairedLatch
 for node:ShotLatch in encounter.latches:
  if node is RuntimeMapPairedLatch:pair=node;break
 if pair==null:return
 var original:=pair.open_a
 var closing:Rect2=pair.gate_rect if original else pair.paired_gate_rect
 var blocker:=CharacterBody2D.new();blocker.collision_layer=2;blocker.collision_mask=0;blocker.position=closing.get_center()
 var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(22,32);shape.shape=box;blocker.add_child(shape);stage.add_child(blocker)
 await frames(1)
 controller.router.request_action(&"shoot_release",(pair.bell_body.global_position-controller.motor.global_position).normalized())
 await frames(10)
 check(pair.blocked_count==1 and pair.open_count==0 and pair.open_a==original,str(instance.module_id)+" actual shot cannot close paired gate on CharacterBody2D")
 check(pair.gate_shape.disabled==original and pair.paired_gate_shape.disabled!=original,"blocked pair preserves both real gate collisions atomically")
 blocker.queue_free()
