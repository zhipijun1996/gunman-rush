extends Node2D
## Paper puppet consumes live Motors and accepted events. No motion authority.
var app: FixedWorldApp
var shapes: RefCounted
var motor: Node2D
var enemy: EnemyActor
var puppet: Node2D
var legs: Array[Node2D] = []
var scarf: Node2D
var weapon: Node2D
var flash: Polygon2D
var shadow: Polygon2D
var age := 0.0
var shot_age := 1.0
var facing := 1.0
var hurt_age := 0.0
var warning: Node2D
var accepted_aim := Vector2.RIGHT

func _ready() -> void:
	puppet = Node2D.new()
	add_child(puppet)
	shadow = shapes.polygon(self,shapes.ellipse(Vector2.ZERO,Vector2(17,3)),Color("163c3b",.22),-1,false)
	if enemy == null: _hero()
	else: _enemy()
	_palette_mask(puppet)
	if weapon != null:_palette_mask(weapon)

func _hero() -> void:
	for side: int in 2:
		var leg := Node2D.new()
		leg.position = Vector2(-5+side*10,6)
		puppet.add_child(leg)
		shapes.sheet(leg,PackedVector2Array([Vector2(-3,-2),Vector2(3,-2),Vector2(4,10),Vector2(7,12),Vector2(-4,12)]),Color("284c4e"),0,1)
		legs.append(leg)
	scarf = Node2D.new()
	scarf.position = Vector2(-7,-7)
	puppet.add_child(scarf)
	shapes.sheet(scarf,PackedVector2Array([Vector2(1,-2),Vector2(-11,-1),Vector2(-20,6),Vector2(-35,5),Vector2(-27,11),Vector2(-15,10),Vector2(-4,3)]),Color("b65c48"),0,1)
	shapes.sheet(puppet,PackedVector2Array([Vector2(-9,-6),Vector2(7,-7),Vector2(12,9),Vector2(0,11),Vector2(-12,8)]),Color("d3aa63"),1,1.5)
	shapes.polygon(puppet,PackedVector2Array([Vector2(-4,-6),Vector2(1,-5),Vector2(0,10),Vector2(-6,9)]),Color("f1ddb0"),2)
	shapes.sheet(puppet,PackedVector2Array([Vector2(-13,-9),Vector2(-13,-21),Vector2(-6,-27),Vector2(7,-24),Vector2(13,-15),Vector2(9,-5),Vector2(-6,-5)]),Color("c88f61"),3,1.5)
	shapes.sheet(puppet,PackedVector2Array([Vector2(-1,-20),Vector2(9,-19),Vector2(12,-14),Vector2(8,-8),Vector2(-2,-9),Vector2(-5,-14)]),Color("234d52"),4,1)
	shapes.polygon(puppet,shapes.ellipse(Vector2(6,-15),Vector2(2,2.5),0,12),Color("f8d690"),5)
	shapes.sheet(puppet,PackedVector2Array([Vector2(-11,-8),Vector2(8,-9),Vector2(12,-5),Vector2(-8,-3)]),Color("b65c48"),5,1)
	weapon = Node2D.new()
	weapon.position = Vector2(5,0)
	add_child(weapon)
	shapes.sheet(weapon,PackedVector2Array([Vector2(-3,-3),Vector2(21,-3),Vector2(24,1),Vector2(11,4),Vector2(5,10),Vector2(0,8),Vector2(2,3)]),Color("31575a"),0,1)
	shapes.polygon(weapon,shapes.rect_points(Rect2(8,-3,13,2)),Color("dfbd79"),1)
	flash = shapes.polygon(weapon,PackedVector2Array([Vector2(24,-2),Vector2(32,-6),Vector2(29,-1),Vector2(37,1),Vector2(29,3),Vector2(31,8),Vector2(24,4)]),Color("ffe8ac"),2,false)
	app.controller.shoot_ability.shot_fired.connect(_shot)
	app.controller.actor_resources.health.changed.connect(_hurt)
	var light := PointLight2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1,1,1,.7),Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(1,.5)
	light.texture = texture
	light.texture_scale = 1.5
	light.energy = .10
	light.color = Color("ffe1a1")
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.position = Vector2(8,-9)
	add_child(light)

