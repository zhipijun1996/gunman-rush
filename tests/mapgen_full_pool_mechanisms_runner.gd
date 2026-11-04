extends "res://tests/mapgen_full_pool_runner.gd"
## Isolated native interaction fixtures. Only the initial placement is selected;
## accepted Router shots and actual native callbacks advance every transaction.
var shot_cases:=0
func include_binding(content:Dictionary)->bool:
 return not _target(content).is_empty() or content.has("review029_wave") or content.has("review040_release") or not content.get("approved_hq_cells",[]).is_empty()
func _target(content:Dictionary)->Dictionary:
 for spec:Dictionary in content.get("approved_hq_cells",[]):
  if spec.kind=="hit_turret":return {"point":RuntimeMapShotLatchAdapter.rectangle(spec.rect).get_center(),"turret":true}
 for spec:Dictionary in RuntimeMapContentAdapter.mechanisms(content):
  if spec.has("carrier_dock") or spec.has("sequence_offset") or spec.get("kind")=="reward_pair":continue
  if spec.has("paired_gate") or spec.has("ferry_id") or spec.get("kind") in ["group_motion","retractable_gears","retract_thorns"]:return {"point":Vector2(spec.bell[0],spec.bell[1]),"id":str(spec.id)}
 return {}
func initial_spawn(definition:PlatformingModuleDefinition,content:Dictionary,_instance:Dictionary)->Vector2:
 var target:=_target(content)
 if str(_instance.module_id)=="idea-plains-hq09-001":return Vector2(568 if _instance.transform.mirror_x else 72,334)
 if content.has("review029_wave"):return RuntimeMapShotLatchAdapter.rectangle(content.review029_wave.rect).get_center()
 if target.is_empty():
  for spec:Dictionary in content.get("approved_hq_cells",[]):
   if spec.kind=="support_start_motion":
    for platform:ModuleMovingPlatformDefinition in definition.ferries:
     if str(platform.platform_id)==str(spec.id):return platform.at_time(0)-Vector2(0,platform.size.y*.5+18)
  return definition.entry_port.position
 var bell:Vector2=target.point
 var candidates:Array[Vector2]=[]
 for angle:int in 16:candidates.append(bell+Vector2.RIGHT.rotated(TAU*angle/16)*56)
 for platform:Rect2 in definition.platforms:
  for offset:float in [-180,-120,-80,80,120,180]:
   var candidate:=Vector2(clampf(bell.x+offset,platform.position.x+13,platform.end.x-13),platform.position.y-18)
   if candidate.distance_to(bell)<300 and candidate.distance_to(bell)>45:candidates.append(candidate)
 for angle:int in 16:candidates.append(bell+Vector2.RIGHT.rotated(TAU*angle/16)*80)
 for candidate:Vector2 in candidates:
  var clear:=true
  var player_rect:=Rect2(candidate-Vector2(12,18),Vector2(24,36)).grow(-.1)
  for index:int in definition.platforms.size():
   var rect:Rect2=definition.platforms[index]
   if rect.intersects(player_rect) or index not in definition.one_way_platform_indices and GEO.segment_hits_rect([candidate.x,candidate.y],[bell.x,bell.y],[rect.position.x-3,rect.position.y-3,rect.size.x+6,rect.size.y+6]):clear=false;break
  for spec:Dictionary in RuntimeMapContentAdapter.mechanisms(content):
   var rect:=RuntimeMapShotLatchAdapter.rectangle(spec.get("paired_gate") if spec.get("initial_open")=="A" else spec.gate)
   if rect.intersects(player_rect) or GEO.segment_hits_rect([candidate.x,candidate.y],[bell.x,bell.y],[rect.position.x-3,rect.position.y-3,rect.size.x+6,rect.size.y+6]):clear=false;break
  if clear:return candidate
 return definition.entry_port.position
