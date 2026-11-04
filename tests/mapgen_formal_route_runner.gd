extends SceneTree
## Fixed-seed, input-only start-to-Boss route. No position, HP or tuning writes.
## Uses actual admitted banks and original source route waypoints as guidance.
const READY := preload("res://tests/formal_region_test_support.gd")
var app: DemoApp
var trace: Array=[]
var ticks := 0
var jump_ticks := 0
var failures := 0
var initial_player := 0
var accepted_boss_damage := 0.0
var route_seed := "formal-integration-1"
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
 for i: int in n:
  await physics_frame
  ticks+=1
  if ticks%5==0 and is_instance_valid(app.player) and app.lifetime.active:trace.append({"tick":ticks,"position":[app.player.position.x,app.player.position.y],"velocity":[app.player.velocity.x,app.player.velocity.y],"health":app.controller.actor_resources.health.current,"grounded":app.player.is_on_floor(),"axis":app.controller.router.axis})
func routes(source: Dictionary) -> Array:
 var start: String=str(source.result.map.anchors.start_departure.instance_id)+"/"+str(source.result.map.anchors.start_departure.port_id)
 var finish: String=str(source.result.map.anchors.boss_arrival.instance_id)+"/"+str(source.result.map.anchors.boss_arrival.port_id)
 var graph := {}
 for instance: Dictionary in source.result.map.instances:
  for route: Dictionary in instance.routes:
   var a: String=str(instance.id)+"/"+str(route.from_port)
   var b: String=str(instance.id)+"/"+str(route.to_port)
   if not graph.has(a): graph[a]=[]
   graph[a].append({"target":b,"instance":instance,"route":route})
 for edge: Dictionary in source.result.map.connections:
  var a: String=str(edge.a.instance_id)+"/"+str(edge.a.port_id)
  var b: String=str(edge.b.instance_id)+"/"+str(edge.b.port_id)
  if not graph.has(a):graph[a]=[]
  if not graph.has(b):graph[b]=[]
  graph[a].append({"target":b,"edge":edge});graph[b].append({"target":a,"edge":edge})
 var queue: Array=[start];var prev: Dictionary={start:{}};var cursor:=0
 while cursor<queue.size():
  var at: String=queue[cursor];cursor+=1
  if at==finish:break
  for step: Dictionary in graph.get(at,[]):
   if prev.has(step.target):continue
   var record:=step.duplicate();record["from"]=at;prev[step.target]=record;queue.append(step.target)
 if not prev.has(finish):return []
 var output: Array=[];var at:=finish
 while at!=start:var step: Dictionary=prev[at];output.push_front(step);at=step.from
 return output
func bank(instance_id: String, port_id: String) -> Vector2:
 for placement: LevelModulePlacement in app.stage.level_plan.modules:
  if placement.instance_id!=instance_id:continue
  for row: Dictionary in placement.definition.get_meta("runtime_map_v2_port_admission").used_ports:
   if row.port_id==port_id:return placement.position+Vector2(row.body_center_pixels[0],row.body_center_pixels[1])
 return Vector2.INF
func down_gap(goal: Vector2) -> float:
 var player: PlayerMotor=app.player
 var floor_hit: Dictionary={}
 for offset: float in [-10.0,0.0,10.0]:
  var ray:=PhysicsRayQueryParameters2D.create(player.global_position+Vector2(offset,0),player.global_position+Vector2(offset,22),1,[player.get_rid()])
  var hit:=player.get_world_2d().direct_space_state.intersect_ray(ray)
  if not hit.is_empty() and (floor_hit.is_empty() or hit.position.y<floor_hit.position.y):floor_hit=hit
 if floor_hit.is_empty():return INF
 var module:=floor_hit.collider.get_parent() as PlatformingModule
 if module==null:return INF
 var top: float=floor_hit.position.y
 var spans: Array[Vector2]=[]
 for rect: Rect2 in module.definition.platforms:
  if absf(module.global_position.y+rect.position.y-top)<1:spans.append(Vector2(module.global_position.x+rect.position.x,module.global_position.x+rect.end.x))
 spans.sort_custom(func(a:Vector2,b:Vector2):return a.x<b.x)
 var joined: Array[Vector2]=[]
 for span: Vector2 in spans:
  if not joined.is_empty() and joined[-1].y>=span.x:joined[-1].y=maxf(joined[-1].y,span.y)
  else:joined.append(span)
 var candidates: Array[float]=[]
 for span: Vector2 in joined:
  if player.position.x<span.x-12 or player.position.x>span.y+12:continue
  for x: float in [span.x-20,span.y+20]:
   if x<module.position.x+24 or x>module.position.x+module.definition.world_bounds.size.x-24:continue
   if player.test_move(player.global_transform,Vector2(x-player.position.x,0),null,0):continue
   var drop:=PhysicsRayQueryParameters2D.create(Vector2(x,top+2),Vector2(x,top+700),1,[player.get_rid()])
   var landing:=player.get_world_2d().direct_space_state.intersect_ray(drop)
   if not landing.is_empty() and landing.position.y>top+28:candidates.append(x)
 if candidates.is_empty():return INF
 candidates.sort_custom(func(a:float,b:float):return absf(a-player.position.x)<absf(b-player.position.x))
 return candidates[0]
