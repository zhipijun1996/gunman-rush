class_name ModuleBossTrial
extends Node2D
## Local practice encounter; never owns RunDirector or permanent progress.
const BOSS := preload("res://scenes/bosses/clockwork_guardian.tscn")
const GOLD := preload("res://resources/items/power_gold.tres")
var boss_scene: PackedScene = BOSS
var boss_definition: BossDefinition
var core_left := 890.0
var core_right := 1240.0
var spawn_position := Vector2(950, 557.8)
var lab: ModuleLab
var boss: BossMotor
var encounter: BossEncounter
var build := BuildState.new()
var rewards := RewardService.new()
var offer: RewardOffer
var claimed := false
var started := false
var reward_position := Vector2.ZERO
var _claim_pending: DemoToken
var _contact: DemoContactEmitter
var _eligible_shots: Dictionary = {}
var _hud: Label

func setup(owner_lab: ModuleLab) -> void:
	process_physics_priority = 850
	lab = owner_lab
	boss = boss_scene.instantiate() as BossMotor
	if boss_definition!=null: (boss.get_node("Encounter") as BossEncounter).definition=boss_definition
	boss.position = spawn_position
	add_child(boss)
	encounter = boss.get_node("Encounter") as BossEncounter
	encounter.configure_arena(core_left, core_right, lab.player)
	if encounter is WindkeeperEncounter:
		(encounter as WindkeeperEncounter).bind_stage_geometry(lab.module,lab.controller,lab.policy,lab.lifetime,lab.segment)
	var receiver := boss.get_node("Damageable") as Damageable
	lab.policy.bind_damageable(&"practice_boss", receiver, encounter.health)
	var sink := receiver.damage_sink
	receiver.damage_sink = func(context: Dictionary) -> bool:
		var key := "%s:%s" % [context.get("session_id", -1), context.get("shot_id", -1)]
		return started and lab.lifetime.active and _eligible_shots.get(key, -1) == lab.lifetime.actor_epoch and sink.call(context) == true
	lab.controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, shot_id: int) -> void:
		if started and in_core() and lab.lifetime.active:
			_eligible_shots["%s:%s" % [lab.controller.session_id, shot_id]] = lab.lifetime.actor_epoch
	)
	encounter.projectile_created.connect(_projectile_created)
	_contact = DemoContactEmitter.new()
	_contact.policy = lab.policy
	_contact.controller = lab.controller
	_contact.source_id = &"practice_boss_contact"
	_contact.kind = DamageRequest.Kind.MONSTER
	_contact.half_size = Vector2(72,62).min(encounter.definition.collision_size/2) if encounter is WindkeeperEncounter else Vector2(25,27)
	_contact.enabled = false
	boss.add_child(_contact)
	_hud = Label.new()
	_hud.position = Vector2(400, 330)
	_hud.add_theme_font_size_override("font_size", 18)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if encounter is WindkeeperEncounter:
		_hud.position = Vector2(140,230)
		_hud.add_theme_font_size_override("font_size",16)
		_hud.add_theme_color_override("font_outline_color",Color("172c28"))
		_hud.add_theme_constant_override("outline_size",2)
	if encounter is WindkeeperEncounter:
		var backing:=ColorRect.new();backing.name="PracticeBossBacking"
		backing.position=_hud.position-Vector2(8,4)
		backing.size=Vector2(880,58)
		backing.color=Color(.06,.12,.14,.90)
		backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(backing)
	add_child(_hud)
	if encounter is WindkeeperEncounter:
		var intro_layer:=CanvasLayer.new();intro_layer.layer=4;add_child(intro_layer)
		var intro_hud:=WindkeeperHud.new();intro_hud.intro_only=true;intro_layer.add_child(intro_hud);intro_hud.bind(encounter)
	build.configure(lab.controller)
	rewards.configure(lab.lifetime, build)
	lab.policy.batch_resolved.connect(_batch_resolved)

