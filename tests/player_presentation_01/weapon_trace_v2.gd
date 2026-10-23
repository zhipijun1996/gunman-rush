extends SceneTree
## Original Home/Motor,explicit added stationary training targets and dev equips.
## No actor placement,HP/resource/tuning/grant injection;skills earn real damage.
var app: PlayerWeaponFeelPreview
var actor: PlayerMotor
var controller: PlayerController
var rows: Array[Dictionary] = []
var accepted: Array[Dictionary] = []
var errors: Array[String] = []
var checks := 0
var output := ""
var capture := false
var candidate := true
var comprehensive := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg=="--candidate=off": candidate=false
		if arg=="--capture": capture=true
		if arg=="--comprehensive": comprehensive=true
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks+=1
	if not value: errors.append(label)

func frames(count: int) -> void:
	for unused: int in count:
		if capture: await RenderingServer.frame_post_draw
		else: await process_frame
		await physics_frame
		var ability := controller.shoot_ability
		var runtime := ability.runtime
		var projectiles: Array[Dictionary] = []
		for item: PlayerProjectile in ability._projectiles:
			if is_instance_valid(item) and not item.spent:
				projectiles.append({"id":item.shot_id,"position":[item.position.x,item.position.y],"direction":[item.direction.x,item.direction.y],"age":item._age,"launch":[item.launch_motion.x,item.launch_motion.y],"radius":item.radius,"speed":item.speed,"damage":item.damage,"life":item.lifetime,"skill":item.skill_attack})
		var entities: Array[Dictionary] = []
		for item: WeaponEntity in runtime.entities:
			if is_instance_valid(item) and not item.spent: entities.append({"id":item.serial,"kind":item.kind,"phase":item.phase,"position":[item.position.x,item.position.y],"age":item.age,"direction":[item.direction.x,item.direction.y],"skill":item.skill})
		var muzzle := (actor.get_node("CourierVisual") as CourierVisual).visible_muzzle_position()
		rows.append({"sample":rows.size(),"tick":Engine.get_physics_frames(),"draw_counter":Engine.get_frames_drawn(),"position":[actor.position.x,actor.position.y],"velocity":[actor.velocity.x,actor.velocity.y],"normal":[actor.normal_velocity.x,actor.normal_velocity.y],"recoil":[actor.recoil_velocity.x,actor.recoil_velocity.y],"motion_steps":actor.motion_steps,"hp":controller.actor_resources.health.current,"stamina":controller.actor_resources.stamina.current,"combat":controller.combat_energy.current,"charges":controller.action_resources.shot_charges,"used_jumps":controller.jump_ability.used_jumps,"muzzle":[muzzle.x,muzzle.y],"aim":[controller.router.aim_direction.x,controller.router.aim_direction.y],"camera":[app.home_scene.camera.position.x,app.home_scene.camera.position.y],"camera_offset":[app.home_scene.camera.offset.x,app.home_scene.camera.offset.y],"body":app.motion_visual.animation_state,"weapon":ability.weapon.id,"epoch":ability.weapon_epoch,"packet":ability.packet_id,"rounds":ability.rounds_remaining,"cooldown":ability.cooldown_remaining,"phase":runtime.phase,"runtime_age":runtime.age,"beam":[[runtime._beam_start.x,runtime._beam_start.y],[runtime._beam_point.x,runtime._beam_point.y]],"projectiles":projectiles,"entities":entities,"targets":app.training_targets.map(func(t:Damageable)->float:return t.health),"weapon_fx":app.weapon_feel.effects.size(),"voice_count":app.weapon_audio._voices.size(),"sustained_voices":active_sustains()})
		check(app.weapon_audio._voices.size()==12,"shared twelve voices")
		check(app.weapon_feel.effects.size()<=app.weapon_feel.profile.transient_cap,"bounded cosmetic effects")
		check(app.weapon_feel._seen_entities.size()<=entities.size(),"retired entity identities do not accumulate")
		if rows.size()>6500: errors.append("bounded route exceeded6500");return

func active_sustains() -> int:
	var count := 0
	for voice: AudioStreamPlayer in app.weapon_audio._voices:
		if voice.playing and bool(voice.get_meta("weapon_sustained",false)) and str(voice.get_meta("cue_id","")).begins_with("weapon_"): count+=1
	return count

func walk_to(x: float) -> void:
	controller.router.activate_device(&"gamepad")
	controller.router.set_aim(&"gamepad",Vector2.RIGHT,false)
	for unused: int in 180:
		if absf(actor.position.x-x)<4: break
		controller.router.set_move_axis(signf(x-actor.position.x))
		await frames(1)
	controller.router.set_move_axis(0)
	await frames(3)
	check(absf(actor.position.x-x)<9,"real walk reaches training distance")

