class_name PlayerAuthoredPoses
extends RefCounted
## Presentation only. Wake is owned by the intro; wall poses consume Traversal.
const TEXTURE := preload("res://assets/player_presentation_01/wake_wall/poses.png")
const LOOK_TEXTURE := preload("res://assets/player_presentation_01/wake_wall/look.png")
const WAKE_HOLDS := [.55,.14,.16,.16,.18,.18,.14,.18]
const WAKE_SECONDS := 1.69
var waking := false
var age := 0.0
var frame := -1
var session := -1
var look_direction := 0.0
var look_age := 0.0
var look_return_age := 0.0

func begin_wake(controller: PlayerController) -> void:
	waking = true
	age = 0.0
	session = controller.session_id
	frame = 0

func clear() -> void:
	waking = false
	age = 0.0
	frame = -1
	look_direction = 0.0
	look_age = 0.0
	look_return_age = 0.0

func advance(delta: float, body: UnderworldPlayer) -> void:
	if body.controller.session_id != session and waking: clear()
	if body._dead or body._hurt_remaining > 0:
		clear()
		return
	frame = -1
	if waking:
		age += delta
		var elapsed := age
		frame = 7
		for i: int in WAKE_HOLDS.size():
			if elapsed < float(WAKE_HOLDS[i]):
				frame = i
				break
			elapsed -= float(WAKE_HOLDS[i])
	elif body.controller.active and body.controller.traversal.state == &"wall_attach":
		var traversal := body.controller.traversal
		body.facing = -traversal.wall_normal
		look_direction = 0.0
		frame = 8 if traversal.state_age < .08 else 9 if traversal.state_age < .16 else 10 if traversal.wall_slide_age <= traversal.definition.wall_hold_seconds else 10+posmod(int((traversal.wall_slide_age-traversal.definition.wall_hold_seconds)*5),2)

	else:
		var camera := body.get_viewport().get_camera_2d() as WorldCamera
		var requested := camera.accepted_look_direction() if camera != null and camera.target == body.motor else 0.0
		var available := body.controller.active and body.motor.is_on_floor() and absf(body.motor.normal_velocity.x)<10 and body._flash<=0 and not body.controller.router.aim_engaged and not body.controller.router.focus_heal_held()
		if not available:
			look_direction = 0.0
		elif requested != 0:
			if requested != look_direction: look_age = 0.0
			look_direction = requested
			look_age += delta
			look_return_age = 0.0
			frame = 12+(0 if requested<0 else 3)+(0 if look_age<.12 else 1+posmod(int((look_age-.12)*2),2))
		elif look_direction != 0:
			look_return_age += delta
			if look_return_age < .10:
				frame = 12+(0 if look_direction<0 else 3)
			else: look_direction = 0.0

func draw(body: UnderworldPlayer) -> void:
	var factor := UnderworldActors.HUMANOID_HEIGHT/46.0
	var target := Rect2(Vector2(-40,-58)*factor+Vector2(0,18),Vector2(80,64)*factor)
	body.draw_set_transform(Vector2.ZERO,0,Vector2(body.facing,1))
	if frame>=12:
		var index := frame-12
		body.draw_texture_rect_region(LOOK_TEXTURE,target,Rect2(index%3*80,index/3*64,80,64))
	else:
		body.draw_texture_rect_region(TEXTURE,target,Rect2(frame%4*80,frame/4*64,80,64))
	body.draw_set_transform(Vector2.ZERO)
