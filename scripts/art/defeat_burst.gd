class_name DefeatBurst
extends Node2D
var mini:=false
var age:=0.0
func _ready()->void:
	z_index=8
	GameAudio.cue(self,&"boss_impact")
	var camera:=get_viewport().get_camera_2d()
	if camera is StageCameraRig:camera.add_impulse(5,.4)
func _process(delta:float)->void:
	age+=delta;queue_redraw()
	if age>=.9:queue_free()
func _draw()->void:
	var t:=clampf(age/.9,0,1)
	var size:float=(130 if mini else 220)*(.35+.65*sin(minf(1,t*2)*PI/2))
	var source:Rect2=PlainsCohesionArt.MINI_BURST if mini else PlainsCohesionArt.WIND_BURST
	draw_texture_rect_region(PlainsCohesionArt.ATLAS,Rect2(Vector2.ONE*-size/2,Vector2.ONE*size),source,Color(1,1,1,pow(1-t,.7)))
	for i:int in 12:
		var direction:=Vector2.from_angle(float(i)*TAU/12)
		var point:=direction*(15+age*95)+Vector2(0,age*age*35)
		draw_line(point,point+direction*5,Color(1,.85,.43,1-t),2)
