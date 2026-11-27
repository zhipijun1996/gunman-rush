extends ArenaBossBehavior
var shell: EmberSpentShell
var shell_site := Vector2.ZERO

func configure(owner_actor: EnemyActor, target: PlayerController, damage_policy: FrameDamagePolicy, scope: DemoLifetime, id: StringName, safe_points: Array[Vector2]) -> void:
	super.configure(owner_actor,target,damage_policy,scope,id,safe_points)
	shell_site=Vector2(home.x+286,floor_y)

func strike_category() -> StringName:
	return &"enemy_body" if move_id==&"roll" else &"machine_solid"

func configure_head(at: Vector2, _player: Vector2, side: int) -> void:
	match move_id:
		&"roll":
			footprint=machine.collision_size
			attack_origin=at
			var span:=machine.engagement_span()
			attack_goal=Vector2(clampf(at.x+side*machine.reach,home.x+span.x+64,home.x+span.y-64),at.y)
		&"shed":
			if is_instance_valid(shell):
				move_id=&"vent"
				configure_head(at,_player,side)
				return
			footprint=Vector2(76,31)
			attack_goal=shell_site-Vector2(0,footprint.y/2)
			attack_origin=attack_goal+Vector2.UP*139
		&"vent":
			footprint=Vector2(82,32)
			attack_origin=at+Vector2(side*69,12)
			attack_goal=attack_origin+Vector2(side*115,-10)

func advance_body(delta: float) -> void:
	if move_id==&"roll":
		actor.motor.move_and_collide((attack_goal-actor.motor.global_position).limit_length(machine.attack_speed*delta))
	if move_id==&"shed" and state_time>=machine.attack_duration and not is_instance_valid(shell):
		shell=EmberSpentShell.new()
		shell.player=controller
		actor.motor.get_parent().add_child(shell)
		shell.global_position=shell_site

func active_rect(fraction: float) -> Rect2:
	if move_id==&"roll": return Rect2(actor.motor.global_position-footprint/2,footprint)
	if move_id==&"shed": return Rect2(attack_origin.lerp(attack_goal,pow(clampf(fraction,0,1),2))-footprint/2,footprint)
	return super.active_rect(fraction)

func _exit_tree() -> void:
	if is_instance_valid(shell): shell.queue_free()
	super._exit_tree()
