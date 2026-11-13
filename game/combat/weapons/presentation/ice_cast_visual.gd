class_name IceCastVisual
extends RefCounted
## Bounded pixel geometry, drawn from accepted runtime/projectile ages only.
const EDGE := Color("407cbb")
const BLUE := Color("71d6ff")
const CORE := Color("e1fbff")
const INK := Color("102d47")

static func crystal(canvas:Node2D,at:Vector2,length:float,width:float,angle:float,fade:float=1.0)->void:
	canvas.draw_set_transform(at.snapped(Vector2(2,2)),angle)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-length*.6,0),Vector2(-length*.22,-width),Vector2(length*.55,-width*.35),Vector2(length,0),Vector2(length*.55,width*.35),Vector2(-length*.22,width)]),Color(INK,fade))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-length*.46,0),Vector2(-length*.15,-width*.72),Vector2(length*.48,-width*.2),Vector2(length*.85,0),Vector2(-length*.15,width*.72)]),Color(BLUE,fade))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-length*.38,0),Vector2(length*.8,0),Vector2(-length*.12,width*.56)]),Color(EDGE,fade))
	canvas.draw_line(Vector2(-length*.2,0),Vector2(length*.7,0),Color(CORE,fade),2,false)
	canvas.draw_set_transform(Vector2.ZERO)

static func charge(canvas:Node2D,muzzle:Vector2,axis:Vector2,progress:float)->void:
	var t:=clampf(progress,0,1)
	for i:int in 12:
		var angle:=i*TAU/12+t*3.0
		var radius:=lerpf(44,9,t)+sin(i*1.7)*3
		var point:=muzzle+Vector2.from_angle(angle)*radius
		canvas.draw_line(point.snapped(Vector2(2,2)),(point-Vector2.from_angle(angle)*5).snapped(Vector2(2,2)),Color(BLUE,.25+t*.65),2,false)
	for i:int in 3:
		var angle:=axis.angle()+i*TAU/3-t*2
		crystal(canvas,muzzle+Vector2.from_angle(angle)*(17-8*t),4+6*t,3,axis.angle(),.5+t*.5)
	PixelVfx.arc(canvas,muzzle,lerpf(27,14,t),t*3,t*3+PI*1.5,Color(EDGE,.45),1)
	PixelVfx.clip(canvas,&"charge",muzzle,fposmod(t*1.7,.999),0,Color(.58,.88,1,.35+t*.35))
	crystal(canvas,muzzle,4+10*t,2+5*t,axis.angle())

static func projectile(canvas:Node2D,axis:Vector2,age:float,history:Array[Vector2])->void:
	for i:int in range(1,history.size()):
		var strength:=float(i)/history.size()
		var a:=canvas.to_local(history[i-1]).snapped(Vector2(2,2))
		var b:=canvas.to_local(history[i]).snapped(Vector2(2,2))
		canvas.draw_line(a,b,Color(EDGE,strength*.32),14*strength,false)
		canvas.draw_line(a,b,Color(BLUE,strength*.65),5*strength,false)
	PixelVfx.clip(canvas,&"cold",Vector2.ZERO,fposmod(age/.8,1),axis.angle())
	var normal:=axis.orthogonal()
	for i:int in 4:
		var phase:=fposmod(age*2.5+i*.25,1)
		var point:Vector2=-axis*(15+phase*46)+normal*sin(age*23+i*2.4)*(7+phase*5)
		crystal(canvas,point,5-phase*2,2,axis.angle(),(1-phase)*.7)
	crystal(canvas,Vector2.ZERO,27,11,axis.angle())
	var glint_at:=axis*lerpf(-9,19,fposmod(age*3.5,1))
	canvas.draw_line(glint_at-axis*2-normal*2,glint_at+axis*3+normal*2,Color(CORE,.9),1,false)
	crystal(canvas,-axis*12+normal*10,12,4,axis.angle()+.12,.8)
	crystal(canvas,-axis*12-normal*10,12,4,axis.angle()-.12,.8)

static func burst(canvas:Node2D,at:Vector2,axis:Vector2,age:float,impact:bool)->void:
	var t:=clampf(age/.30,0,1)
	PixelVfx.clip(canvas,&"ice",at,t,axis.angle(),Color.WHITE,Vector2.ONE*(1.0 if impact else 1.2))
	var core:=maxf(0,1-t/.24)
	if core>0:
		PixelVfx.streak(canvas,at,-axis,14*core,2*core,CORE,core)
		PixelVfx.streak(canvas,at,axis,20*core,1.5*core,BLUE,core)
