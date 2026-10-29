class_name ForestDepthEnemyPresentation
extends Node2D
@export var actor: EnemyActor
var age := 0.0
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
	age = 0.0
	queue_redraw()
func _exit_tree() -> void:
	if is_instance_valid(actor) and actor.health.changed.is_connected(_motion_initialized):
		actor.health.changed.disconnect(_motion_initialized)
func _process(delta: float) -> void:
	if get_tree().paused: return
	motion.advance(actor, delta)
	age += delta
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(actor): return
	var alive := not actor.health.terminal
	var behavior := actor.attack_behavior
	var state: StringName = behavior.state if behavior else &"idle"
	var body_color := Color("756248") if alive else Color("393f38")
	body_color = hit_template.tint(body_color)
	if not ForestBibleActors.draw_enemy_body(self, actor, age):
		hit_template.begin_body(self)
		draw_circle(Vector2.ZERO,12,body_color)
		for side: int in [-1,1]:
			for i: int in 3:
				var elbow := Vector2(side*(16+i*3),-9+i*8)
				draw_line(Vector2(side*6,-4+i*3),elbow,hit_template.tint(Color("9aaa6a")),3)
				draw_line(elbow,elbow+Vector2(side*5,8),hit_template.tint(Color("9aaa6a")),2)
		draw_circle(Vector2(-4,-4),2,hit_template.tint(Color("ffdf94")))
		draw_circle(Vector2(4,-4),2,hit_template.tint(Color("ffdf94")))
		draw_set_transform(Vector2.ZERO)
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
