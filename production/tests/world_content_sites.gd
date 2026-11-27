extends SceneTree
var catalog:=WorldContentCatalog.new()
var failures:=0
var checks:=0

class Storage extends WorldSaveService:
	var writable:=true
	var saved:={}
	var revision:=0
	func commit(candidate: Dictionary, next_revision: int)->bool:
		if not writable: return false
		saved=candidate.duplicate(true)
		revision=next_revision
		return true
	func load_profile()->Dictionary:
		return {"accepted":true,"payload":saved.duplicate(true),"revision":revision}

func check(result: bool, message: String)->void:
	checks+=1
	if not result:
		failures+=1
		printerr("FAIL ",message)

func grass_entrance_discovery() -> void:
	var room := OrdinaryRoomSession.new()
	var store := Storage.new()
	root.add_child(room)
	var doc := WorldRoomDocument.read("res://rooms/world/P02.json")
	var opened := room.open(doc,store,null,catalog)
	check(opened.is_empty(),"open the registered P02 grass approach")
	if opened.is_empty():
		var flag := "discover_p02_low_slope"
		room.player.reset_at(FixedWorldProvider.point(doc.exits.d001.spawn))
		await frames(6)
		check(not room.state.has(flag),"the lower approach preserves the secret")
		store.writable=false
		room.player.reset_at(FixedWorldProvider.point(doc.sites[flag].at))
		await frames(6)
		check(not room.state.has(flag),"an unrecorded discovery stays retryable")
		store.writable=true
		await frames(6)
		check(room.state.has(flag) and store.saved.receipts.has(flag),"the grass entrance records the locked discovery")
		await room.audio_service.shutdown()
	room.free()
	await frames(3)

func _initialize()->void: run.call_deferred()

func frames(count:int)->void:
	for i in count: await physics_frame

func enter(id: String, ids: Array, store: Storage, previous: OrdinaryRoomSession=null) -> OrdinaryRoomSession:
	var doc:=WorldRoomDocument.read("res://tests/content_channel_room.json")
	doc.room_id=id
	if id=="P18":
		doc.entities={"floor":doc.entities.floor,"patrol":doc.entities.patrol}
		doc.entities.patrol.properties.point=[280,366]
	else:
		doc.entities={"floor":doc.entities.floor}
		doc.erase("content_bindings")
	doc.sites={}
	for key: String in ids: doc.sites[key]={"at":[160,366]}
	var room:=OrdinaryRoomSession.new()
	root.add_child(room)
	var err:=room.open(doc,store if previous==null else null,previous,catalog)
	check(err.is_empty(),"ordinary room %s opens: %s" % [id,err])
	await frames(8)
	return room

func prior_flags(room: OrdinaryRoomSession,flags: Array)->void:
	var next:=room.state.candidate()
	for flag: String in flags:
		if flag not in next.flags: next.flags.append(flag)
	check(room.state.commit(next,room.state.revision),"prepare earlier journey receipts")

func act(room: OrdinaryRoomSession,id:String)->bool:
	return room.content_sites.claim(id,room.state.revision)

func practice_target_trial() -> void:
	var official:=WorldContentCatalog.new()
	check(official.load_locked().ok and official.load_bindings("res://config/imported_world/bindings.json").ok,"locked catalog and production bindings for the reward test")
	var room:=OrdinaryRoomSession.new()
	root.add_child(room)
	var doc:=preload("system_room_fixture.gd").flat("P18")
	doc.sites["intro_active_skill"]={"at":[350,585]}
	doc.entities.floor_tuning_dummy={"id":"floor_tuning_dummy","definition_id":"enemy.chime_target","definition_version":1,"properties":{"point":[534,585]}}
	var loaded:=room.open(doc,Storage.new(),null,official)
	check(loaded.is_empty(),"isolated reward and practice target room: "+loaded)
	if not loaded.is_empty(): room.free(); return
	await frames(6)
	var at: Vector2=room.content_sites.positions.intro_active_skill
	room.controller.router.set_move_axis(1)
	for tick in 210:
		await physics_frame
		if room.player.position.x>=at.x: break
	room.controller.router.set_move_axis(0)
	await frames(10)
	prior_flags(room,["encounter_P21_clear"])
	check(act(room,"intro_active_skill"),"walk to the bound active-skill site and take the pulse")
	var target: EnemyActor=room.room.enemies.floor_tuning_dummy
	var hits: Array=[]
	target.health.changed.connect(func(result: ActorResourceResult):
		if result.operation==&"damage" and result.amount_applied<0: hits.append(result.amount_applied))
	var direction:=(target.motor.global_position-room.player.global_position).normalized()
	room.controller.router.request_action(&"weapon_skill",direction)
	await frames(100)
	check(not hits.is_empty(),"P18 practice dummy takes an actual aimed pulse")
	room.free()
	await frames(3)

