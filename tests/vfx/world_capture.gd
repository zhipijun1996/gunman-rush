extends "res://tests/world/plains35_fixture.gd"
## Actual world/controller media. Explicit local start, survivor HP and energy fixtures.
## Does not prove quest acquisition, a full room route or a full Boss fight.
var scenario:="shot"
var output:="res://build/vfx/world-media"
var shot_count:=0
func _initialize() -> void:
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--case="):scenario=arg.trim_prefix("--case=")
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 run.call_deferred()
func record(count:int,label:String) -> void:
 for i:int in count:
  await physics_frame
  if scenario=="heal" and app.story.active:app.story.finish()
  await RenderingServer.frame_post_draw
  if i in [1,3,8,18,36,60]:root.get_texture().get_image().save_png(output+"/"+label+"-%03d.png"%i)
func settle() -> void:
 for i:int in 300:
  await physics_frame
  if not app.busy:return
 check(false,"world transition finishes")
func run() -> void:
 root.size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute(output)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 app.preferences.value.reduced=false;app._apply_preferences()
 await app.review.begin("P-R10" if scenario=="shot" else "P-R01" if scenario=="heal" else "P-R14","","base")
 await settle()
 if app.story.active:app.story.finish();await ticks(2)
 if scenario=="shot":
  var target:EnemyActor=app.room.enemies["P-R10:r9:teach_down"]
  for other:EnemyActor in app.room.enemies.values():
   if other!=target:other.cancel_attacks();other.process_mode=Node.PROCESS_MODE_DISABLED
  var definition:=target.definition.health_definition.duplicate(true) as HealthDefinition
  definition.max_health=50;definition.initial_current=50
  target.health.configure(definition);target.damageable.bind_health(target.health)
  await fixture(Vector2(896,2030));await record(30,"idle")
  app.controller.shoot_ability.shot_fired.connect(func(_axis:Vector2,_serial:int) -> void:shot_count+=1)
  var aim:=(target.motor.position-app.player.position-Vector2(0,-6)).normalized()
  app.controller.router.request_action(&"shoot_release",aim)
  await record(75,"pulse")
  check(shot_count==1 and target.health.current<50,"recorded actual accepted pulse and damage")
  app.controller.shoot_ability.equip(preload("res://resources/weapons/pulse_ice.tres"))
  app.controller.combat_energy.grant("vfx_media_declared_energy_fixture",80)
  aim=(target.motor.position-app.player.position-Vector2(0,-6)).normalized()
  app.controller.router.request_action(&"weapon_skill",aim)
  await record(100,"ice")
  check(target.damageable.chill_remaining>0,"recorded surviving actual ice receiver")
 elif scenario=="heal":
  await fixture(Vector2(720,622));await record(30,"idle")
  app.submit_damage(&"vfx_media_declared_damage",DamageRequest.Kind.MONSTER,2,&"vfx_media_hit")
  await record(100,"hurt")
  var hp:=app.controller.actor_resources.health.current
  app.controller.combat_energy.grant("vfx_media_declared_energy_fixture",100)
  app.controller.router.set_focus_heal_held(&"keyboard_mouse",true)
  await record(68,"heal")
  app.controller.router.set_focus_heal_held(&"keyboard_mouse",false)
  await record(30,"release")
  check(app.controller.actor_resources.health.current>hp,"recorded committed HP restoration")
 else:
  await fixture(app.room.battle_entry_anchor)
  await record(240,"boss")
  check(app.room.battle_started,"recorded actual Boss encounter entry")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
 print("VFX WORLD MEDIA: ",scenario," ",failures," failures")
 quit(failures)
