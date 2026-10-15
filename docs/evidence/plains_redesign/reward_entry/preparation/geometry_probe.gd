extends SceneTree
var app: DemoApp
func _initialize() -> void: run.call_deferred()
func pair(p:Vector2)->Array:return [p.x,p.y]
func run()->void:
 app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
 if not app.start_plains("level-design-v2-baseline"):quit(2);return
 for i:int in 120:
  await physics_frame
  await process_frame
  if app.stage is PlainsRegionStage and not app._stage_pending:break
 if not app.stage is PlainsRegionStage:quit(3);return
 var trace=load("res://tests/level_formal_trace.gd").new()
 if not trace.attach(app,"return",0,"blind_legacy"):quit(4);return
 var guard:EnemyMotor
 for i:int in (app.stage as PlainsRegionStage).enemies.size():
  if (app.stage as PlainsRegionStage).enemy_manifest[i].id=="plains/enemy/area_0_0":guard=(app.stage as PlainsRegionStage).enemies[i]
 if guard==null:quit(5);return
 var actor:=guard.get_node("Actor") as EnemyActor
 var data:Dictionary={"scope":"actual live DemoApp static geometry queries at hypothetical bank/recorded enemy centres; no input traversal or player/enemy repositioning","manifest_hash":app.stage.generated.manifest.manifest_hash,"guard_spawn":pair(guard.global_position),"protected_radius":actor.definition.protected_radius,"recoil_distance":app.player.weapon_motion.base_distance(app.player.tuning,true),"samples":[]}
 var space:=app.player.get_world_2d().direct_space_state
 for point:Vector2 in [Vector2(0,-700),Vector2(-60,-700),Vector2(-90,-700),Vector2(-120,-700),Vector2(90,-800)]:
  for enemy_point:Vector2 in [Vector2(30.23,-809.14),Vector2(70,-810),Vector2(110,-810)]:
   var delta:=enemy_point-point
   var query:=PhysicsShapeQueryParameters2D.new();var shape:=CircleShape2D.new();shape.radius=app.player.tuning.projectile_radius
   query.shape=shape;query.transform=Transform2D(0,point);query.motion=delta;query.collision_mask=9;query.exclude=[app.player.get_rid(),guard.get_rid()]
   var cast:=space.cast_motion(query)
   var ray:=PhysicsRayQueryParameters2D.create(enemy_point,point,1,[guard.get_rid(),app.player.get_rid()]);var hit:=space.intersect_ray(ray)
   var nearest:=INF
   for safe:Vector2 in actor.attack_behavior.protected_points:nearest=minf(nearest,point.distance_to(safe))
   var recoil:float=data.recoil_distance
   var retreat:=Vector2(-delta.normalized().x*recoil,0)
   data.samples.append({"bank":pair(point),"enemy_centre":pair(enemy_point),"bank_supported":trace.bank_supported(point),"whole_recoil_supported":trace.bank_supported(point,retreat),"retreat":pair(retreat),"cast_motion":Array(cast),"projectile_path_clear":cast.size()==2 and cast[0]>=1,"enemy_ray_clear":hit.is_empty(),"ray_hit_path":"" if hit.is_empty() else str(hit.collider.get_path()),"ray_hit_position":[] if hit.is_empty() else pair(hit.position),"distance_to_protected_anchor":nearest})
 var f:=FileAccess.open("res://build/plains_redesign/high_entry_diagnosis/geometry_probe.json",FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
 print("HIGH ENTRY GEOMETRY: ",data.samples.size()," queries; actual normal-spawn live world, no traversal claim")
 app.queue_free();await process_frame;quit(0)
