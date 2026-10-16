class_name ThornSeedProjectile
extends BossProjectile
## Ballistic seed becomes a short branch-local thorn patch. Signal goes to the
## existing BossProjectile -> coordinator -> FrameDamagePolicy consumer.
var encounter: Node
var owner_attack_epoch := -1
var target_session := -1
var origin := Vector2.ZERO
var goal := Vector2.ZERO
var flight_seconds := 1.0
var arc_height := 100.0
var zone_seconds := 0.4
var zone_size := Vector2(80, 30)
var age := 0.0
var landed := false
var committed := false
func advance(delta: float) -> void:
	if spent or not is_inside_tree() or delta <= 0: return
	if not is_instance_valid(encounter) or not encounter.active or encounter.health.terminal or not encounter.combat_target_active() or owner_attack_epoch != encounter.attack_epoch:
		dispose()
		return
	var target_controller := _target.get_node_or_null("Controller") as PlayerController
	if target_controller != null and target_controller.session_id != target_session:
		dispose()
		return
	age += delta
	if not landed:
		var t := clampf(age / flight_seconds, 0, 1)
		var next := origin.lerp(goal, t) + Vector2(0, -sin(PI * t) * arc_height)
		var ray := PhysicsRayQueryParameters2D.create(global_position, next, 1, [_owner_body.get_rid(), (_target as PhysicsBody2D).get_rid()])
		var collision := get_world_2d().direct_space_state.intersect_ray(ray)
		if not collision.is_empty() and (collision.position as Vector2).distance_to(goal) > radius * 2:
			dispose()
			return
		global_position = next
		if t >= 1:
			landed = true
			age = 0
			GameAudio.cue(self, &"bell")
	if landed:
		if age >= zone_seconds:
			dispose()
			return
		var shape := _target.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape != null and not committed:
			var target_bounds := shape.shape.get_rect()
			target_bounds.position += shape.global_position
			if bounds().intersects(target_bounds):
				committed = true
				hit.emit(_target, event_id, amount)
	queue_redraw()
func bounds() -> Rect2:
	return Rect2(goal - Vector2(zone_size.x * .5, zone_size.y), zone_size)
func _draw() -> void:
	if landed:
		draw_rect(Rect2(Vector2(-zone_size.x*.5, -zone_size.y), zone_size), Color(.8,.23,.32,.65))
		for x: int in range(-int(zone_size.x*.5), int(zone_size.x*.5), 14):
			draw_line(Vector2(x,0),Vector2(x+6,-zone_size.y),Color(1,.65,.34),3)
	else:
		draw_circle(Vector2.ZERO, radius, Color(.95,.64,.3))
		draw_arc(Vector2.ZERO,radius+3,0,TAU,16,Color(.4,.2,.3),2)
