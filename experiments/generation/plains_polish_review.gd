extends Node2D
## Explicit rendered Boss8 fixture, separate from normal title/Home entry.
## AI uses actual PlayerController inputs and projectiles; no HP/motion cheats.
var app: DemoApp
var boss: WindkeeperEncounter
var _module_origin := Vector2.ZERO
var _jump_armed := true
var _ready_to_drive := false
var _tick := 0
var _label: Label
func _ready() -> void:
	process_physics_priority = -200
	app = preload("res://game/application/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	add_child(app)
	await get_tree().physics_frame
	app.start_plains("polish-review-01")
	for unused: int in 5: await get_tree().physics_frame
	# Explicit final-room fixture, not a claim to have traversed rooms1–7.
	for index: int in range(2,9): app.director._enter_stage(index,&"boss" if index == 8 else &"combat")
	app.lifetime.stage_epoch += 7
	app.lifetime.actor_epoch += 7
	app._load_stage()
	for unused: int in 8: await get_tree().physics_frame
	var stage := app.stage as GeneratedDemoStage
	for module: PlatformingModule in stage.assembler.modules:
		if module.definition.module_id == &"plains_boss_arena": _module_origin = module.global_position
	app.player.reset_at(_module_origin+Vector2(300,582))
	app.player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	boss = stage.boss.get_node("Encounter") as WindkeeperEncounter
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	_label = Label.new()
	_label.position = Vector2(18,192)
	_label.text = "REVIEW FIXTURE / explicit Boss8 spawn\nActual input, HP and projectile progression"
	_label.add_theme_font_size_override("font_size",14)
	_label.add_theme_color_override("font_outline_color",Color("183d33"))
	_label.add_theme_constant_override("outline_size",4)
	canvas.add_child(_label)
	_ready_to_drive = true
func _physics_process(_delta: float) -> void:
	if not _ready_to_drive or get_tree().paused: return
	_tick += 1
	if _tick % 60 == 0:
		print("REVIEW tick=%s phase=%s mode=%s playerHP=%.0f bossHP=%.0f" % [_tick,boss.stage_phase,boss.mode,app.controller.actor_resources.health.current,boss.health.current])
	var player := app.player
	var controller := app.controller
	if boss.health.terminal or controller.actor_resources.health.terminal:
		controller.router.set_move_axis(0)
		_label.text = "REVIEW FIXTURE / %s\nHP %.0f / boss %.0f" % ["DEFEAT — REWARD ON SAFE BRIDGE" if boss.health.terminal else "PLAYER FAILED",controller.actor_resources.health.current,boss.health.current]
		return
	var px := player.global_position.x - _module_origin.x
	var py := player.global_position.y - _module_origin.y
	var bx := boss.motor.global_position.x - _module_origin.x
	var desired := (bx + (160 if px > bx else -160) if boss.core_open else 300.0) if boss.stage_phase == 1 else (620.0 if boss.stage_phase == 2 else clampf(bx+165,600,970))
	controller.router.set_move_axis(clampf((desired-px)/40,-1,1))
	if player.is_on_floor(): _jump_armed = true
	if boss.stage_phase == 1 and player.is_on_floor() and py < 550: controller.router.request_action(&"drop_through")
	var dodge := boss.mode in [&"stomp_warning",&"charge_warning"] and boss.clock < .3
	var climb := boss.stage_phase >= 2 and (py > 500 or boss.stage_phase == 3 and (440 < px and px < 480 or 700 < px and px < 740))
	if _jump_armed and player.is_on_floor() and (dodge or climb):
		controller.router.set_jump_held(&"review",true)
		_jump_armed = false
	elif player.normal_velocity.y >= 0: controller.router.set_jump_held(&"review",false)
	if boss.core_open and controller.shoot_ability.cooldown_remaining <= 0 and (boss.stage_phase != 1 or py > 510) and (boss.stage_phase == 1 or player.is_on_floor() and py < 470) and (boss.stage_phase == 1 or absf(px-desired) < 25):
		controller.shoot_ability.try_fire(boss.motor.global_position+boss.core_offset()-player.global_position,player.is_on_floor())
