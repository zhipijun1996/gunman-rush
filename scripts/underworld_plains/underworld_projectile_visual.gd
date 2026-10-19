class_name UnderworldProjectileVisual
extends Node2D
## Explicit procedural pixel VFX, not generated illustration. No collision,
## damage, random stream, resource, time-scale or animation-completion gameplay.
const INK := Color("17241f")
const FRIEND := Color("f3dda0")
const FRIEND_EDGE := Color("aa854b")
const HOSTILE := Color("e29166")
const HOSTILE_EDGE := Color("8f4841")
const BELL := preload("res://assets/underworld_plains/actors/bell.png")
const EFFECT_LIFETIME := 0.18
var age := 0.0
var axis := Vector2.RIGHT
var friendly := true
var impact := false
var source: WeakRef

static func enabled(node: Node) -> bool:
	return UnderworldActors.enabled(node)

static func emit(origin: Node2D, at: Vector2, direction: Vector2, is_friendly: bool, is_impact: bool) -> UnderworldProjectileVisual:
	if not origin.is_inside_tree() or not enabled(origin): return null
	var effect := UnderworldProjectileVisual.new()
	effect.name = "ProjectileImpact" if is_impact else "ProjectileMuzzle"
	effect.axis = direction.normalized()
	effect.friendly = is_friendly
	effect.impact = is_impact
	effect.source = weakref(origin)
	# Sibling: an accepted contact may finish after the projectile is retired;
	# stage teardown still frees all effects. Cancelled shots emit no impact.
	origin.get_parent().add_child(effect)
	effect.global_position = at
	return effect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 9
	add_to_group(&"underworld_projectile_vfx")

func _process(delta: float) -> void:
	if not impact and source != null:
		var projectile: Node = source.get_ref()
		if not is_instance_valid(projectile) or bool(projectile.get("spent")):
			queue_free()
			return
	age += delta
	if age >= EFFECT_LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var strength := 1.0 - age / EFFECT_LIFETIME
	var color := FRIEND if friendly else HOSTILE
	color.a = strength
	var edge := FRIEND_EDGE if friendly else HOSTILE_EDGE
	edge.a = strength
	var spread := 3.0 + age * (58.0 if impact else 24.0)
	var base := axis.angle() + (PI if impact else 0.0)
	for i: int in 5 if impact else 3:
		var angle := base + (float(i) - (2.0 if impact else 1.0)) * 0.65
		var p := (Vector2.from_angle(angle) * spread).snapped(Vector2(2,2))
		draw_rect(Rect2(p - Vector2.ONE * 2, Vector2.ONE * 4), edge)
		draw_rect(Rect2(p, Vector2.ONE * 2), color)
	if age < 0.06:
		draw_rect(Rect2(-2,-2,4,4), color)

static func paint(canvas: Node2D, direction: Vector2, radius: float, elapsed: float, trail: Array[Vector2], kind: StringName, is_friendly: bool, skill: bool = false, blade_texture: Texture2D = null) -> void:
	var head := FRIEND if is_friendly else HOSTILE
	var edge := FRIEND_EDGE if is_friendly else HOSTILE_EDGE
	# Bounded world-space history, never a screen-sized glow. Trail uses each
	# true historical position so curved bells do not leave a straight fake ray.
	for i: int in range(1, trail.size()):
		var fade := float(i) / trail.size() * 0.6
		var c := edge
		c.a = fade
		var a := canvas.to_local(trail[i-1]).snapped(Vector2(2,2))
		var b := canvas.to_local(trail[i]).snapped(Vector2(2,2))
		canvas.draw_line(a,b,c,4 if skill else 2,false)
	var r := clampf(radius,3,13)
	canvas.draw_set_transform(Vector2.ZERO,direction.angle())
	if kind == &"bell":
		canvas.draw_set_transform(Vector2.ZERO,sin(elapsed*12)*0.15)
		var size := Vector2(20,20*float(BELL.get_height())/BELL.get_width())
		canvas.draw_texture_rect(BELL,Rect2(-size/2,size),false)
	elif kind == &"blade":
		if blade_texture != null:
			canvas.draw_set_transform(Vector2.ZERO,elapsed*20)
			canvas.draw_texture_rect(blade_texture,Rect2(-11,-11,22,22),false)
			canvas.draw_set_transform(Vector2.ZERO)
			return
		# Headless fixtures without an equipped catalog retain a blade silhouette.
		canvas.draw_set_transform(Vector2.ZERO,elapsed*20)
		for i: int in 4:
			canvas.draw_set_transform(Vector2.ZERO,elapsed*20+i*PI*.5)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-2,-3),Vector2(0,-11),Vector2(4,-3),Vector2(2,2)]),INK)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0,-3),Vector2(0,-8),Vector2(2,-3)]),head)
	elif is_friendly:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-11,-3),Vector2(1,-r-1),Vector2(8,0),Vector2(1,r+1),Vector2(-11,3)]),INK)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-8,-1),Vector2(1,-r+1),Vector2(6,0),Vector2(1,r-1),Vector2(-8,1)]),head)
		canvas.draw_rect(Rect2(-8,-1,8,2),edge)
		if skill:
			canvas.draw_line(Vector2(-12,-5),Vector2(0,-5),edge,2,false)
			canvas.draw_line(Vector2(-12,5),Vector2(0,5),edge,2,false)
	else:
		# Enemy seeds and boss rings retain a compact bright danger core with
		# a dark border; warm rust separates them from cream player shots.
		var points := PackedVector2Array([Vector2(-r-5,0),Vector2(-r,-r),Vector2(0,-r-2),Vector2(r+2,0),Vector2(0,r+2),Vector2(-r,r)])
		canvas.draw_colored_polygon(points,INK)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-r-2,0),Vector2(-r+2,-r+2),Vector2(0,-r),Vector2(r,0),Vector2(0,r),Vector2(-r+2,r-2)]),edge)
		canvas.draw_rect(Rect2(-2,-2,4,4),head)
		if kind == &"ring":
			canvas.draw_arc(Vector2.ZERO,r,0,TAU,12,head,2,false)
	canvas.draw_set_transform(Vector2.ZERO)
