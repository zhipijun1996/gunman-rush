extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var app: FixedWorldApp=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://world_gold_test.json";root.add_child(app)
	var ok:=app.continue_world()
	for frame: int in 90: await physics_frame
	ok=ok and app.services.ledger().gold==5 and app.services.ledger().drops.size()==3 and app.room.loot.pickups.size()==3
	for row: Dictionary in app.services.ledger().drops.values(): ok=ok and int(row.amount)==1
	app.queue_free()
	for frame: int in 5: await physics_frame
	print("WORLD GOLD RESTART: ",0 if ok else 1," failures");quit(0 if ok else 1)
