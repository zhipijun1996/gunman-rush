class_name ProjectileDrag
extends ProjectileField
@export var bounds := Rect2(0,0,192,128)
@export var speed_scale := 0.35
@export var factions: Array[String] = ["player","enemy"]
var mist_age := 0.0

func _process(delta: float) -> void:
	mist_age = fmod(mist_age+delta,TAU/.65)
	queue_redraw()

func _draw() -> void:
	var light := Color("c0d4ff").lerp(MechanismRegionArt.accent(self),.64)
	var rows := maxi(1,ceili(bounds.size.y/41.0))
	var cols := maxi(1,ceili(bounds.size.x/116.0))
	var band := bounds.size/Vector2(cols,rows)
	for y: int in rows:
		for x: int in cols:
			var wave := sin(mist_age*.65+y*2.4+x*1.5)
			var shimmer := .34+.13*wave
			var cell := bounds.position+Vector2(x,y)*band
			var lean := .08+.07*sin(y*4.2+x*1.8+mist_age*.65)
			var at := cell+Vector2(band.x*lean,0)
			var inset := band.y*(.10+.09*wave)
			var field := Rect2(at+Vector2(0,inset),Vector2(band.x*(1-lean*1.6),band.y-inset))
			if (x+y)%2==1:
				draw_set_transform(Vector2(field.get_center().x*2,0),0,Vector2(-1,1))
			ProjectileMechanismArt.paint(self,field,ProjectileMechanismArt.MIST,Color(light,shimmer))
			draw_set_transform_matrix(Transform2D.IDENTITY)
	for left: bool in [true,false]:
		var x := bounds.position.x if left else bounds.end.x
		var joint := Vector2(x,bounds.end.y-6)
		MechanismRegionArt.stamp(self,"mount",joint+Vector2(0,3),Vector2(17,14))
		draw_set_transform(joint,0 if left else PI)
		ProjectileMechanismArt.paint(self,Rect2(-5,-5,17,9),ProjectileMechanismArt.LENS)
		draw_set_transform_matrix(Transform2D.IDENTITY)
