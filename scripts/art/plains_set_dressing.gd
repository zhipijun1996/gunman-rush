class_name PlainsSetDressing
extends Node2D
## Separate deterministic presentation plan. No level/reward stream is consumed.
const VERSION := "plains-v3-dressing-1"
var presentation_manifest: Dictionary = {}
func configure(stage: GeneratedDemoStage) -> void:
	presentation_manifest = plan(stage)
	for item: Dictionary in presentation_manifest.items:
		var sprite := Sprite2D.new()
		sprite.texture = PlainsV3Assets.texture("decor.json", item.id)
		sprite.centered = false
		sprite.position = Vector2(item.x, item.y)
		sprite.scale = Vector2.ONE * float(item.scale)
		sprite.z_index = -2 if bool(item.landmark) else 1
		sprite.modulate = Color(0.76, 0.81, 0.71, 0.52) if bool(item.landmark) else Color(0.94, 0.96, 0.83, 0.85)
		add_child(sprite)
static func plan(stage: GeneratedDemoStage) -> Dictionary:
	var seed_text := str(stage.generated.manifest.seed)
	var stream := RunRandomStream.new(seed_text, "decoration", "plains", VERSION)
	var items: Array[Dictionary] = []
	var landmarks := 0
	var blocked: Array[Rect2] = stage.assembler.world_dangers()
	for point: Vector2 in stage.exit_positions:
		blocked.append(Rect2(point - Vector2(110, 180), Vector2(220, 240)))
	blocked.append(Rect2(stage.spawn - Vector2(90, 140), Vector2(180, 200)))
	if is_instance_valid(stage.route_signpost):
		blocked.append(Rect2(stage.route_signpost.position - Vector2(100, 170), Vector2(220, 200)))
	var blueprint := str(stage.generated.manifest.get("blueprint_id", "bridge_crossing"))
	for module: PlatformingModule in stage.assembler.modules:
		for local_rect: Rect2 in module.definition.platforms:
			var rect := Rect2(module.to_global(local_rect.position), local_rect.size)
			if rect.size.x < 180 or rect.size.y < 40 or items.size() >= 24:
				continue
			# Small ivy/stone detail lives below the standing line inside solid rock.
			var id := "ivy" if stream.next_int(2) == 0 else "stones"
			var texture := PlainsV3Assets.texture("decor.json", id)
			var scale_value := minf(32.0 / texture.get_height(), (rect.size.x - 32) / texture.get_width())
			var x := rect.position.x + 12 + stream.next_int(maxi(1, int(rect.size.x - texture.get_width() * scale_value - 24)))
			items.append({"id": id, "x": x, "y": rect.position.y + 6, "scale": scale_value, "landmark": false})
			if landmarks >= 2 or rect.size.x < 300:
				continue
			var landmark_id := "windmill" if blueprint == "windmill_ascent" else "ruin_arch"
			var image := PlainsV3Assets.texture("decor.json", landmark_id)
			var factor := 130.0 / image.get_height()
			var area := Rect2(Vector2(rect.get_center().x - image.get_width() * factor / 2, rect.position.y - 130), image.get_size() * factor)
			var safe := true
			for danger: Rect2 in blocked:
				if danger.grow(24).intersects(area):
					safe = false
			if safe:
				items.append({"id": landmark_id, "x": area.position.x, "y": area.position.y, "scale": factor, "landmark": true})
				landmarks += 1
	return {"version": VERSION, "asset_manifest_hash": FileAccess.get_sha256("res://assets/plains_v3/manifest.json"), "decoration_seed": seed_text, "items": items}
