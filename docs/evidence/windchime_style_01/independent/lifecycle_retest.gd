extends SceneTree
var failures: Array[String] = []
var checks := 0
func _init() -> void: _run.call_deferred()
func expect(ok: bool, label: String) -> void:
 checks += 1
 print("REVIEW ",label,"=",ok)
 if not ok: failures.append(label)
func _run() -> void:
 var lab := preload("res://scenes/demo/windchime_lab.tscn").instantiate() as WindchimeLab
 root.add_child(lab)
 for tick: int in 60: await physics_frame
 var motor: EnemyMotor = lab._enemy_motors[0]
 var actor := motor.get_node("Actor") as EnemyActor
 var hp := actor.health.current
 lab.player.reset_at(motor.global_position - Vector2(65,0))
 var fired := lab.controller.shoot_ability.try_fire(Vector2.RIGHT,true)
 for tick: int in 12: await physics_frame
 expect(fired,"real_shot_accepted")
 expect(actor.health.current < hp,"real_shot_commits_damage_before_death")
 print("BEFORE_CONTACT player_health=",lab.controller.actor_resources.health.current," enemy_health=",actor.health.current)
 for tick: int in 240:
  lab.player.reset_at(motor.global_position)
  await physics_frame
  if not lab.controller.active: break
 expect(not lab.controller.active and not lab.lifetime.active,"real_contact_fatal_ends_lifetime")
 var old_token := lab.lifetime.token()
 lab.restart()
 motor = lab._enemy_motors[0]
 actor = motor.get_node("Actor") as EnemyActor
 expect(not lab.lifetime.accepts(old_token),"new_attempt_rejects_old_token")
 expect(actor.health.current == 3,"restart_recreates_enemy_health")
 for tick: int in 45: await physics_frame
 expect(lab.controller.active,"restart_reactivates_player")
 expect(lab.lifetime.active,"restart_reactivates_damage_scope")
 var restored_hp := lab.controller.actor_resources.health.current
 for tick: int in 90:
  lab.player.reset_at(motor.global_position)
  await physics_frame
 expect(lab.controller.actor_resources.health.current < restored_hp,"contact_still_damages_after_restart")
 hp = actor.health.current
 lab.controller.reset_at(motor.global_position - Vector2(65,0))
 fired = lab.controller.shoot_ability.try_fire(Vector2.RIGHT,true)
 for tick: int in 12: await physics_frame
 expect(fired,"shot_accepted_after_restart")
 expect(actor.health.current < hp,"shot_damage_commits_after_restart")
 lab._toggle_material_map()
 lab._toggle_material_map()
 for tick: int in 45: await physics_frame
 expect(lab.lifetime.active,"material_roundtrip_does_not_reuse_dead_scope")
 lab.queue_free()
 for tick: int in 12: await process_frame
 print("WINDCHIME_INDEPENDENT checks=%d failures=%d" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
