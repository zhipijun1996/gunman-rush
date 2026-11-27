extends SceneTree

class Storage extends WorldSaveService:
	var data: Dictionary
	var seq:=0
	var writable:=true
	func commit(payload: Dictionary, next: int) -> bool:
		if not writable: return false
		data=payload.duplicate(true)
		seq=next
		return true
	func load_profile() -> Dictionary: return {"accepted":true,"payload":data.duplicate(true),"revision":seq}

var catalog:=WorldContentCatalog.new()
var storage:=Storage.new()
var s: OrdinaryRoomSession
var checks:=0
var failures:=0

func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL workshop ",label)

func enter(id: String) -> bool:
	var before:=s
	s=OrdinaryRoomSession.new()
	root.add_child(s)
	var err:=s.open(preload("service_chamber.gd").document(id),storage if before==null else null,before,catalog)
	check(err.is_empty(),"service chamber "+id+" "+err)
	await frames(4)
	return err.is_empty()

func stock(flags: Array, inventory: Dictionary) -> void:
	var next:=s.state.candidate()
	for id: String in flags:
		if id not in next.flags: next.flags.append(id)
	for key: String in inventory: next.inventory[key]=inventory[key]
	check(s.state.commit(next,s.state.revision),"travel fixture previous flags/materials")

func stand(id: String) -> void:
	s.player.reset_at(s.content_sites.positions[id])
	await frames(8)
	check(s.content_sites.near(id),"standing at "+id)

func install(id: String, recipe: String) -> bool:
	return WorldWeaponWorkshop.install(s.content_sites,id,recipe,s.state.revision)

func close_room() -> void:
	await s.audio_service.shutdown()
	s.free()
	s=null
	await frames(3)

func laser_budget() -> void:
	storage=Storage.new()
	if not await enter("P18"): return
	stock(["branch_laser"],{})
	check(s.select_world_weapon("sustained_laser",s.state.revision),"restore unlocked finite laser")
	var target: EnemyActor=s.room.enemies.floor_tuning_dummy
	s.player.reset_at(Vector2(613,375))
	await frames(8)
	var controller:=s.controller
	var router:=controller.router
	var holder:=controller.shoot_ability
	var aim:=Vector2.RIGHT
	router.activate_device(&"keyboard_mouse")
	router.set_aim(&"keyboard_mouse",aim,true)
	check(holder.try_fire(aim,true),"start finite laser from ordinary controller")
	var amounts: Array[float]=[]
	target.damageable.damaged.connect(func(context: Dictionary): amounts.append(context.amount))
	for tick in 110:
		await physics_frame
		if holder.behavior().phase!=&"beam": break
		var body:=s.player.get_node("CourierVisual") as CourierVisual
		aim=body.muzzle_position(Vector2.RIGHT).direction_to(target.motor.global_position)
		router.set_aim(&"keyboard_mouse",aim,true)
	await frames(3)
	var total:=0.0
	for amount in amounts: total+=amount
	check(holder.behavior().phase==&"idle" and amounts.size()==5 and is_equal_approx(total,7.5),"five finite laser hits total 1.5B, actual "+str(amounts))
	check(not holder.try_fire(aim,true),"holding the ended beam cannot restart it")
	router.set_aim(&"keyboard_mouse",aim,false)
	await close_room()