func player_x() -> float: return app.player.position.x
func go(point: Vector2, limit: int = 200, allow_above: bool = true) -> bool:
 var stale := 0;var before := app.player.position
 var escape_x:=INF
 for i: int in limit:
  if not app.lifetime.active:return false
  var delta:=point-app.player.position
  if absf(delta.x)<24 and (absf(delta.y)<40 or allow_above and app.player.is_on_floor() and delta.y>0 and delta.y<180):
   app.controller.router.set_source_axis(&"route_probe",0);return true
  var axis:=clampf(delta.x/20.0,-1,1)
  var descending:=delta.y>35 and app.player.is_on_floor()
  if descending:
   app.controller.router.request_action(&"drop_through")
   var gap:=down_gap(point)
   if is_finite(gap):axis=clampf((gap-app.player.position.x)/5.0,-1,1)
  app.controller.router.set_source_axis(&"route_probe",axis,true)
  var grounded:=app.player.is_on_floor()
  if app.player.position.distance_to(before)<1:stale+=1
  else:stale=0
  before=app.player.position
  var ray:=PhysicsRayQueryParameters2D.create(app.player.global_position+Vector2(signf(axis)*15,12),app.player.global_position+Vector2(signf(axis)*18,80),1,[app.player.get_rid()])
  var ledge:=app.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
  var ceiling_ray:=PhysicsRayQueryParameters2D.create(app.player.global_position+Vector2(0,-19),app.player.global_position+Vector2(0,minf(-20,delta.y-18)),1,[app.player.get_rid()])
  var ceiling_hit:=app.player.get_world_2d().direct_space_state.intersect_ray(ceiling_ray)
  var ceiling_blocked: bool=not ceiling_hit.is_empty() and not ceiling_hit.collider.is_in_group("one_way_platform")
  if grounded and ceiling_blocked and delta.y < -30 and not is_finite(escape_x):
   var collider: Node2D=ceiling_hit.collider
   var shape:=collider.get_node_or_null("CollisionShape2D") as CollisionShape2D
   if shape!=null and shape.shape is RectangleShape2D:
    var half: Vector2=shape.shape.size*.5
    var left: float=shape.global_position.x-half.x-15
    var right: float=shape.global_position.x+half.x+15
    var candidates: Array[float]=[left,right]
    candidates.sort_custom(func(a:float,b:float):return absf(player_x()-a)<absf(player_x()-b))
    for x: float in candidates:
     var clear:=true
     var module:=collider.get_parent() as PlatformingModule
     var column:=Rect2(Vector2(x-12,point.y-98),Vector2(24,app.player.position.y+17-(point.y-98)))
     if module!=null:
      for index: int in module.definition.platforms.size():
       if index in module.definition.one_way_platform_indices:continue
       var obstacle: Rect2=module.definition.platforms[index];obstacle.position+=module.global_position
       if obstacle.intersects(column):clear=false;break
     if clear:escape_x=x;break
  if is_finite(escape_x):
   axis=clampf((escape_x-player_x())/5,-1,1)
   app.controller.router.set_source_axis(&"route_probe",axis,true)
   if absf(player_x()-escape_x)<2:escape_x=INF
  if grounded and not is_finite(escape_x) and not descending and (not ceiling_blocked or ledge or absf(delta.x)<40) and (delta.y < -30 or stale>4 or (ledge and absf(delta.x)>45)):
   app.controller.router.request_action(&"jump");jump_ticks=0
  if not grounded:
   jump_ticks+=1
   if jump_ticks==26:app.controller.router.request_action(&"jump_release")
   if not ceiling_blocked and delta.y<=35 and (delta.y < -65 and app.player.velocity.y>-160 or absf(delta.x)>180 and ledge) and app.controller.shoot_ability.cooldown_remaining<=0 and app.controller.action_resources.shot_charges>0:
    var direction: Vector2=Vector2(-axis*clampf(absf(delta.x)/120.0,0,1),1).normalized() if delta.y < -65 else Vector2(-axis,.65).normalized()
    app.controller.router.request_action(&"shoot_release",direction)
  for latch: ShotLatch in app.stage.shot_latches:
   if latch.is_open:continue
   var body: StaticBody2D=latch._second_body if latch.sequence_step==1 and is_instance_valid(latch._second_body) else latch.bell_body
   if body.global_position.distance_to(app.player.global_position)<230 and app.controller.shoot_ability.cooldown_remaining<=0:
    app.controller.router.request_action(&"shoot_release",(body.global_position-app.player.global_position).normalized());break
  await frames(1)
 print("STUCK target=",point," actual=",app.player.position," grounded=",app.player.is_on_floor())
 return false
