class_name PlainsRegionScenery
extends Node2D
## Sparse, semantic presentation only. No collision, interaction or random stream.
const VERSION := "plains-composition-v2"
const MAX_LANDMARKS := 8
var manifest: Dictionary
var supports: Array[Rect2] = []
var protected_regions: Array[Rect2] = []
var presentation_manifest: Dictionary = {}

func configure(m: Dictionary, slabs: Array[Rect2] = [], blocked: Array[Rect2] = []) -> void:
	manifest = m
	supports = slabs.duplicate()
	protected_regions = blocked.duplicate()

func _ready() -> void:
	z_index = -10
	var veil := Sprite2D.new()
	var pixels := GradientTexture2D.new()
	pixels.width = 2
	pixels.height = 2
	veil.texture = pixels
	var b: Array = manifest.world_bounds
	veil.position = Vector2(b[0] + b[2] / 2.0, b[1] + b[3] / 2.0)
	veil.scale = Vector2(b[2] / 2.0, b[3] / 2.0)
	var depth := ShaderMaterial.new()
	depth.shader = preload("res://game/presentation/world/art/plains_depth.gdshader")
	veil.material = depth
	add_child(veil)
	var composition := PlainsRegionComposition.new()
	composition.name = "PlainsRegionComposition"
	composition.configure(manifest, supports, protected_regions)
	add_child(composition)
	presentation_manifest = plan(manifest, supports, protected_regions)
	for item: Dictionary in presentation_manifest.items:
		# A complete workshop now supplies this location's actual identity.
		# Keep small meadow windmills as secondary functional orientation props.
		if item.identity in ["repair_gallery","clock_court"] and is_instance_valid(composition.landscape) and composition.landscape.replaces_area(str(item.area_id)):
			continue
		var sprite := Sprite2D.new()
		sprite.name = "Landmark_" + str(item.area_id)
		sprite.texture = PlainsV3Assets.texture("decor.json", item.asset_id)
		sprite.centered = false
		sprite.scale = Vector2.ONE * float(item.scale)
		sprite.position = Vector2(item.display_bounds[0], item.display_bounds[1])
		sprite.modulate = Color(0.88, 0.93, 0.85, 0.86)
		sprite.set_meta("landmark", item.duplicate(true))
		add_child(sprite)

static func solid_supports(stage: PlainsRegionStage) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for module: PlatformingModule in stage.assembler.modules:
		for index: int in module.definition.platforms.size():
			if index in module.definition.one_way_platform_indices:
				continue
			var slab: Rect2 = module.definition.platforms[index]
			result.append(Rect2(slab.position + module.position, slab.size))
	if is_instance_valid(stage.assembler.ground_supports):
		result.append_array(stage.assembler.ground_supports.columns)
	return result

static func protection(stage: PlainsRegionStage) -> Array[Rect2]:
	var blocked: Array[Rect2] = stage.assembler.world_dangers()
	for module: PlatformingModule in stage.assembler.modules:
		# Landing/standing anchors and moving-platform sweeps retain priority.
		for anchor: Vector2 in module.definition.anchors:
			blocked.append(Rect2(module.position + anchor - Vector2(36, 55), Vector2(72, 78)))
		for ferry: ModuleMovingPlatformDefinition in module.definition.ferries:
			blocked.append(Rect2(module.position + ferry.envelope().position, ferry.envelope().size).grow(36))
	for area: Dictionary in stage.generated.manifest.areas:
		var origin := Vector2(area.position[0], area.position[1])
		blocked.append(Rect2(origin - Vector2(90, 110), Vector2(180, 150)))
		# Area headings; route clues are below the standing line.
		# Context signs are dynamic; keep their small observation band clear.
		blocked.append(Rect2(origin + Vector2(-100,-80),Vector2(200,20)))
	for latch: Dictionary in stage.generated.manifest.shot_latch_plan.latches:
		var module: PlatformingModule = stage.assembler.modules[int(latch.node_index)]
		var bell := module.position + Vector2(latch.bell[0], latch.bell[1])
		blocked.append(Rect2(bell - Vector2(85, 125), Vector2(170, 185)))
		blocked.append(Rect2(module.position + Vector2(latch.gate[0], latch.gate[1]), Vector2(latch.gate[2], latch.gate[3])).grow(24))
		if not latch.get("sequence_gate", []).is_empty():
			var gate: Array = latch.sequence_gate
			blocked.append(Rect2(module.position + Vector2(gate[0], gate[1]), Vector2(gate[2], gate[3])).grow(24))
	for connection: Dictionary in stage.generated.manifest.connections:
		if connection.condition == "backside":
			var gate: Array = connection.gate
			blocked.append(Rect2(gate[0], gate[1], gate[2], gate[3]).grow(24))
			var control := Vector2(connection.control[0], connection.control[1])
			blocked.append(Rect2(control - Vector2(130, 65), Vector2(290, 80)))
	for chest: Dictionary in stage.generated.manifest.rewards:
		var point := Vector2(chest.position[0], chest.position[1])
		blocked.append(Rect2(point - Vector2(120, 85), Vector2(240, 120)))
	var merchant := stage.merchant_position
	blocked.append(Rect2(merchant - Vector2(150, 155), Vector2(300, 200)))
	for enemy: Dictionary in stage.generated.manifest.enemies:
		var point := Vector2(enemy.position[0], enemy.position[1])
		var radius := float(enemy.get("patrol_radius", 0)) + 65.0
		var depth := float(enemy.get("dive_depth", 0))
		blocked.append(Rect2(point - Vector2(radius, 90), Vector2(radius * 2.0, 150 + depth)))
	blocked.append(Rect2(stage.spawn - Vector2(100, 160), Vector2(250, 210)))
	return blocked

