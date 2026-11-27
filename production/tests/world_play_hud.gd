extends SceneTree
## Observe the shipped HUD through room changes, both map inputs and live resources.
class Pilot extends WorldGameHost:
	func startup_destination() -> Dictionary: return {"ok":true,"room":"P01"}

var host := Pilot.new()
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func tick(n:=4) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL HUD ",label)
func shot(tag: String) -> void:
	var directory:=OS.get_environment("WORLD_HUD_CAPTURE")
	if directory.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(tag+".png"))
func click(where: Vector2) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=where
	root.push_input(motion,true)
	for down: bool in [true,false]:
		var button:=InputEventMouseButton.new()
		button.position=where;button.button_index=MOUSE_BUTTON_LEFT;button.pressed=down
		root.push_input(button,true)
func run() -> void:
	root.add_child(host)
	await tick(130)
	var hud:=host.game_hud
	var session:=host.active
	check(hud.visible and hud.session==session,"active session")
	check(hud.portrait.texture!=null and hud.hearts.capacity==session.controller.actor_resources.health.capacity,"portrait and real hearts")
	check(not hud.skill_text.visible and not hud.guard_icon.visible,"new character has no advanced prompts")
	check(hud.map_card.map.known_rooms().keys()==["P01"],"unexplored routes hidden")
	var hp:=session.controller.actor_resources.health
	hp.apply_damage(ActorResourceRequest.new(&"hud-hit",hp.epoch,1,hp.get_instance_id()))
	session.controller.combat_energy.grant("hud-charge",18)
	var candidate:=session.services.earned_candidate(session.state.candidate(),"hud-purse",37)
	candidate.flags.append_array(["gun","intro_active_skill","D","H","Q"])
	check(session.state.commit(candidate,session.state.revision),"progress transaction accepted")
	await tick(6)
	check(hud.hearts.current==hp.current and hud.hearts.current<hud.hearts.capacity,"damage updates real hearts")
	check(hud.resonance.current==session.controller.combat_energy.current and hud.resonance.capacity==session.controller.combat_energy.capacity(),"official resonance meter")
	check(hud.money.text=="金币  37","committed currency")
	check(hud.skill_text.visible and hud.skill_text.text.contains("Q") and hud.skill_text.text.contains("共鸣脉冲"),"earned keyboard pulse prompt")
	check(hud.guard_icon.visible and hud.hook_icon.visible,"earned guard and hook")
	await shot("play-desktop")
	click(hud.map_card.get_global_rect().get_center())
	await tick()
	check(host.route_map.visible and paused and not hud.visible,"normal pointer opens map and suspends HUD")
	await shot("expanded-map")
	host.route_map.close()
	await tick()
	check(not paused and hud.visible,"map returns to gameplay")
	var old_state:=session.state
	host.enter_room("P02","d001")
	await tick(8)
	check(hud.session==host.active and hud.location.text.contains("风铃平原") and hud.location.text.contains(str(host.catalog.lookup("rooms","P02").row.name)),"context rebound")
	check(not old_state.committed.is_connected(hud._world_changed) or old_state==host.active.state,"departed room released")
	check(host.find_children("PlayHud","CanvasLayer",true,false).size()==1,"one HUD after transition")
	check(hud.map_card.map.known_rooms().has("P02") and not hud.map_card.map.known_rooms().has("P16"),"map adds visit without undiscovered niche")
	var touch:=preload("res://tests/plains_touch_driver.gd").new()
	touch.attach(host.active)
	await tick()
	check(hud.map_card.get_global_rect().is_equal_approx(host.active.touch_controls.map_button),"touch map rectangle")
	check(not hud.map_card.get_global_rect().intersects(host.active.touch_controls.pause_button),"pause reservation")
	check(not hud.rows.get_global_rect().intersects(hud.map_card.get_global_rect()) and not hud.skill_text.visible,"phone layout and device-specific hints")
	var location_rect:=hud.location.get_global_rect()
	check(location_rect.position.x>host.active.touch_controls.left_center.x+host.active.touch_controls.radius,"location clears movement pad")
	check(not location_rect.intersects(host.active.touch_controls.healing_button),"location clears the original healing control")
	var label_center := hud.location.get_global_rect().get_center()
	touch.finger(touch.MOVE,label_center,true)
	await tick()
	check(not hud.location.visible,"location clears floating stick when planted over its label")
	touch.lift(touch.MOVE)
	await tick()
	check(hud.location.visible,"location returns when floating stick lifts")
	await shot("play-touch")
	touch.tap(host.active.touch_controls.map_button.get_center())
	await tick()
	check(paused and host.route_map.visible and not hud.visible,"viewport finger opens map once")
	touch.tap(host.route_map.close_button.get_global_rect().get_center());await tick()
	check(not paused and not host.route_map.visible and hud.visible,"viewport finger closes map")
	hud.set_overlay_hidden(true);await tick()
	check(not hud.visible,"shell can suppress HUD")
	hud.set_overlay_hidden(false);await tick()
	check(hud.visible,"shell can restore HUD")
	paused=true;host.route_map.open(true);host.route_map.close()
	check(paused,"return to preexisting pause")
	paused=false
	await host.active.audio_service.shutdown()
	host.free()
	print("WORLD PLAY HUD failures=",failures," checks=",checks)
	quit(1 if failures else 0)
