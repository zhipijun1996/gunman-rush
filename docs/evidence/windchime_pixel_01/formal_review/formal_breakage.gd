extends SceneTree
var checks:=0
var failures:Array[String]=[]
func _init()->void:_run.call_deferred()
func check(ok:bool,msg:String)->void:
	checks+=1
	if not ok:failures.append(msg);printerr("FAIL: "+msg)
func floating(stage:PlainsRegionStage)->Array:
	var rows:Array=[]
	var scenery:=stage.get_node("PixelRegionScenery") as PixelRegionScenery
	for item:Dictionary in scenery.placements:
		var point:Vector2=item.position
		var ray:=PhysicsRayQueryParameters2D.create(point-Vector2(0,1),point+Vector2(0,3),1)
		var hit:=stage.get_world_2d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():rows.append({"root":str(point),"kind":item.kind,"bounds":str(item.bounds)})
	return rows
func _run()->void:
	var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	check(app.start_plains("level-design-v2-baseline/08"),"normal actual start for explicit geometry fixture")
	for i:int in 10:await physics_frame
	# Explicit second-map setup, not campaign traversal.
	app.director.stage_index=2;app._load_stage()
	for i:int in 10:await physics_frame
	var stage:=app.stage as PlainsRegionStage
	var before:=floating(stage)
	check(before.is_empty(),"initial actual decoration roots have actual physical support")
	var encounter:=stage.boss.get_node("Encounter") as WindkeeperEncounter
	var arena:WindkeeperArena
	for child:Node in encounter.get_children():
		if child is WindkeeperArena:arena=child
	check(arena!=null,"actual Boss arena breakage consumer installed")
	var old_art:=stage.terrain_art.art.get_instance_id()
	var old_piece_count:=stage.terrain_art.art.get_child_count()
	# Explicit phase fixture exercises the production committed breakage callback;
	# no victory, damage application or physical itinerary is claimed.
	encounter.stage_phase=3;encounter.phase_changed.emit(3)
	for i:int in 30:await physics_frame
	check(arena.broken,"actual production bridge break callback executed")
	check(stage.terrain_art.art.get_instance_id()!=old_art,"actual terrain observer rebuilt after committed breakage")
	var after:=floating(stage)
	check(after.is_empty(),"decoration remains grounded after actual Boss bridge breakage: "+str(after))
	var scenery:=stage.get_node("PixelRegionScenery") as PixelRegionScenery
	var placements:=scenery.placements.duplicate(true)
	scenery.configure(stage)
	check(scenery.placements==placements,"repeat configure is deterministic and cannot duplicate props")
	scenery.configure(stage)
	check(scenery.placements==placements,"second configure remains idempotent")
	var refreshed_piece_count:=stage.terrain_art.art.get_child_count()
	app._load_stage()
	for i:int in 30:await physics_frame
	stage=app.stage as PlainsRegionStage
	check((stage.boss.get_node("Encounter") as WindkeeperEncounter).stage_phase==3,"actual reload restores broken Boss phase")
	var restored_floating:=floating(stage)
	check(restored_floating.is_empty(),"reloaded broken geometry has no floating decoration")
	check(stage.terrain_art.art.get_child_count()==refreshed_piece_count,"reload restores same terrain presentation geometry")
	var file:=FileAccess.open("res://build/pixel-review/formal_breakage.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"explicit second-map phase/geometry lifecycle fixture; not Boss gameplay or campaign route","checks":checks,"failures":failures,"floating_before":before,"floating_after":after,"floating_after_reload":restored_floating,"old_piece_count":old_piece_count,"new_piece_count":stage.terrain_art.art.get_child_count()},"  "))
	check(await load("res://tests/audio_teardown.gd").drain_world(app),"actual audio drains")
	app.free()
	for i:int in 10:await process_frame
	print("PIXEL_FORMAL_BREAKAGE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