static func plan(m: Dictionary, slabs: Array[Rect2], blocked: Array[Rect2]) -> Dictionary:
	var items: Array[Dictionary] = []
	var omitted: Array[Dictionary] = []
	var used: Array[String] = []
	for area: Dictionary in m.areas:
		if str(area.get("role", "")) not in ["junction","merchant"]:
			continue
		var id := str(area.get("landmark", ""))
		# Ivy is a hanging asset, not a grounded shrub. Workshop vines attach
		# to the distant building; its foreground support gets a real cairn.
		if id == "ivy": id = "stones"
		if id not in ["ruin_arch", "stones", "windmill", "ivy"]:
			omitted.append({"area_id": area.id, "reason": "unsupported_noninteractive_identity"})
			continue
		if items.size() >= MAX_LANDMARKS or used.count(id) >= (2 if id in ["windmill","stones"] else 1):
			omitted.append({"area_id": area.id, "reason": "sparse_identity_limit"})
			continue
		var origin := Vector2(area.position[0], area.position[1])
		var texture := PlainsV3Assets.texture("decor.json", id)
		var height := 150.0 if id == "windmill" else 112.0 if id == "ruin_arch" else 80.0 if id == "ivy" else 42.0
		var scale_value := height / texture.get_height()
		var size := texture.get_size() * scale_value
		var candidates: Array[Rect2] = []
		for slab: Rect2 in slabs:
			if slab.size.x < size.x + 32 or slab.size.y <= 0 or absf(slab.position.y - origin.y) > 80:
				continue
			if origin.x < slab.position.x - 600 or origin.x > slab.end.x + 600:
				continue
			candidates.append(slab)
		candidates.sort_custom(func(a: Rect2, b: Rect2): return absf(a.get_center().x - origin.x) < absf(b.get_center().x - origin.x))
		var selected: Dictionary = {}
		for slab: Rect2 in candidates:
			# Scan stable positions; never retry generation or alter a supporting body.
			var left := slab.position.x + size.x / 2.0 + 16
			var right := slab.end.x - size.x / 2.0 - 16
			var steps := maxi(1, int((right - left) / 24.0))
			for step: int in range(steps + 1):
				var x := lerpf(left, right, float(step) / steps)
				var bounds := Rect2(Vector2(x - size.x / 2.0, slab.position.y - size.y), size)
				if blocked.any(func(region: Rect2): return region.intersects(bounds.grow(8))):
					continue
				selected = {"area_id": area.id, "asset_id": id, "scale": scale_value, "foot": [x, slab.position.y], "support": rect_values(slab), "display_bounds": rect_values(bounds), "reason": "semantic_identity_on_clear_static_solid", "identity": area.get("identity",""), "depth": "midground", "asset_source": "assets/plains_v3/decor.png", "source_sha256": FileAccess.get_sha256("res://assets/plains_v3/decor.png")}
				break
			if not selected.is_empty():
				break
		if selected.is_empty():
			omitted.append({"area_id": area.id, "asset_id": id, "reason": "no_solid_support" if candidates.is_empty() else "clearance"})
		else:
			items.append(selected)
			used.append(id)
	return {"version": VERSION, "items": items, "omitted": omitted, "asset_manifest_hash": FileAccess.get_sha256("res://assets/plains_v3/manifest.json")}

static func rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
