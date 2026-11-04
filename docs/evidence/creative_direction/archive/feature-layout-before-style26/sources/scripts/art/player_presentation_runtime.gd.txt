class_name PlayerPresentationRuntime
extends RefCounted
## Formal assembly only: no preview controls, equipment grants or training targets.
const WEAPON_PROFILE := preload("res://resources/player_presentation_01/weapon_feel_v1.tres")

class WeaponFeel extends PlayerWeaponFeelV2:
	func _valid_projectile(projectile: PlayerProjectile) -> bool:
		return is_instance_valid(projectile) and is_instance_valid(controller) and controller.active and projectile.owner_id == controller.motor.get_instance_id() and projectile.session_id == controller.session_id and projectile.weapon_epoch == controller.shoot_ability.weapon_epoch
	func _contact(point: Vector2, axis: Vector2, projectile: PlayerProjectile, mode: int) -> void:
		if _valid_projectile(projectile): super._contact(point, axis, projectile, mode)
	func _wall(point: Vector2, axis: Vector2, projectile: PlayerProjectile) -> void:
		if _valid_projectile(projectile): super._wall(point, axis, projectile)
	func clear() -> void:
		super.clear()
		# These leaves live on projectiles. Restore/free on cancellation or detach.
		for leaf: PlayerWeaponFeelProjectile in leaves:
			if is_instance_valid(leaf): leaf.free()
		leaves.clear()

static func make_body(motor: PlayerMotor, controller: PlayerController, body_name: String, avatar_id := "courier") -> UnderworldPlayer:
	var body: UnderworldPlayer = UnderworldPlayer.new() if avatar_id == "courier_classic" else PlayerMotionCandidateVisual.new()
	body.name = body_name
	body.motor = motor
	body.controller = controller
	return body

static func current_body(player: Node) -> UnderworldPlayer:
	for child: Node in player.get_children():
		if child is UnderworldPlayer and not child.is_queued_for_deletion(): return child as UnderworldPlayer
	return null

static func _remove(player: Node, child_name: String) -> void:
	var child := player.get_node_or_null(NodePath(child_name))
	if child != null:
		player.remove_child(child)
		child.free()

static func apply_avatar(player: PlayerMotor, avatar_id: String) -> void:
	var body := current_body(player)
	if body == null: return # Nonpixel/historical Courier consumers keep their body.
	var want_new := avatar_id != "courier_classic"
	if (body is PlayerMotionCandidateVisual) != want_new:
		_remove(player, "MotionFeel")
		_remove(player, "WeaponFeel")
		var body_name := str(body.name)
		player.remove_child(body)
		body.free()
		body = make_body(player, player.get_node("Controller") as PlayerController, body_name, avatar_id)
		player.add_child(body)
	attach(player)

static func attach(player: PlayerMotor) -> void:
	var body := current_body(player)
	if body == null: return
	var audio := player.get_tree().get_first_node_in_group(&"game_audio") as PlayerWeaponFeelAudioV2
	if audio == null: return
	var motion := player.get_node_or_null("MotionFeel") as PlayerMotionFeel
	if body is PlayerMotionCandidateVisual:
		if motion != null and (motion.visual != body or motion.audio != audio):
			_remove(player, "MotionFeel")
			motion = null
		if motion == null:
			motion = PlayerMotionFeel.new()
			motion.name = "MotionFeel"
			motion.visual = body as PlayerMotionCandidateVisual
			motion.audio = audio
			player.add_child(motion)
	elif motion != null:
		_remove(player, "MotionFeel") # Its exit restores original jump/land listeners.
	var weapon := player.get_node_or_null("WeaponFeel") as PlayerWeaponFeelV2
	if weapon != null and weapon.audio != audio:
		_remove(player, "WeaponFeel")
		weapon = null
	if weapon == null:
		# Home assembles before its first physics tick; use the original lazy
		# Runtime accessor instead of assuming the preview's startup wait occurred.
		body.controller.shoot_ability.behavior()
		weapon = WeaponFeel.new()
		weapon.name = "WeaponFeel"
		weapon.controller = body.controller
		weapon.audio = audio
		weapon.profile = WEAPON_PROFILE
		player.add_child(weapon)
	if is_instance_valid(weapon.renderer): weapon.renderer.catch_visual = body
