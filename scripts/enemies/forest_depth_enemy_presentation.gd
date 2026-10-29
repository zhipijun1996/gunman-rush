class_name ForestDepthEnemyPresentation
extends Node2D
@export var actor: EnemyActor
var age := 0.0
var hit_template: EnemyHitTemplate
var motion: ForestMotion02
var lifecycle := EnemyPresentationLifecycle.new()
func _ready() -> void:
	if EnemyPresentationBinding.bind_existing(actor,self,&"forest").is_empty(): return
	hit_template = EnemyHitTemplate.install(actor, self)
	motion = ForestMotion02.install(self)
	lifecycle.bind(actor,self,_presentation_initialized,Callable(),motion)
	lifecycle.own_cleanup(hit_template.dispose)
func _presentation_initialized() -> void:
	age = 0.0
	queue_redraw()
func synchronize_presentation() -> void:
	lifecycle.synchronize()
func _exit_tree() -> void:
	lifecycle.dispose()
func _process(delta: float) -> void:
	if not lifecycle.advance(delta): return
	age += delta
	queue_redraw()
func _draw() -> void:
	if not lifecycle.is_bound(): return
	if not is_instance_valid(actor): return
	var alive := not actor.health.terminal
	var behavior := actor.attack_behavior
	var state: StringName = lifecycle.read_state().get("state",&"idle")
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
		# Silk is an attack object, not a preview of a future path. The body
		# performs its loading pose before the strand begins to extend.
		if state in [&"extend",&"hold",&"retract"]:
			var a := to_local(spider.line_start)
			var b := to_local(spider.line_end)
			var color := Color("ffbc68") if not spider.line_active else Color("ef6065")
			draw_line(a,b,Color(color,.20),(actor.definition as ForestEnemyDefinition).line_radius*2)
			draw_line(a,b,color,2 if not spider.line_active else 4)
