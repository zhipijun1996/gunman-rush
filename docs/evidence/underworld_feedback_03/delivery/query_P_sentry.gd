extends SceneTree
var app: DemoApp
func pair(p: Vector2) -> Array: return [p.x,p.y]
func _initialize() -> void: run.call_deferred()
func run() -> void:
 app=preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
 app.meta_persistence_enabled=false
 root.add_child(app)
 for n: int in 8: await physics_frame
 app.start_plains("level-design-v2-baseline/08")
 var stage: PlainsRegionStage
 for n: int in 180:
  await physics_frame
  stage=app.stage as PlainsRegionStage
  if stage!=null and stage.is_node_ready() and stage.assembly_ok and not app._stage_pending: break
 if stage==null or app._stage_pending: printerr("readiness timeout");quit(1);return
 var output: Dictionary={"source_commit":"9402bf92fa9be16b10d401db5e02b5c63124ff3c","seed":"level-design-v2-baseline/08","query_only":true,"player_moved":false,"AI_or_resources_injected":false,"player_shape":"actual24x36 rectangle, center offset zero","shooters":[]}
 var supports:=PlainsRegionScenery.solid_supports(stage)
 for i: int in stage.enemies.size():
  var body:=stage.enemies[i]
  var actor:=body.get_node("Actor") as EnemyActor
  if actor.definition.behavior_id not in [&"sentry",&"fan_sentry"]: continue
  var near: Array=[]
  var candidates: Array=[]
  for slab: Rect2 in supports:
   if slab.get_center().distance_to(body.global_position)>650 and not slab.grow(250).has_point(body.global_position): continue
   near.append([slab.position.x,slab.position.y,slab.size.x,slab.size.y])
   for offset: int in [-140,-120,-100,-80,80,100,120,140]:
    var x:=body.global_position.x+float(offset)
    if x<slab.position.x+16 or x>slab.end.x-16:continue
    var at:=Vector2(x,slab.position.y-18.1)
    var distance:=at.distance_to(actor.attack_behavior.home)
    if distance<65 or distance>actor.definition.activation_range-20:continue
    var protected:=false
    var clearance:=INF
    for safe: Vector2 in actor.attack_behavior.protected_points:
     clearance=minf(clearance,at.distance_to(safe))
     if at.distance_to(safe)<actor.definition.protected_radius+5:protected=true
    var shape:=RectangleShape2D.new();shape.size=Vector2(24,36)
    var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape;query.transform=Transform2D(0,at);query.collision_mask=1;query.exclude=[app.player.get_rid()]
    var overlaps:=body.get_world_2d().direct_space_state.intersect_shape(query)
    var feet:=PhysicsRayQueryParameters2D.create(at+Vector2(0,17),at+Vector2(0,23),1,[app.player.get_rid()])
    var ground:=body.get_world_2d().direct_space_state.intersect_ray(feet)
    var ray:=PhysicsRayQueryParameters2D.create(body.global_position,at,1,[body.get_rid(),app.player.get_rid()])
    var hit:=body.get_world_2d().direct_space_state.intersect_ray(ray)
    candidates.append({"point":pair(at),"distance_home":distance,"protected_clearance":clearance,"protected":protected,"solid_support":[slab.position.x,slab.position.y,slab.size.x,slab.size.y],"body_overlap_count":overlaps.size(),"feet_support":not ground.is_empty(),"feet_hit":pair(ground.position) if not ground.is_empty() else [],"LOS_clear":hit.is_empty(),"LOS_blocker":str(hit.collider.get_path()) if not hit.is_empty() else "","valid":not protected and overlaps.is_empty() and not ground.is_empty() and hit.is_empty()})
  output.shooters.append({"source_id":str(stage.enemy_manifest[i].id),"behavior":str(actor.definition.behavior_id),"position":pair(body.global_position),"home":pair(actor.attack_behavior.home),"activation_range":actor.definition.activation_range,"protected_radius":actor.definition.protected_radius,"nearby_solid_supports":near,"candidates":candidates})
 var f:=FileAccess.open("/workspace/clock-style-lab/build/underworld_r3/delivery/query_P_sentry.json",FileAccess.WRITE);f.store_string(JSON.stringify(output,"  "));f.close()
 app.queue_free()
 for n: int in 5:await physics_frame
 print("QUERY_P_SENTRY_COMPLETE")
 quit(0)
