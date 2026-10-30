extends ShotLatch
## New isolated Cell: a real native Area2D senses the authored moving body.
## Original ShotLatch keeps its gate collision, clock and anti-pinch close.
var sensor_rect:=Rect2()
var carrier_id:=""
var sensor:Area2D
var occupants:Array[Node2D]=[]
var last_occupied:=false
var recorder
func _register_shot(_direction:Vector2,_shot_id:int)->void:
	pass
func configure_dock()->void:
	bell_body.collision_layer=0
	sensor=Area2D.new();sensor.collision_layer=0;sensor.collision_mask=1
	sensor.position=sensor_rect.get_center()
	var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=sensor_rect.size;shape.shape=rectangle;sensor.add_child(shape);add_child(sensor)
	sensor.body_entered.connect(func(body:Node2D):
		if body not in occupants:occupants.append(body))
	sensor.body_exited.connect(func(body:Node2D):occupants.erase(body))
	queue_redraw()
func _physics_process(delta:float)->void:
	super._physics_process(delta)
	var occupied:=false
	for body:Node2D in occupants:
		if is_instance_valid(body) and body is ModuleMovingPlatform and str(body.definition.platform_id)==carrier_id:occupied=true
	if occupied:
		_opened_at=_clock
		if not is_open:
			is_open=true;open_count+=1;gate_body.collision_layer=0;gate_shape.set_deferred("disabled",true);opened.emit()
	if occupied!=last_occupied:
		if recorder!=null:recorder.events.append({"frame":recorder.context.frame,"type":"dock_occupied","id":link_id,"occupied":occupied,"carrier_id":carrier_id})
		last_occupied=occupied;queue_redraw()
func _draw()->void:
	if not gate_rect.has_area():return
	_draw_gate(gate_rect,.15 if is_open else 1.)
	draw_rect(sensor_rect,Color(.2,.8,.35,.45) if last_occupied else Color(.9,.65,.2,.4))
	draw_rect(sensor_rect,Color("e8bd65"),false,2)
	draw_string(ThemeDB.fallback_font,sensor_rect.position+Vector2(-12,-12),"CARRIER DOCK",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e8bd65"))
