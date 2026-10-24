extends Node2D
## Readability graybox: bark shield and open back; hanging seed with rooted tether.
@export var actor: EnemyActor
var shield_flash := 0.0
var hit_template: EnemyHitTemplate
func _ready() -> void:
	hit_template = EnemyHitTemplate.install(actor, self)
	if actor.damageable is ForestBarkDamageable:
		(actor.damageable as ForestBarkDamageable).shield_contact.connect(func(_context: Dictionary)->void:shield_flash=.12)
func _process(delta: float) -> void:
	shield_flash=maxf(0,shield_flash-delta)
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(actor) or actor.health.terminal:return
	var behavior:=actor.attack_behavior
	var phase: StringName=behavior.state if behavior else &"idle"
	var warning:=phase==&"telegraph"
	var bible_body := ForestBibleActors.draw_enemy_body(self, actor)
	if actor.definition.behavior_id==&"forest_bark_beetle":
		var facing:=float(actor.brain.direction)
		if not bible_body:
			hit_template.begin_body(self)
			draw_rect(Rect2(-18,-12,36,24),hit_template.tint(Color("7a9c58")))
			# Vertical segmented bark plate identifies exactly the guarded side.
			for index: int in 3:
				draw_line(Vector2(facing*(14+index),-11+index*2),Vector2(facing*(14+index),11-index*2),Color("ffdd99") if shield_flash>0 else Color("694c39"),3)
			# Unplated back/top keep their ordinary damage affordance visible.
			draw_circle(Vector2(-facing*9,-5),4,hit_template.tint(Color("d3d68a")))
			for side: int in [-1,1]:
				for foot: int in 3:draw_line(Vector2(-12+foot*11,side*8),Vector2(-15+foot*11,side*14),Color("4c613d"),2)
			draw_set_transform(Vector2.ZERO)
		elif shield_flash > 0:
			draw_line(Vector2(facing*17,-11),Vector2(facing*17,11),Color("ffdd99"),2)
		if warning and behavior!=null:
			var goal:=to_local(behavior.attack_goal)
			draw_line(Vector2(0,13),goal+Vector2(0,13),Color("ffc36b"),3)
			draw_line(goal+Vector2(-facing*8,7),goal+Vector2(0,13),Color("ffc36b"),2)
	else:
		if bible_body: ForestBibleActors.draw_tether_attachment(self, actor)
		if behavior!=null:
			var root_world: Vector2 = behavior.home+Vector2(0,-(actor.definition as ForestEnemyDefinition).swing_rise-30)
			if bible_body:
				var attachment: Variant = get_meta(ForestBibleActors.TETHER_ATTACHMENT_METADATA,null)
				if attachment is Dictionary and attachment.get("actor_id") == actor.get_instance_id():
					root_world = attachment.tether_root
			var root := to_local(root_world)
			draw_line(root,Vector2(0,-13),Color("718c4d"),3)
			draw_circle(root,5,Color("9cae68"))
		if not bible_body:
			hit_template.begin_body(self)
			draw_colored_polygon(PackedVector2Array([Vector2(0,-15),Vector2(13,-5),Vector2(10,11),Vector2(0,15),Vector2(-10,11),Vector2(-13,-5)]),hit_template.tint(Color("b6bc65") if phase!=&"blocked" else Color("8b7863")))
			draw_arc(Vector2.ZERO,8,-PI*.8,PI*.8,18,Color("ece9ac"),2)
			draw_set_transform(Vector2.ZERO)
		if phase==&"turn":draw_arc(Vector2.ZERO,20,0,TAU,24,Color("bde0a4"),2)
