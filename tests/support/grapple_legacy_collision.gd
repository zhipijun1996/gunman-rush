extends TraversalAbility
## Causal control: exact after_move from source 6c61faadd511c48a267b975550da897e701fd09f.
## Not a complete old physics snapshot and never used by production/default tests.
func after_move() -> void:
	if state != &"hook_pull" or not _pull_step_requested: return
	var motor := controller.motor
	var distance := motor.global_position.distance_to(hook_tip)
	# Commit arrival against the anchor sampled for this Motor step. Waiting for
	# advance lets an escaping target move the stop ring away again every tick.
	if distance <= definition.hook_stop_distance + 0.05:
		if not is_instance_valid(hook_target) or not hook_target.is_inside_tree():
			_set_state(&"hook_miss"); return
		var receiver := hook_target.get_node_or_null("Damageable") as Damageable
		if receiver != null and not receiver.active: _set_state(&"hook_miss"); return
		motor.clear_recoil()
		controller.jump_ability.cancel_requests()
		motor.normal_velocity = Vector2.ZERO
		if receiver != null:
			receiver.receive_damage({"session_id":controller.session_id,"event_id":"hook/%s/%s/%s" % [motor.get_instance_id(),_session,_serial],"source_actor_id":motor.get_instance_id(),"target_actor_id":receiver.actor_id,"target_epoch":receiver.damage_epoch,"attack_id":_serial,"amount":definition.hook_damage,"damage_type":&"grapple","source_faction":&"player","hit_direction":hook_direction,"on_committed":controller.on_grapple_damage.bind(_session,_serial,(receiver.actor_id if receiver.actor_id!=0 else receiver.get_instance_id()) if receiver.faction==&"enemy" else 0)})
		_set_state(&"hook_contact_kick")
	elif motor.get_slide_collision_count() > 0 and distance > definition.hook_stop_distance+2:
		# A collision that prevents approach terminates the pull, never tunnels.
		_set_state(&"hook_miss")

