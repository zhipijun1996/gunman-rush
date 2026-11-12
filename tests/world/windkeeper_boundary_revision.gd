extends "res://tools/art/plains_actor_capture_base.gd"
## Declared positions/stages isolate the formal Boss's next-action decisions.
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL WINDKEEPER BOUNDARY: ",label)

func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate()
 app.save_path="user://windkeeper_boundary_revision.json"
 root.add_child(app);app.start_new();await settle()
 for phase:int in [1,3]:
  for side:int in [-1,1]:
   for facing:int in [-1,1]:await boundary_case(phase,side,facing)
 await mill_passage()
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("WINDKEEPER BOUNDARY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)

func prepare() -> WindkeeperPressureEncounter:
 load_fixture("P-R14");await settle();await ticks(4)
 app.player.reset_at(app.room.battle_entry_anchor)
 app.room.update_battle(app.player.position)
 var boss:=app.room.encounter as WindkeeperPressureEncounter
 boss.set_physics_process(false);boss.cancel_pending_attacks()
 check(boss.active,"formal room entry starts the real encounter")
 return boss

func boundary_case(phase:int,side:int,facing:int) -> void:
 var boss:=await prepare()
 boss.stage_phase=phase;boss.direction=facing;boss._pose_from.clear()
 if phase==3:
  boss._support_index=0 if side<0 else boss._support_rects.size()-1
  var slab:Rect2=boss._support_rects[boss._support_index]
  boss.motor.global_position=Vector2(slab.get_center().x,slab.position.y-65)
 else:
  boss.motor.global_position=Vector2(boss.arena.left_x+18 if side<0 else boss.arena.right_x-18,boss._base_y)
 boss._enter(&"observe",0);boss._update_combat_shapes()
 boss._retreat_ready_age=boss._fight_age+1000 # Ordinary retreat is deliberately unavailable.
 boss._group_plan={"attacks":[&"seeds"],"double_stomp":false,"sweep_high":false}
 boss._attack_index=0;boss._preparation_index=-1
 var start:=boss.motor.global_position
 boss._begin_attack()
 check(boss._hop_prepared and boss.mode in [&"turn",&"retreat_warning"],"edge overrides attack and cooldown: phase/side/facing %s/%s/%s"%[phase,side,facing])
 var target:=boss._hop_target
 check((target.x-start.x)*side<0,"locked retreat target moves into the arena")
 if phase==3:
  check(boss._hop_height>boss._config().retreat_height,"phase-three retreat has a higher real arc")
 var airborne:=false
 var min_y:=start.y
 for i:int in 220:
  boss.physics_tick(1.0/60);await physics_frame
  min_y=minf(min_y,boss.motor.global_position.y)
  if boss.mode==&"retreat":airborne=true
  elif airborne:break
 check(airborne and boss.motor.global_position.distance_to(target)<1,"actual backward jump lands on its committed floor/deck")
 check(start.y-min_y>boss._hop_height*.9,"backward jump has a real elevated trajectory")
 if phase==3:
  check(boss._standing_on_support(),"full Boss stance is on an actual verified deck")
  var next:=boss._next_support_index(start.x)
  if boss._lock_support_hop(next,boss._config().final_chase_speed,false):
   check(boss._hop_height>=boss._config().support_hop_height*boss._config().phase_three_jump_height_scale,"ordinary phase-three traversal also uses the higher arc")

func mill_passage() -> void:
 var boss:=await prepare()
 boss.stage_phase=2;boss.motor.global_position.x=(boss.arena.left_x+boss.arena.right_x)*.5
 boss._enter(&"observe",1000);boss._pose_from.clear();boss._update_combat_shapes()
 var hub:=boss.motor.to_global(PlainsBossViewPose.windmill_origin(boss.rig_pose()))
 var half:=Vector2(12,18)
 var start:=hub-Vector2(100,0)
 var finish:=hub+Vector2(100,0)
 check(not boss.body_contact_sweep(boss.motor.global_position,start-boss.motor.global_position,finish,half),"full player sweep through phase-two rotor carries no contact damage")
 var body_point:=boss.motor.to_global((boss.rig_pose().body_transform as Transform2D).origin)
 check(boss.body_contact_sweep(boss.motor.global_position,body_point-boss.motor.global_position,body_point,half),"real torso contact stays enabled while rotor is passable")
 var query:=PhysicsRayQueryParameters2D.create(start,finish,4,[app.player.get_rid()])
 check(boss.motor.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"rotor adds no physical or shootable obstacle across its upper span")
