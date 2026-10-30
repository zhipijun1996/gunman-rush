extends "pair_latch_v2-0c82d9047c16.gd"
## V3 strengthens V1/V2 frame-atomic swapping: close first, then open.
## There is no physics/query/signal yield between these assignments.
func _apply_pair_state() -> void:
	var closing_body: StaticBody2D=paired_gate_body if open_a else gate_body
	var closing_shape: CollisionShape2D=paired_gate_shape if open_a else gate_shape
	var opening_body: StaticBody2D=gate_body if open_a else paired_gate_body
	var opening_shape: CollisionShape2D=gate_shape if open_a else paired_gate_shape
	closing_body.collision_layer=1
	closing_shape.disabled=false
	opening_body.collision_layer=0
	opening_shape.disabled=true
	is_open=open_a
	queue_redraw()
