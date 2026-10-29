extends Node2D
## Graybox follows actual accepted state; never drives movement or damage.
@export var actor: EnemyActor
var hit_template: EnemyHitTemplate
var motion: ForestMotion02
func _ready() -> void:
	hit_template = EnemyHitTemplate.install(actor, self)
	motion = ForestMotion02.install(self)
	motion.sync_epoch(actor)
	actor.health.changed.connect(_motion_initialized)
func _motion_initialized(result: ActorResourceResult) -> void:
	if result == null or result.snapshot == null or result.operation != &"initialize" or result.snapshot.epoch != actor.health.epoch: return
	motion.sync_epoch(actor)
	queue_redraw()
func _exit_tree() -> void:
	if is_instance_valid(actor) and actor.health.changed.is_connected(_motion_initialized):
		actor.health.changed.disconnect(_motion_initialized)
func _process(delta: float) -> void:
	if get_tree().paused: return
	motion.advance(actor, delta)
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(actor):return
	if actor.health.terminal and motion.death_elapsed >= ForestMotion02.DEATH_SECONDS:return
	var behavior:=actor.attack_behavior as ForestCrossbranchBehavior
	var color:=Color("b3ca74")
	if behavior!=null and behavior.state==&"telegraph":color=Color("f3c365")
	if behavior!=null and behavior.state==&"blocked":color=Color("aa7272")
	color = hit_template.tint(color)
	if not ForestBibleActors.draw_enemy_body(self, actor):
		hit_template.begin_body(self)
		draw_rect(Rect2(-14,-16,28,32),color)
		draw_line(Vector2(-20,-10),Vector2(-7,-1),hit_template.tint(Color("536f58")),4)
		draw_line(Vector2(20,-10),Vector2(7,-1),hit_template.tint(Color("536f58")),4)
		draw_circle(Vector2(-5,-5),2,hit_template.tint(Color("243a32")));draw_circle(Vector2(5,-5),2,hit_template.tint(Color("243a32")))
		draw_set_transform(Vector2.ZERO)
	if not actor.health.terminal and behavior!=null and behavior.state==&"telegraph" and behavior.committed_shore>=0:
		var goal: Vector2=to_local(behavior.shores[behavior.committed_shore].position)
		draw_line(Vector2.ZERO,goal,Color(1,.75,.3,.5),2,true)
		draw_arc(goal,20,0,TAU,24,Color("f3c365"),2,true)
