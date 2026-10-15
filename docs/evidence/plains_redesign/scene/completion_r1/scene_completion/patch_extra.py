from pathlib import Path
p=Path('scripts/art/plains_region_scenery.gd');s=p.read_text();s=s.replace('var id := str(area.get("landmark", ""))','var id := str(area.get("landmark", ""))\n\t\t# Ivy is a hanging asset, not a grounded shrub. Workshop vines attach\n\t\t# to the distant building; its foreground support gets a real cairn.\n\t\tif id == "ivy": id = "stones"');p.write_text(s)
p=Path('tests/plains_redesign_scene_runner.gd');s=p.read_text();s=s.replace('var current_issues: Array[String] = []','var current_issues: Array[String] = []\nvar elective_ascent := false\nvar elective_receipts: Array = []');s=s.replace('var viewport := Rect2(0,0,1280,720)','var viewport := Rect2(0,0,1280,720)');s=s.replace('var local: Vector2=app.player.global_position-module.global_position','var local: Vector2=app.player.global_position-module.global_position\n\t\tif elective_ascent:\n\t\t\trows.append({"id":"elective_distant_receiver","world":Rect2(module.global_position+Vector2(385,264),Vector2(100,36)),"mandatory":false})');s=s.replace('for region: Dictionary in regions:\n\t\t\tvar b: Array=region.bounds','for region: Dictionary in regions:\n\t\t\tif row.id=="elective_distant_receiver":continue # Recorded remote bank, explicitly not an all-ascent visibility claim.\n\t\t\tvar b: Array=region.bounds');s=s.replace('"scenery":scene_inventory(app.stage)})','"scenery":scene_inventory(app.stage),"elective_receipts":elective_receipts.duplicate(true)})');s=s.replace('current_issues=[]\n\tif mutation.is_empty():','current_issues=[]\n\telective_ascent=false\n\telective_receipts=[]\n\tif mutation.is_empty():')
s=s.replace('if ok and mode=="main_then_high":','if ok and mode=="extra_upward_recoil":\n\t\tok=await extra_upward_recoil(trace)\n\telif ok and mode=="main_then_high":')
s=s.replace('await run_case(2,"fast","outer_return")','await run_case(2,"fast","outer_return")\n\t\tawait run_case(1,"fast","extra_upward_recoil")')
insert='''
func extra_upward_recoil(trace) -> bool:
	var well: PlatformingModule
	for module: PlatformingModule in trace.stage.modules:
		if module.definition.module_id==&"plains_windchime_well":well=module;break
	if well==null:return false
	trace.current_edge="elective_extra_upward_recoil"
	if not await trace.move_to(well.position.x+265):return false
	trace.critical_traversal+=1
	var latch: ShotLatch=trace.shot_latch_encounter.for_module(well)
	var first_event:=trace.events.size()
	trace.controller.router.set_move_axis(1)
	trace.controller.router.request_action(&"jump")
	await trace.tick(14)
	trace.controller.router.request_action(&"shoot_release",(trace.motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(trace.motor.get_canvas_transform()*latch.bell_body.global_position))
	trace.controller.router.set_move_axis(0)
	await trace.tick(18)
	var second_tick: int=trace.trace_ticks+1
	elective_ascent=true
	# A second ordinary legal downward shot, with the real cooldown, charges,
	# energy and accepted events. No capability or resource injection.
	trace.controller.router.request_action(&"shoot_release",Vector2.DOWN)
	trace.controller.router.request_action(&"jump_release")
	var apex:=trace.motor.global_position.y
	var settled:=false
	for unused: int in 240:
		trace.controller.router.set_move_axis(clampf((well.position.x+430-trace.motor.global_position.x)/5.5,-1,1))
		await trace.tick()
		apex=minf(apex,trace.motor.global_position.y)
		if trace.motor.is_on_floor():settled=true;break
	trace.critical_traversal-=1
	var accepted: Array=[]
	for event: Dictionary in trace.events.slice(first_event):
		if event.kind=="shot_accepted":accepted.append(event)
	var scope:={"second_request_tick":second_tick,"accepted_shots":accepted,"apex_world_y":apex,"well_origin":pair(well.global_position),"settled":settled,"limitation":"Actor always mandatory. Distant old bank recorded throughout elective ascent but may leave finite view; canonical complete well arc remains separately mandatory."}
	elective_receipts.append(scope)
	check(accepted.size()==2 and accepted[1].tick>=second_tick,"elective second upward recoil uses two accepted real shots")
	check(apex<well.position.y-100,"elective actual ascent exceeds canonical well observation band")
	return settled and latch.is_open and await trace.move_to(well.world_exit().x)

'''
s=s.replace('func run() -> void:',insert+'func run() -> void:');p.write_text(s)
p=Path('tools/run_plains_redesign_scene_tests.py');s=p.read_text();s=s.replace('len(routes) != 5','len(routes) != 6').replace('actual five-route native contract','actual six-route native contract');s=s.replace('(2, "fast", "outer_return")}','(2, "fast", "outer_return"), (1, "fast", "extra_upward_recoil")}');s=s.replace('if any(rect_intersects(bounds, ui["bounds"]) for ui in frame.get("ui", [])):','if target["id"] != "elective_distant_receiver" and any(rect_intersects(bounds, ui["bounds"]) for ui in frame.get("ui", [])):');s=s.replace('manifest = case.get("manifest", {})','if case.get("custom") == "extra_upward_recoil":\n            receipts = case.get("elective_receipts", [])\n            if len(receipts) != 1 or len(receipts[0].get("accepted_shots", [])) != 2 or not receipts[0].get("settled") or receipts[0]["apex_world_y"] >= receipts[0]["well_origin"][1] - 100:\n                problems.append("missing legal actual extra upward recoil evidence")\n        manifest = case.get("manifest", {})');p.write_text(s)
