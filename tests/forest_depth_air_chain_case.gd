extends RefCounted
## Scheduled intent only. The real Controller/Motor accepts actions and moves the body.
var active_leg := -1
var step_index := 0
var step_started := -1
var instance_data: Dictionary = {}
var program: Array = []
var entry_support := ""
var exit_support := ""
var start := Vector2.ZERO
var goal := Vector2.ZERO
func drive(trace: Node, leg: Dictionary) -> void:
	if active_leg != int(trace.leg_index):
		active_leg = int(trace.leg_index)
		step_index = 0
		step_started = -1
		instance_data = trace.instance(leg)
		if instance_data.is_empty():
			trace.fail("air_chain_missing_actual_instance")
			return
		var raw: Dictionary = instance_data.local_geometry
		program = leg.get("action_program",raw.get("action_program",[])).duplicate(true)
		if program.is_empty() or not raw.has("spawn") or not raw.has("goal"):
			trace.fail("air_chain_missing_program_or_ports")
			return
		entry_support = str(leg.get("entry_support_id",instance_data.platform_id_map.get("entry","")))
		exit_support = str(leg.get("landing_support_id",instance_data.platform_id_map.get("crown","")))
		start = trace.local_point(instance_data,raw.spawn)
		goal = trace.point(leg.get("landing",[float(raw.goal[0])+float(instance_data.translation[0]),float(raw.goal[1])+float(instance_data.translation[1])]))
		if entry_support.is_empty() or exit_support.is_empty():
			trace.fail("air_chain_missing_actual_support_mapping")
			return
	if trace.age > 400:
		trace.fail("air_chain_bounded_phase/"+str(trace.phase))
		return
	if trace.phase == "align":
		trace.controller.router.set_move_axis(clampf((start.x-trace.player.global_position.x)/12,-1,1))
		trace.stable = trace.stable+1 if trace.at_destination(start,entry_support) and absf(trace.player.velocity.x)<1 else 0
		if trace.stable >= 13:
			trace.controller.router.set_move_axis(0)
			trace.event("air_chain_departure",{"geometry_instance":instance_data.id,"entry_support":entry_support,"program":program.duplicate(true),"grounded":trace.player.is_on_floor(),"shots":trace.controller.action_resources.shot_charges,"hook_used":trace.controller.traversal.hook_used})
			trace.jump(true)
			trace.set_phase("air_chain_launch")
	elif trace.phase == "air_chain_launch":
		# First H shares the human jump-and-hook intent; never reset the body.
		var first: Dictionary = program[0]
		if str(first.action)=="R" and trace.age==6: trace.jump(false)
		var delay_frames: int = int(leg.get("first_hook_delay",1)) if str(first.action)=="H" else 7
		if str(first.action)=="H" and (delay_frames < 1 or delay_frames > 5):
			trace.fail("air_chain_invalid_first_hook_delay")
			return
		if trace.age == delay_frames:
			_submit(trace)
	elif trace.phase == "air_chain_action":
		var action: Dictionary = program[step_index]
		if str(action.action) == "H":
			if trace.controller.traversal.state in [&"hook_miss",&"hook_retract"]:
				trace.jump(false)
				trace.fail("air_chain_actual_H_failed/"+str(step_index))
				return
			if trace.controller.traversal.state == &"hook_kick": trace.jump(false)
			var target: String = _target(action)
			var contact := false
			var restored := false
			for actual: Dictionary in trace.events:
				if int(actual.tick)<step_started or int(actual.leg)!=active_leg: continue
				if actual.kind=="hook_contact_kick" and str(actual.get("target",""))==target: contact=true
				if actual.kind=="hook_kick" and str(actual.get("target",""))==target: restored=true
			if contact and restored and trace.controller.traversal.state==&"free" and trace.age>20:
				trace.event("air_chain_H_completed",{"step":step_index,"target":target,"grounded":trace.player.is_on_floor(),"hook_used":trace.controller.traversal.hook_used,"hook_tip":trace.pair(trace.controller.traversal.hook_tip)})
				_advance(trace)
		else:
			var accepted := false
			for actual: Dictionary in trace.events:
				if int(actual.tick)>=step_started and int(actual.leg)==active_leg and actual.kind=="shot_fired": accepted=true
			if accepted and trace.age>=9 and trace.player.recoil_burst_remaining<=0 and trace.controller.traversal.state==&"free":
				trace.jump(false)
				trace.event("air_chain_R_completed",{"step":step_index,"shots":trace.controller.action_resources.shot_charges,"grounded":trace.player.is_on_floor()})
				_advance(trace)
	elif trace.phase == "air_chain_receive":
		trace.controller.router.set_move_axis(clampf((goal.x-trace.player.global_position.x)/20,-1,1))
		trace.stable = trace.stable+1 if trace.at_destination(goal,exit_support) else 0
		if trace.stable >= 12:
			trace.event("air_chain_arrival",{"geometry_instance":instance_data.id,"exit_support":exit_support,"program_steps":program.size(),"shots":trace.controller.action_resources.shot_charges,"hook_used":trace.controller.traversal.hook_used})
			trace.complete_leg()
func _target(action: Dictionary) -> String:
	return str(instance_data.anchor_id_map.get(str(action.get("anchor","")),""))
func _submit(trace: Node) -> void:
	var action: Dictionary = program[step_index]
	step_started = int(trace.tick)
	trace.controller.router.set_move_axis(0)
	if str(action.action)=="H":
		var target := _target(action)
		if target.is_empty():
			trace.fail("air_chain_missing_anchor_mapping/"+str(step_index))
			return
		if not trace.hook(target): return
	elif str(action.action)=="R":
		var aim: Array = action.get("direction",[])
		if aim.size()!=2:
			trace.fail("air_chain_missing_R_direction")
			return
		trace.request(&"shoot_release",Vector2(float(aim[0]),float(aim[1])).normalized())
	else:
		trace.fail("air_chain_unknown_action/"+str(step_index))
		return
	trace.event("air_chain_action_requested",{"step":step_index,"action":str(action.action),"mapped_target":_target(action) if str(action.action)=="H" else "","grounded":trace.player.is_on_floor(),"hook_used":trace.controller.traversal.hook_used,"shots":trace.controller.action_resources.shot_charges})
	trace.set_phase("air_chain_action")
func _advance(trace: Node) -> void:
	step_index += 1
	if step_index>=program.size():
		trace.set_phase("air_chain_receive")
	else:
		_submit(trace)
