extends "res://tests/world/plains35_fixture.gd"
## Real AI/ground support, authored species binding, and camera-independent sky composition.
func run() -> void:
 app=load("res://game/application/world/fixed_world.tscn").instantiate()
 app.save_path="user://fan_species_test.json";root.add_child(app);app.workbench.enabled=true
 await load_room("P-R32")
 await fixture(Vector2(1728,814))
 var health:=HealthDefinition.new();health.resource_id=&"fan_test_health";health.max_health=100;health.initial_current=100
 app.controller.actor_resources.health.configure(health)
 var ground:EnemyActor=app.room.enemies.get("P-R32:pier_sentry")
 check(ground!=null and ground.definition.behavior_id==&"ground_fan_sentry" and not ground.definition.aerial,"pier uses independent grounded fan species")
 check(ground.health.current==14,"ground fan is three base-gun hits")
 for enemy:EnemyActor in app.room.enemies.values():
  if enemy!=ground:enemy.set_physics_process(false)
 var start:=ground.motor.position
 var min_x:=start.x;var max_x:=start.x;var supported:=true;var phases:Dictionary={}
 for i:int in 360:
  await ticks(1)
  min_x=minf(min_x,ground.motor.position.x);max_x=maxf(max_x,ground.motor.position.x)
  supported=supported and ground.motor.supported_at(ground.motor.global_position)
  phases[ground.attack_behavior.state]=true
 check(supported and max_x-min_x>20 and absf(ground.motor.position.y-start.y)<.1,"ground fan patrols on the actual floor between volleys")
 check(ground.attack_behavior._serial>=6 and ground.attack_behavior._serial%3==0,"ground AI commits real three-shot volleys")
 check(phases.has(&"telegraph") and phases.has(&"attack") and phases.has(&"recovery"),"ground shot has readable prepare/commit/recover")
 var strategy:=EnemyBehaviorRegistry.create_attack_strategy(&"ground_fan_sentry")
 check(strategy.projectile_angles()==[-.18,0.0,.18],"ground fan preserves existing three-way shot pattern")
 var gv:=ground.motor.get_node("Presentation") as UnderworldEnemy
 check(gv.revision_visual.rig.animation.atlas.resource_path.ends_with("ground_fan_sentry.png"),"rooted original artwork belongs to ground species")
 var art:=app.room.get_node("RegionalArt") as PlainsRoomArt
 check(art.sky.texture.resource_path.ends_with("clockheart-landscape.png"),"tower and hills share one opaque background plate")
 check(art.depths.is_empty(),"P32 has no separately sliding tower foot")
 for at:Vector2 in [Vector2(1184,942),Vector2(1824,814),Vector2(2656,622)]:
  await fixture(at);await ticks(20)
  var camera:=app.camera as Camera2D
  var visible_size:=root.get_visible_rect().size/camera.zoom
  var picture:=Rect2(art.sky.position-art.sky.texture.get_size()*art.sky.scale*.5,art.sky.texture.get_size()*art.sky.scale)
  var screen:=Rect2(camera.get_screen_center_position()-visible_size*.5,visible_size)
  check(picture.grow(1).encloses(screen),"tower background covers whole viewport at "+str(at))
 await load_room("P-R06")
 var flyer:EnemyActor
 for enemy:EnemyActor in app.room.enemies.values():
  if enemy.definition.behavior_id==&"fan_sentry":flyer=enemy;break
 check(flyer!=null and flyer.definition.aerial,"existing aerial placements retain their gameplay identity")
 var fv:=flyer.motor.get_node("Presentation") as UnderworldEnemy
 var skin:=fv.revision_visual.rig as PlainsActorSkin
 check(skin.animation.columns==8 and skin.motion_animation==skin.animation,"flyer has eight authored poses in every state")
 check(skin.animation.atlas.resource_path.ends_with("/fan_sentry.png"),"flyer uses its own winged artwork")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(2)
 print("FAN SPECIES: ",failures," failures");quit(1 if failures else 0)
