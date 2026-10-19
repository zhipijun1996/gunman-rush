extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func pointer(overlay: TouchOverlay, id: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index=id;event.position=at;event.pressed=pressed
	overlay.handle_touch(event)

func drag(overlay: TouchOverlay, id: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=id;event.position=at
	overlay.handle_touch(event)

func run() -> void:
	var fixture := preload("res://tests/combat_tests.gd").new()
	fixture.tree=self
	await fixture.fixture(Vector2(80,-1000))
	var router: InputRouter=fixture.controller.router
	fixture.controller.traversal.grant(&"grapple")
	fixture.controller.physics_tick(1.0/60)
	var overlay: TouchOverlay=InputSetup.attach(fixture.motor,router)
	overlay.set_enabled(true)
	var gun := overlay.right_center
	var hook := overlay.hook_center
	pointer(overlay,1,gun,true)
	drag(overlay,1,gun+Vector2.RIGHT*overlay.radius)
	pointer(overlay,2,hook,true)
	drag(overlay,2,hook+Vector2.UP*overlay.hook_radius)
	var before_mode := router.aim_mode
	var before_direction := router.aim_direction
	drag(overlay,1,gun+Vector2.LEFT*overlay.radius)
	var pass_priority := router.aim_mode==&"grapple" and router.aim_direction.is_equal_approx(Vector2.UP)
	print("INDEPENDENT TOUCH PRIORITY: before=",before_mode,"/",before_direction," after=",router.aim_mode,"/",router.aim_direction," pass=",pass_priority)
	router.clear("independent_cleanup")
	fixture.world.free()
	await process_frame
	quit(0 if pass_priority else 1)
