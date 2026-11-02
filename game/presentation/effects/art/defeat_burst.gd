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
	if PixelFormalActors.pixel_context(self) or get_meta("pixel_style",false):
		var opacity := maxf(0,1-age/.9)
		for i: int in 16:
			var axis := Vector2.from_angle(i*TAU/16)
			var p := (axis*(12+age*(90 if mini else 150))+Vector2(0,age*age*35)).snapped(Vector2(2,2))
			draw_rect(Rect2(p,Vector2(4,4)),Color(PixelFormalActors.CREAM if i%2==0 else PixelFormalActors.MOSS,opacity))
		return
	var t:=clampf(age/.9,0,1)
	var size:float=(130 if mini else 220)*(.35+.65*sin(minf(1,t*2)*PI/2))
	var source:Rect2=PlainsCohesionArt.MINI_BURST if mini else PlainsCohesionArt.WIND_BURST
	draw_texture_rect_region(PlainsCohesionArt.ATLAS,Rect2(Vector2.ONE*-size/2,Vector2.ONE*size),source,Color(1,1,1,pow(1-t,.7)))
	for i:int in 12:
		var direction:=Vector2.from_angle(float(i)*TAU/12)
		var point:=direction*(15+age*95)+Vector2(0,age*age*35)
		draw_line(point,point+direction*5,Color(1,.85,.43,1-t),2)
