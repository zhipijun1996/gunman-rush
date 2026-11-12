extends "res://tests/world/windkeeper_boundary_revision.gd"
## Real P14 and PlayerMotor: walking guardian is crossed above; pounce below.
## Explicit phase/position/group fixtures, no changed physics or disabled hull.
var capture:=false
func run()->void:
 capture="capture" in OS.get_cmdline_user_args();root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate()
 app.save_path="user://windkeeper_crossing.json";root.add_child(app);app.start_new();await settle()
 for phase:int in [1,2]:
  for side:int in ([-1] if capture else [-1,1]):
   await walking_cross(phase,side)
   await pounce_cross(phase,side)
 if not capture:
  for frame:int in [16,20]:await walking_cross(2,-1,frame,Vector2(.94,.34))
  await distant_corner()
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("WINDKEEPER CROSSING: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)

func step(boss:WindkeeperPressureEncounter)->void:
 boss.physics_tick(1.0/60);await physics_frame

func observe_projectile_hits(boss:WindkeeperPressureEncounter)->Array[int]:
 var hits:Array[int]=[0]
 boss.projectile_created.connect(func(p:BossProjectile)->void:
  p.hit.connect(func(body:Node,_id:StringName,_amount:float)->void:
   if body==app.player:hits[0]+=1))
 return hits

func walking_cross(phase:int,side:int,shot_frame:int=18,aim:Vector2=Vector2(.86,.5))->void:
 var boss:=await prepare("base")
 var projectile_hits:=observe_projectile_hits(boss)
 boss.stage_phase=phase;boss.direction=side;boss._pose_from.clear()
 boss.motor.global_position=Vector2(boss.arena.left_x+18 if side<0 else boss.arena.right_x-18,boss._base_y)
 park_player(boss,phase,side)
 boss._group_plan.clear();boss._enter(&"observe",0)
 var saw_retreat:=false
 for i:int in 180:
  await step(boss)
  if boss.mode==&"retreat":saw_retreat=true
  if saw_retreat and boss.mode==&"observe":break
 if capture:print("CROSS MEDIA upper-start phase=",phase," frame=",Engine.get_process_frames())
 var after_retreat:=boss.motor.position
 var saw_approach:=false
 for i:int in 150:
  await step(boss)
  if boss.mode==&"approach":saw_approach=true
  if str(boss.mode).ends_with("_warning"):break
 check(saw_retreat and saw_approach and (boss.motor.position.x-after_retreat.x)*side>40,"spacing retreat is followed by real ground pursuit: %s/%s"%[phase,side])
 var wall:=boss.arena.left_x-boss._config().wall_clearance if side<0 else boss.arena.right_x+boss._config().wall_clearance
 check(absf(boss.motor.position.x-wall)>=boss._config().corner_standoff_distance-1,"ground pursuit leaves a real takeoff lane")
 # Use the actual next committed stomp/seeds group, retaining its live warning.
 var initial_direction:=boss.direction
 var contacts:=0
 var router:=app.controller.router
 var crossed:=false
 var min_clearance:=INF
 router.set_source_axis(&"keyboard_mouse",-side)
 for i:int in 45:
  if absf(app.player.global_position.x-boss.motor.global_position.x)<190:break
  await step(boss)
 router.set_jump_held(&"keyboard_mouse",true)
 for i:int in 240:
  if i==shot_frame:router.request_action(&"shoot_release",Vector2(side*aim.x,aim.y).normalized())
  if i==32:router.set_jump_held(&"keyboard_mouse",false)
  var previous:=app.player.global_position-boss.motor.global_position
  await step(boss)
  if boss.body_contact_sweep(boss.motor.global_position,previous,app.player.global_position,Vector2(12,18)):contacts+=1
  if absf(app.player.global_position.x-boss.motor.global_position.x)<55:min_clearance=minf(min_clearance,boss.motor.global_position.y-app.player.global_position.y)
  if (app.player.global_position.x-boss.motor.global_position.x)*-side>110:
   crossed=true;router.set_source_axis(&"keyboard_mouse",0)
  if crossed and boss.mode==&"recover":break
 check(crossed and contacts==0,"real jump/recoil clears walking Boss without hull contact: %s/%s contacts=%s clearance=%s input=%s/%s"%[phase,side,contacts,min_clearance,shot_frame,aim])
 check(boss.direction==initial_direction and boss.mode==&"recover","crossing earns the remainder of the original-facing group and recovery")
 for i:int in int(boss._config().group_recovery_seconds*60)-1:await step(boss)
 check(projectile_hits[0]==0,"upper crossing and counterattack window receive no physical projectile hit, despite invincible fixture")
 var snapshot:=boss.combat_snapshot();boss.restore_combat_state(snapshot)
 check(boss.direction==initial_direction and boss._group_plan.has("facing"),"save restore preserves committed facing rather than retargeting")
 if capture:root.get_texture().get_image().save_png("res://build/corner-rework/boss-over.png")
 router.clear("completed upper crossing fixture")
 for i:int in 150:
  await step(boss)
  if boss.direction!=initial_direction:break
 check(boss.direction!=initial_direction,"after recovery the real turn reacquires the player behind")
 if capture:
  print("CROSS MEDIA upper-end phase=",phase," frame=",Engine.get_process_frames());await ticks(20)

func pounce_cross(phase:int,side:int)->void:
 var boss:=await prepare("base")
 var projectile_hits:=observe_projectile_hits(boss)
 boss.stage_phase=phase;boss.direction=side;boss._pose_from.clear()
 boss.motor.global_position=Vector2((boss.arena.left_x+boss.arena.right_x)*.5,boss._base_y)
 app.player.reset_at(boss.motor.global_position+Vector2(side*225,47))
 app.controller.router.clear("ground passage start fixture");await ticks(3)
 boss._group_plan={"attacks":[&"lunge",&"stomp"],"double_stomp":false,"sweep_high":false}
 boss._attack_index=0;boss._preparation_index=-1;boss._begin_attack()
 check(boss.mode==&"lunge_warning","forward pounce has its full committed warning")
 for i:int in 100:
  if boss.mode==&"lunge":break
  await step(boss)
 if capture:print("CROSS MEDIA lower-start phase=",phase," frame=",Engine.get_process_frames())
 var target:=boss._hop_target
 var contacts:=0
 var crossed:=false
 var grounded:=true
 var router:=app.controller.router
 router.set_source_axis(&"keyboard_mouse",-side)
 for i:int in 160:
  var previous:=app.player.global_position-boss.motor.global_position
  await step(boss)
  if boss.body_contact_sweep(boss.motor.global_position,previous,app.player.global_position,Vector2(12,18)):contacts+=1
  grounded=grounded and app.player.is_on_floor()
  if (app.player.global_position.x-boss.motor.global_position.x)*-side>110:crossed=true;router.set_source_axis(&"keyboard_mouse",0)
  if crossed and boss.mode==&"recover":break
 check(crossed and grounded and contacts==0,"real ground run passes under a live pounce: %s/%s contacts=%s"%[phase,side,contacts])
 check(boss._hop_target==target,"ground crossing does not retarget the locked pounce landing")
 check(boss.direction==side and boss.mode==&"recover","pounce combo completes in its original direction")
 for i:int in int(boss._config().group_recovery_seconds*60)-1:await step(boss)
 check(projectile_hits[0]==0,"lower crossing has a real counterattack window without a new rear wave")
 if capture:root.get_texture().get_image().save_png("res://build/corner-rework/boss-under.png")
 router.clear("completed lower crossing fixture")
 if capture:print("CROSS MEDIA lower-end phase=",phase," frame=",Engine.get_process_frames())

func distant_corner()->void:
 var boss:=await prepare("base");boss.stage_phase=1;boss.direction=-1
 boss.motor.global_position=Vector2(boss.arena.right_x,boss._base_y)
 park_player(boss,1,-1)
 var hit_times:Array[float]=[]
 boss.projectile_created.connect(func(p:BossProjectile)->void:
  p.hit.connect(func(body:Node,_id:StringName,_amount:float)->void:
   if body==app.player:hit_times.append(boss._fight_age)))
 boss._group_plan.clear();boss._enter(&"observe",0)
 var closest:=INF
 for i:int in 960:
  await step(boss)
  closest=minf(closest,boss.motor.position.x)
 check(closest<boss.arena.left_x+150,"opposite-side corner camping causes actual approach, without needing an earlier retreat latch")
 check(hit_times.size()>=3,"stationary corner is reached repeatedly by real physical attacks, hits="+str(hit_times.size()))
