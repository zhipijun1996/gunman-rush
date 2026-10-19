class_name ThornQueenWeaveKnot
extends StaticBody2D
signal severed
var health := HealthState.new()
var damageable: Damageable
var body_size := Vector2.ZERO
var bare_stem_tip := Vector2.ZERO
var _shape: CollisionShape2D
var _definition: HealthDefinition
var _restoring := false
func configure(config: ThornQueenWeaveDefinition,policy: FrameDamagePolicy,target_id: StringName = &"queen/weave_knot") -> bool:
	body_size=config.knot_collision_size
	collision_layer=4
	collision_mask=0
	add_to_group(&"grapple_target")
	_shape=CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size=body_size
	_shape.shape=rectangle
	add_child(_shape)
	_definition=config.knot_health_definition
	health.configure(_definition)
	damageable=Damageable.new()
	damageable.name="Damageable"
	damageable.faction=&"enemy"
	damageable.actor_id=get_instance_id()
	add_child(damageable)
	damageable.bind_health(health)
	damageable.died.connect(_sever)
	queue_redraw()
	health.changed.connect(func(_result: ActorResourceResult) -> void: queue_redraw())
	return policy.bind_damageable(target_id,damageable,health)
func _sever() -> void:
	collision_layer=0
	remove_from_group(&"grapple_target")
	_shape.set_deferred("disabled",true)
	if not _restoring: severed.emit()
	queue_redraw()
func _draw() -> void:
	draw_line(Vector2.ZERO,bare_stem_tip,Color("8e8265"),2,true)
	if health.terminal:
		draw_line(Vector2(-12,-10),Vector2(12,10),Color("776956"),3)
		return
	draw_circle(Vector2.ZERO,body_size.x*.5,Color("be8367"))
	draw_arc(Vector2.ZERO,body_size.x*.5+5,0,TAU,24,Color("f1d9a1"),2)
	for n: int in int(health.current): draw_circle(Vector2(-4+n*8,0),2,Color("fff1cd"))

func restore_health(value: float) -> bool:
	if not is_finite(value) or value<0 or value>_definition.max_health: return false
	var restored := _definition.duplicate(true) as HealthDefinition
	restored.initial_current=value
	_restoring=true
	var accepted := health.configure(restored)
	_restoring=false
	if not accepted: return false
	collision_layer=4 if value>0 else 0
	_shape.set_deferred("disabled",value<=0)
	if value>0:
		if not is_in_group(&"grapple_target"): add_to_group(&"grapple_target")
	else:
		if is_in_group(&"grapple_target"): remove_from_group(&"grapple_target")
	queue_redraw()
	return true