func _physics_process(_delta: float) -> void:
	if is_instance_valid(_hud):
		var intro: bool=encounter is WindkeeperEncounter and (encounter as WindkeeperEncounter).mode==&"intro" and encounter.active
		_hud.visible=not intro
		var backing:=get_node_or_null("PracticeBossBacking") as ColorRect
		if backing!=null: backing.visible=not intro
		_hud.text = "PRACTICE BOSS / %s / HP %.0f / GOLD %s" % ["DEFEATED" if encounter.health.terminal else ("ACTIVE" if started else "DORMANT"), encounter.health.current, "CLAIMED" if claimed else ("READY" if offer != null else "LOCKED")]
		if encounter is WindkeeperEncounter:
			var sheep := encounter as WindkeeperEncounter
			_hud.text = "%s / PHASE %s / HP %.0f / %s\n%s" % [(sheep.definition as WindkeeperDefinition).display_name.split(" / ")[-1],sheep.stage_phase,sheep.health.current,str(sheep.mode).to_upper(),sheep.objective().split(" / ")[-1]]
	if is_instance_valid(_contact):
		_contact.enabled = started and in_core() and lab.lifetime.active and encounter.body_contact_enabled()

func in_core() -> bool:
	return is_instance_valid(lab.player) and lab.player.global_position.x >= core_left

func advance() -> void:
	if not lab.ready_for_play or not lab.lifetime.active:
		_claim_pending = null
		return
	if not started and in_core() and lab.player.is_on_floor() and not lab.controller.actor_resources.health.terminal:
		started = encounter.activate()
		if started:
			lab._status = "BOSS PRACTICE / core entered. Retreat is allowed; GOLD stays local to this attempt."
	_contact.enabled = started and in_core() and encounter.body_contact_enabled()
	_commit_claim()

func _projectile_created(projectile: BossProjectile) -> void:
	projectile.hit.connect(func(body: Node2D, event_id: StringName, amount: float) -> void:
		if body == lab.player and in_core() and lab.lifetime.active:
			var request := DamageRequest.new()
			request.token = lab.lifetime.token()
			request.actor_epoch = lab.lifetime.actor_epoch
			request.health_epoch = lab.controller.actor_resources.health.epoch
			request.target_id = &"player"
			request.source_id = &"practice_boss_projectile"
			request.event_id = event_id
			request.amount = amount
			lab.policy.submit(request)
	)

func _batch_resolved(_results: Array[DamageResult]) -> void:
	if not lab.lifetime.active or lab.controller.actor_resources.health.terminal:
		_claim_pending = null
		return
	if started and encounter.health.terminal and offer == null:
		offer = rewards.create_gold_offer(&"practice_gold", GOLD, encounter.defeat_id)
		reward_position = boss.global_position
		if encounter is WindkeeperEncounter: reward_position = (encounter as WindkeeperEncounter).reward_stand_position()
		lab._status = "BOSS DEFEATED / approach the gold marker and claim PRACTICE GOLD once."
		queue_redraw()

func queue_claim() -> void:
	if lab.ready_for_play and lab.lifetime.active and not get_tree().paused:
		_claim_pending = lab.lifetime.token()

func can_claim() -> bool:
	return offer != null and not claimed and lab.lifetime.active and lab.player.global_position.distance_to(reward_position) <= 100.0

func _commit_claim() -> void:
	var token := _claim_pending
	_claim_pending = null
	if token == null or not lab.lifetime.accepts(token) or not can_claim():
		return
	var request := RewardClaimRequest.new()
	request.token = token
	request.offer_id = offer.offer_id
	request.option_id = offer.candidates[0].stable_id
	request.claim_id = &"practice_gold_claim"
	if rewards.claim(request).status == EconomyReceipt.Status.COMMITTED:
		claimed = true
		lab._status = "PRACTICE GOLD CLAIMED / local build only. Reach EXIT to clear."
		queue_redraw()

func cancel_pending(preserve_boss: bool = false) -> void:
	_claim_pending = null
	if encounter is WindkeeperEncounter and not preserve_boss:
		(encounter as WindkeeperEncounter).cancel_pending_attacks()
		_eligible_shots.clear()
		if is_instance_valid(lab.controller): lab.controller.shoot_ability.clear_projectiles()

func _draw() -> void:
	draw_line(Vector2(890, 305), Vector2(890, 600), Color(0.95, 0.7, 0.24, 0.7), 3.0)
	if offer != null and not claimed:
		draw_circle(reward_position, 15.0, Color("ffd55b"))

func _exit_tree() -> void:
	if is_instance_valid(encounter):
		encounter.cancel()
