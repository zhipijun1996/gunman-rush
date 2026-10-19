class_name PixelPlainsActor
extends WindchimeActorVisual
## All clusters use two world units, shared with the actual low-resolution view.
var _hurt_remaining := 0.0
var _dead := false
var _death_age := 0.0

func _ready() -> void:
	super._ready()
	_dead = controller.actor_resources.health.terminal
	controller.actor_resources.health.changed.connect(_health_changed)
	controller.died.connect(_accepted_death)

func _health_changed(result: ActorResourceResult) -> void:
	if result == null or result.status != ActorResourceResult.Status.APPLIED: return
	if result.operation == &"damage" and result.amount_applied < 0:
		if result.snapshot != null and result.snapshot.terminal:
			_accepted_death()
		else:
			_hurt_remaining = .18
	queue_redraw()

func _accepted_death() -> void:
	if not _dead: _death_age = 0.0
	_dead = true
	_hurt_remaining = 0.0
	_flash = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	super._process(delta)
	_hurt_remaining = maxf(0,_hurt_remaining-delta)
	# Only the real health terminal flag owns death; inactive menus do not.
	if controller.actor_resources.health.terminal:
		if not _dead: _accepted_death()
		_death_age += delta
	elif _dead:
		_dead = false
		_death_age = 0.0
	modulate = Color(1,.68,.58) if _hurt_remaining>0 and int((.18-_hurt_remaining)*35)%2==0 else Color.WHITE

func _draw() -> void:
	if _dead:
		# A floor-anchored fallen hood and four bounded motes; no Motor writes.
		var opacity := maxf(.25,1-_death_age/.65)
		draw_rect(Rect2(-16,8,30,8),Color("111e2b",opacity))
		draw_rect(Rect2(-14,6,16,8),Color("c77f68",opacity))
		draw_rect(Rect2(2,10,12,4),Color("ead39a",opacity))
		for i: int in 4:
			var p := Vector2(-10+i*8,-2-2*roundf(_death_age*(12+i*3)))
			draw_rect(Rect2(p,Vector2(2,2)),Color("ead39a",maxf(0,1-_death_age/.45)))
		return
	var ink := Color("111e2b")
	var cream := Color("ead39a")
	var rose := Color("c77f68")
	var face := 1.0 if controller.router.aim_direction.x >= 0 else -1.0
	var stride := 2.0 * roundf(sin(_clock*15)*2) if motor.is_on_floor() and absf(motor.velocity.x)>10 else 0.0
	draw_set_transform(Vector2.ZERO,0,Vector2(face,1))
	draw_rect(Rect2(-8,6,6,10),ink)
	draw_rect(Rect2(2,6,6,10),ink)
	draw_rect(Rect2(-10+stride,14,8,4),ink)
	draw_rect(Rect2(2-stride,14,10,4),ink)
	draw_rect(Rect2(-8,-6,16,14),Color("6e9180"))
	draw_rect(Rect2(-4,-6,10,12),cream)
	draw_rect(Rect2(-10,-20,18,18),rose)
	draw_rect(Rect2(-12,-16,22,10),rose)
	draw_rect(Rect2(0,-16,12,10),ink)
	draw_rect(Rect2(6,-14,4,4),cream)
	var flutter := 2 * roundi(sin(_clock*5))
	draw_rect(Rect2(-22,-6+flutter,18,4),rose)
	draw_rect(Rect2(-32,-4+flutter,14,4),rose)
	draw_rect(Rect2(-36,0+flutter,12,2),Color("a66d45"))
	draw_set_transform(Vector2.ZERO)
	var aim := controller.router.aim_direction.normalized()
	var anchor := motor.get_node("CourierVisual") as CourierVisual
	var muzzle := to_local(anchor.visible_muzzle_position()).snapped(Vector2(2,2))
	var hand := Vector2(face*4,0)
	_pixel_line(hand,muzzle,ink,4)
	_pixel_line(hand+aim*10-Vector2(0,2),muzzle-Vector2(0,2),Color("a66d45"),2)
	if _flash>0: draw_rect(Rect2(muzzle+aim*4-Vector2(2,2),Vector2(6,6)),cream)

func _pixel_line(a: Vector2,b: Vector2,color: Color,width: float) -> void:
	var count := maxi(1,ceili(a.distance_to(b)/2))
	for i: int in count+1:
		var p := a.lerp(b,float(i)/count).snapped(Vector2(2,2))
		draw_rect(Rect2(p-Vector2.ONE*width*.5,Vector2.ONE*width),color)
