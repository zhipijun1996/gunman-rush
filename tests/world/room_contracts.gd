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
	for i: int in 80:
		await physics_frame
		if not app.busy: return
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://room_interface_test.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app)
	app.start_new();await settle()
	var candidate:=app.state.value.duplicate(true)
	candidate.flags.append_array(["intro_move","intro_shoot","intro_complete","station_briefed"])
	app.state.commit(candidate,app.state.revision)
	var player_id:=app.player.get_instance_id()
	for id: String in app.content.data.rooms:
		var contract:=app.content.room(id)
		for entry: Dictionary in contract.doors:
			if app.content.room(entry.target_room).is_empty(): continue
			app.load_room(id,entry.id);await settle();await ticks(3)
			check(app.room.room_id==id and app.player.is_on_floor(),id+"/"+str(entry.id)+" physical entry supported")
			check(app.player.position.distance_to(FixedWorldProvider.point(entry.landing_contract.safe_standing_position_world_units))<4,"entry settles locally without forced room-wide leap")
			check(app.player.get_instance_id()==player_id,"paired entry preserves player instance")
			for blocked: Dictionary in app.room.doors:
				if app.content.room(blocked.target_room).is_empty(): check(not app.room.door_open.get(blocked.id,true),"unbuilt target has visible closed barrier")
		var placements: Dictionary={}
		for npc: Node in app.room.find_children("*","WorldNpc",true,false):
			check(not placements.has(npc.npc_id),"unique authored NPC placement")
			placements[npc.npc_id]=true
			check(not app._npc(npc.npc_id).is_empty() and app._npc(npc.npc_id).room_id==id,"NPC binding matches canonical room")
		if not app.room.boss_identity.is_empty():
			check(app.content.action(app.room.defeat_action).get("room_id")==id and app.content.action(app.room.reward_action).get("room_id")==id,"Boss-owned binding references real room actions")
	app.queue_free();await ticks(5)
	print("WORLD ROOMS: %d assertions, %d failures" % [checks,failures]);quit(failures)
