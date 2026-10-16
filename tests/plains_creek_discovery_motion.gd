extends RefCounted
## Shared by the golden and formal growth observer: only Router input, real support and latch.
## claim_callback is awaited ON the island while grounded, before returning to the boat.
static func toggle(driver: Variant,latch: ShotLatch,ferry: ModuleMovingPlatform=null) -> bool:
	if _driver_cancelled(driver): return false
	var _cancel_await_5: bool = not await driver.wait_for_shot_energy()
	if _driver_cancelled(driver): return false
	if _cancel_await_5: return false
	if ferry!=null:
		for unused: int in 30:
			driver.controller.router.set_move_axis(clampf((ferry.global_position.x-35-driver.motor.global_position.x)/5.5,-1,1))
			await driver.advance()
			if _driver_cancelled(driver): return false
			if absf(driver.motor.global_position.x-(ferry.global_position.x-35))<2:break
	var bell: StaticBody2D=latch.bell_body
	driver.controller.router.request_action(&"shoot_release",(bell.global_position-driver.motor.global_position).normalized())
	for unused: int in 35:
		if ferry!=null:driver.controller.router.set_move_axis(clampf((ferry.global_position.x-35-driver.motor.global_position.x)/5.5,-1,1))
		await driver.advance()
		if _driver_cancelled(driver): return false
	return true
static func traverse(driver: Variant,module: PlatformingModule,bank: PlatformingModule,claim_callback: Callable=Callable(),forward: bool=true) -> bool:
	if _driver_cancelled(driver): return false
	var latch: ShotLatch=null
	# The actual consumer passes its bound production latch via explicit driver metadata.
	if not module.has_meta("discovery_latch"): return false
	latch=module.get_meta("discovery_latch") as ShotLatch
	if latch==null or module.moving_platforms.is_empty(): return false
	var ferry: ModuleMovingPlatform=module.moving_platforms[0]
	var _cancel_await_24: bool = not await driver.move_to(module.position.x+(130 if forward else 670))
	if _driver_cancelled(driver): return false
	if _cancel_await_24: return false
	if not latch.motion_target.motion_running:
		var _cancel_await_26: bool = not await toggle(driver,latch) or not ferry.motion_running
		if _driver_cancelled(driver): return false
		if _cancel_await_26: return false
	var _cancel_await_27: bool = not await driver.move_to(module.position.x+(130 if forward else 670))
	if _driver_cancelled(driver): return false
	if _cancel_await_27: return false
	var endpoint:=module.to_global(ferry.definition.start if forward else ferry.definition.finish)
	var docked:=false
	for unused: int in 900:
		var phase:=fposmod(ferry.motion_clock+ferry.definition.initial_phase*ferry.definition.period(),ferry.definition.period())
		var fresh:=phase<.25 if forward else phase>ferry.definition.dwell_duration+ferry.definition.travel_duration and phase<ferry.definition.dwell_duration+ferry.definition.travel_duration+.25
		if fresh and ferry.global_position.distance_to(endpoint)<3: docked=true;break
		await driver.advance()
		if _driver_cancelled(driver): return false
	if not docked:return false
	driver.controller.router.request_action(&"jump")
	var boarded:=false
	for frame: int in 110:
		driver.controller.router.set_move_axis(clampf((ferry.global_position.x-driver.motor.global_position.x)/5.5,-1,1))
		await driver.advance()
		if _driver_cancelled(driver): return false
		if frame>5 and driver.motor.is_on_floor() and absf(driver.motor.global_position.y+18-(ferry.global_position.y-ferry.definition.size.y*.5))<3:boarded=true;break
	driver.controller.router.request_action(&"jump_release")
	if not boarded:return false
	var target: Vector2=(bank.world_entry()+bank.world_exit())*.5
	var parked:=false
	for unused: int in 900:
		driver.controller.router.set_move_axis(clampf((ferry.global_position.x-driver.motor.global_position.x)/5.5,-1,1))
		await driver.advance()
		if _driver_cancelled(driver): return false
		var local_x:=ferry.global_position.x-module.position.x
		if (local_x>=360 and local_x<490) if forward else (local_x<=480 and local_x>310):
			var _cancel_await_51: bool = not await toggle(driver,latch,ferry)
			if _driver_cancelled(driver): return false
			if _cancel_await_51:return false
			parked=not ferry.motion_running;break
	if not parked:return false
	driver.controller.router.set_move_axis(0)
	var parked_clock:=ferry.motion_clock
	var parked_position:=ferry.global_position
	var original_module: PlatformingModule=driver.module
	driver.module=bank
	var _cancel_await_59: bool = await driver.jump_to(target)
	if _driver_cancelled(driver): return false
	var landed: bool = _cancel_await_59
	driver.module=original_module
	if not landed or not driver.motor.is_on_floor() or driver.motor.global_position.distance_to(target)>1:return false
	await driver.advance(12)
	if _driver_cancelled(driver): return false
	if ferry.motion_running or ferry.motion_clock!=parked_clock or not ferry.global_position.is_equal_approx(parked_position):return false
	if claim_callback.is_valid():
		await claim_callback.call()
		if _driver_cancelled(driver): return false
	# Leave by real drop-through, never set body position or platform phase.
	driver.controller.router.request_action(&"drop_through")
	var back_on_boat:=false
	for frame: int in 120:
		driver.controller.router.set_move_axis(clampf((ferry.global_position.x-driver.motor.global_position.x)/5.5,-1,1))
		await driver.advance()
		if _driver_cancelled(driver): return false
		if frame>3 and driver.motor.is_on_floor() and absf(driver.motor.global_position.y+18-(ferry.global_position.y-ferry.definition.size.y*.5))<3:back_on_boat=true;break
	if not back_on_boat:return false
	driver.controller.router.set_move_axis(0)
	var _cancel_await_74: bool = not await toggle(driver,latch,ferry) or not ferry.motion_running
	if _driver_cancelled(driver): return false
	if _cancel_await_74:return false
	var destination:=module.to_global(ferry.definition.finish if forward else ferry.definition.start)
	var arrived:=false
	for unused: int in 900:
		driver.controller.router.set_move_axis(clampf((ferry.global_position.x-driver.motor.global_position.x)/5.5,-1,1))
		await driver.advance()
		if _driver_cancelled(driver): return false
		if ferry.global_position.distance_to(destination)<3:arrived=true;break
	if not arrived:return false
	driver.controller.router.set_move_axis(0)
	await driver.advance(6)
	if _driver_cancelled(driver): return false
	var _cancel_await_84: bool = not await driver.jump_to(module.position+Vector2(640 if forward else 160,282))
	if _driver_cancelled(driver): return false
	if _cancel_await_84:return false
	var _cancel_await_85: bool = await driver.move_to((module.world_exit() if forward else module.world_entry()).x)
	if _driver_cancelled(driver): return false
	return _cancel_await_85

static func _driver_cancelled(driver: Variant) -> bool:
	return is_instance_valid(driver) and driver.has_method("is_trace_cancelled") and bool(driver.call("is_trace_cancelled"))
