extends RefCounted
## Feed viewport-level fingers to the real touch overlay. Identifiers match
## independent fingers and remain owned until the corresponding lift.
var viewport: Viewport
var controls
var contacts := {}
const MOVE:=1
const JUMP:=2
const AIM:=3
const USE:=4

func attach(session: OrdinaryRoomSession) -> void:
	viewport=session.get_viewport()
	controls=session.get("touch_controls")
	contacts.clear()
	controls.set_enabled(true)

func finger(index: int, point: Vector2, down: bool) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=index
	event.position=point
	event.pressed=down
	viewport.push_input(event,true)
	if down: contacts[index]=point
	else: contacts.erase(index)

func lift(index: int) -> void:
	if contacts.has(index): finger(index,contacts[index],false)

func drag(index: int, point: Vector2) -> void:
	var event:=InputEventScreenDrag.new()
	event.index=index
	event.position=point
	event.relative=point-Vector2(contacts[index])
	contacts[index]=point
	viewport.push_input(event,true)

func move(axis: float) -> void:
	if is_zero_approx(axis):
		lift(MOVE)
		return
	if not contacts.has(MOVE): finger(MOVE,controls.left_center,true)
	drag(MOVE,controls.left_center+Vector2.RIGHT*axis*controls.radius)

func jump(down: bool) -> void:
	lift(JUMP)
	if down: finger(JUMP,controls.jump_center,true)

func fire(direction: Vector2) -> void:
	finger(AIM,controls.right_center,true)
	drag(AIM,controls.right_center+direction.normalized()*controls.radius)
	lift(AIM)

func tap(point: Vector2) -> void:
	finger(USE,point,true)
	lift(USE)
