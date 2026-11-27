class_name MapViewport
extends Control
## Shared map projection, gestures and theme; no level/provider dependency.
signal open_requested
var expanded := false
var region_chip := false
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var _touches: Dictionary = {}
var _pinch_distance := 0.0

func _world_rect() -> Rect2:
	return Rect2(0,0,1,1)
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	focus_mode=Control.FOCUS_ALL
	if not expanded: size=Vector2(160,32) if region_chip else Vector2(240,156)
func _process(_delta: float) -> void: queue_redraw()
func frame() -> Rect2:
	return Rect2(16,16,maxf(1,size.x-32),maxf(1,size.y-32)) if expanded else Rect2(8,30,224,100)
func _fit_scale() -> float:
	var bounds:=_world_rect()
	return minf(frame().size.x/bounds.size.x,frame().size.y/bounds.size.y)
func project(p: Array) -> Vector2:
	return project_point(Vector2(p[0],p[1]))
func project_point(p: Vector2) -> Vector2:
	return frame().get_center()+(p-_world_rect().get_center())*_fit_scale()*zoom+pan
func zoom_at(factor: float, anchor: Vector2) -> void:
	if not expanded or not is_finite(factor) or factor<=0: return
	var next:=clampf(zoom*factor,1.0,6.0)
	var relative:=anchor-frame().get_center()
	pan=relative-(relative-pan)*(next/zoom)
	zoom=next
	_limit_pan()
	queue_redraw()
func drag_by(amount: Vector2) -> void:
	if not expanded or not amount.is_finite(): return
	pan+=amount
	_limit_pan()
	queue_redraw()
func _limit_pan() -> void:
	var limit:=frame().size*zoom*0.75
	pan=pan.clamp(-limit,limit)
func reset_view() -> void:
	zoom=1
	pan=Vector2.ZERO
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if not expanded:
		if (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed) or event.is_action_pressed("ui_accept"):
			open_requested.emit()
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: zoom_at(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.2,event.position)
	elif event is InputEventMouseMotion and dragging: drag_by(event.relative)
	elif event is InputEventMagnifyGesture: zoom_at(event.factor,event.position)
	elif event is InputEventScreenTouch:
		if event.pressed: _touches[event.index]=event.position
		else: _touches.erase(event.index)
		_pinch_distance=0
	elif event is InputEventScreenDrag:
		_touches[event.index]=event.position
		if _touches.size()==1: drag_by(event.relative)
		elif _touches.size()==2:
			var points:=_touches.values()
			var distance: float=points[0].distance_to(points[1])
			if _pinch_distance>1: zoom_at(distance/_pinch_distance,(points[0]+points[1])*0.5)
			_pinch_distance=distance
	accept_event()
func panel() -> StyleBoxFlat:
	var material := preload("res://game/presentation/ui/demo_ui_01/clockwork_theme.gd")
	var highlighted := not expanded and (has_focus() or Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()))
	return material.plate(material.RAISED if highlighted else material.PANEL, material.BRASS if highlighted else material.EDGE, 4)
