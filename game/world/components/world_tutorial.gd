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
func _ready() -> void:
	process_physics_priority=1100
	controller.jump_ability.jumped.connect(func() -> void: jumped=true)
	controller.landed.connect(_landed)
	controller.shoot_ability.shot_fired.connect(_shot)
	controller.weapon_damage_committed.connect(_hit)
func enter(value: FixedWorldRoom,origin: Vector2) -> void:
	reset_proof();room=value;initial_x=origin.x
func reset_proof() -> void:
	moved=0;shot=false;recoil=false;jumped=false;move_landed=false
	recoil_moved=false;air_recoil_pending=false
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
	if _enabled() and room.enemies.has(room.tutorial_target) and receiver==(room.enemies[room.tutorial_target] as EnemyActor).damageable: shot=true
func _physics_process(_delta: float) -> void:
	if not _enabled() or not controller.active: return
	var player:=controller.motor
	moved=maxf(moved,absf(player.position.x-initial_x))
	if air_recoil_pending and player.recoil_burst_remaining>0 and player.position.distance_to(recoil_origin)>20: recoil_moved=true
	if room.tutorial_action in ["tutorial_move","tutorial_opening"] and moved>room.tutorial_min_move and move_landed and not state.has("intro_move"): action_requested.emit("tutorial_move")
	elif room.tutorial_action in ["tutorial_shoot","tutorial_opening"] and shot and state.has("intro_move") and not state.has("intro_shoot"): action_requested.emit("tutorial_shoot")
	elif room.tutorial_action=="tutorial_recoil" and recoil and state.has("intro_shoot") and not state.has("intro_complete"): action_requested.emit("tutorial_recoil")