func run()->void:
	check(catalog.load_locked().ok,"load pinned world")
	check(catalog.load_bindings("res://tests/content_channel_bindings.json",true).ok,"use real enemy fixture binding")
	var store:=Storage.new()
	var s:=await enter("G08",["W"],store)
	if s.controller==null: quit(1); return
	check(not s.controller.traversal.wall_enabled and not act(s,"W"),"entering G08 cannot bypass victory")
	prior_flags(s,["encounter_G07_clear"])
	store.writable=false
	check(not act(s,"W") and not s.controller.traversal.wall_enabled,"failed write leaves W inactive")
	store.writable=true
	s.controller.router.request_action(&"interact")
	await frames(2)
	check(s.state.has("W") and s.controller.traversal.wall_enabled and s.state.value.receipts.has("wr_G08_primary"),"real interaction grants W and unlocks the controller")
	if s.content_sites.menu.visible_panel(): s.content_sites.menu.close()
	check(not act(s,"W"),"unique W cannot repeat")
	s=await enter("T18",["H"],store,s)
	check(s.controller.traversal.wall_enabled and not act(s,"H"),"first visit restores W and preserves H gate")
	prior_flags(s,["encounter_T04_clear"])
	check(act(s,"H") and s.controller.traversal.hook_enabled,"H activates grapple")
	s=await enter("Y23",["D"],store,s)
	prior_flags(s,["encounter_Y20_clear"])
	check(act(s,"D") and s.controller.jump_ability.maximum_jumps()>=2,"D activates second jump")
	s=await enter("K12",["Q"],store,s)
	prior_flags(s,["castle_key","encounter_K11_clear"])
	check(act(s,"Q") and s.recoil_guard.owned and not s.recoil_guard.is_protecting(),"Q is owned but standing still gives no protection")
	var protected_once:=false
	s.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	for tick in 12:
		await physics_frame
		if s.recoil_guard.is_protecting():
			protected_once=true
			var hit:=DamageRequest.new()
			hit.kind=DamageRequest.Kind.MONSTER
			check(s.recoil_guard.protects(hit),"enemy contact is guarded")
			hit.hazard_category=&"machine_solid"
			check(not s.recoil_guard.protects(hit),"solid machine cannot be guarded")
			hit.kind=DamageRequest.Kind.ENVIRONMENT
			hit.hazard_category=&"phase_light"
			check(s.recoil_guard.protects(hit),"phase curtain is guarded")
	check(protected_once and not s.recoil_guard.is_protecting(),"Q protects real moving recoil then expires")
	s=await enter("F_IN01",["weapon_shuriken"],store,s)
	prior_flags(s,["encounter_F_IN01_clear"])
	var took:=act(s,"weapon_shuriken")
	check(took and s.controller.shoot_ability.weapon.id==&"shadow_shuriken","weapon source equips actual shuriken")
	check(s.select_world_weapon("gun",s.state.revision) and s.controller.shoot_ability.weapon.id==&"pulse_gun","can return to owned sidearm")
	check(not s.select_world_weapon("B",s.state.revision),"no access to unearned bomb")
	s=await enter("P08",["town_arrival","npc20_town","tp_P08"],store,s)
	check(not s.state.has("town_arrival") and not s.state.has("travel_P08"),"town story and station independent on entry")
	check(act(s,"town_arrival") and not s.state.has("town_east_wicket_open"),"talking to town resident never operates the gate")
	check(act(s,"tp_P08") and s.state.has("travel_P08"),"ringing the station requires actual local interaction")
	var cash:=s.state.candidate()
	cash.services.gold=40
	check(s.state.commit(cash,s.state.revision),"fund equipment transaction")
	store.writable=false
	check(not s.content_sites.buy("npc20_town","shop20_B01",s.state.revision) and s.services.ledger().gold==40,"failed shop keeps currency")
	store.writable=true
	check(s.content_sites.buy("npc20_town","shop20_B01",s.state.revision) and s.services.ledger().gold==5 and s.services.ledger().owned.has("B01"),"merchant delivers owned equipment for pinned price")
	check(not s.content_sites.buy("npc20_town","shop20_B01",s.state.revision),"merchant never charges twice")
	s=await enter("R12",["quest22_meal_marks"],store,s)
	check(act(s,"quest22_meal_marks") and int(s.state.value.inventory.get("qi_harbor_rubbing",0))==1,"investigation may precede quest acceptance")
	s=await enter("R_IN01",["npc.axi","wr20_equipment_EQ_FILTER"],store,s)
	check(not act(s,"quest22_meal_complete") and not act(s,"wr20_equipment_EQ_FILTER"),"cannot deliver or claim before accepting")
	check(act(s,"quest22_meal_accept") and act(s,"quest22_meal_complete") and not s.state.value.inventory.has("qi_harbor_rubbing") and not s.services.ledger().owned.has("EQ_FILTER"),"delivery consumes quest item but leaves prize in room")
	check(act(s,"wr20_equipment_EQ_FILTER") and s.services.ledger().owned.has("EQ_FILTER") and not s.services.active("EQ_FILTER"),"separate source grants unequipped filter")
	s.free()
	await process_frame
	s=await enter("R_IN01",["npc.axi","wr20_equipment_EQ_FILTER"],store)
	check(s.services.ledger().gold==5 and s.controller.traversal.double_enabled and s.recoil_guard.owned and not act(s,"wr20_equipment_EQ_FILTER"),"save restores rights, receipts and balance")
	s=await enter("G12",["npc20_workshop"],store,s)
	var stash:=s.state.candidate()
	stash.gear_ids.carried=["TG01","TG02","TG03","TG04"]
	stash.inventory["time_gear"]=4
	check(s.state.commit(stash,s.state.revision),"earlier gear pickups carried")
	var sites:=s.content_sites
	check(not sites.exchange("npc20_workshop","exchange_EQ_GEAR01",s.state.revision),"possession alone is not delivery")
	check(sites.deliver_gears("npc20_workshop",s.state.revision) and s.state.value.gear_ids.delivered.size()==4,"NPC receives exact carried identities")
	check(sites.exchange("npc20_workshop","exchange_EQ_GEAR01",s.state.revision) and s.services.ledger().owned.has("G01") and s.state.value.gear_ids.delivered.size()==4,"separate exchange gives accessory and preserves delivered total")
	check(not sites.exchange("npc20_workshop","exchange_EQ_GEAR01",s.state.revision),"exchange reward cannot duplicate")
	s=await enter("Z08",["wr_Z08_primary"],store,s)
	prior_flags(s,["core_T","core_I","core_E","encounter_Z06_clear"])
	check(s.content_sites.available_endings("wr_Z08_primary").size()==1 and not act(s,"wr_Z08_primary"),"explicit ending choice required")
	s.content_sites.interact_site("wr_Z08_primary")
	var panel:=s.content_sites.menu
	var first:=panel.choices.get_child(0) as Button
	first.pressed.emit()
	check(not s.state.value.receipts.has("ending:ordinary"),"choosing a branch displays a second confirmation")
	(panel.choices.get_child(0) as Button).pressed.emit()
	check(s.state.value.receipts.has("ending:ordinary") and panel.message.text.contains(catalog.lookup("endings","ordinary").row.aftermath[0]) and s.state.value.story_hosts.ending=="ordinary","ending prose and aftermath follow confirmed save")
	panel.close()
	prior_flags(s,["true_gate_clear","clock_memory_witnessed"])
	check(s.content_sites.available_endings("wr_Z08_primary").size()==2 and s.content_sites.confirm_ending("wr_Z08_primary","true",s.state.revision) and s.state.value.receipts.has("ending:ordinary"),"return and independently witness the true ending")
	s=await enter("P18",["intro_active_skill"],store,s)
	check(not s.controller.router.weapon_skill_available and not act(s,"intro_active_skill"),"early pulse cannot be activated before its award")
	prior_flags(s,["encounter_P21_clear"])
	check(act(s,"intro_active_skill") and int(s.state.value.inventory.get("skill_core",0))==0,"unlock pulse without consuming a shared skill core")
	s.touch_controls.set_enabled(true)
	s.controller.router.set_aim(&"touch",Vector2.RIGHT)
	await frames(4)
	for down: bool in [true,false]:
		var action:=InputEventScreenTouch.new()
		action.index=5
		action.position=s.touch_controls.skill_center
		action.pressed=down
		root.push_input(action,true)
		await frames(2)
	check(s.controller.shoot_ability.behavior().phase==&"intro_pulse","actual touch skill starts short charge")
	await frames(55)
	check(s.state.value.enemies.has("patrol") and s.state.value.enemies.patrol.health<=0,"released pulse kills a real enemy via normal damage and defeat commit")
	await frames(120)
	s.controller.router.request_action(&"weapon_skill",Vector2.RIGHT)
	await frames(2)
	check(s.controller.shoot_ability.behavior().phase==&"intro_pulse","pulse can recharge")
	var emissions: Array=[]
	s.controller.shoot_ability.shot_fired.connect(func(_d:Vector2,_i:int): emissions.append(true))
	s=await enter("P08",["town_arrival"],store,s)
	await frames(25)
	check(emissions.is_empty() and s.controller.shoot_ability.behavior().phase==&"idle","crossing during charge releases no projectile in either room")
	s.controller.router.request_action(&"weapon_skill",Vector2.RIGHT)
	await frames(2)
	check(s.controller.shoot_ability.behavior().phase==&"intro_pulse","acquired skill stays available after crossing")
	s.controller.die()
	check(s.controller.shoot_ability.behavior().phase==&"idle" and s.controller.shoot_ability.get_projectiles().is_empty(),"death cancels charge and clears shots")
	s.free()
	await frames(3)
	await practice_target_trial()
	await grass_entrance_discovery()
	print("WORLD CONTENT SITES failures=%d checks=%d" % [failures,checks]);quit(1 if failures else 0)
