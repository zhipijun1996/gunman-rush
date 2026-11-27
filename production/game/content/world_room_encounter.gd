class_name WorldRoomEncounter
extends Node2D
## The authored formation supplies combatants and the victory site. The locked
## encounter supplies the eligibility, permanent flag and one-time purse.

var session: OrdinaryRoomSession
var encounter: Dictionary
var waves: Array
var placements: Dictionary = {}
var start_offset := Vector2.ZERO
var awaiting_challenge := false
var eligibility := {}
var next_wave := 0
var active_wave: Array = []
var hint := Label.new()

static func check_sites(document: Dictionary, catalog: WorldContentCatalog) -> String:
	var sites: Dictionary = document.get("sites", {})
	var assigned := {}
	for key: String in sites:
		if not key.begins_with("enc_"): continue
		var found := catalog.lookup("encounters",key)
		if not found.ok or found.row.room != document.room_id: return "encounter_room_mismatch:" + key
		var site: Variant = sites[key]
		if not site is Dictionary or not WorldRoomValidation.vector(site.get("at")):
			return "invalid_encounter_site:" + key
		if site.has("start_at") and not WorldRoomValidation.vector(site.start_at): return "invalid_encounter_start:" + key
		var groups: Variant = site.get("waves")
		if not groups is Array or groups.is_empty(): return "encounter_waves_required:" + key
		for group: Variant in groups:
			if not group is Array or group.is_empty(): return "encounter_empty_wave:" + key
			for member: Variant in group:
				if not member is String or assigned.has(member): return "encounter_member_invalid:" + key
				var entity: Dictionary = document.entities.get(member,{})
				if not str(entity.get("definition_id","")).begins_with("enemy.") or entity.definition_id == "enemy.chime_target": return "encounter_enemy_required:" + str(member)
				assigned[member] = key
		var exclusive: Variant = site.get("victory_only",[])
		if not exclusive is Array: return "encounter_purse_invalid:" + key
		for id: Variant in exclusive:
			if not id is String or assigned.get(id,"") != key or document.get("content_bindings",{}).get("enemy_instances",{}).has(id):
				return "encounter_purse_member_invalid:" + str(id)
	return ""

func configure(owner_session: OrdinaryRoomSession, row: Dictionary, site: Dictionary) -> void:
	session = owner_session
	encounter = row
	var required: Array = row.get("requires",[]).duplicate()
	for ability: String in row.get("minimum_abilities",[]):
		if ability not in required: required.append(ability)
	eligibility = {"requires":required,"excludes":row.get("excludes",[])}
	waves = site.waves
	position = FixedWorldProvider.point(site.at)
	start_offset = FixedWorldProvider.point(site.get("start_at",site.at)) - position
	awaiting_challenge = row.kind == "optional_boss" or site.has("start_at")
	for group: Array in waves:
		for id: String in group: placements[id] = {}
	var ordinary: Array[Dictionary] = []
	for placement: Dictionary in session.room.enemy_placements:
		if placements.has(placement.id): placements[placement.id] = placement
		else: ordinary.append(placement)
	session.room.enemy_placements = ordinary
	session.room.add_child(self)
	hint.position = Vector2(-125,-68)
	hint.size.x = 250
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_override("font",EquipmentMenu.UI_FONT)
	hint.add_theme_constant_override("outline_size",4)
	add_child(hint)
	hint.hide()

func _physics_process(_delta: float) -> void:
	if not session.lifetime.active or not session.controller.active:
		hint.hide()
		return
	if session.state.has(encounter.completion_flag):
		hint.hide()
		set_physics_process(false)
		return
	if not session.content_catalog.condition_match(eligibility,session.state.value.flags,session.state.value.services.equipped).matches: return
	if awaiting_challenge:
		hint.position = start_offset + Vector2(-125,-68)
		hint.text = session.controller.router.interact_prompt("发起挑战")
		hint.visible = session.player.position.distance_to(position + start_offset) <= 60.0
		return
	hint.hide()
	for id: String in active_wave:
		if not session.room.enemies[id].health.terminal: return
	if not session.pending_defeats.is_empty(): return
	if next_wave < waves.size():
		active_wave = waves[next_wave]
		next_wave += 1
		for id: String in active_wave:
			var actor := session.room.spawn_enemy(placements[id],session.controller,session.policy,session.lifetime,session.state.value.enemies.get(id,{}),session.player.position)
			actor.defeated.connect(session._defeated.bind(id))
		return
	hint.position = Vector2(-125,-68)
	hint.text = session.controller.router.interact_prompt("确认胜利")
	hint.visible = session.player.position.distance_to(position) <= 60.0

func confirm() -> bool:
	if session.state.has(encounter.completion_flag): return false
	if awaiting_challenge:
		if session.player.position.distance_to(position + start_offset) > 60.0 or not session.player.is_on_floor(): return false
		if not session.lifetime.active or not session.controller.active or session.controller.has_pending_damage(): return false
		if not session.content_catalog.condition_match(eligibility,session.state.value.flags,session.state.value.services.equipped).matches: return false
		awaiting_challenge = false
		hint.hide()
		return true
	if session.player.position.distance_to(position) > 60.0: return false
	if next_wave != waves.size() or not session.pending_defeats.is_empty() or session.controller.has_pending_damage(): return false
	if not session.lifetime.active or not session.controller.active or not session.player.is_on_floor(): return false
	if not session.content_catalog.condition_match(eligibility,session.state.value.flags,session.state.value.services.equipped).matches: return false
	for id: String in placements:
		if not session.room.enemies.has(id) or not session.room.enemies[id].health.terminal: return false
	var candidate := session.state.candidate()
	var flag: String = encounter.completion_flag
	candidate.flags.append(flag)
	candidate.receipts[flag] = {"source":flag,"source_hash":MetaSaveService.canonical_json(encounter).sha256_text(),"revision":session.state.revision+1}
	candidate = session.services.earned_candidate(candidate,encounter.id,int(encounter.coin_reward))
	if session.state.commit(candidate,session.state.revision):
		GameAudio.cue(session.player,&"coin")
		session.player.get_node("PlayerFeedback").reward_received(session.player.global_position,false)
		hint.hide()
	return true
