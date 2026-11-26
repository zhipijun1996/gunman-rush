class_name ProjectileGrate
extends ProjectileField
@export var bounds := Rect2(0,0,32,128)
var body: StaticBody2D

func _ready() -> void:
	body = StaticBody2D.new()
	body.position = bounds.get_center()
	var shape := RectangleShape2D.new()
	shape.size = bounds.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _draw() -> void:
	var width := bounds.size.x
	var height := bounds.size.y
	var rod_count := maxi(1,ceili(width/16))
	var rod_width := minf(9,width/rod_count*.72)
	var y := bounds.position.y
	for i: int in rod_count:
		var x := bounds.position.x+(i+.5)*width/rod_count
		ProjectileMechanismArt.beam(self,Rect2(roundf(x-rod_width/2),y,rod_width,height),ProjectileMechanismArt.ROD,10,true)
	var rims := maxi(2,ceili(height/88.)+1)
	var rim_height := minf(6,height/rims)
	for i: int in rims:
		var top := lerpf(y,bounds.end.y-rim_height,float(i)/(rims-1))
		MechanismRegionArt.panel(self,Rect2(bounds.position.x,top,width,rim_height))
		for x: float in [bounds.position.x,bounds.end.x]:
			MechanismRegionArt.stamp(self,"mount",Vector2(x,top+rim_height/2),Vector2(8,9))
