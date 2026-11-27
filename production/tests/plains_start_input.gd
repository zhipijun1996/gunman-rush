extends RefCounted
## A fresh-save prelude for downstream field regression and camera takes. Move to
## the P01 ground weapon and use the same interaction as an ordinary player.
static func take_ground_gun(pilot: WorldGameHost) -> bool:
	if not is_instance_valid(pilot.active) or pilot.active.room.room_id!="P01": return false
	var room:=pilot.active
	for i: int in 180:
		await pilot.get_tree().physics_frame
		if room.controller.active and room.player.is_on_floor(): break
	if not room.controller.active or room.state.has("gun"): return false
	var target:=room.opening.position.x
	var direction:=signf(target-room.player.position.x)
	room.controller.router.set_move_axis(direction)
	for i: int in 180:
		await pilot.get_tree().physics_frame
		if (target-room.player.position.x)*direction<=2: break
	room.controller.router.set_move_axis(0)
	if not room.opening.can_reach(): return false
	room.controller.router.request_action(&"interact")
	for i: int in 20:
		await pilot.get_tree().physics_frame
		if room.state.has("gun") and room.controller.shoot_ability.enabled: return true
	return false