func _enemy() -> void:
	var half: Vector2 = enemy.definition.collision_size*.5
	var body_color := Color("a85a4b")
	var p := PackedVector2Array([Vector2(-half.x,half.y-3),Vector2(-half.x*.85,-half.y*.65),Vector2(-half.x*.2,-half.y),Vector2(half.x*.65,-half.y*.8),Vector2(half.x,half.y-3)])
	shapes.sheet(puppet,p,body_color,1,2)
	shapes.sheet(puppet,PackedVector2Array([Vector2(-half.x-2,half.y-7),Vector2(half.x+2,half.y-7),Vector2(half.x+3,half.y-1),Vector2(-half.x-3,half.y-1)]),Color("d0a368"),2,1.5)
	shapes.sheet(puppet,shapes.ellipse(Vector2(0,-half.y*.25),half*Vector2(.64,.4),0,16),Color("354e4d"),2,1)
	for side: int in 2:
		shapes.polygon(puppet,shapes.ellipse(Vector2(-4+side*8,-half.y*.25),Vector2(2,3),0,10),Color("ffe2a1"),3)
	shapes.line(puppet,PackedVector2Array([Vector2(-4,-half.y),Vector2(2,-half.y-8),Vector2(6,-half.y-5)]),Color("3c5852"),2,2)
	warning = Node2D.new()
	add_child(warning)
	shapes.polygon(warning,PackedVector2Array([Vector2(-2,-half.y-25),Vector2(3,-half.y-25),Vector2(1,-half.y-16)]),Color("a04437"),5)
	shapes.polygon(warning,shapes.ellipse(Vector2(0,-half.y-12),Vector2(2,2),0,8),Color("a04437"),5)
	if enemy.definition.aerial:
		for side: int in [-1,1]:
			var wing := Node2D.new()
			wing.position = Vector2(side*half.x*.65,0)
			puppet.add_child(wing)
			shapes.sheet(wing,PackedVector2Array([Vector2.ZERO,Vector2(side*24,-15),Vector2(side*20,1),Vector2(side*9,8)]),Color("b5b489"),0,1.5)
			legs.append(wing)
	else:
		for side: int in 2:
			var leg := Node2D.new()
			leg.position = Vector2(-half.x*.6+side*half.x*1.2,half.y-3)
			puppet.add_child(leg)
			shapes.sheet(leg,shapes.rect_points(Rect2(-4,-3,9,3)),Color("334f4d"),0,1)
			legs.append(leg)
	enemy.damageable.damaged.connect(_enemy_hurt)

func _shot(axis: Vector2, _id: int) -> void:
	shot_age = 0
	accepted_aim = axis
func _hurt(result: ActorResourceResult) -> void:
	if result != null and result.operation == &"damage" and result.amount_applied<0: hurt_age = .2
func _enemy_hurt(_context: Dictionary) -> void: hurt_age = .18

func _process(delta: float) -> void:
	if not is_instance_valid(motor):hide();return
	global_position = motor.global_position
	age += delta
	shot_age += delta
	hurt_age = maxf(0,hurt_age-delta)
	puppet.modulate = Color(1.8,1.4,1.1) if hurt_age>0 and int(hurt_age*35)%2==0 else Color.WHITE
	var speed: Vector2 = motor.get("velocity")
	var stride := sin(age*18)*clampf(absf(speed.x)/180,0,1)
	if enemy == null:
		var accepted: Vector2 = app.player.normal_velocity
		if absf(accepted.x)>5:facing = signf(accepted.x)
		puppet.scale.x = facing
		scarf.rotation = sin(age*5)*.05+clampf(-speed.x/1000,-.25,.25)
		for i: int in legs.size():legs[i].rotation = stride*.4*(-1 if i==0 else 1)
		var aim: Vector2 = app.controller.router.aim_direction.normalized()
		if shot_age<.18:aim = accepted_aim
		if aim.is_zero_approx():aim = Vector2(facing,0)
		weapon.rotation = aim.angle()
		weapon.position.x = facing*5
		flash.visible = shot_age<.08
		if app.controller.actor_resources.health.terminal:
			puppet.rotation = 1.3
			weapon.hide()
		else:
			puppet.rotation = clampf(speed.x*.0001,-.06,.06)
			weapon.show()
	else:
		var state: StringName = enemy.attack_behavior.state if enemy.attack_behavior!=null else &"idle"
		warning.visible = state==&"telegraph" and not enemy.health.terminal
		puppet.scale.y = .87 if state==&"telegraph" else 1.0
		puppet.position.y = enemy.definition.collision_size.y*.065 if state==&"telegraph" else 0.0
		puppet.rotation = .12*enemy.brain.direction if state==&"attack" else 0.0
		if enemy.health.terminal:
			puppet.rotation = 1.2
			puppet.modulate.a = .45
		else:
			for i: int in legs.size():legs[i].rotation = (sin(age*13)*.25 if enemy.definition.aerial else stride*.4)*(-1 if i==0 else 1)
	var ground := INF
	for platform: Rect2 in app.room.platforms:
		if global_position.x>=platform.position.x and global_position.x<=platform.end.x and platform.position.y>=global_position.y:ground = minf(ground,platform.position.y)
	var distance := ground-global_position.y
	shadow.visible = distance<110
	if shadow.visible:
		shadow.position.y = distance-1
		shadow.modulate.a = clampf(1-(distance-18)/100,0,1)
		shadow.scale.x = lerpf(1,.6,clampf((distance-18)/100,0,1))

func _palette_mask(node: Node) -> void:
	if node is CanvasItem:node.light_mask=2
	for child: Node in node.get_children():_palette_mask(child)
