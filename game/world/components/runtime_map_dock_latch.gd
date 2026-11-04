class_name RuntimeMapDockLatch
extends ShotLatch
## An actual Area2D watches the bound native carrier, not a matching name in
## another module. The inherited clock and anti-pinch close retain their rules.
var sensor: Area2D
var platform: ModuleMovingPlatform
var sensor_rect:=Rect2()
func _register_shot(_direction: Vector2,_id: int) -> void:pass
func _receive_projectile(_hit: Dictionary) -> bool:return false
func configure_dock(target: ModuleMovingPlatform,rectangle: Rect2) -> void:
	platform=target;sensor_rect=rectangle
	bell_body.collision_layer=0;gate_visual_enabled=true
	sensor=Area2D.new();sensor.collision_layer=0;sensor.collision_mask=1;sensor.position=rectangle.get_center()
	var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=rectangle.size;shape.shape=box;sensor.add_child(shape);add_child(sensor)
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _cancelled or not lifetime.active or not controller.active or controller.actor_resources.health.terminal:return
	if sensor.get_overlapping_bodies().has(platform):
		_opened_at=_clock
		if not is_open:
			is_open=true;open_count+=1;gate_body.collision_layer=0;gate_shape.set_deferred("disabled",true);opened.emit();queue_redraw()
func _draw() -> void:
	if gate_rect.has_area():_draw_gate(gate_rect,.18 if is_open else 1)
	if sensor_rect.has_area():_draw_sigil(sensor_rect.get_center(),sigil_index,24)
