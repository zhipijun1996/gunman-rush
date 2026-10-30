extends Node2D
## Formal Plains consumers over delivery geometry. Owns art only, never bodies,
## enemy selection, authored coordinates, rewards, or the gameplay RNG stream.
var world: Node2D
var art: UnderworldTerrain
var scenery: UnderworldScenery
var parallax: UnderworldParallax
var fine: UnderworldPresentation
var authored_solids: Array[Rect2] = []
var geometry_revision := 0
var _installed: Dictionary = {}
var _native_chests: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for instance: Node2D in world.registry.instances.values(): _install_instance(instance)
	# Keep the original CourierVisual alive for its authoritative projectile muzzle.
	var body := PlayerPresentationRuntime.current_body(world.motor)
	if body == null:
		body = PlayerPresentationRuntime.make_body(world.motor, world.player, "PixelPlainsActor", world.avatar_selection_id)
		world.motor.add_child(body)
	world.motor.get_node("CourierVisual").visible = false
	world.motor.get_node("PlayerFeedback").visible = false
	world.motor.get_node("PlayerVisualAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	if get_tree().get_first_node_in_group(&"game_audio") == null:
		var audio := PlayerWeaponFeelAudioV2.new()
		audio.name = "GameAudio"
		world.add_child(audio)
	PlayerPresentationRuntime.attach(world.motor)
	scenery = UnderworldScenery.new()
	scenery.name = "FormalPlainsScenery"
	add_child(scenery)
	refresh_geometry()
	parallax = UnderworldParallax.new()
	parallax.name = "FormalPlainsParallax"
	parallax.origin = world.motor.global_position
	parallax.configure(world._camera, world._bounds, {"manifest_hash":world.registry.map_data.map_id,"seed":930001})
	world.add_child(parallax)
	fine = UnderworldPresentation.attach(world, world, world.motor)
	fine.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Foreground keeps its native ALWAYS mode: it tracks the paused overview
	# camera while its own implementation freezes wind/animation clocks.
	_refresh_native_chests()

func _install_instance(instance: Node2D) -> void:
	_installed[instance.get_instance_id()] = true
	PixelFormalActors.install(instance)
	UnderworldActors.install(instance)
	instance.module.terrain_candidate_preview = true
	instance.module.queue_redraw()
	for child: Node in instance.module.get_children():
		if child is ModuleMovingPlatform: child.set_painted_enabled(true)
	for latch: ShotLatch in instance.find_children("*", "ShotLatch", true, false):
		latch.formal_presentation = true
		latch.set_region_presentation(true)
		latch.refresh_pixel_presentation()
	# The delivered OR consumer draws a gold placeholder rectangle. Its native
	# stage still owns interaction/claims; only its drawing is replaced here.
	var consumer: Variant = instance.get("original_region_chests")
	if consumer != null and is_instance_valid(consumer.stage):
		consumer.stage.visible = false
		for index: int in consumer.stage.chests.size():
			var sprite := Sprite2D.new()
			sprite.name = "NativeChest_" + str(instance.name) + "_" + str(index)
			add_child(sprite)
			_native_chests.append({"stage":consumer.stage,"index":index,"sprite":sprite,"claimed":null})

func _refresh_native_chests() -> void:
	for row: Dictionary in _native_chests:
		if not is_instance_valid(row.stage) or not is_instance_valid(row.sprite): continue
		var chest: Dictionary = row.stage.chests[row.index]
		if row.claimed == chest.claimed: continue
		# M29's authored claim centre is y46 over its native one-way top y64.
		# This foot is art only; the unchanged native claim centre stays at y46.
		UnderworldObjects.place_chest(row.sprite, to_local(chest.position + Vector2(0,18)), bool(chest.claimed), StringName(str(chest.tier)))
		row.claimed = chest.claimed

func collect_solids() -> Array[Rect2]:
	var solids: Array[Rect2] = []
	for instance: Node2D in world.registry.instances.values():
		var module: PlatformingModule = instance.module
		for index: int in module.definition.platforms.size():
			if index in module.definition.one_way_platform_indices: continue
			var slab: Rect2 = module.definition.platforms[index]
			solids.append(Rect2(module.to_global(slab.position), slab.size))
	return solids

func _protection() -> Array[Rect2]:
	var blocked: Array[Rect2] = []
	blocked.append(Rect2(world.segment._anchors[&"map_start"] - Vector2(100, 160), Vector2(250, 210)))
	for instance: Node2D in world.registry.instances.values():
		var module: PlatformingModule = instance.module
		blocked.append_array(module.world_dangers())
		for anchor: Vector2 in module.definition.anchors:
			blocked.append(Rect2(module.to_global(anchor) - Vector2(36, 55), Vector2(72, 78)))
		for ferry: ModuleMovingPlatformDefinition in module.definition.ferries:
			var envelope := ferry.envelope()
			blocked.append(Rect2(module.to_global(envelope.position), envelope.size).grow(36))
		for enemy: Dictionary in instance.content.enemies:
			var point := instance.to_global(Vector2(enemy.position[0], enemy.position[1]))
			var radius := float(enemy.get("patrol_radius", 0)) + 65.0
			blocked.append(Rect2(point - Vector2(radius, 90), Vector2(radius * 2, 150 + float(enemy.get("dive_depth", 0)))))
		for reward: Dictionary in instance.content.reward_sites:
			var point := instance.to_global(Vector2(reward.position[0], reward.position[1]))
			blocked.append(Rect2(point - Vector2(120, 85), Vector2(240, 120)))
		for chest: Dictionary in instance.content.get("original_region_chests", []):
			var point := instance.to_global(Vector2(chest.position[0], chest.position[1]))
			blocked.append(Rect2(point - Vector2(120, 85), Vector2(240, 120)))
		for latch: ShotLatch in instance.find_children("*", "ShotLatch", true, false):
			var bells: Array[Vector2] = [latch.bell_position]
			if not latch.sequence_offset.is_zero_approx(): bells.append(latch.bell_position + latch.sequence_offset)
			bells.append_array(latch.access_positions)
			for bell: Vector2 in bells:
				blocked.append(Rect2(latch.to_global(bell) - Vector2(85, 125), Vector2(170, 185)))
			# Inspect actual shapes, so paired/sequence gates share the same
			# keepout even when their vendor subclass uses another field name.
			for shape: CollisionShape2D in latch.find_children("*", "CollisionShape2D", true, false):
				if shape.shape is RectangleShape2D:
					var rect := shape.shape.get_rect()
					blocked.append(Rect2(shape.to_global(rect.position), rect.size).grow(24))
	# Actual delivered openings, including sealed ports, remain visually legible.
	for spec: Dictionary in world.registry.map_data.instances:
		var instance: Node2D = world.registry.instances.get(spec.id)
		if not is_instance_valid(instance): continue
		for port: Dictionary in spec.ports:
			var raw: Array = port.local_position_pixels
			var point := instance.to_global(Vector2(raw[0], raw[1]))
			var size := Vector2(128, 32) if port.face in ["TOP", "BOTTOM"] else Vector2(32, 128)
			blocked.append(Rect2(point - size * 0.5, size).grow(48))
	return blocked

func refresh_geometry() -> void:
	var solids := collect_solids()
	if solids == authored_solids: return
	# Observe committed native definitions, including the deferred Boss break.
	var replacement := UnderworldTerrain.build(solids)
	if replacement == null:
		world._fail("formal_plains_terrain_build_rejected")
		return
	if is_instance_valid(art): art.free()
	art = replacement
	art.name = "FormalPlainsTerrain"
	art.z_index = -1
	add_child(art)
	authored_solids = solids
	geometry_revision += 1
	scenery.configure_geometry(solids, _protection(), str(world.registry.map_data.map_id), {"world_bounds":world._bounds})
	if is_instance_valid(fine):
		# Both occlusion and rooted props follow the actual new solid union.
		for row: Dictionary in fine.emitters:
			row.light.free()
			row.bloom.free()
		fine.emitters.clear()
		for child: Node in fine.get_children():
			if child is LightOccluder2D: child.free()
		fine.install_lights()
		fine.install_occluders(world)
		fine.refresh()

func _process(_delta: float) -> void:
	for instance: Node2D in world.registry.instances.values():
		if not _installed.has(instance.get_instance_id()): _install_instance(instance)
	refresh_geometry()
	_refresh_native_chests()
