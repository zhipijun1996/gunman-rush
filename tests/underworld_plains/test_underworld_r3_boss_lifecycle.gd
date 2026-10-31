extends SceneTree
## Adversarial actual-App boundaries, distinct from uninterrupted full fights.
## Initial HP=1 and frozen AI are explicit collision-order fixtures. All lethal
## damage is from real player bullets and encounter-created ground waves.
var checks:=0
var failures:Array[String]=[]
var observations:Array[Dictionary]=[]
var app:DemoApp
var encounter:WindkeeperEncounter
var map_hashes: Dictionary = {}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func frames(n:int)->void:
	for i:int in n:await physics_frame
func clear_fixture()->void:
	if is_instance_valid(app):
		app.abandon_run();paused=false
		check(await load("res://tests/audio_teardown.gd").drain_world(app),"boundary fixture audio drains")
		app.free();await frames(3)
func fixture(map_index:int,one_hp:bool)->void:
	await clear_fixture()
	app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app);app.start_plains("underworld-r3-boss-adversarial")
	await frames(8)
	if map_index==2:app.director.stage_index=2;app.director.region_map_index=2;app._load_stage();await frames(8)
	var stage := app.stage as PlainsRegionStage
	check(stage.map_index == map_index and app.director.region_map_index == map_index and str(stage.generated.manifest.seed) == PlainsRegionCampaign.seed_for(app.director.seed,map_index) and str(stage.generated.manifest.manifest_hash).length() == 64,"actual Boss fixture map, derived seed and hash match the requested consumer")
	var actual_hash := str(stage.generated.manifest.manifest_hash)
	check(not map_hashes.has(3-map_index) or map_hashes[3-map_index] != actual_hash,"mini and main fixtures own distinct actual Manifest hashes")
	map_hashes[map_index] = actual_hash
	encounter=app.stage.boss.get_node("Encounter") as WindkeeperEncounter
	app.player.reset_at(encounter.motor.global_position+Vector2(-200,47));await frames(5)
	check(app._boss_started,"actual formal core starts encounter")
	encounter.set_physics_process(false);encounter.skip_intro();encounter._enter(&"observe",30);encounter._update_combat_shapes();await frames(2)
	# Keep the unchanged actual spawn protection; do not manufacture an
	# otherwise-ineligible simultaneous hit during entry immunity.
	await frames(45)
	if one_hp:
		var boss_health:=encounter.definition.health_definition.duplicate(true) as HealthDefinition
		boss_health.initial_current=1;encounter.health.configure(boss_health)
		var player_health:=app.controller.actor_resources.health_definition.duplicate(true) as HealthDefinition
		player_health.initial_current=1;app.controller.actor_resources.health.configure(player_health)
	app.policy.set_physics_process(false)
func real_bullet()->PlayerProjectile:
	var point := encounter.motor.global_position+Vector2(0,-20)
	if encounter is BellstriderEncounter: point = encounter.motor.to_global(encounter.core_offset())
	app.controller.router.request_action(&"shoot_release",(point-app.player.global_position).normalized())
	await frames(1)
	var live:=app.controller.shoot_ability.get_projectiles()
	check(live.size()==1,"actual Router action creates exactly one live player bullet")
	if live.is_empty():return null
	var bullet:=live[0];bullet.set_physics_process(false);return bullet
func release_wave(side: int) -> BossProjectile:
	if encounter is BellstriderEncounter:
		# Observe the real owner-bound Bell release, not its inherited Windkeeper
		# helper. Both real sides remain frozen in this collision-order fixture.
		(encounter as BellstriderEncounter)._ring_pair()
		var chosen: BossProjectile
		for shot: BossProjectile in encounter._projectiles:
			shot.set_physics_process(false)
			if shot.direction == Vector2(side,0): chosen = shot
		check(chosen is BellstriderRingProjectile,"lifecycle uses the actual Bellstrider ground-wave producer")
		return chosen
	encounter._wave(side)
	var shot := encounter._projectiles.back() as BossProjectile
	shot.set_physics_process(false)
	return shot

func run()->void:
	for map_index:int in [1,2]:
		for reverse:bool in [false,true]:
			await fixture(map_index,true)
			var bullet:=await real_bullet()
			var wave := release_wave(-1)
			var wallet_before := app.wallet.balance
			var state_before := (app.stage as PlainsRegionStage).region_state
			var boss_coin_id := BellstriderRewards.source_id(app.stage as PlainsRegionStage)
			await frames(1)
			if reverse:wave.advance(1);bullet.advance(1)
			else:bullet.advance(1);wave.advance(1)
			check(bullet.spent and wave.spent,"both actual projectile sweeps collide")
			check(app.policy._queue.size()==2,"actual opposing collisions collect into one pending frame batch")
			var results:=app.policy.resolve_batch()
			check(results.size()==2 and results[0].lethal and results[1].lethal,"real opposing bullets commit both lethal HP in either order")
			await frames(4)
			check(not app.lifetime.active and app.director.state==DemoRunDirector.State.HOME,"actual simultaneous death returns Home as failure")
			check(app.current_reward==null and app.meta.snapshot().completed_biomes==0,"actual simultaneous lethal never creates Gold or biome completion")
			check(not app.director.manifest.snapshot().stages[0].outputs.has("mini_boss_reward"),"actual simultaneous lethal never pays mini reward")
			check(map_index!=1 or not state_before.drops.has(boss_coin_id),"simultaneous player death creates no physical Bell coin entitlement")
			await frames(72)
			check(app.wallet.balance==wallet_before,"past the delayed major impact simultaneous death still pays no coins")
			observations.append({"map":map_index,"reverse":reverse,"results":results.size(),"home":app.director.state==DemoRunDirector.State.HOME,"reward":app.current_reward!=null})
	# A real accepted bullet is held before contact; actual segment return
	# invalidates its actor/session and the old bullet must dispose without HP.
	await fixture(1,false)
	var stale:=await real_bullet();var hp:=encounter.health.current;var epoch:=app.lifetime.actor_epoch
	check(app.segment.return_to_anchor(),"actual safe segment return accepted")
	check(app.lifetime.actor_epoch==epoch+1,"actual segment return increments actor epoch")
	stale.advance(.3)
	app.policy.resolve_batch()
	check(stale.spent and encounter.health.current==hp,"held old actor bullet cannot damage current Boss after return")
	# Actual encounter-created waves are cancelled at phase invalidation; a
	# retained old object cannot hit after cancellation/restore.
	var cancelled := release_wave(-1)
	var player_hp:=app.controller.actor_resources.health.current
	encounter.cancel_pending_attacks();cancelled.advance(1);app.policy.resolve_batch()
	check(cancelled.spent and app.controller.actor_resources.health.current==player_hp,"cancelled phase wave cannot submit late damage")
	var saved:=JSON.parse_string(JSON.stringify(encounter.combat_snapshot())) as Dictionary
	var serial:=encounter._attack_serial
	encounter.restore_combat_state(saved)
	check(encounter._projectiles.is_empty() and encounter._attack_serial==serial,"JSON reload does not respawn an already-emitted phase wave")
	await clear_fixture()
	DirAccess.make_dir_recursive_absolute("res://build/underworld_r3/boss")
	var file:=FileAccess.open("res://build/underworld_r3/boss/lifecycle.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"scope":"actual App projectile transactions; HP1/frozen-AI are explicit initial boundary fixtures, not full fight evidence"},"\t"));file.close()
	print("UNDERWORLD R3 BOSS LIFECYCLE: %d checks, %d failures"%[checks,failures.size()]);quit(1 if not failures.is_empty() else 0)
