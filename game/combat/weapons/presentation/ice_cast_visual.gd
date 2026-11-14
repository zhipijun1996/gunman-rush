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
	var t:=clampf(progress,0,.98)
	PixelVfx.clip(canvas,&"focus-gather",muzzle,t,axis.angle(),Color(.65,.86,1,.9),Vector2(.75,.75))
	PixelVfx.glint(canvas,muzzle,1+3*t,CORE,t)

static func projectile(canvas:Node2D,axis:Vector2,age:float,history:Array[Vector2])->void:
	# Only the actual swept path can leave a trail. The shaped lance supplies
	# the front facets and cold-air wake, replacing the old oversized cluster.
	for i:int in range(1,history.size()):
		var strength:=float(i)/history.size()
		var a:=canvas.to_local(history[i-1]).round()
		var b:=canvas.to_local(history[i]).round()
		canvas.draw_line(a,b,Color(EDGE,strength*.25),6*strength,false)
		canvas.draw_line(a,b,Color(BLUE,strength*.45),2*strength,false)
	PixelVfx.clip(canvas,&"cold",axis*12,fposmod(age/.8,1),axis.angle())

static func burst(canvas:Node2D,at:Vector2,axis:Vector2,age:float,impact:bool)->void:
	var t:=clampf(age/.30,0,1)
	PixelVfx.clip(canvas,&"ice",at,t,axis.angle(),Color.WHITE,Vector2.ONE*(1.0 if impact else 1.2))
	var core:=maxf(0,1-t/.24)
	if core>0:
		PixelVfx.streak(canvas,at,-axis,14*core,2*core,CORE,core)
		PixelVfx.streak(canvas,at,axis,20*core,1.5*core,BLUE,core)
