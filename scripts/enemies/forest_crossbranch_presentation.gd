extends Node2D
## Graybox follows actual accepted state; never drives movement or damage.
@export var actor: EnemyActor
var hit_template: EnemyHitTemplate
func _ready() -> void:
	hit_template = EnemyHitTemplate.install(actor, self)
func _process(_delta: float) -> void:queue_redraw()
func _draw() -> void:
	if not is_instance_valid(actor):return
	if actor.health.terminal:return
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
	if behavior!=null and behavior.state==&"telegraph" and behavior.committed_shore>=0:
		var goal: Vector2=to_local(behavior.shores[behavior.committed_shore].position)
		draw_line(Vector2.ZERO,goal,Color(1,.75,.3,.5),2,true)
		draw_arc(goal,20,0,TAU,24,Color("f3c365"),2,true)
