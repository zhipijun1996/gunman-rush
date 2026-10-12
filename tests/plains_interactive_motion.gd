extends RefCounted
static func traverse(driver:Variant,module:PlatformingModule,latch:ShotLatch,forward:bool=true)->bool:
	var id:String=str(module.definition.module_id)
	if id=="plains_thorn_cells":
		if not await driver.move_to(module.position.x+(170 if forward else 360)):return false
		if not await driver.jump_to(module.position+Vector2(420 if forward else 150,282)):return false
	elif id=="plains_thorn_wall":
		if not await driver.move_to(module.position.x+(225 if forward else 450)):return false
		if not await driver.jump_to(module.position+Vector2(352,152)):return false
		if not await driver.jump_to(module.position+Vector2(490 if forward else 210,282)):return false
	elif id in ["plains_remote_bell","plains_bell_ferry_control"]:
		if latch==null:return false
		if not latch.is_open:
			var body:StaticBody2D=latch.bell_body if forward else latch.access_bodies[0]
			if not await driver.move_to(body.global_position.x):return false
			driver.controller.router.request_action(&"shoot_release",(body.global_position-driver.motor.global_position).normalized())
			await driver.advance(32)
			if not latch.is_open:return false
		if id=="plains_bell_ferry_control":return await load("res://tests/plains_exploration_motion.gd").carrier(driver,module,forward)
	return await driver.move_to((module.world_exit() if forward else module.world_entry()).x)
