extends "res://tests/world/plains35_fixture.gd"
## Actual static support, including both sides of each base; a passing lift is not ground.
func supported(foot: Vector2, half_width: float, label: String) -> void:
	for offset:float in [-half_width,0.0,half_width]:
		var point:=foot+Vector2(offset,0)
		var query:=PhysicsRayQueryParameters2D.create(point-Vector2(0,8),point+Vector2(0,8),1)
		var hit:=app.player.get_world_2d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.collider is StaticBody2D and not hit.collider is AnimatableBody2D,label+" static support at "+str(point))

func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://station_grounding_test.json";root.add_child(app)
	await app.review.begin("P-R01","","base");await ticks(5)
	for npc:Node in app.room.find_children("*","WorldNpc",true,false):
		supported(npc.position+Vector2(0,18),18,npc.npc_id)
	var altar:=app.room.get_node("RiftStation")
	supported(altar.position+Vector2(0,18),54,"rift base")
	for placement:Dictionary in app.room.art_placements:
		var widths:Dictionary={"waiting_shelter":112,"merchant_counter":43,"storage_crates":41,"hanging_chime":36,"gear_lamp":21}
		supported(FixedWorldProvider.point(placement.point),float(widths[placement.asset]),placement.asset)
	supported(FixedWorldProvider.point(app.room.story_sequence.npc_point)+Vector2(0,18),18,"arrival speaker")
	supported(FixedWorldProvider.point(app.room.story_sequence.blocking_point)+Vector2(0,18),18,"north guard")
	supported(app.room.traveler_point+Vector2(0,18),18,"traveler host")
	for sign:Dictionary in app.room.signs:
		supported((sign.interaction_point as Vector2)+Vector2(0,18),22,"notice board")
	for id:String in ["Npc0","Npc1"]:
		var npc:=app.room.get_node(id) as WorldNpc
		await fixture(npc.position-Vector2(32,3));await ticks(5)
		check(app.player.is_on_floor() and app.context_target().get("id")==npc.npc_id,"supported player can interact with "+npc.npc_id)
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
	print("STATION GROUNDING: ",failures," failures");quit(failures)
