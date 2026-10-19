extends SceneTree
var checks := 0
var failures: Array[String] = []
func _init() -> void: _run.call_deferred()
func expect(ok: bool,label: String) -> void:
 checks += 1
 if not ok: failures.append(label); printerr("FAIL ",label)
func _run() -> void:
 var lab := preload("res://scenes/demo/windchime_lab.tscn").instantiate() as WindchimeLab
 root.add_child(lab)
 for tick: int in 60: await physics_frame
 for cycle: int in 20:
  # Allow real ground recovery; Restart does not promise a stamina refill.
  for recovery_tick: int in 180: await physics_frame
  var old_scope := lab.lifetime
  var token := old_scope.token()
  var accepted := lab.controller.shoot_ability.try_fire(Vector2.UP,true)
  expect(accepted,"fresh sample accepts real shot")
  var shots := lab.controller.shoot_ability.get_projectiles()
  expect(shots.size()==1,"one real shot")
  if shots.size()==1:
   expect(shots[0].presentation is WindchimeProjectileVisual,"actual projectile consumes new presentation")
  lab._toggle_catalog()
  expect(paused,"catalog actual pause")
  lab.restart()
  for tick: int in 3: await physics_frame
  expect(not paused and not lab._catalog.visible,"restart closes catalog")
  expect(not old_scope.active and not lab.lifetime.accepts(token),"old scope and token cancelled")
  expect(lab.controller.shoot_ability.get_projectiles().is_empty(),"old real projectiles cancelled")
  expect(get_nodes_in_group(&"grapple_target").size()==2,"only two live enemy bodies after recreation")
  expect(lab.policy._targets.size()==3,"fresh registry has exactly current actor set")
  lab._toggle_material_map()
  for tick: int in 3: await physics_frame
  expect(get_nodes_in_group(&"grapple_target").is_empty(),"materials clear all real enemies")
  expect(lab.policy._targets.size()==1,"materials clear all enemy targets")
  lab._toggle_material_map()
  for tick: int in 3: await physics_frame
 lab._toggle_pause()
 var actor := lab._enemy_motors[0]
 var initial := actor.position
 for tick: int in 4: await process_frame
 expect(actor.position==initial,"pause stops actual enemy simulation")
 lab.leave()
 expect(not paused,"home emits with global pause clear")
 lab.queue_free()
 for tick: int in 15: await process_frame
 expect(get_nodes_in_group(&"grapple_target").is_empty(),"exit leaves no enemy body group")
 print("WINDCHIME_REPEAT checks=%d failures=%d" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
