class_name WorldRecoilGuardVisual
extends Node2D
## Read-only protection feedback. A fading trail never means extended immunity.
var guard: WorldRecoilGuard
var trail: Array[Vector2] = []
var glow := 0.0
var protecting := false

func _ready() -> void:
	z_index=2
	var unlit:=CanvasItemMaterial.new()
	unlit.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material=unlit

func _process(delta: float) -> void:
	var enabled:=is_instance_valid(guard) and guard.is_protecting()
	if not enabled and glow<=0 and not protecting:return
	protecting=enabled
	glow=1.0 if protecting else maxf(0,glow-delta*12)
	if protecting:
		trail.push_front(global_position)
		if trail.size()>5:trail.pop_back()
	elif glow<=0:trail.clear()
	queue_redraw()

func _draw() -> void:
	if glow<=0:return
	for i: int in range(1,trail.size()):
		var fade:=glow*(1.0-float(i)/trail.size())*.65
		draw_line(to_local(trail[i-1])+Vector2(0,-6),to_local(trail[i])+Vector2(0,-6),Color(.65,.94,.87,fade),6-i,false)
	if not protecting:return
	var shell:=PackedVector2Array([Vector2(-16,-20),Vector2(0,-27),Vector2(16,-20),Vector2(20,3),Vector2(0,20),Vector2(-20,3),Vector2(-16,-20)])
	draw_polyline(shell,Color(.18,.48,.44,.8),5,false)
	draw_polyline(shell,Color(.86,1,.82,.95),2,false)
	draw_line(Vector2(-26,-12),Vector2(-20,-12),Color("f5ddb1"),2)
	draw_line(Vector2(20,9),Vector2(26,9),Color("f5ddb1"),2)
