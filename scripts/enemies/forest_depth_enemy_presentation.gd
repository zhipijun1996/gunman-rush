class_name ForestDepthEnemyPresentation
extends Node2D
@export var actor: EnemyActor
var age := 0.0
func _process(delta: float) -> void:
	age += delta
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(actor): return
	var alive := not actor.health.terminal
	var behavior := actor.attack_behavior
	var state: StringName = behavior.state if behavior else &"idle"
	var body_color := Color("756248") if alive else Color("393f38")
	draw_circle(Vector2.ZERO,12,body_color)
	for side: int in [-1,1]:
		for i: int in 3:
			var elbow := Vector2(side*(16+i*3),-9+i*8)
			draw_line(Vector2(side*6,-4+i*3),elbow,Color("9aaa6a"),3)
			draw_line(elbow,elbow+Vector2(side*5,8),Color("9aaa6a"),2)
	draw_circle(Vector2(-4,-4),2,Color("ffdf94"))
	draw_circle(Vector2(4,-4),2,Color("ffdf94"))
	if behavior is ForestThreadSpiderBehavior and alive:
		var spider := behavior as ForestThreadSpiderBehavior
		if state in [&"telegraph",&"extend",&"hold",&"retract"]:
			var a := to_local(spider.line_start)
			var b := to_local(spider.line_end)
			var color := Color("ffbc68") if not spider.line_active else Color("ef6065")
			draw_line(a,b,Color(color,.20),(actor.definition as ForestEnemyDefinition).line_radius*2)
			draw_line(a,b,color,2 if not spider.line_active else 4)
			draw_circle(a,5,color,false,2)
			draw_circle(b,5,color,false,2)
