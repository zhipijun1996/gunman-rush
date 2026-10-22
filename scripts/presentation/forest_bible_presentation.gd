class_name ForestBiblePresentation
extends RefCounted
## V15 presentation only. Solids are rendered by the unchanged shared
## UnderworldTerrain 47-core / exact-boundary adapter mounted by the stage.
const LAYOUT := "forest-bible-world-v15"
const FAR: Texture2D = preload("res://assets/style_exploration/underworld/forest/background_sky.png")
const FOREST_PROPS: Texture2D = preload("res://assets/style_exploration/underworld/forest/chime_props.png")
const TREE := Rect2(16, 16, 968, 740)
const FRUIT: Texture2D = preload("res://assets/forest_bible_v2/native/fruit.png")
const DISCOVERY_TEXTURES := {
	"buried_bell_plate": preload("res://assets/forest_bible_v2/native/buried_bell_plate.png"),
	"mushroom_hut_cache": preload("res://assets/forest_bible_v2/native/mushroom_hut_cache.png"),
	"numbered_bridge_badge": preload("res://assets/forest_bible_v2/native/numbered_bridge_badge.png"),
	"spiral_heartwood_cache": preload("res://assets/forest_bible_v2/native/spiral_heartwood_cache.png"),
	"old_mailbag": preload("res://assets/forest_bible_v2/native/old_mailbag.png"),
	"broken_crown_observatory": preload("res://assets/forest_bible_v2/native/broken_crown_observatory.png"),
}
const DISCOVERY_KINDS := {
	"voiceless_bell": "buried_bell_plate", "root_cache": "mushroom_hut_cache",
	"old_badge": "numbered_bridge_badge", "spiral_core": "spiral_heartwood_cache",
	"unsent_letter": "old_mailbag", "branch_ring_map": "broken_crown_observatory",
}

static func enabled(m: Dictionary) -> bool:
	return m.get("layout_version") in [LAYOUT, "forest-branching-expedition-v16", "forest-varied-bible-v17"]

static func draw_background(canvas: Node2D, m: Dictionary, camera_center: Vector2, view_size: Vector2, _clock: float) -> void:
	# Existing Underworld forest source, rather than an independent new style.
	# One real panorama and one separate alpha tree are two distinct layers;
	# this first cross-region comparison does not claim a completed third layer.
	var view := Rect2(camera_center-view_size*0.5, view_size)
	canvas.draw_rect(view.grow(8), Color("091512"))
	var scale_value := maxf(view_size.x/FAR.get_width(), view_size.y/FAR.get_height())*1.5
	var size := Vector2(FAR.get_size())*scale_value
	var travel := (size-view_size)*0.45
	var offset := Vector2(clampf(camera_center.x*0.035, -travel.x, travel.x), clampf(camera_center.y*0.015, -travel.y, travel.y))
	canvas.draw_texture_rect(FAR, Rect2(camera_center-size*0.5-offset, size), false, Color(0.40, 0.48, 0.46, 1.0))
	if m.get("layout_version") == "forest-branching-expedition-v16":
		_draw_exploration_landmarks(canvas, m, camera_center, view)
	var landmark := _landmark_bounds(m)
	if landmark.has_area():
		var height := 740.0
		var tree_size := Vector2(height*TREE.size.x/TREE.size.y, height)
		var foot := Vector2(landmark.get_center().x, landmark.end.y+32.0)
		# World anchored background identity, never an extra solid surface.
		var parallax := (camera_center-landmark.get_center())*0.12
		canvas.draw_texture_rect_region(FOREST_PROPS, Rect2(foot+parallax-Vector2(tree_size.x*0.5, tree_size.y), tree_size), TREE, Color(0.32, 0.39, 0.35, 0.58))

	# Parent-own drawing precedes the shared terrain child and all actors.
	draw_structure_backdrops(canvas, m)

static func draw_structure_backdrops(canvas: Node2D, m: Dictionary) -> void:
	if not enabled(m): return
	# The Assembler also calls this helper, but its draw order is after terrain.
	# Check the actual host script without a strong preload back-edge to Stage.
	var host_script := canvas.get_script() as Script
	if host_script == null or host_script.get_global_name() != &"ThornForestRegionStage": return
	for row: Dictionary in m.get("platforms", []):
		if row.get("id") != "bible_backbranch__recovery" or bool(row.get("one_way", false)) or row.has("motion"): continue
		var support: Rect2 = _rect(row.rect)
		var scale_value := 400.0/TREE.size.y
		var foot := Vector2(support.position.x+264.0, support.position.y)
		var bounds := Rect2(foot-Vector2(473.0,709.0)*scale_value, TREE.size*scale_value)
		# Keep the entire source span, including faint root tips, supported.
		if bounds.position.x < support.position.x+8.0 or bounds.end.x > support.end.x-8.0: return
		canvas.draw_texture_rect_region(FOREST_PROPS, bounds, TREE, Color(0.23,0.28,0.24,0.42))
		return

static func draw_surface(canvas: Node2D, row: Dictionary) -> void:
	if bool(row.get("one_way", false)):
		UnderworldTerrain.draw_one_way(canvas, _rect(row.rect))

static func draw_surfaces(canvas: Node2D, m: Dictionary) -> void:
	# Solids have a real consumer of the SAME TileSet and exact-boundary
	# shader as Plains. Do not overpaint those pixels with forest log strips.
	for row: Dictionary in m.get("platforms", []):
		draw_surface(canvas, row)

