extends "res://tests/actor_actions_runner.gd"
## Real Controller/Motor floor contact, accepted shots and full motion windows.
func run() -> void:
 for mode: String in ["shot_burst", "legacy_impulse"]:
  for aim: Vector2 in [Vector2.UP,Vector2.DOWN,Vector2.RIGHT,Vector2(1,1).normalized(),Vector2(-1,-1).normalized()]:
   await fixture(Vector2(400,682));await tick(3)
   motor.tuning.recoil_mode=mode
   var start:=motor.position
   controller.router.request_action(&"shoot_release",aim)
   await tick()
   check(events.size()==1,"ground shot accepted %s %s" % [mode,aim])
   check(is_zero_approx(motor.recoil_velocity.y),"ground shot has zero vertical recoil")
   for frame: int in 18:
    await tick()
    check(absf(motor.position.y-start.y)<.1,"floor height preserved through recoil window")
   check(is_zero_approx(motor.weapon_apex_remaining),"ground shot cannot start aerial apex")
   check(absf(motor.position.x-start.x)>1 if absf(aim.x)>.01 else absf(motor.position.x-start.x)<.1,"only horizontal component displaces player")
 for id: String in ["triple_machine_gun","shadow_shuriken","fan_shuriken","sustained_laser"]:
  await fixture(Vector2(400,682));await tick(3)
  controller.shoot_ability.equip(load("res://resources/weapons/%s.tres" % id))
  var y:=motor.position.y
  controller.router.activate_device(&"gamepad")
  controller.router.set_aim(&"gamepad",Vector2.DOWN,true)
  if id!="sustained_laser":controller.router.request_action(&"shoot_release",Vector2.DOWN)
  for frame: int in 40:
   await tick()
   check(absf(motor.position.y-y)<.1,"ground delayed/continuous weapon cannot lift: "+id)
 for id: String in ["pulse_ice","machine_storm","laser_cannon"]:
  await fixture(Vector2(400,682));await tick(3)
  var def:=load("res://resources/weapons/%s.tres" % id) as WeaponDefinition
  controller.shoot_ability.equip(def);controller.combat_energy.current=def.skill_cost
  var y:=motor.position.y
  check(controller.shoot_ability.behavior().begin(Vector2.DOWN,true,true),"ground active skill accepts: "+id)
  for frame: int in 90:
   await tick()
   check(absf(motor.position.y-y)<.1,"ground active skill cannot lift: "+id)
 for aim: Vector2 in [Vector2.DOWN,Vector2(1,1).normalized()]:
  await fixture(Vector2(400,682));await tick(3)
  var y:=motor.position.y
  controller.router.request_action(&"shoot_release",aim)
  controller.router.request_action(&"jump")
  await tick()
  check(motor.recoil_velocity.y < -100 and motor.position.y < y,"same-frame jump retains full aerial recoil")
  check(controller.action_resources.shot_charges==1,"jump-shot consumes aerial charge")
 # An angled ground shot keeps its original X magnitude, rather than becoming a full-speed horizontal shot.
 await fixture(Vector2(400,682));await tick(3)
 var aim:=Vector2(1,1).normalized()
 controller.shoot_ability.try_fire(aim,true)
 check(absf(motor.recoil_velocity.x+aim.x*motor.tuning.shot_burst_speed*motor.tuning.ground_recoil_multiplier)<.01,"ground projection preserves X magnitude")
 # Supporting platform motion remains independent of the shot.
 var floor_body:=world.get_child(0) as StaticBody2D
 floor_body.constant_linear_velocity=Vector2(0,-20)
 await tick(1)
 var before:=motor.position.y
 controller.shoot_ability.cooldown_remaining=0
 controller.router.request_action(&"shoot_release",Vector2.DOWN)
 await tick(1)
 check(motor.position.y<before,"ground shot does not erase platform carry")
 world.free();await process_frame
 print("GROUND SHOOTING: ",checks," assertions, ",failures," failures")
 quit(1 if failures else 0)
