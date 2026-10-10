extends RefCounted

func run(tree: SceneTree, check: Callable) -> void:
	var fixture := preload("res://tests/combat_tests.gd").new()
	fixture.tree = tree
	await fixture.fixture(Vector2(80, 150))
	var motor: PlayerMotor = fixture.motor
	var controller: PlayerController = fixture.controller
	var adapter := motor.get_node("PlayerVisualAdapter") as PlayerVisualAdapter
	var visual := motor.get_node("CourierVisual") as CourierVisual
	adapter.set_process(false)
	visual.set_process(false)
	check.call(visual != null and visual.body.texture != null and visual.arm.texture != null, "courier parts imported into the actual shared player scene")
	check.call(motor.get_node("CollisionShape2D").shape.size == Vector2(24, 36) and visual.position == Vector2(0, 18) and visual.scale.is_equal_approx(Vector2.ONE * (36.0 / 104.0)), "feet and nominal art height align with the unchanged 24x36 collision")
	var location := motor.position
	var charges := controller.action_resources.shot_charges
	var sequence := controller.router.sequence
	controller.router.set_aim(&"keyboard_mouse", Vector2.LEFT, true)
	adapter._process(0.01)
	visual._process(0.01)
	check.call(visual.facing == -1.0 and visual.aim_direction == Vector2.LEFT and is_equal_approx(absf(visual.arm.rotation), PI) and visual.arm.scale.y == -1.0, "left aim mirrors torso and independently points weapon left")
	controller.router.set_aim(&"keyboard_mouse", Vector2.DOWN, true)
	adapter._process(0.01)
	visual._process(0.01)
	check.call(visual.facing == -1.0 and visual.aim_direction == Vector2.DOWN and is_equal_approx(visual.arm.rotation, PI / 2.0) and is_zero_approx(visual.body.rotation), "vertical aiming preserves facing and never rotates the body")
	check.call(motor.position == location and controller.action_resources.shot_charges == charges and controller.router.sequence == sequence, "cosmetic updates neither move actor nor consume resources or enqueue inputs")
	controller.router.set_aim(&"keyboard_mouse", Vector2.ZERO)
	check.call(controller.shoot_ability.try_fire(Vector2.LEFT, false), "real gameplay shot supplies cosmetic recoil event")
	check.call(visual.state == &"recoil" and visual.aim_direction == Vector2.LEFT and controller.action_resources.shot_charges == charges - 1 and controller.shoot_ability.get_projectiles().size() == 1, "accepted shot has one cosmetic reaction alongside exactly one real projectile and resource use")
	motor.normal_velocity.x = 100.0
	adapter._process(0.01)
	check.call(visual.aim_direction == Vector2.LEFT and visual.facing == -1.0, "recoil retains the actual left shot direction while actor still has rightward momentum")
	var recoil_left := adapter._recoil_remaining
	check.call(not controller.shoot_ability.try_fire(Vector2.UP, false) and adapter._recoil_remaining == recoil_left and visual.aim_direction == Vector2.LEFT, "rejected cooldown shot produces no cosmetic recoil or aim change")
	motor.velocity.y = -100.0
	adapter._process(0.2)
	check.call(visual.state == &"jump", "expired recoil returns to observed rising locomotion")
	motor.velocity.y = 100.0
	adapter._process(0.01)
	check.call(visual.state == &"fall", "observed descending state uses fall pose")
	controller.active = false
	adapter._process(0.01)
	check.call(visual.state != &"death", "temporary menu or completion deactivation is not interpreted as death")
	controller.active = true
	controller.die()
	check.call(visual.state == &"death", "actual controller death overrides recoil and locomotion")
	var elapsed := visual.elapsed
	adapter.set_process(true)
	visual.set_process(true)
	tree.paused = true
	await tree.process_frame
	await tree.process_frame
	adapter._process(1.0)
	check.call(visual.elapsed == elapsed and visual.state == &"death", "paused tree freezes cosmetic animation and state")
	tree.paused = false
	adapter.set_process(false)
	visual.set_process(false)
	controller.reset_at(location)
	adapter._process(0.01)
	visual._process(0.01)
	check.call(visual.state != &"death" and visual.modulate.a == 1.0, "explicit legacy new life restores visible courier without changing respawn policy")
	var opaque_pixels := 0
	var image := visual.body.texture.get_image()
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				opaque_pixels += 1
	check.call(opaque_pixels > 100 and opaque_pixels < image.get_width() * image.get_height(), "real body SVG has visible paint and transparent margins, not a full rectangular sprite")
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		visual.set_state(&"idle")
		visual.set_aim_direction(direction)
		visual._process(0.0)
		var art_bounds := Rect2()
		var have_pixel := false
		for part: Sprite2D in [visual.body, visual.left_leg, visual.right_leg, visual.scarf, visual.arm]:
			var pixels := part.texture.get_image()
			var origin := part.get_rect().position
			for y: int in pixels.get_height():
				for x: int in pixels.get_width():
					if pixels.get_pixel(x, y).a <= 0.5:
						continue
					var point: Vector2 = motor.to_local(part.to_global(origin + Vector2(x + 0.5, y + 0.5)))
					art_bounds = art_bounds.expand(point) if have_pixel else Rect2(point, Vector2.ZERO)
					have_pixel = true
		print("COURIER OPAQUE BOUNDS aim=%s local=%s collision=%s" % [direction, art_bounds, Rect2(-12, -18, 24, 36)])
		check.call(have_pixel and art_bounds.size.x < 60.0 and art_bounds.size.y < 60.0 and art_bounds.position.y > -30.0 and art_bounds.end.y < 35.0, "actual transformed cardinal-aim paint stays in bounded cosmetic envelope; collision remains separate")
	fixture.world.free()
