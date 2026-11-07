extends SceneTree
## Focused headless checks of the new native lighting rig and data contract.

var checks: Array[Dictionary] = []
var failed := false

func check_item(name: String, passed: bool, details: Dictionary = {}) -> void:
	checks.append({"name": name, "passed": passed, "details": details})
	if not passed:
		failed = true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Variant = load("res://study.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.get_node("Traveler").set_physics_process(false)
	scene.set_ambient_paused(true)
	scene.ambient_time = 1.2
	await process_frame
	var regions: Array = scene.data["regions"]
	check_item("all_configured_regions_present", regions.size() == scene.get_node("Regions").get_child_count(), {"regions": regions.size()})
	check_item("regional_collision_geometry", scene.get_node("Geometry").get_child_count() == regions.size())
	var samples: Dictionary = {}
	var total_lights := 0
	var total_occluders := 0
	var total_depth_layers := 0
	for spec: Dictionary in regions:
		var id := str(spec["id"])
		scene.set_region(id)
		var region: Node2D = scene.get_node("Regions/" + id)
		var active_bodies := 0
		var collision_ok := true
		for group in scene.get_node("Geometry").get_children():
			for body: StaticBody2D in group.get_children():
				collision_ok = collision_ok and body.collision_layer == (1 if str(group.name) == id else 0)
				if body.collision_layer == 1:
					active_bodies += 1
		check_item(id + "_only_active_region_collides", collision_ok and active_bodies == scene.terrain_bodies(id).size(), {"active_bodies": active_bodies})
		var grid: Dictionary = spec.get("terrainGrid", scene.data.get("terrainGrid", {}))
		if not grid.is_empty():
			var tiles: TileMapLayer = region.get_node("Terrain/Terrain47")
			var atlas_metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/terrain47-manifest.json"))["regions"][id]
			var occupied := {}
			for cell: Array in grid["cells"]:
				occupied[Vector2i(int(cell[0]), int(cell[1]))] = true
			var directions := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]
			var grid_ok: bool = tiles.get_used_cells().size() == occupied.size() and not tiles.collision_enabled
			for cell: Vector2i in occupied:
				var raw := 0
				for bit in directions.size():
					if occupied.has(cell + directions[bit]):
						raw |= 1 << bit
				var atlas: Array = atlas_metadata["maskToAtlas"][str(tiles.normalized_mask(raw))]
				grid_ok = grid_ok and tiles.get_cell_atlas_coords(cell) == Vector2i(int(atlas[0]), int(atlas[1]))
			check_item(id + "_47_grid_matches_occupied_cells", grid_ok, {"cells": occupied.size()})
		var lights: Node = region.get_node("Lighting/Lights")
		var native_ok: bool = lights.get_child_count() == spec.get("lighting", {}).get("lights", []).size()
		for light: PointLight2D in lights.get_children():
			var source: Dictionary = spec["lighting"]["lights"][int(light.get_meta("light_index"))]
			native_ok = native_ok and light.enabled and light.texture is GradientTexture2D
			native_ok = native_ok and is_equal_approx(light.texture_scale * 128, float(source["radius"]))
			native_ok = native_ok and light.shadow_enabled == bool(source.get("shadow", true))
			native_ok = native_ok and light.range_item_cull_mask == 1
			native_ok = native_ok and light.position == Vector2(float(source["x"]), float(source["y"])).round()
		var visible_count := 0
		for candidate: Node2D in scene.get_node("Regions").get_children():
			if candidate.visible:
				visible_count += 1
			if candidate != region:
				for light: PointLight2D in candidate.get_node("Lighting/Lights").get_children():
					native_ok = native_ok and not light.enabled
		var background: Sprite2D = region.get_node("Background")
		native_ok = native_ok and background.material is CanvasItemMaterial and background.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED
		var occluders: Node = region.get_node("Lighting/Occluders")
		for occluder: LightOccluder2D in occluders.get_children():
			native_ok = native_ok and occluder.visible and occluder.occluder.polygon.size() >= 3
		check_item(id + "_native_light_rig", native_ok and visible_count == 1, {"lights": lights.get_child_count(), "occluders": occluders.get_child_count()})
		total_lights += lights.get_child_count()
		total_occluders += occluders.get_child_count()
		scene.set_lighting_enabled(false)
		var unlit_ok: bool = scene.get_node("Ambient").color == Color.WHITE and background.modulate == Color.WHITE
		unlit_ok = unlit_ok and not scene.get_node("Traveler/Visual/ReadabilityFill").enabled
		for light: PointLight2D in lights.get_children():
			unlit_ok = unlit_ok and not light.enabled
		check_item(id + "_light_switch", unlit_ok)
		scene.set_lighting_enabled(true)
		var layer_count: int = region.get_node("Midground").get_child_count() + region.get_node("Nearground").get_child_count()
		var depth_ok: bool = layer_count == spec.get("layers", []).size()
		total_depth_layers += layer_count
		scene.ambient_time = 3.2
		scene._update_depth()
		for group_name in ["Midground", "Nearground"]:
			var group: Node2D = region.get_node(group_name)
			for layer: Sprite2D in group.get_children():
				var speed := float(layer.get_meta("parallax"))
				var base: Vector2 = layer.get_meta("base_position")
				var expected: float = base.x + float(scene.camera_offset) - floorf(float(scene.camera_offset) * speed + 0.5)
				depth_ok = depth_ok and layer.position == layer.position.round() and is_equal_approx(layer.position.x, expected)
				var material_ok: bool = layer.material is ShaderMaterial or (layer.material is CanvasItemMaterial and layer.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED)
				depth_ok = depth_ok and layer.texture != null and material_ok
				if layer.material is ShaderMaterial:
					var mask_material := layer.material as ShaderMaterial
					depth_ok = depth_ok and mask_material.get_shader_parameter("platform_mask") is Texture2D
					scene.set_protection_enabled(false)
					depth_ok = depth_ok and mask_material.get_shader_parameter("protection_enabled") == false
					scene.set_protection_enabled(true)
					depth_ok = depth_ok and mask_material.get_shader_parameter("protection_enabled") == true
		scene.set_depth_enabled(false)
		depth_ok = depth_ok and not region.get_node("Midground").visible and not region.get_node("Nearground").visible
		scene.set_depth_enabled(true)
		scene.ambient_time = 1.2
		scene._update_depth()
		depth_ok = depth_ok and scene.camera_offset == 0
		check_item(id + "_independent_pixel_depth", depth_ok, {"layers": layer_count})
		for offset in [-32, 0, 32]:
			scene.set_camera_offset(offset)
			check_item(id + "_camera_" + str(offset), scene.camera_offset == offset)
		scene.camera_manual = false
		scene._update_depth()
		var particles: Node2D = region.get_node("Particles")
		samples[id] = {"1.2": particles.snapshot(1.2), "2.4": particles.snapshot(2.4)}
	var before: float = scene.ambient_time
	await process_frame
	await process_frame
	check_item("paused_clock_stays_fixed", is_equal_approx(before, float(scene.ambient_time)))
	var report := {"engine": Engine.get_version_info().get("string"), "checks": checks, "passed": not failed, "regions": regions.size(), "independent_depth_layers": total_depth_layers, "native_point_lights": total_lights + 1, "occluders": total_occluders, "notes": ["Native node and behavior inspection only.", "Dummy renderer; no Godot frame or lighting appearance inspected.", "Particle samples are deterministic input/state checks, not visual evidence."]}
	var file := FileAccess.open("res://lighting-checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	file = FileAccess.open("res://particle-samples.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(samples, "  ") + "\n")
	file.close()
	print("LIGHTING_CHECKS ", "passed" if not failed else "failed", " count=", checks.size(), " native_lights=", total_lights + 1, " occluders=", total_occluders)
	quit(1 if failed else 0)
