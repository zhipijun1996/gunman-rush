class_name PlainsPlaceComposer
extends "res://scripts/art/plains_environment_composer.gd"
## Whole painted place bodies. Pixels, outline and shoulder stay one original
## image at one uniform scale; there is no terrain UV or alpha-join pipeline.

func _build_terrain() -> void:
	_facts["terrain_method"] = "complete original Sprite2D, one uniform scale, no crop or shoulder layers"
	var solids: Dictionary = {}
	for solid: Dictionary in _plan.get("solid_polygons", []):
		solids[str(solid.id)] = solid
	var seen: Dictionary = {}
	for instance: Dictionary in _plan.get("terrain_instances", []):
		var id := str(instance.get("id", ""))
		var solid_id := str(instance.get("solid_id", ""))
		var missing: Array[String] = []
		for field: String in ["id", "place_id", "texture", "source_anchor_px", "world_anchor", "uniform_scale", "solid_id"]:
			if not instance.has(field):
				missing.append(field)
		if not missing.is_empty() or not solids.has(solid_id) or seen.has(id):
			_facts.omitted.append({"terrain_instance_id":id, "reason":"whole_body_instance_contract_invalid", "missing_fields":missing, "solid_exists":solids.has(solid_id), "duplicate_id":seen.has(id)})
			continue
		seen[id] = true
		var factor := float(instance.uniform_scale)
		var source_raw: Array = instance.source_anchor_px
		var world_raw: Array = instance.world_anchor
		if factor <= 0.0 or not is_finite(factor) or source_raw.size() != 2 or world_raw.size() != 2:
			_facts.omitted.append({"terrain_instance_id":id, "reason":"whole_body_scale_or_anchor_invalid"})
			continue
		var source_anchor := _pair(source_raw)
		var world_anchor := _pair(world_raw)
		if not source_anchor.is_finite() or not world_anchor.is_finite():
			_facts.omitted.append({"terrain_instance_id":id, "reason":"whole_body_anchor_not_finite"})
			continue
		var texture := _texture({"texture":instance.texture})
		if texture == null:
			continue
		var sprite := Sprite2D.new()
		sprite.name = "WholePlaceBody_" + id.validate_node_name()
		sprite.texture = texture
		sprite.centered = false
		sprite.position = world_anchor - source_anchor * factor
		sprite.scale = Vector2.ONE * factor
		sprite.z_as_relative = false
		sprite.z_index = -2
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		add_child(sprite)
		_presented.append(solid_id)
		var actual_anchor := sprite.global_transform * source_anchor
		_facts.terrain.append({"instance_id":id, "place_id":instance.place_id, "solid_id":solid_id, "source":instance.texture, "source_sha256":FileAccess.get_sha256(str(instance.texture)), "actual_source_dimensions":[texture.get_width(), texture.get_height()], "source_anchor_px":source_raw, "declared_world_anchor":world_raw, "actual_world_anchor":[actual_anchor.x, actual_anchor.y], "actual_position":[sprite.position.x, sprite.position.y], "uniform_scale":factor, "actual_scale":[sprite.scale.x, sprite.scale.y], "node_path":str(sprite.get_path()), "source_region":"entire original texture", "alpha":"original whole image; no generated cap or side masks", "collision_written":false})
	if _facts.terrain.is_empty():
		_facts.omitted.append({"reason":"no_complete_place_body_installed"})

func _build_objects() -> void:
	super._build_objects()
	# The shared bridge source also depicts its measured stone foundations.
	# Retire only supports explicitly owned by an actually installed bridge.
	var bridge_sources: Dictionary = {}
	for item: Dictionary in _facts.objects:
		if str(item.get("role", "")) == "bridge":
			bridge_sources[str(item.surface_id)] = item
	for solid: Dictionary in _plan.get("solid_polygons", []):
		var owner := str(solid.get("presentation_owner_surface_id", ""))
		if owner.is_empty() or not bridge_sources.has(owner):
			continue
		if str(solid.id) not in _presented:
			_presented.append(str(solid.id))
		_facts.objects.append({"role":"source_owned_support", "solid_id":solid.id, "owner_surface_id":owner, "source":bridge_sources[owner].source, "source_sha256":bridge_sources[owner].source_sha256, "primitive_fallback_retired":true})

func _build_layers() -> void:
	for instance: Dictionary in _plan.get("layer_instances", []):
		var factor := float(instance.get("uniform_scale", 0.0))
		var depth := float(instance.get("depth_factor", -1.0))
		var anchor_raw: Array = instance.get("world_anchor", [])
		var pivot_raw: Array = instance.get("pivot_px", [])
		var reference_raw: Array = instance.get("camera_reference", [])
		if factor <= 0.0 or not is_finite(factor) or depth < 0.0 or depth > 1.0 or not is_finite(depth) or anchor_raw.size() != 2 or pivot_raw.size() != 2 or reference_raw.size() != 2:
			_facts.omitted.append({"layer_id":instance.get("id", ""), "reason":"whole_place_layer_contract_invalid"})
			continue
		var texture := _texture({"texture":instance.get("texture", "")})
		if texture == null:
			continue
		var world := _pair(anchor_raw)
		var reference := _pair(reference_raw)
		var sprite := _sprite(instance, texture, world, factor, int(instance.get("z_index", -30)))
		sprite.name = "PlaceWorldLayer_" + str(instance.get("id", "painted")).validate_node_name()
		add_child(sprite)
		_layers.append({"node":sprite, "base_position":world, "reference":reference, "depth_factor":depth})
		_facts.layers.append({"id":instance.get("id", ""), "world_anchor":anchor_raw, "source_pivot_px":pivot_raw, "camera_reference":reference_raw, "depth_factor":depth, "uniform_scale":factor, "actual_source_dimensions":[texture.get_width(), texture.get_height()], "source":instance.texture, "source_sha256":FileAccess.get_sha256(str(instance.texture)), "node_path":str(sprite.get_path()), "mapping":"shared global camera: world anchor + camera delta * (1-depth); no per-place screen reset"})
