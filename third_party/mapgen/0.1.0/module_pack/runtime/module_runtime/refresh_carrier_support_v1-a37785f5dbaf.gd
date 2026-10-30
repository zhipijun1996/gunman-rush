extends Node
## A narrow Cell adapter for original EnemyMotor, which lacks platform carry.
## Consume actual platform displacement through Godot collision movement only.
## No transform assignment, parenting attachment, AI/health/resource mutation.
var actor: EnemyActor
var platform: ModuleMovingPlatform
var previous_platform:=Vector2.ZERO
var carried_distance:=0.0
var carried_frames:=0
var blocked_frames:=0
func configure(enemy: EnemyActor, ferry: ModuleMovingPlatform) -> void:
	actor=enemy;platform=ferry;previous_platform=ferry.global_position
	process_physics_priority=-80
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(platform):return
	var before:=previous_platform;var step:=platform.global_position-before;previous_platform=platform.global_position
	if actor.health.terminal:return
	var body: EnemyMotor=actor.get_parent();var feet:=body.global_position.y+actor.definition.collision_size.y/2
	var supported:=absf(feet-(before.y-platform.definition.size.y/2))<=.25 and absf(body.global_position.x-before.x)+actor.definition.collision_size.x/2<=platform.definition.size.x/2+.25
	if not supported or step.is_zero_approx():return
	var collision:=body.move_and_collide(step)
	carried_frames+=1;carried_distance+=step.length()
	if collision!=null:blocked_frames+=1
func snapshot() -> Dictionary:
	return {"actor":str(actor.definition.stable_id) if is_instance_valid(actor) else "freed","carrier":str(platform.definition.platform_id),"carried_frames":carried_frames,"carried_distance":carried_distance,"blocked_frames":blocked_frames,"movement":"native move_and_collide only"}
