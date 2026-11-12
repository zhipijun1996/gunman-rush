class_name WorldTutorial
extends Node
## Accepted action proof for an authored tutorial placement; no permanent writes here.
signal action_requested(id: String)
var controller: PlayerController
var state: FixedWorldState
var room: FixedWorldRoom
var initial_x:=0.0
var moved:=0.0
var shot:=false
var recoil:=false
var jumped:=false
var move_landed:=false
var recoil_origin:=Vector2.ZERO
var recoil_moved:=false
var air_recoil_pending:=false
var learned_hints: Dictionary = {}
func _ready() -> void:
	process_physics_priority=1100
	controller.jump_ability.jumped.connect(func() -> void:
		jumped=true
		_mark_hint("jump"))
	controller.landed.connect(_landed)
	controller.shoot_ability.shot_fired.connect(_shot)
	controller.weapon_damage_committed.connect(_hit)
func enter(value: FixedWorldRoom,origin: Vector2) -> void:
	reset_proof();room=value;initial_x=origin.x
func reset_proof() -> void:
	moved=0;shot=false;recoil=false;jumped=false;move_landed=false
	recoil_moved=false;air_recoil_pending=false

func _mark_hint(id: String) -> void:
	if not is_instance_valid(room) or room.onboarding.is_empty():return
	var key:=String(controller.router.current_device)+":"+id
	learned_hints[key]=true

func hint(phase: String, target: Dictionary) -> String:
	if not is_instance_valid(room) or room.onboarding.is_empty() or not controller.active:return ""
	var key:=String(controller.router.current_device)+":"
	if not state.has("intro_gun"):
		if phase!="pickup":return ""
		if target.get("kind","")=="intro_pickup":return "pickup"
		return "move" if not learned_hints.has(key+"move") else ""
	var bell:=room.mechanisms.get(str(room.onboarding.get("bell_id",""))) as WorldShotLatch
	if bell!=null and not bell.is_open and controller.motor.position.x<bell.gate_rect.end.x+64:return "shoot"
	if bell!=null and bell.is_open:_mark_hint("shoot")
	if not learned_hints.has(key+"jump") and controller.motor.is_on_floor() and FixedWorldProvider.rect(room.onboarding.jump_approach).has_point(controller.motor.position):return "jump"
	return ""
func _enabled() -> bool:
	return is_instance_valid(room) and not room.tutorial_action.is_empty()
func _landed() -> void:
	if not _enabled(): return
	move_landed=jumped
	if state.has("intro_shoot") and recoil_moved and controller.motor.position.x>=room.tutorial_recoil_finish_x: recoil=true
func _shot(_direction: Vector2,_id: int) -> void:
	if not _enabled(): return
	air_recoil_pending=not controller._was_grounded
	recoil_origin=controller.motor.position;recoil_moved=false
func _hit(_packet: int,_shot_id: int,receiver: Damageable,_session: int,_epoch: int) -> void:
	if not _enabled():return
	if room.tutorial_action=="tutorial_opening":
		for enemy: EnemyActor in room.enemies.values():
			if is_instance_valid(enemy) and receiver==enemy.damageable:shot=true;return
	elif room.enemies.has(room.tutorial_target) and receiver==(room.enemies[room.tutorial_target] as EnemyActor).damageable:shot=true
func _physics_process(_delta: float) -> void:
	if not _enabled() or not controller.active: return
	var player:=controller.motor
	moved=maxf(moved,absf(player.position.x-initial_x))
	if not room.onboarding.is_empty() and absf(controller.router.axis)>.1 and moved>=float(room.onboarding.move_distance):_mark_hint("move")
	if air_recoil_pending and player.recoil_burst_remaining>0 and player.position.distance_to(recoil_origin)>20: recoil_moved=true
	if room.tutorial_action in ["tutorial_move","tutorial_opening"] and moved>room.tutorial_min_move and move_landed and not state.has("intro_move"): action_requested.emit("tutorial_move")
	elif room.tutorial_action in ["tutorial_shoot","tutorial_opening"] and shot and state.has("intro_move") and not state.has("intro_shoot"): action_requested.emit("tutorial_shoot")
	elif room.tutorial_action=="tutorial_recoil" and recoil and state.has("intro_shoot") and not state.has("intro_complete"): action_requested.emit("tutorial_recoil")