func exercise(stage:PlainsRegionStage,encounter:RuntimeMapShotLatchEncounter,controller:PlayerController,_lifetime:DemoLifetime,_policy:FrameDamagePolicy,content:Dictionary,instance:Dictionary):
 var label:=str(instance.module_id)+" mirror="+str(instance.transform.mirror_x)
 var target:=_target(content)
 if not target.is_empty():
  var latch:ShotLatch
  if target.get("turret",false):latch=encounter.extras._turrets[0].node.latch
  else:
   for node:ShotLatch in encounter.latches:
    if node.link_id==target.id:latch=node;break
  if str(instance.module_id)=="idea-plains-hq09-001":
   var motion:=encounter.latches[0]
   controller.router.request_action(&"shoot_release",(motion.bell_body.global_position-controller.motor.global_position).normalized())
   await frames(22)
   check(motion.is_open,label+" actual first shot clears moving projectile barrier")
  var before:=latch.open_count
  var initial:=latch.is_open
  var aimed:Vector2=encounter.extras._turrets[0].node.body.global_position if target.get("turret",false) else latch.bell_body.global_position
  controller.router.request_action(&"shoot_release",(aimed-controller.motor.global_position).normalized())
  await frames(45)
  check(latch.open_count>before,label+" actual parent projectile/relay impact accepted; player="+str(controller.motor.global_position)+" target="+str(aimed))
  if latch.open_count>before:
   shot_cases+=1
   if latch is RuntimeMapPairedLatch:
    check(latch.is_open!=initial and latch.gate_shape.disabled==latch.open_a and latch.paired_gate_shape.disabled!=latch.open_a,label+" paired gate complementary real collisions")
   if latch is RuntimeMapHazardLatch:
    for emitter:DemoContactEmitter in latch.emitters:check(not emitter.enabled,label+" accepted hit retracts actual native damage emitter")
   if latch.motion_mode:check(latch.motion_target.motion_running and latch.motion_target.motion_clock>0,label+" actual native motion advances")
 if content.has("review029_wave"):
  check(encounter.extras._waves[0].triggered,label+" real player Area overlap activates wave once")
  for enemy:EnemyMotor in stage.enemies:check(enemy.visible and enemy.collision_layer!=0,label+" triggered original native enemy remains collision-active")
 for spec:Dictionary in content.get("approved_hq_cells",[]):
  if spec.kind=="native_one_way_carriers":
   for id:Variant in spec.ids:
    var carrier:ModuleMovingPlatform=encounter._runtime_modules[0].carriers[str(id)]
    check(carrier.is_in_group("one_way_platform"),label+" carrier uses existing one-way traversal group")
    for node:Node in carrier.get_children():
     if node is CollisionShape2D:check(node.one_way_collision,label+" actual carrier shape is one-way")
  if spec.kind=="support_start_motion":
   await frames(12)
   check(encounter.extras._starts[0].started and encounter.extras._starts[0].platform.motion_running,label+" actual sole contact starts carrier")
 for row:Dictionary in encounter._runtime_modules:
  for spec:Dictionary in content.get("approved_hq_cells",[]):
   if spec.kind=="group_motion":
    var running:bool=row.carriers[str(spec.targets[0])].motion_running
    for id:Variant in spec.targets:check(row.carriers[str(id)].motion_running==running,label+" group shares the accepted start/park transaction")
   if spec.kind=="rigid_mounted_bell":
    var mounted:ShotLatch=row.latches[str(spec.id)]
    check(mounted.bell_body.global_position.is_equal_approx(row.carriers[str(spec.mount)].to_global(Vector2(spec.offset[0],spec.offset[1]))),label+" native carrier retains rigid mounted bell offset")
 for latch:ShotLatch in encounter.latches:
  if latch is RuntimeMapDockLatch:
   var limit:=ceili(latch.platform.definition.period()*60)+6
   for tick:int in limit:
    if latch.is_open:break
    await frames(1)
   check(latch.is_open and latch.gate_body.collision_layer==0,label+" actual bound carrier overlaps dock sensor and opens real gate")
 # Commit through the Stage's existing reward transaction boundary; the resource
 # grant precedes map mutation exactly as in DemoApp. This is not a UI-distance case.
 var claims:Array=[]
 for row:Dictionary in encounter.extras._rewards:claims.append(row.claim)
 for row:Dictionary in encounter.extras._releases:claims.append(row.claim)
 for claim:String in claims:
  var wallet:=RunWallet.new()
  check(wallet.grant(1,StringName(claim)),label+" native resource grant accepted before map claim")
  stage.commit_cache_claim({"id":claim,"claimed":false})
 await frames(2)
 for row:Dictionary in encounter.extras._rewards:check(not row.latch.open_a,label+" actual reward claim switches complementary gates")
 for row:Dictionary in encounter.extras._releases:check(row.module.inactive_platform_indices.has(row.index),label+" accepted reward releases actual collision plate")
 encounter.cancel_pending()
 if is_instance_valid(encounter.extras):
  for row:Dictionary in encounter.extras._turrets:check(row.node.pending.is_empty() and row.node.children.is_empty(),label+" cancellation drains pending relay projectiles")
