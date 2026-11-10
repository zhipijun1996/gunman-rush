class_name WorldChargingStation
extends Node2D
## Open brass alcove: back wall, occupant, contact arcs, then stone sill.
const BACK := preload("res://assets/player_presentation_01/charging/station.png")
const FRONT := preload("res://assets/player_presentation_01/charging/station_front.png")
var charge := 0.0
var success := 0.0
var age := 0.0

func _ready() -> void:
	position.y+=preload("res://game/presentation/world/station/rest_presentation.tres").base_embed
	z_index=0
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var rear:=Sprite2D.new()
	rear.texture=BACK;rear.centered=false;rear.position=Vector2(-48,-92);rear.z_index=-3
	add_child(rear)

func set_occupied(value: bool) -> void:
	z_index=2 if value else 0

func _process(delta: float) -> void:
	age+=delta
	success=maxf(0,success-delta*1.8)
	queue_redraw()

func _draw() -> void:
	var light:=.2+charge*.5+success*.2
	for side:float in [-1.0,1.0]:
		var contact:=Vector2(side*16,-25)
		draw_circle(contact,5,Color(.25,.75,.65,light*.12))
		draw_rect(Rect2(contact-Vector2(1,2),Vector2(2,4)),Color(.62,.94,.81,light))
		if charge>.01:
			for strand:int in 2:
				var path:=PackedVector2Array()
				for j:int in 6:
					var t:=float(j)/5
					var x:=side*(20-9*sin(t*PI)) + sin(age*13+j*2+strand*3)*1.6
					path.append(Vector2(roundf(x),roundf(-42+t*30+strand*5)))
				draw_polyline(path,Color(.45,.9,.8,charge*(.32+.12*sin(age*9+strand))),1)
	if charge>.01:
		var bridge:=PackedVector2Array()
		for i:int in 7:
			bridge.append(Vector2(-16+i*5.333, -25+sin(i*2+age*10)*2).round())
		draw_polyline(bridge,Color(.58,.95,.82,charge*.42),1)
		var travel:=fmod(age*2,1)*6
		var index:=mini(5,int(travel))
		var spark:=bridge[index].lerp(bridge[index+1],travel-index).round()
		draw_rect(Rect2(spark,Vector2(2,1)),Color(.82,1,.88,charge*.8))
	if success>0:
		draw_arc(Vector2(0,-28),22+(1-success)*8,PI*.12,PI*.88,16,Color(.7,.95,.83,success*.5),1)
	draw_texture(FRONT,Vector2(-48,-92))
