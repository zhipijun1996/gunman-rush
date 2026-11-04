class_name RuntimeMapCarrierSupport
extends Node
## The original module-pack displacement observer, routed through EnemyMotor's
## native collision API. It never parents or teleports an enemy.
var actor: EnemyActor
var platform: ModuleMovingPlatform
var previous:=Vector2.ZERO
var warmup:=2
func setup(enemy: EnemyActor,carrier: ModuleMovingPlatform,frames: int) -> void:
	actor=enemy;platform=carrier;previous=carrier.global_position;warmup=frames;process_physics_priority=-80
func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(platform):return
	var before:=previous;var step:=platform.global_position-before;previous=platform.global_position
	if warmup>0:warmup-=1;return
	if actor.health.terminal or step.is_zero_approx():return
	var motor:=actor.get_parent() as EnemyMotor
	var half:=actor.definition.collision_size*.5
	var feet:=motor.global_position.y+half.y
	if absf(feet-(before.y-platform.definition.size.y*.5))<=.25 and absf(motor.global_position.x-before.x)+half.x<=platform.definition.size.x*.5+.25:
		motor.move_attack(step,false,delta)
