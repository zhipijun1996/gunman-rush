extends RefCounted
## Real input drivers for new action types. No body/resource writes.
static func carrier(driver: Variant,module: PlatformingModule,forward: bool=true,shaft: bool=false,end_module: PlatformingModule=null,standing_offset: float=0) -> bool:
	var ferry: ModuleMovingPlatform=module.moving_platforms[0]
	var bank_x: float=module.position.x+(-25 if shaft else 130 if forward else 670)
	if not await driver.move_to(bank_x): return false
	var endpoint: Vector2=module.to_global(ferry.definition.start if forward else ferry.definition.finish)
	var docked:=false
	for unused: int in 900:
		var elapsed:=fposmod((ferry.motion_clock if ferry.bell_controlled else module.clock)+ferry.definition.initial_phase*ferry.definition.period(),ferry.definition.period())
		var fresh:=elapsed<.25 if forward else elapsed>ferry.definition.dwell_duration+ferry.definition.travel_duration and elapsed<ferry.definition.dwell_duration+ferry.definition.travel_duration+.25
		if fresh and ferry.global_position.distance_to(endpoint)<3: docked=true;break
		await driver.advance()
	if not docked: print("CARRIER NO DOCK ",module.position," actor=",driver.motor.global_position);return false
	driver.controller.router.request_action(&"jump")
	var boarded:=false
	for frame: int in 110:
		driver.controller.router.set_move_axis(clampf((ferry.global_position.x+standing_offset-driver.motor.global_position.x)/5.5,-1,1))
		await driver.advance()
		var feet: Vector2=driver.motor.global_position+Vector2(0,18)
		if frame>5 and driver.motor.is_on_floor() and absf(feet.y-(ferry.global_position.y-ferry.definition.size.y*.5))<3: boarded=true;break
	driver.controller.router.request_action(&"jump_release")
	if not boarded: print("CARRIER NO BOARD ",module.position," actor=",driver.motor.global_position," ferry=",ferry.global_position);return false
	var destination: Vector2=module.to_global(ferry.definition.finish if forward else ferry.definition.start)
	for unused: int in 900:
		driver.controller.router.set_move_axis(clampf((ferry.global_position.x+standing_offset-driver.motor.global_position.x)/5.5,-1,1))
		await driver.advance()
		if ferry.global_position.distance_to(destination)<3: break
	driver.controller.router.set_move_axis(0)
	driver.controller.router.request_action(&"jump_release")
	await driver.advance(6)
	var target: Vector2=module.position+Vector2(0,-700) if shaft else module.position+Vector2(640 if forward else 160,282)
	if end_module!=null: driver.module=end_module
	if not await driver.jump_to(target): print("CARRIER NO EXIT ",module.position," actor=",driver.motor.global_position," target=",target);return false
	return true if shaft else await driver.move_to((module.world_exit() if forward else module.world_entry()).x)
static func low_arch(driver: Variant,module: PlatformingModule,forward: bool=true) -> bool:
	if not await driver.move_to(module.position.x+(275 if forward else 365)): return false
	driver.controller.router.request_action(&"jump")
	for frame: int in 120:
		driver.controller.router.set_move_axis(1 if forward else -1)
		if frame==7: driver.controller.router.request_action(&"jump_release")
		await driver.advance()
		if frame>7 and driver.motor.is_on_floor(): break
	driver.controller.router.request_action(&"jump_release")
	return await driver.move_to((module.world_exit() if forward else module.world_entry()).x)
static func twin_gears(driver: Variant,module: PlatformingModule,forward: bool=true) -> bool:
	var centres: Array=[220.0,510.0] if forward else [510.0,220.0]
	for x: float in centres:
		if not await driver.move_to(module.position.x+x+(-90 if forward else 90)): print("TWIN NO APPROACH ",driver.motor.global_position);return false
		var saw: ModuleSawHazard=module.hazards[0 if x==220 else 1]
		# Wait until the wheel withdraws from the takeoff side; phases are independent.
		for unused: int in 300:
			var phase_x:=saw.global_position.x-(module.position.x+x)
			var motion_x:=saw.definition.at_time(module.clock+.05).x-saw.definition.at_time(module.clock).x
			if (phase_x>25 and motion_x>0) if forward else (phase_x< -25 and motion_x<0): break
			await driver.advance()
		if not await driver.jump_to(module.position+Vector2(x+(90 if forward else -90),282)): print("TWIN NO HOP ",driver.motor.global_position," used=",driver.controller.jump_ability.used_jumps," phase=",module.clock," direction=",forward);return false
	return await driver.move_to((module.world_exit() if forward else module.world_entry()).x)
static func recoil_point(driver: Variant,target: Vector2) -> bool:
	if not await driver.wait_for_shot_energy(): return false
	driver.controller.router.request_action(&"jump")
	for frame: int in 150:
		driver.controller.router.set_move_axis(clampf((target.x-driver.motor.global_position.x)/5.5,-1,1))
		if frame==18: driver.controller.router.request_action(&"shoot_release",Vector2.DOWN)
		await driver.advance()
		if frame>20 and driver.motor.is_on_floor():
			driver.controller.router.request_action(&"jump_release");await driver.advance(2)
			return absf(driver.motor.global_position.y-target.y)<2 and await driver.move_to(target.x)
	return false
