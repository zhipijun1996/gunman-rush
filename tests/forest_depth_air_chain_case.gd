extends RefCounted
## Scheduled intent only. The real Controller/Motor accepts actions and moves the body.
var active_leg := -1
var step_index := 0
var step_started := -1
var instance_data: Dictionary = {}
var program: Array = []
var source_program: Array = []
var entry_support := ""
var exit_support := ""
var start := Vector2.ZERO
var goal := Vector2.ZERO
var rest_anchor_id := ""
var hang_started := -1
var receiver_side_cast_started := false
func drive(trace: Node, leg: Dictionary) -> void:
	if active_leg != int(trace.leg_index):
		active_leg = int(trace.leg_index)
		rest_anchor_id=str(leg.get("rest_anchor_id",""));hang_started=-1
		step_index = 0
		step_started = -1
		instance_data = trace.instance(leg)
		if instance_data.is_empty():
			trace.fail("air_chain_missing_actual_instance")
			return
		var raw: Dictionary = instance_data.local_geometry
		program = leg.get("action_program",raw.get("action_program",[])).duplicate(true)
		source_program=program.duplicate(true)
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
		var delay_frames: int = int(leg.get("first_hook_delay",1)) if str(first.action) in ["H","HANG"] else 7
		if str(first.action) in ["H","HANG"] and (delay_frames < 1 or delay_frames > 5):
			trace.fail("air_chain_invalid_first_hook_delay")
			return
		if trace.age == delay_frames:
			_submit(trace)
	elif trace.phase == "air_chain_action":
		var action: Dictionary = program[step_index]
		if str(action.action) == "HANG":
			if trace.controller.traversal.state==&"hook_hang":
				trace.jump(false);trace.controller.router.set_move_axis(0)
				if hang_started<0:
					hang_started=int(trace.tick)
					trace.event("rest_branch_observation",{"target":rest_anchor_id,"grounded":trace.player.is_on_floor(),"shots":trace.controller.action_resources.shot_charges})
				if int(trace.tick)-hang_started>=int(leg.get("hang_observation_frames",18)):
					trace.event("rest_branch_departure",{"target":rest_anchor_id,"held_frames":int(trace.tick)-hang_started,"grounded":trace.player.is_on_floor()})
					_advance(trace)
			elif trace.controller.traversal.state in [&"hook_miss",&"hook_retract"]:trace.fail("rest_branch_actual_hook_failed")
		elif str(action.action) == "H":
			if action.has("current_receiver_side") and not receiver_side_cast_started:
				var target_id:=_target(action)
				var target: Node2D=trace.stage.assembler.hook_targets.get(target_id)
				if not is_instance_valid(target):trace.fail("current_receiver_side_anchor_missing");return
				var side: float=float(action.current_receiver_side)
				trace.controller.router.set_move_axis(side)
				if (trace.player.global_position.x-target.global_position.x)*side>4:
					trace.controller.router.set_move_axis(0)
					trace.event("current_receiver_side_rehook",{"step":step_index,"target":target_id,"side":side,"shots":trace.controller.action_resources.shot_charges,"can_air_jump":trace.controller.jump_ability.can_air_jump()})
					if not trace.hook(target_id):return
					receiver_side_cast_started=true;step_started=int(trace.tick)
				return
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
		elif str(action.action)=="J":
			var accepted: bool=trace.events.any(func(e:Dictionary)->bool:return int(e.tick)>=step_started and int(e.leg)==active_leg and e.kind=="jumped")
			if accepted and not trace.player.is_on_floor():
				trace.event("current_anchor_jump_completed",{"step":step_index,"shots":trace.controller.action_resources.shot_charges,"grounded":trace.player.is_on_floor()})
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
	return rest_anchor_id if str(action.action)=="HANG" else str(instance_data.anchor_id_map.get(str(action.get("anchor","")),""))
func _submit(trace: Node) -> void:
	var action: Dictionary = program[step_index]
	var free_base: bool=trace.controller.shot_energy!=null and trace.controller.shot_energy.definition.resource_path=="res://resources/player/demo_ui_01/time_energy_v2.tres" and not trace.controller.shot_energy.definition.shooting_consumes_energy and trace.player.tuning.max_air_shots==1 and trace.controller.shoot_ability.weapon.id==&"pulse_gun" and trace.controller.shoot_ability.weapon.tier==1
	if str(action.action)=="R" and trace.controller.action_resources.shot_charges==0 and free_base:
		var anchor_jump: bool=trace.controller.traversal.state==&"hook_hang" and trace.controller.traversal.hook_target is GrappleAnchor and trace.controller.jump_ability.enabled and trace.controller.jump_ability.maximum_jumps()>0
		var air_jump: bool=trace.controller.jump_ability.can_air_jump()
		var receiver_rehook: bool=step_index>0 and step_index==program.size()-1 and str(program[step_index-1].action)=="H" and trace.controller.traversal.hook_target is GrappleAnchor and not trace.controller.traversal.hook_used
		var replacement: String="J" if anchor_jump or air_jump else "H" if receiver_rehook else ""
		if not replacement.is_empty():
			program[step_index]={"action":replacement}
			if replacement=="H":
				var target: Node2D=trace.controller.traversal.hook_target
				program[step_index].anchor=str(program[step_index-1].anchor)
				program[step_index].current_receiver_side=signf(goal.x-target.global_position.x)
				receiver_side_cast_started=false
			trace.event("current_input_substitution",{"step":step_index,"source_action":"R","executed_action":replacement,"source_program":source_program.duplicate(true),"executed_program":program.duplicate(true),"max_air_shots":trace.player.tuning.max_air_shots,"shots":trace.controller.action_resources.shot_charges,"anchor_jump":anchor_jump,"can_air_jump":air_jump,"hook_state":String(trace.controller.traversal.state)})
			action=program[step_index]
	step_started = int(trace.tick)
	trace.controller.router.set_move_axis(0)
	if str(action.action) in ["H","HANG"]:
		var target := _target(action)
		if target.is_empty():
			trace.fail("air_chain_missing_anchor_mapping/"+str(step_index))
			return
		if action.has("current_receiver_side"):
			trace.controller.router.set_move_axis(float(action.current_receiver_side))
		else:
			if not trace.hook(target): return
	elif str(action.action)=="J":
		if trace.controller.traversal.state!=&"hook_hang" and not trace.controller.jump_ability.can_air_jump():
			trace.fail("current_jump_requires_real_ability_qualification");return
		trace.event("current_anchor_jump_requested",{"step":step_index,"hook_state":String(trace.controller.traversal.state),"shots":trace.controller.action_resources.shot_charges})
		trace.jump(true)
	elif str(action.action)=="R":
		var aim: Array = action.get("direction",[])
		if aim.size()!=2:
			trace.fail("air_chain_missing_R_direction")
			return
		trace.request(&"shoot_release",Vector2(float(aim[0]),float(aim[1])).normalized())
	else:
		trace.fail("air_chain_unknown_action/"+str(step_index))
		return
	trace.event("air_chain_action_requested",{"step":step_index,"action":str(action.action),"mapped_target":_target(action) if str(action.action) in ["H","HANG"] else "","grounded":trace.player.is_on_floor(),"hook_used":trace.controller.traversal.hook_used,"shots":trace.controller.action_resources.shot_charges})
	trace.set_phase("air_chain_action")
func _advance(trace: Node) -> void:
	step_index += 1
	if step_index>=program.size():
		trace.set_phase("air_chain_receive")
	else:
		_submit(trace)
