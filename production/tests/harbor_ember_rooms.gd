extends "res://tests/machine_bosses.gd"
## Check both regions against the real physics space. Body and arrival probes
## resolve the same collision mask used by the production passage host.
var measured_rooms := 0
var arrival_points := 0

func inspect_room(id: String) -> void:
	var doc:=WorldRoomDocument.read("res://rooms/world/"+id+".json")
	var s:=OrdinaryRoomSession.new()
	root.add_child(s)
	var err:=s.open(doc,null,null,catalog)
	check(err.is_empty(),id+" "+err)
	if err.is_empty():
		measured_rooms+=1
		await frames(3)
		var collision:=s.player.get_node("CollisionShape2D") as CollisionShape2D
		var space:=s.room.get_world_2d().direct_space_state
		for link: Dictionary in catalog.connections(id).rows:
			var p: Vector2
			if link.connection_type=="physical": p=FixedWorldProvider.point(doc.exits[link.id].spawn)
			elif link.connection_type=="interior": p=FixedWorldProvider.point(doc.sites[link.id].at)
			else: continue
			arrival_points+=1
			check(WorldPassage.supported(space,p,collision,s.player.collision_mask),id+"/"+link.id+" unstable landing at "+str(p))
		for key: String in doc.sites:
			var p:=FixedWorldProvider.point(doc.sites[key].at)
			check(WorldPassage.supported(space,p,collision,s.player.collision_mask),id+"/"+key+" unsupported content or handle at "+str(p))
		if s.audio_service!=null: await s.audio_service.shutdown()
	s.free()
	await frames(2)

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"regional registry and world")
	for file: String in DirAccess.get_files_at("res://rooms/world"):
		if not file.ends_with(".json") or not (file.begins_with("E") or file.begins_with("R")): continue
		await inspect_room(file.get_basename())
	check(measured_rooms==47,"26 harbor and 21 ember actual rooms")
	await exercise("R20","harbor_warden","harbor_warden")
	await exercise("E09","thermal_bell_keeper","thermal_bell_keeper")
	print("HARBOR EMBER ROOMS failures=",failures," checks=",checks," rooms=",measured_rooms," arrivals=",arrival_points)
	quit(1 if failures else 0)
