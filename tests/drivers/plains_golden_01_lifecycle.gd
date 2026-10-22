extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func run() -> void:
	var host := preload("res://scenes/dev/cloud_preview.tscn").instantiate()
	host.entry = "scene"
	host.entry_scene = "res://scenes/dev/plains_golden_01.tscn"
	host.task_id = "PLAINS-GOLDEN-01"
	root.add_child(host)
	for frame: int in 12: await physics_frame
	var demo: Node = host.custom_scene
	check(is_instance_valid(demo) and not is_instance_valid(host.app),"actual generic-scene entry")
	check(not demo.changing and demo.player.is_on_floor(),"candidate has actual supported spawn")
	var initial: Dictionary = demo.snapshot()
	check(initial.capabilities == {"grapple":false,"wall":false,"double_jump":false},"no ungranted ability")
	var old_life: DemoLifetime = demo.lifetime
	var old_player: PlayerMotor = demo.player
	demo.controller.router.request_action(&"shoot_release",Vector2.UP)
	for frame: int in 2: await physics_frame
	check(demo.controller.shoot_ability.get_projectiles().size() == 1,"actual accepted shot has live projectile")
	demo.toggle_pause()
	var at: Vector2 = demo.player.position
	var clock: float = demo.policy.clock
	for frame: int in 6: await physics_frame
	check(paused and demo.player.position == at and demo.policy.clock == clock,"pause freezes Motor and gameplay clock")
	demo.toggle_pause()
	await demo.launch("B")
	for frame: int in 8: await physics_frame
	check(not old_life.active and not is_instance_valid(old_player),"restart invalidates old lifetime and disposes actor")
	check(demo.candidate == "B" and demo.controller.shoot_ability.get_projectiles().is_empty(),"B starts without old projectiles")
	check(demo.wallet.balance == 0 and not demo.claimed and demo.latch.open_count == 0,"new candidate has separate session ledger")
	check(demo.controller.actor_resources.health.current == initial.health,"new run uses original health definition")
	check(demo.player.get_node("PixelPlainsActor") is UnderworldPlayer,"actual shared player renderer")
	check(demo.enemy.get_node("Presentation") is UnderworldEnemy,"actual shared enemy renderer")
	host.return_to_menu()
	for frame: int in 8: await physics_frame
	check(is_instance_valid(host.app) and not host.app.meta_persistence_enabled and host.entry == "menu","full real menu remains accessible and persistence isolated")
	check(not is_instance_valid(demo),"custom scene disposed on menu return")
	check(await load("res://tests/audio_teardown.gd").drain_world(host),"native audio drains")
	host.free()
	for frame: int in 6: await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/plains_golden_01/m1")
	FileAccess.open("res://build/plains_golden_01/m1/lifecycle.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"actual_generic_scene":true},"  "))
	print("PLAINS_GOLDEN_LIFECYCLE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
