extends RefCounted
static func traverse(driver:Variant,module:PlatformingModule,latch:ShotLatch,forward:bool=true)->bool:
	if module.definition.module_id==&"plains_thorn_slalom":
		var path:Array=[145,350,520,540,735] if forward else [735,520,350,320,125]
		if not await driver.move_to(module.position.x+path[0]):return false
		for i:int in range(1,path.size()):
			if i==3:
				if not await driver.move_to(module.position.x+path[i]):return false
			elif not await driver.jump_to(module.position+Vector2(path[i],282)):return false
		return await driver.move_to((module.world_exit() if forward else module.world_entry()).x)
	if latch==null:return false
	if not latch.is_open:
		var first:StaticBody2D=latch.bell_body if forward else latch.access_bodies[0]
		if not await driver.move_to(first.global_position.x):return false
		driver.controller.router.request_action(&"shoot_release",Vector2.UP);await driver.advance(30)
		if latch.sequence_step!=1:return false
		if forward:
			if not await driver.move_to(module.position.x+420):return false
			if not await driver.jump_to(module.position+Vector2(520,192)):return false
		else:
			if not await driver.jump_to(module.position+Vector2(850,192)):return false
		var second:StaticBody2D=latch._second_body if forward else latch.access_bodies[1]
		driver.controller.router.request_action(&"shoot_release",(second.global_position-driver.motor.global_position).normalized());await driver.advance(30)
		if not latch.is_open:return false
		driver.controller.router.request_action(&"drop_through");await driver.advance(50)
	return await driver.move_to((module.world_exit() if forward else module.world_entry()).x)