func run() -> void:
 app=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();app.meta_persistence_enabled=false;root.add_child(app)
 for i: int in 3:await process_frame
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--seed="):route_seed=arg.trim_prefix("--seed=")
 app.menu._start_title_adventure();await frames(2);app.start_plains(route_seed)
 if not await READY.ready(app,self):print("NOT READY");await finish();return
 var stage:=app.stage as MapgenPlainsStage
 var source: Dictionary=preload("res://addons/mapgen/data_json.gd").parse(stage.generated.manifest.mapgen.source_json).value
 initial_player=app.player.get_instance_id()
 var path:=routes(source)
 print("PATH ",path.map(func(s:Dictionary):return str(s.from)+" -> "+str(s.target)))
 var latch:=stage.runtime_latches.latches[0]
 app.controller.router.request_action(&"shoot_release",(latch.bell_body.global_position-app.player.global_position).normalized());await frames(30)
 var ok:=true
 for step: Dictionary in path:
  if not app.lifetime.active:ok=false;break
  if step.has("route"):
   print("ROOM ",step.instance.module_id," ",step.route.from_port," -> ",step.route.to_port," POINTS ",step.route.author_path_pixels)
   var origin:=Vector2(step.instance.origin_blocks[0],step.instance.origin_blocks[1])*128.0
   var port: Dictionary={}
   for raw: Dictionary in step.instance.ports:
    if raw.id==step.route.to_port:port=raw;break
   if step.route.has("author_path_pixels"):
    for raw: Array in step.route.author_path_pixels.slice(1,-1):
     print("WAYPOINT ",origin+Vector2(raw[0],raw[1]))
     if not await go(origin+Vector2(raw[0],raw[1]),900,true):ok=false;break
   if ok and not await go(bank(str(step.instance.id),str(step.route.to_port)),900,false):ok=false
  else:
   var parts: PackedStringArray=str(step.target).split("/")
   var peer: Dictionary={}
   for instance: Dictionary in source.result.map.instances:
    if instance.id==parts[0]:peer=instance;break
   var port: Dictionary={}
   for p: Dictionary in peer.ports:
    if p.id==parts[1]:port=p;break
   var point:=bank(str(peer.id),str(port.id))
   if not await go(point,220,false):ok=false
  if not ok:break
 print("ROUTE RESULT ",ok," active=",app.lifetime.active," ticks=",ticks)
 if ok and app.lifetime.active:
  await go(app.stage.boss_arena.get_center()+Vector2(-200,app.stage.boss_arena.size.y/2-18),180,false)
  var boss: BellstriderEncounter=app.stage.boss.get_node("Encounter")
  var before_combat: float=boss.health.current
  var minimum: float=before_combat
  for i: int in 2400:
   if not app.lifetime.active:break
   if boss.health.terminal or minimum<before_combat:break
   var delta:=boss._core.global_position-app.player.global_position
   var axis:=clampf((absf(delta.x)-220)/30,-1,1)*signf(delta.x)
   if absf(delta.x)<100:axis=-signf(delta.x)
   app.controller.router.set_source_axis(&"route_probe",axis,true)
   if app.player.is_on_floor() and (boss.mode in [&"roll_warning",&"combo_warning",&"ring_warning"] or absf(delta.x)<150):app.controller.router.request_action(&"jump")
   if app.controller.shoot_ability.cooldown_remaining<=0 and (app.player.is_on_floor() or app.controller.action_resources.shot_charges>0):app.controller.router.request_action(&"shoot_release",delta.normalized())
   minimum=minf(minimum,boss.health.current)
   await frames(1)
  accepted_boss_damage=before_combat-minimum
  if accepted_boss_damage<=0 or not app.lifetime.active:failures+=1
  if app.player.get_instance_id()!=initial_player:failures+=1
 else:failures+=1
 if accepted_boss_damage>0 and app.lifetime.active:
  var hash_before: String=app.stage.level_plan.map_hash
  var health_before: float=app.stage.boss.get_node("Encounter").health.current
  app._stage_pending=true
  await app._load_stage()
  if app._stage_pending or app.stage.level_plan.map_hash!=hash_before or app.stage.boss.get_node("Encounter").health.current!=health_before or not app.stage.boss_seal.closed or not app.segment.is_safe(app.player.position):failures+=1
  print("MAPGEN LIVE BOSS REINSTALL same_source=",app.stage.level_plan.map_hash==hash_before," health=",app.stage.boss.get_node("Encounter").health.current," safe=",app.segment.is_safe(app.player.position))
 print("MAPGEN FORMAL ROUTE: ticks=",ticks," accepted_boss_damage=",accepted_boss_damage," failures=",failures)
 await finish()
func finish() -> void:
 DirAccess.make_dir_recursive_absolute("res://build/mapgen_formal")
 var f=FileAccess.open("res://build/mapgen_formal/route_trace.json",FileAccess.WRITE);f.store_string(JSON.stringify({"seed":route_seed,"input_only":true,"accepted_boss_damage":accepted_boss_damage,"failures":failures,"trace":trace}))
 if app.lifetime.active:app.abandon_run()
 for i: int in 8:await process_frame
 await preload("res://tests/audio_teardown.gd").drain_world(app);app.queue_free()
 for i: int in 3:await process_frame
 quit(1 if failures else 0)
