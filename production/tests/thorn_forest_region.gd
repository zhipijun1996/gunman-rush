extends SceneTree
## Walkable map mouths, physical landings and the two forest movement cycles.
var catalog := WorldContentCatalog.new()
var checks := 0
var failures := 0

class Storage extends WorldSaveService:
	func commit(_next: Dictionary, _revision: int) -> bool: return true
	func load_profile() -> Dictionary: return {"accepted":true,"revision":0,"payload":{}}

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, details: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL forest ",details)

func frames(count: int) -> void:
	for i: int in count: await physics_frame

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"catalog")
	var count := 0
	for file: String in DirAccess.get_files_at("res://rooms/world"):
		if not file.begins_with("F") or not file.ends_with(".json"): continue
		var doc := WorldRoomDocument.read("res://rooms/world/"+file)
		count += 1
		check(WorldContentRoomBridge.check_passages(doc,catalog,true).ok,file+" authoritative opening")
		var session := OrdinaryRoomSession.new()
		root.add_child(session)
		var error := session.open(doc,Storage.new(),null,catalog)
		check(error.is_empty(),file+" open "+error)
		if not error.is_empty():
			session.free()
			continue
		await frames(6)
		var body := session.player.get_node("CollisionShape2D") as CollisionShape2D
		var space := session.player.get_world_2d().direct_space_state
		for edge: String in doc.exits:
			var gate: Dictionary = doc.exits[edge]
			var arrival := await WorldPassage.validate_landing(session,doc,gate,FixedWorldProvider.point(gate.point),session.player)
			check(arrival.is_empty(),file+" terrain passage "+edge+" "+arrival)
			check(WorldPassage.supported(space,FixedWorldProvider.point(gate.spawn),body,session.player.collision_mask),file+" landing "+edge)
		for id: String in doc.sites:
			var at := FixedWorldProvider.point(doc.sites[id].at)
			check(WorldPassage.supported(space,at,body,session.player.collision_mask),file+" supported interaction "+id)
		for id: String in session.room.enemies:
			var actor: EnemyActor = session.room.enemies[id]
			if actor.attack_behavior is ForestCrossbranchBehavior:
				var movement := actor.attack_behavior as ForestCrossbranchBehavior
				check(movement.shores.size()==2,file+" two authored shores")
				await frames(279)
				check(movement.current_shore==1,file+" migrated onto real secondary ground "+str(movement.state))
		await session.audio_service.shutdown()
		session.free()
		await frames(2)
	check(count==20,"all twenty forest rooms")
	print("THORN FOREST REGION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