func surviving_ground_hit() -> void:
	storage=Storage.new()
	if not await enter("R02"): return
	var target: EnemyActor=s.room.enemies.patrol_2
	s.player.reset_at(Vector2(1360,464))
	await frames(8)
	var before:=target.health.current
	var ordinary_damage:=s.player.tuning.projectile_damage
	var initial_y:=target.motor.position.y
	var knocked_back:=false
	s.controller.router.request_action(&"shoot_release",Vector2.LEFT)
	for tick in 40:
		var initial_x:=target.motor.position.x
		await frames(1)
		if target.health.current>=before: continue
		if -target.motor.velocity.x>target.definition.patrol_speed and target.motor.position.x<initial_x and target.motor.supported_at(target.motor.position):
			knocked_back=true
	check(before>ordinary_damage and not target.health.terminal and is_equal_approx(before-target.health.current,ordinary_damage),"single starting shot applies exactly B to the living R02 old harbor guard")
	check(knocked_back and absf(target.motor.position.y-initial_y)<1,"surviving ground guard is displaced along the quay faster than its ordinary patrol")
	await close_room()

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"immutable world")
	if not await enter("G08"): quit(1); return
	await stand("smith")
	check(not s.content_sites.claim("smith",s.state.revision),"requires the actual wall device")
	stock(["W"],{})
	check(s.content_sites.claim("smith",s.state.revision),"smith from the legal G08 catwalk before G12")
	s.controller.router.request_action(&"interact")
	await frames(3)
	check(s.content_sites.menu.visible_panel() and s.content_sites.menu.heading.text=="武器工坊","active world input enters G08 workshop")
	s.content_sites.menu.close()
	check(not install("smith","install_attack_1"),"insufficient materials")
	var malformed:=s.state.candidate()
	malformed.inventory.attack_rank=15
	check(not s.state.commit(malformed,s.state.revision),"reject an out-of-contract saved attack rank before equipping")
	check(s.player.tuning.projectile_damage==5,"base attack package from current growth")

	# One actual optional-end chamber awards the sky core. No fictitious root-first prerequisite.
	if not await enter("A06"): quit(1); return
	stock(["H","D"],{})
	await stand("wr_A06_primary")
	check(s.content_sites.claim("wr_A06_primary",s.state.revision),"A06 sky core received")
	check(not s.state.has("skill_tier_1") and s.state.value.inventory.get("skill_core")==1,"picking up the chip does not install it")
	if not await enter("G12"): quit(1); return
	var smith:="npc20_workshop"
	await stand(smith)
	var ticket:=s.state.revision
	storage.writable=false
	check(not install(smith,"install_skill_1") and s.state.value.inventory.skill_core==1 and not s.state.has("skill_tier_1"),"unwritable slot keeps chip, ability and price")
	storage.writable=true
	check(install(smith,"install_skill_1") and s.state.has("skill_tier_1"),"first installed core can come from sky")
	check(not WorldWeaponWorkshop.install(s.content_sites,smith,"install_skill_1",ticket),"duplicate UI ticket cannot replay installation")
	check(s.controller.shoot_ability.behavior().skill_definition()==WeaponActionRuntime.ICE,"first tier activates integrated ice shot")
	s.controller.combat_energy.current=s.controller.combat_energy.capacity()
	s.controller.router.request_action(&"weapon_skill",Vector2.RIGHT)
	await frames(3)
	check(s.controller.shoot_ability.behavior().phase==&"shared_ice" and s.controller.combat_energy.current<s.controller.combat_energy.capacity(),"actual skill input commits shared ice cost and starts windup")
	await frames(20)
	var needles:=s.controller.shoot_ability.get_projectiles()
	check(not needles.is_empty() and needles[0].skill_attack and needles[0].chill_seconds>0 and is_equal_approx(needles[0].damage,15),"actual frozen skill deals 3B and carries chill")
	stock([],{"attack_alloy":8,"part_triple":1,"part_laser":1,"part_fan":1,"part_boomerang":1,"part_magnetic":1,"part_singularity":1})
	await stand(smith)
	check(not install(smith,"forge_fan"),"a blueprint does not grant an unowned weapon")
	for rank in range(1,5):
		check(install(smith,"install_attack_"+str(rank)),"install locked rank "+str(rank))
	check(s.state.value.inventory.attack_alloy==0 and s.player.tuning.projectile_damage==21 and not install(smith,"install_attack_5"),"full 8-alloy curve terminates at 21")
	check(install(smith,"forge_triple") and install(smith,"forge_laser"),"two independently forged choices for gun")
	check(s.select_world_weapon("triple_machine_gun",s.state.revision) and s.controller.shoot_ability.weapon.tier==2,"select forged primary")
	await frames(120)
	var rounds: Array=[]
	var tap:=func(_direction: Vector2,_packet: int):
		var shots:=s.controller.shoot_ability.get_projectiles()
		if not shots.is_empty(): rounds.append(shots[-1].damage)
	s.controller.shoot_ability.shot_fired.connect(tap)
	check(s.controller.shoot_ability.try_fire(Vector2.LEFT,true),"live triple primary")
	await frames(22)
	check(rounds.size()==3 and is_equal_approx(rounds.reduce(func(sum,x): return sum+x,0.0),31.5),"three actual bullets total 1.5B with no rounding")
	s.controller.shoot_ability.shot_fired.disconnect(tap)
	if not await enter("M06"): quit(1); return
	stock(["encounter_M06_clear"],{})
	await stand("wr_T17_primary")
	check(s.content_sites.claim("wr_T17_primary",s.state.revision),"root chip received separately")
	if not await enter("Y11"): quit(1); return
	await stand("npc20_canyon")
	check(install("npc20_canyon","install_skill_2") and s.controller.shoot_ability.weapon.id==&"machine_storm","second workshop and equipped branch update immediately")
	check(not install("npc20_canyon","forge_fan"),"field workshop cannot forge unique branches")
	if not await enter("G12"): quit(1); return
	await stand(smith)
	stock(["B","weapon_shuriken"],{})
	for branch: Dictionary in s.weapon_growth.branch_upgrades:
		await stand(smith)
		if not s.state.has(branch.grant_flag): check(install(smith,branch.id),"forge "+branch.id)
		check(s.select_world_weapon(branch.branch,s.state.revision),"equip "+branch.branch)
		check(s.controller.shoot_ability.weapon==WorldWeaponWorkshop.ADVANCED[branch.branch],"both cores inherited by "+branch.branch)
		await frames(127)
		s.controller.combat_energy.current=s.controller.combat_energy.capacity()
		s.controller.router.request_action(&"weapon_skill",Vector2.LEFT)
		await frames(4)
		var action:=s.controller.shoot_ability.behavior()
		check(action.occupied() and action.skill_cooldown>0 and s.controller.combat_energy.current<s.controller.combat_energy.capacity(),"real weapon-specific skill consumes and starts "+branch.branch)
		check(s.select_world_weapon("gun",s.state.revision),"switch cancels "+branch.branch+" and returns to the workbench")
		await frames(30)
	await stand(smith)
	check(s.select_world_weapon("collapse_singularity",s.state.revision),"choose persistent active branch")
	check(not install(smith,"forge_fan"),"duplicate branch cannot reuse spent parts")
	check(s.checkpoint(),"commit current selection")
	await close_room()
	if not await enter("G12"): quit(1); return
	check(s.world_weapon_loadouts().size()==9 and s.controller.shoot_ability.weapon.id==&"star_collapse" and s.player.tuning.projectile_damage==21 and s.state.value.inventory.skill_core==0,"reload family, selected branch, damage and receipts")
	await close_room()
	await laser_budget()
	await surviving_ground_hit()
	print("WORLD WEAPON WORKSHOP failures=",failures," checks=",checks)
	quit(1 if failures else 0)
