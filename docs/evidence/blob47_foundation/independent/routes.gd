extends SceneTree
var failures: Array[String] = []
var completed := 0
func _init() -> void: call_deferred("run")
func run() -> void:
	for index: int in 10:
		var lab := preload("res://scenes/demo/blob47_lab.tscn").instantiate() as Blob47Lab
		lab.seed_text = "independent-route-%02d" % index
		root.add_child(lab)
		for adapter: String in ["KeyboardMouseAdapter","GamepadAdapter"]: lab.player.get_node(adapter).process_mode = Node.PROCESS_MODE_DISABLED
		var session := lab.controller.session_id
		for direction: int in [1,-1]:
			var hold := 0
			var reached := false
			for tick: int in 2000:
				lab.controller.router.set_move_axis(direction)
				if lab.player.is_on_floor() and lab.player.is_on_wall() and hold == 0:
					lab.controller.router.set_jump_held(&"independent",true); hold = 7
				elif hold > 0:
					hold -= 1
					if hold == 0: lab.controller.router.set_jump_held(&"independent",false)
				await physics_frame
				if (direction > 0 and lab.player.position.x > 2490) or (direction < 0 and lab.player.position.x < 85): reached = true; break
			print("INDEPENDENT_ROUTE seed=",lab.seed_text," direction=",direction," reached=",reached," position=",lab.player.position," restarts=",lab.controller.session_id-session," modules=",lab.layout.modules.map(func(m:Dictionary)->String:return m.id))
			if reached: completed += 1
			else: failures.append(lab.seed_text+"/"+str(direction))
			if lab.controller.session_id != session: failures.append(lab.seed_text+"/unexpected restart")
		lab.leave(); lab.free()
		await process_frame
	await process_frame
	print("INDEPENDENT_ROUTES completed=",completed," failures=",failures)
	quit(0 if failures.is_empty() else 1)
