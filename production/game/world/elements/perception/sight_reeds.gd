@tool
class_name WorldSightReeds
extends Node2D
@export var element_id := ""
@export var state_scope := "attempt"
@export var section_id := "main"
@export var bounds := Rect2(0,0,160,128):
	set(value):
		bounds = value
		queue_redraw()
@export var initial_active := true
var active := true
var network: WorldLightNetwork

func element_bind(context: Dictionary) -> void:
	active = initial_active
	network = WorldLightNetwork.of(context.room)
	network.reeds.append(self)
	tree_exiting.connect(func(): network.reeds.erase(self),CONNECT_ONE_SHOT)
	z_index = -1
	queue_redraw()

func element_state() -> Dictionary: return {"active":active}
func element_can_receive(input: String, _value: bool) -> bool: return input == "set_active"
func element_propose(_input: String, value: bool) -> Dictionary: return {"active":value}
func element_restore(data: Dictionary) -> void:
	active = data.active
	queue_redraw()

func _draw() -> void:
	var amount := 1.0 if active else 0.23
	var height := bounds.size.y*amount
	var spacing := maxf(5, bounds.size.x/256)
	var i := 0
	var x := bounds.position.x
	while x < bounds.end.x:
		var sway := sin(i*2.47)
		var base := Vector2(x,bounds.end.y)
		var tip := Vector2(clampf(x+8*sway,bounds.position.x,bounds.end.x),bounds.end.y-height*(0.76+0.24*absf(sway)))
		var mid := base.lerp(tip,0.56)
		var color := Color("536849") if active else Color("685947")
		draw_line(base,tip,color,2)
		draw_line(mid,Vector2(clampf(mid.x+8*sway,bounds.position.x,bounds.end.x),mid.y-0.23*height),color.lightened(0.15),2)
		draw_rect(Rect2(tip,Vector2(minf(3,bounds.end.x-tip.x),minf(7,height))),Color("9a8962"))
		x += spacing; i += 1
