extends SceneTree
var checks := 0
var failures: Array[String] = []
func _init() -> void: _run.call_deferred()
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message);printerr("FAIL: "+message)
func frames(n: int) -> void:
	for i: int in n: await physics_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	var preview := preload("res://scenes/demo/pixel_plains_preview.tscn").instantiate() as PixelPlainsPreview
	root.add_child(preview)
	await frames(45)
	var room := preview.room
	expect(room.player.is_on_floor(),"actual player supported in SubViewport")
	expect(room.get_viewport()==preview.viewport,"real room belongs to low-res viewport")
	expect(preview.viewport.size==Vector2i(640,360),"640x360 render resolution")
	expect(room.camera.zoom==Vector2(.5,.5),"viewport world spans 1280x720")
	var initial := room.player.position
	var right := InputEventKey.new()
	right.physical_keycode=KEY_D;right.pressed=true
	root.push_input(right)
	await frames(15)
	expect(room.player.position.x>initial.x+10,"root viewport keyboard input reaches actual Motor through SubViewport")
	right.pressed=false;root.push_input(right)
	await frames(10)
	room.restart()
	await frames(10)
	# Catalog/manual pause interleave and actual wrapper button callback.
	preview._buttons.get_child(1).pressed.emit()
	expect(paused and room._catalog.visible,"actual wrapper catalog pauses room")
	for icon: Node in room._catalog.get_children():
		if icon is TextureRect:
			expect(icon.size==Vector2(32,32),"catalog icon actual size stays at32 logical pixels")
			expect(Rect2(Vector2.ZERO,room._catalog.size).encloses(Rect2(icon.position,icon.size)),"catalog keeps every canonical mask within panel")
	preview._buttons.get_child(4).pressed.emit()
	preview._buttons.get_child(1).pressed.emit()
	expect(paused and not room._catalog.visible,"manual pause survives catalog close")
	preview._buttons.get_child(0).pressed.emit()
	expect(not paused and not room._catalog.visible,"actual wrapper restart clears both modal and pause")
	var old_scope := room.lifetime
	var old_epoch := old_scope.epoch
	room.restart()
	expect(room.lifetime!=old_scope and room.lifetime.epoch>old_epoch,"restart owns new lifetime epoch")
	var health := room.controller.actor_resources.health
	room.controller.shoot_ability.try_fire(Vector2.RIGHT,true)
	await frames(1)
	var projectiles := room.controller.shoot_ability.get_projectiles()
	expect(not projectiles.is_empty(),"actual projectile created by actual shoot ability")
	if not projectiles.is_empty(): expect(projectiles[0].presentation is PixelPlainsProjectile,"new projectile pixels replace original drawing")
	preview._buttons.get_child(2).pressed.emit()
	preview._buttons.get_child(3).pressed.emit()
	expect(not preview._light and not preview._effects,"wrapper toggle states off")
	expect(not (room.scenery as PixelPlainsScenery).light_enabled and not (room.decoration as PixelPlainsDecoration).effects_enabled,"toggle disables actual systems")
	preview._buttons.get_child(0).pressed.emit()
	expect(not (room.scenery as PixelPlainsScenery).light_enabled,"Restart preserves Light off state")
	expect(not (room.decoration as PixelPlainsDecoration).effects_enabled,"Restart preserves Wind off state")
	room._toggle_pause()
	var requested := [false]
	preview.home_requested.connect(func() -> void: requested[0]=true)
	preview._buttons.get_child(5).pressed.emit()
	expect(requested[0] and not paused,"Home exits while paused and emits parent request")
	preview.queue_free()
	await frames(5)
	expect(not paused,"teardown leaves global pause clear")
	print("INDEPENDENT_PIXEL checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
