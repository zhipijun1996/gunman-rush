extends "res://tests/grapple_feel_runner.gd"

func run() -> void:
	for side: float in [-1.0,1.0]:
		case_name="independent_mirrored_down_%s" % side
		var floor_rect := Rect2(-200,200,300,30) if side>0 else Rect2(-100,200,300,30)
		await fixture(Vector2(96*side,182),floor_rect)
		var ring := anchor(Vector2(215*side,300))
		hook(ring)
		check(await wait_state(&"hook_contact_kick"),"mirrored edge actual-body arrival %s" % side)
		check(player.position.x*side>100,"mirrored body clears edge %s" % side)
	case_name="independent_depleted_air_shot_hold"
	await fixture(Vector2(0,182),Rect2(-200,700,500,30))
	controller.router.request_action(&"shoot_release",Vector2.DOWN)
	await frames(2)
	var depleted := controller.action_resources.shot_charges
	check(depleted==1,"actual airborne shot spends one charge before hooking")
	var ring := anchor(Vector2(100,50),true)
	hook(ring)
	check(await wait_state(&"hook_hang"),"depleted actual-airborne arrival attaches")
	check(controller.action_resources.shot_charges==depleted,"hang arrival does not restore consumed charge")
	await frames(60)
	check(controller.action_resources.shot_charges==depleted,"hang hold does not restore consumed charge")
	check(not player.is_on_floor(),"hang is not a hidden landing")
	write_result()
	world.free()
	quit(1 if failures else 0)