func primary(index: int) -> void:
	app.select_weapon(index)
	await frames(3)
	await walk_to(240)
	var ability := controller.shoot_ability
	var before := app.training_targets[0].health
	controller.router.set_aim(&"gamepad",Vector2.RIGHT,ability.weapon.mode==WeaponDefinition.Mode.LASER)
	if ability.weapon.mode!=WeaponDefinition.Mode.LASER: controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await frames(42)
	controller.router.set_aim(&"gamepad",Vector2.RIGHT,false)
	if ability.weapon.mode==WeaponDefinition.Mode.BOOMERANG: controller.router.request_action(&"weapon_context")
	await frames(330 if ability.weapon.mode==WeaponDefinition.Mode.MINE else 34)
	check(app.training_targets[0].health<before,"real committed primary damage "+String(ability.weapon.id))
	check(controller.actor_resources.health.current==5,"safe actual Home hero HP preserved")

func earn_skill(index: int) -> void:
	var definition := WeaponCatalog.get_loadout(index)
	app.select_weapon(0)
	for unused: int in 40:
		if controller.combat_energy.current>=definition.skill_cost: break
		await walk_to(240)
		controller.router.request_action(&"shoot_release",Vector2.RIGHT)
		await frames(24)
	check(controller.combat_energy.current>=definition.skill_cost,"skill energy earned from actual hits "+String(definition.id))
	app.select_weapon(index)
	await walk_to(240)
	var before := app.training_targets[0].health
	var energy := controller.combat_energy.current
	controller.router.request_action(&"weapon_skill",Vector2.RIGHT)
	await frames(45)
	if definition.mode in [WeaponDefinition.Mode.BOOMERANG,WeaponDefinition.Mode.MINE]: controller.router.request_action(&"weapon_context")
	await frames(45)
	check(app.training_targets[0].health<before,"actual accepted skill damage "+String(definition.id))
	check(controller.combat_energy.current<=energy-definition.skill_cost,"skill paid and did not self-charge")

func run() -> void:
	root.size=Vector2i(1280,720)
	if output.is_empty() or FileAccess.file_exists(output): quit(1);return
	app=preload("res://scenes/dev/player_presentation_01/weapon_feel_v2.tscn").instantiate()
	app.weapon_enabled=candidate
	root.add_child(app)
	for unused: int in 150:
		await physics_frame
		if is_instance_valid(app.weapon_feel): break
	check(is_instance_valid(app.weapon_feel),"actual Home hero weapon consumer ready")
	if not is_instance_valid(app.weapon_feel): await finish();return
	actor=app.home_scene.player
	controller=app.home_scene.controller
	controller.router.activate_device(&"gamepad")
	controller.shoot_ability.shot_fired.connect(func(axis:Vector2,serial:int)->void:accepted.append({"type":"shot","sample":rows.size(),"serial":serial,"axis":[axis.x,axis.y]}))
	controller.shoot_ability.runtime.blast_fired.connect(func(point:Vector2)->void:accepted.append({"type":"blast","sample":rows.size(),"point":[point.x,point.y]}))
	controller.shoot_ability.runtime.phase_changed.connect(func(value:StringName)->void:accepted.append({"type":"phase","sample":rows.size(),"value":value}))
	await frames(20)
	var indices: Array[int]=[0,3,4,1,5,6,2,7,8]
	if comprehensive: indices.assign(range(15))
	for index: int in indices: await primary(index)
	if comprehensive:
		for index: int in range(9,15): await earn_skill(index)
	controller.router.clear("weapon_trace_done")
	await frames(15)
	check(not candidate or int(app.weapon_audio.played.get(&"weapon_pulse",0))>0,"new pulse voice observed")
	check(not candidate or int(app.weapon_audio.played.get(&"weapon_blade",0))>0,"new blade voice observed")
	check(not candidate or int(app.weapon_audio.played.get(&"weapon_blast",0))>0,"new blast voice observed")
	await finish()

func finish() -> void:
	var report := {"checks":checks,"errors":errors,"rows":rows,"events":accepted,"candidate":candidate,"comprehensive":comprehensive,"scope":"Actual original Home player and geometry,added explicit stationary training targets,dev loadout selection;real Router/Motor/contacts/resources;skills only earned actual combat damage;bothON/OFF include newly authorized6s mine fuse;not formal grants/encounters/user/device acceptance","audio_events":app.weapon_audio.weapon_events if is_instance_valid(app) else [],"weapon_audio_dropped":app.weapon_audio.weapon_dropped,"weapon_audio_preemptions":app.weapon_audio.weapon_preemptions}
	if is_instance_valid(app):
		check(await load("res://tests/audio_teardown.gd").drain_world(app),"audio playback weakrefs released")
		app.free()
	report["checks"]=checks
	report["errors"]=errors
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for unused: int in 4: await process_frame
	for error: String in errors: printerr(error)
	print("WEAPON V2 TRACE: samples=",rows.size()," checks=",checks," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)
