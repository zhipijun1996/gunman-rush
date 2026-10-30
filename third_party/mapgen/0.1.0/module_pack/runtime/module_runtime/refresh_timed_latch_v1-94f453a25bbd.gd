extends ShotLatch
## Keep original projectile identity, lifetime, epoch, timer and safe-close path.
## Only allow an accepted new hit to restart this gate's existing finite timer.
func _register_shot(direction: Vector2, shot_id: int) -> void:
	var was_open:=is_open
	is_open=false
	super._register_shot(direction,shot_id)
	is_open=was_open

func _receive_projectile(hit: Dictionary) -> bool:
	var was_open:=is_open
	is_open=false
	var accepted:=super._receive_projectile(hit)
	is_open=was_open
	return accepted

func _commit_open(request: Dictionary) -> void:
	var was_open:=is_open
	is_open=false
	super._commit_open(request)
	if was_open and not is_open:is_open=was_open
	if is_open:bell_body.collision_layer=8