static func draw_fruit(canvas: Node2D, role: String, hang_enabled: bool) -> void:
	var tint := Color.WHITE
	if role == "optional": tint = Color(0.77, 0.84, 0.64, 1.0)
	elif role == "recovery": tint = Color(0.66, 0.95, 0.88, 1.0)
	canvas.draw_texture_rect(FRUIT, Rect2(-10, -20, 20, 28), false, tint)
	if hang_enabled:
		canvas.draw_rect(Rect2(-4, -2, 2, 6), Color("d4eee0"))
		canvas.draw_rect(Rect2(2, -2, 2, 6), Color("d4eee0"))

static func draw_bell(canvas: Node2D, radius: float, damaging: bool) -> void:
	var texture := UnderworldTerrain.mechanism_bell_texture()
	var diameter := maxf(1.0, radius*2.0)
	var size := Vector2(texture.get_size())*diameter/maxf(texture.get_width(), texture.get_height())
	canvas.draw_texture_rect(texture, Rect2(-size*0.5, size), false, Color.WHITE if damaging else Color(0.80, 0.87, 0.76, 1.0))

static func draw_bough(canvas: Node2D, row: Dictionary) -> void:
	# Retain the authored real host path. The existing local branch language
	# avoids the independent high-resolution bark/round-end material family.
	ForestFruitBough.draw(canvas, row)

static func draw_discoveries(canvas: Node2D, m: Dictionary, state: PlainsRegionState, _clock: float) -> void:
	for row: Dictionary in m.get("forest_discoveries", []):
		var kind := str(DISCOVERY_KINDS.get(str(row.get("definition_id", "")), ""))
		if not DISCOVERY_TEXTURES.has(kind): continue
		var texture: Texture2D = DISCOVERY_TEXTURES[kind]
		var support := _support_rect(m, str(row.get("host_support_id", row.get("support_id", ""))))
		if not support.has_area(): continue
		var at := Vector2(float(row.position[0]), support.position.y)
		var width := minf(72.0 if kind in ["mushroom_hut_cache", "broken_crown_observatory"] else 48.0, support.size.x-8.0)
		if width < 20.0: continue
		var size := Vector2(width, width*texture.get_height()/texture.get_width())
		at.x = clampf(at.x, support.position.x+size.x*0.5+2.0, support.end.x-size.x*0.5-2.0)
		var claimed := state != null and state.claimed.has(str(row.id))
		var tint := Color(0.59, 0.65, 0.57, 1.0) if claimed else Color(0.94, 0.96, 0.84, 1.0)
		canvas.draw_texture_rect(texture, Rect2(at-Vector2(size.x*0.5, size.y), size), false, tint)

static func draw_chests(canvas: Node2D, chests: Array) -> void:
	for row: Dictionary in chests:
		var claimed := bool(row.get("claimed", false))
		var texture: Texture2D = UnderworldObjects.OPEN_CHEST if claimed else UnderworldObjects.CLOSED_CHEST
		var at: Vector2 = row.position
		var size := Vector2(texture.get_size())*58.0/texture.get_width()
		# Existing chest row position is its centre, 18wu above the support.
		canvas.draw_texture_rect(texture, Rect2(at+Vector2(-size.x*0.5, 18.0-size.y), size), false)

static func draw_gate(canvas: Node2D, rect: Rect2) -> void:
	# Same copper carrier pixels as the Plains mechanism family. Full real
	# blocking rectangle remains visible without adding a false grapple target.
	UnderworldTerrain.draw_mechanism_beam(canvas, rect)
	UnderworldObjects.sequence_plate(canvas, rect.get_center(), 1, false)

static func _draw_exploration_landmarks(canvas: Node2D, m: Dictionary, camera_center: Vector2, view: Rect2) -> void:
	# Reuse the established low-contrast background tree at two authored hubs.
	# This remains a background identity, never a new wall or standing edge.
	for row: Dictionary in m.get("forest_landmarks", []):
		var host := _support_rect(m, str(row.get("support_id", "")))
		var point: Variant = row.get("position")
		if not host.has_area() or not point is Array or point.size() != 2: continue
		var foot := Vector2(float(point[0]), host.position.y)
		if foot.x < host.position.x or foot.x > host.end.x: continue
		var height := 740.0
		var tree_size := Vector2(height*TREE.size.x/TREE.size.y, height)
		var parallax := (camera_center-foot)*0.12
		var target := Rect2(foot+parallax-Vector2(tree_size.x*0.5,tree_size.y),tree_size)
		if not view.grow(48.0).intersects(target): continue
		canvas.draw_texture_rect_region(FOREST_PROPS,target,TREE,Color(0.32,0.39,0.35,0.58))

static func _landmark_bounds(m: Dictionary) -> Rect2:
	var result := Rect2()
	for row: Dictionary in m.get("platforms", []):
		if str(row.get("structure_id", "")) != "hollow": continue
		var rect := _rect(row.rect)
		result = result.merge(rect) if result.has_area() else rect
	return result

static func _support_rect(m: Dictionary, id: String) -> Rect2:
	for row: Dictionary in m.get("platforms", []):
		if str(row.id) == id: return _rect(row.rect)
	return Rect2()

static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
