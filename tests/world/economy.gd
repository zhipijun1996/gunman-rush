extends SceneTree
## Accepted enemy damage and placement fixtures isolate existing loot -> world ledger adaptation.
var app: FixedWorldApp
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print("GOLD CHECK ",ok," ",label)
	if not ok: failures+=1
func ticks(n: int) -> void:
	for i: int in n: await physics_frame
func settle() -> void:
	for i: int in 180:
		await physics_frame
		if not app.busy: return
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://world_gold_test.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle()
	app.player.reset_at(Vector2(600,512))
	var actor: EnemyActor=app.room.enemies["P-R03:practice:01"]
	actor.damageable.receive_damage({"event_id":"gold_fixture_kill","amount":99,"source_faction":&"player","source_actor_id":app.player.get_instance_id(),"target_actor_id":actor.damageable.actor_id,"target_epoch":actor.damageable.damage_epoch})
	await ticks(150)
	check(actor.health.terminal and app.services.ledger().gold==0,"accepted kill leaves actual ground coins instead of silently crediting money")
	var pending: Dictionary=app.services.ledger().get("drops",{})
	check(pending.size()==1 and app.room.loot.pickups.size()==1 and int(pending.values()[0].amount)==5,"existing denominations produce one physical five-value coin")
	check(not app.room.loot.find_children("*","Sprite2D",true,false).is_empty(),"existing PlainsStageVisual renders the drop")
	var id:=str(pending.keys()[0]);var position: Vector2=app.room.loot.pickups[0].position
	app.load_room("P-R01","");await settle();app.load_room("P-R03","");await settle()
	check(app.services.ledger().drops.size()==1 and app.room.loot.pickups.size()==1,"unclaimed drop survives room unload without repeating the kill reward")
	app.state.storage.blocked=true
	app.player.reset_at(position);await ticks(15)
	check(app.services.ledger().gold==0 and app.services.ledger().drops.has(id),"failed durable pickup keeps the coin and does not credit money")
	app.state.storage.blocked=false;await ticks(10)
	check(app.services.ledger().gold==5 and not app.services.ledger().drops.has(id),"real proximity pickup commits money and removes entitlement atomically")
	app.enqueue("coin",id);await ticks(5)
	check(app.services.ledger().gold==5,"duplicate pickup cannot mint money")
	# Separate unclaimed receipt fixture for the independent restart process.
	var candidate:=app._drop_candidate(app._snapshot(),"restart_fixture",3,Vector2(1200,352))
	check(app.state.commit(candidate,app.state.revision),"declared restart fixture persists three unclaimed one-value coins")
	app.return_title();await ticks(5);app.queue_free();await ticks(5)
	print("WORLD GOLD: %d assertions, %d failures" % [checks,failures]);quit(failures)
