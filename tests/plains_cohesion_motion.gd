extends RefCounted
static func traverse(driver:Variant,module:PlatformingModule,latch:ShotLatch,forward:bool=true)->bool:
	if _driver_cancelled(driver): return false
	if module.definition.module_id==&"plains_thorn_slalom":
		var path:Array=[145,350,520,540,735] if forward else [735,520,350,320,125]
		var _cancel_await_5: bool = not await driver.move_to(module.position.x+path[0])
		if _driver_cancelled(driver): return false
		if _cancel_await_5:return false
		for i:int in range(1,path.size()):
			if i==3:
				var _cancel_await_8: bool = not await driver.move_to(module.position.x+path[i])
				if _driver_cancelled(driver): return false
				if _cancel_await_8:return false
			else:
				var _cancel_await_9: bool = not await driver.jump_to(module.position+Vector2(path[i],282))
				if _driver_cancelled(driver): return false
				if _cancel_await_9:return false
		var _cancel_await_10: bool = await driver.move_to((module.world_exit() if forward else module.world_entry()).x)
		if _driver_cancelled(driver): return false
		return _cancel_await_10
	if latch==null:return false
	if not latch.is_open:
		var first:StaticBody2D=latch.bell_body if forward else latch.access_bodies[0]
		var _cancel_await_14: bool = not await driver.move_to(first.global_position.x)
		if _driver_cancelled(driver): return false
		if _cancel_await_14:return false
		driver.controller.router.request_action(&"shoot_release",Vector2.UP)
		await driver.advance(30)
		if _driver_cancelled(driver): return false
		if latch.sequence_step!=1:return false
		if forward:
			var _cancel_await_18: bool = not await driver.move_to(module.position.x+420)
			if _driver_cancelled(driver): return false
			if _cancel_await_18:return false
			var _cancel_await_19: bool = not await driver.jump_to(module.position+Vector2(520,192))
			if _driver_cancelled(driver): return false
			if _cancel_await_19:return false
		else:
			var _cancel_await_21: bool = not await driver.jump_to(module.position+Vector2(850,192))
			if _driver_cancelled(driver): return false
			if _cancel_await_21:return false
		var second:StaticBody2D=latch._second_body if forward else latch.access_bodies[1]
		driver.controller.router.request_action(&"shoot_release",(second.global_position-driver.motor.global_position).normalized())
		await driver.advance(30)
		if _driver_cancelled(driver): return false
		if not latch.is_open:return false
		driver.controller.router.request_action(&"drop_through")
		await driver.advance(50)
		if _driver_cancelled(driver): return false
	var _cancel_await_26: bool = await driver.move_to((module.world_exit() if forward else module.world_entry()).x)
	if _driver_cancelled(driver): return false
	return _cancel_await_26

static func _driver_cancelled(driver: Variant) -> bool:
	return is_instance_valid(driver) and driver.has_method("is_trace_cancelled") and bool(driver.call("is_trace_cancelled"))
