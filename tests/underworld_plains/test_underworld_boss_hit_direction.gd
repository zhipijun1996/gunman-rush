extends SceneTree
## Actual App directional hit boundary fixture. AI is explicitly frozen after
## entry so each real encounter-created wave can be swept in isolation.
var checks:=0
var failures:Array[String]=[]
var observations:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func frames(count:int)->void:
	for i:int in count:await physics_frame
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: ",message)
func run()->void:
	for side:int in [-1,1]:
		var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
		check(app.start_plains("underworld-r3-boss-direction"),"actual formal run starts")
		await frames(8)
		var encounter:=app.stage.boss.get_node("Encounter") as WindkeeperEncounter
		app.player.reset_at(encounter.motor.global_position+Vector2(side*200,47))
		await frames(5)
		check(app._boss_started,"real room entry activates boss")
		encounter.set_physics_process(false);encounter.skip_intro();encounter._enter(&"observe",30);encounter._update_combat_shapes()
		await frames(45)
		app.policy.set_physics_process(false)
		var health:=app.controller.actor_resources.health.current
		encounter._wave(side)
		var wave:=encounter._projectiles.back() as BossProjectile
		wave.set_physics_process(false)
		await frames(1)
		wave.advance(1)
		check(wave.spent and app.policy._queue.size()==1,"real wave sweeps player and queues one actual hit")
		var queued:DamageRequest=app.policy._queue[0] if app.policy._queue.size()==1 else null
		check(queued!=null and queued.hit_direction==Vector2(side,0),"actual Boss hit preserves incoming left/right direction")
		var before:=app.player.global_position
		var batch:=app.policy.resolve_batch()
		check(batch.size()==1 and app.controller.actor_resources.health.current==health-1,"one actual nonlethal HP change commits")
		check(signf(app.player.damage_velocity.x)==side and app.player.damage_remaining>0,"Motor receives same accepted incoming hit direction")
		await frames(3)
		check((app.player.global_position.x-before.x)*side>6,"actual unique Motor moves away from the incoming wave")
		observations.append({"side":side,"source":"actual encounter._wave -> BossProjectile collision -> DemoApp -> FrameDamagePolicy","queued_direction":queued.hit_direction if queued!=null else Vector2.ZERO,"before":before,"after":app.player.global_position,"hp":app.controller.actor_resources.health.current})
		app.abandon_run()
		check(await load("res://tests/audio_teardown.gd").drain_world(app),"actual feedback audio drains before teardown")
		app.free();await frames(5)
	DirAccess.make_dir_recursive_absolute("res://build/underworld_r3/boss")
	var file:=FileAccess.open("res://build/underworld_r3/boss/directional_hits.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"scope":"actual formal App left/right wave collision and Motor; one room initialization/frozen AI boundary fixture, not complete fight"},"\t"));file.close()
	print("UNDERWORLD R3 BOSS HIT DIRECTION: %d checks, %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
