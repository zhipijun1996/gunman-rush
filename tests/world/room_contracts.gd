extends SceneTree
## Qualified contract fixture: load every authored paired entry, independent of route progression.
var app: FixedWorldApp
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: ",label)
func ticks(n: int) -> void:
	for i: int in n: await physics_frame
func settle() -> void:
	for i: int in 240:
		await physics_frame
		if not app.busy: return
func interaction_supported(at:Vector2,safety:SegmentRespawn) -> bool:
	# Art/NPC pivots may embed three pixels into the ground. Validate the actual
	# nearby player standing center, not a player body placed at the art pivot.
	var query:=PhysicsRayQueryParameters2D.create(at+Vector2(0,10),at+Vector2(0,26),1)
	var hit:=app.player.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector2).y>-.8:return false
	return safety.is_safe((hit.position as Vector2)-Vector2(0,18))
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://room_interface_test.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app)
	app.start_new();await settle()
	var candidate:=app.state.value.duplicate(true)
	candidate.flags.append_array(["intro_gun","intro_move","intro_shoot","intro_complete","station_briefed"])
	app.state.commit(candidate,app.state.revision)
	var player_id:=app.player.get_instance_id()
	for id: String in app.content.data.rooms:
		if not OS.get_environment("WORLD_ROOM_FILTER").is_empty() and id!=OS.get_environment("WORLD_ROOM_FILTER"):continue
		app.load_room(id,"");await settle();await ticks(3)
		check(app.room.room_id==id and app.controller.active,id+" default spawn: "+app.status)
		var contract:=app.content.room(id)
		for entry: Dictionary in contract.doors:
			if app.content.room(entry.target_room).is_empty(): continue
			print("ENTRY ",id," ",entry.id)
			app.load_room(id,entry.id);await settle();await ticks(3)
			check(app.room.room_id==id and app.player.is_on_floor(),id+"/"+str(entry.id)+" physical entry supported: "+app.status)
			check(app.player.position.distance_to(FixedWorldProvider.point(entry.landing_contract.safe_standing_position_world_units))<4,id+"/"+str(entry.id)+" local landing actual="+str(app.player.position)+" expected="+str(entry.landing_contract.safe_standing_position_world_units)+" status="+app.status)
			check(app.player.get_instance_id()==player_id,"paired entry preserves player instance")
			var portal:=FixedWorldProvider.point(entry.position_candidate.local_world_units)
			if entry.direction=="up":
				check(absf(app.player.position.x-portal.x)<4,id+" upper entrance falls straight onto its safe floor")
				var supported_landing:=false
				for index: int in app.room.platforms.size():
					if app.room.platforms[index].has_point(app.player.position+Vector2(0,20)):supported_landing=true
				check(supported_landing,id+" upper entry lands on a real solid or one-way receiving platform")
			if entry.direction=="down":
				var shaft:=Rect2(portal-Vector2(52,128),Vector2(104,128))
				var clear:=true
				for index:int in app.room.platforms.size():
					if index not in app.room.one_way_indices and app.room.platforms[index].intersects(shaft):clear=false
				check(clear,id+" downward exit is an unobstructed hole")
			for blocked: Dictionary in app.room.doors:
				if app.content.room(blocked.target_room).is_empty(): check(not app.room.door_open.get(blocked.id,true),"unbuilt target has visible closed barrier")
		var safety:=SegmentRespawn.new();safety.configure(app.controller,app.lifetime)
		for host: WorldRoomInteraction in app.room.interaction_hosts:
			check(app.room.section_at(host.position)==host.section_id,id+" action physical section "+host.action_id)
			check(interaction_supported(host.position,safety),id+" safe interaction support "+host.action_id+" "+str(host.position))
		for retry: Dictionary in app.room.retry_anchors:
			check(safety.is_safe(FixedWorldProvider.point(retry.point)),id+" safe local retry "+str(retry.point))
		for hazard: Rect2 in app.room.hazards:
			for x: float in [hazard.position.x+2,hazard.get_center().x,hazard.end.x-2]:
				var supported:=false
				for platform: Rect2 in app.room.platforms:
					if platform.has_point(Vector2(x,hazard.end.y+1)):supported=true
				check(supported,id+" hazard rooted to physical surface")
		# Only an actual eligible traveler is a host; the NPC loop below checks it.
		var placements: Dictionary={}
		for npc: Node in app.room.find_children("*","WorldNpc",true,false):
			check(not placements.has(npc.npc_id),"unique authored NPC placement")
			placements[npc.npc_id]=true
			check(interaction_supported(npc.position,safety),id+" NPC has safe physical support "+npc.npc_id)
			check(not app._npc(npc.npc_id).is_empty() and app._npc(npc.npc_id).room_id==id,"NPC binding matches canonical room")
		if not app.room.boss_identity.is_empty():
			check(app.content.action(app.room.defeat_action).get("room_id")==id ,"Boss-owned binding references real room actions")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
	print("WORLD ROOMS: %d assertions, %d failures" % [checks,failures]);quit(failures)
