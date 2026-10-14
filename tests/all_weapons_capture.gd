extends SceneTree
## Real shared input and damage. Practice resets label separate demonstrations.
var studio: ActionStudio
var index := -1
var stage: StringName = &"start"
var tick_index := 0
var total := 0
var trace: Array[Dictionary] = []
var screenshots: Array[int] = []
func _initialize() -> void:call_deferred("start")
func start() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/weapons")
	root.size=Vector2i(1280,720);root.add_child(GameAudio.new())
	studio=preload("res://scenes/demo/action_studio.tscn").instantiate();root.add_child(studio)
	# Explicit stationary-target demonstration; public practice defaults to patrol.
	studio.set_training_static(true)
	studio.controller.air_focus_ability.enabled=false
	physics_frame.connect(drive)
func next() -> void:
	index+=1;tick_index=0
	if index>=WeaponCatalog.IDS.size():finish.call_deferred();return
	var c := studio.controller
	studio.restart(4)
	var def := WeaponCatalog.get_loadout(index)
	if def.tier==3 and c.combat_energy.current<def.skill_cost:
		stage=&"earn";c.shoot_ability.equip(preload("res://resources/weapons/pulse_gun.tres"))
		c.router.activate_device(&"gamepad");c.router.set_move_axis(1)
	else:
		stage=&"show";c.shoot_ability.equip(def);c.router.activate_device(&"gamepad")
func drive() -> void:
	total+=1;tick_index+=1
	if stage==&"start":next();return
	if index>=WeaponCatalog.IDS.size():return
	var c := studio.controller;var def := WeaponCatalog.get_loadout(index)
	if stage==&"earn":
		c.router.set_aim(&"gamepad",Vector2.RIGHT)
		c.router.set_move_axis(1 if c.motor.position.x<145 else 0)
		if c.motor.is_on_floor() and c.motor.position.x>=145 and c.shoot_ability.cooldown_remaining<=0 and c.shot_energy.can_fire():c.router.request_action(&"shoot_release",Vector2.RIGHT)
		if c.combat_energy.current>=def.skill_cost:
			studio.restart(4);c.shoot_ability.equip(def);c.router.activate_device(&"gamepad");stage=&"show";tick_index=0
		elif tick_index>600:
			push_error("Real combat charge failed: %s combat=%s stamina=%s hp=%s position=%s active=%s" % [def.id,c.combat_energy.current,c.actor_resources.stamina.current,c.actor_resources.health.current,c.motor.position,studio.lifetime.active]);quit(1);return
	else:
		if tick_index==1 and def.mode in [WeaponDefinition.Mode.BOMB,WeaponDefinition.Mode.MINE,WeaponDefinition.Mode.SINGULARITY]:c.router.set_move_axis(1)
		if tick_index==24:c.router.set_move_axis(0)
		c.router.set_aim(&"gamepad",Vector2.RIGHT,def.mode==WeaponDefinition.Mode.LASER and tick_index>=30 and tick_index<90)
		if tick_index==30:
			if def.tier==3:c.router.request_action(&"weapon_skill",Vector2.RIGHT)
			elif def.mode!=WeaponDefinition.Mode.LASER:c.router.request_action(&"shoot_release",Vector2.RIGHT)
		if tick_index==70 and def.mode in [WeaponDefinition.Mode.BOOMERANG,WeaponDefinition.Mode.MINE]:c.router.request_action(&"weapon_context")
		if tick_index in [34,45,60,77,92]:capture.call_deferred("%s-%03d" % [def.id,tick_index])
		if tick_index>=140:next()
	trace.append({"frame":total,"loadout":String(c.shoot_ability.weapon.id),"stage":String(stage),"phase":String(c.shoot_ability.behavior().phase),"visual":String((c.motor.get_node("CourierVisual") as CourierVisual).state),"position":[c.motor.position.x,c.motor.position.y],"energy":c.actor_resources.stamina.current,"combat":c.combat_energy.current,"health":c.actor_resources.health.current,"entities":c.shoot_ability.behavior().current_entities().size(),"training_hp":studio.training_actors.map(func(a: EnemyActor)->float:return a.health.current),"packet":c.shoot_ability.packet_id,"shots":c.action_resources.shot_charges,"motion_steps":c.motor.motion_steps})
	if total>8000:push_error("Capture failed bounded timeout");quit(1)
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapons/%s.png" % name)
func finish() -> void:
	physics_frame.disconnect(drive)
	var file := FileAccess.open("res://build/weapons/trace.json",FileAccess.WRITE);file.store_string(JSON.stringify({"scope":"shared real input and damage; labeled practice resets, actual pulse-gun earned combat energy before skills; not a whole run","trace":trace}));file.close()
	print("WEAPON MOVIE: ",total," ticks");studio.free();await process_frame;quit()
