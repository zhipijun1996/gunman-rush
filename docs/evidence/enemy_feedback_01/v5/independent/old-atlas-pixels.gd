extends "res://tests/enemy_feedback_01_tests.gd"
## Independent review-only observer. No direct feedback activation or gameplay writes.
const OUT := "res://build/enemy-feedback-01/v5-refine-review/old-atlas-pixels/"
var observations: Array[Dictionary] = []

func observe_leaf(label: String) -> Dictionary:
	var effect := art.get("feedback_remains") as EnemyFeedback01Remains
	var prior_pause := paused
	paused = true
	var layer := effect.visibility_layer
	var mask := root.canvas_cull_mask
	var channel := 1 << 19
	var ancestors: Array[Dictionary] = []
	var parent := effect.get_parent()
	while parent is CanvasItem:
		ancestors.append({"node":parent,"layer":parent.visibility_layer})
		parent.visibility_layer |= channel
		parent = parent.get_parent()
	effect.visibility_layer = channel
	root.canvas_cull_mask = channel
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	effect.visibility_layer = layer
	root.canvas_cull_mask = mask
	for entry: Dictionary in ancestors: entry.node.visibility_layer = entry.layer
	image.save_png(OUT+label+".png")
	var different := 0
	var clear := Color("26362f")
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c := image.get_pixel(x,y)
			if absf(c.r-clear.r)+absf(c.g-clear.g)+absf(c.b-clear.b) > .06: different += 1
	var source := effect.source as AtlasTexture
	var fragment: Texture2D = effect.get("_fragment_texture")
	var row := {"phase":label,"effect":remains_snapshot(effect),"visible_pixels":different,"HP":actor.health.current,"accepted_contexts":accepted.size(),"source_is_atlas":source != null,"source_region":source.region if source != null else Rect2(),"fragment_texture_path":fragment.resource_path if fragment != null else "","fragment_texture_size":fragment.get_size() if fragment != null else Vector2.ZERO,"uv_origin":effect.get("_uv_origin"),"scope":"actual death leaf isolated by render channel; unchanged other scene effects"}
	observations.append(row)
	paused = prior_pause
	return row

func run() -> void:
	root.size = Vector2i(1280,720)
	RenderingServer.set_default_clear_color(Color("26362f"))
	DirAccess.make_dir_recursive_absolute(OUT)
	for path: String in SOURCES:
		await setup(path,false)
		check(art is EnemyPresentation, "actual original EnemyPresentation consumer retained")
		var species := String(actor.definition.stable_id)
		for hit: int in 3:
			check(await shoot_until_health_changes("independent_original_atlas_projectile"), "original Atlas GPU death uses genuine accepted Router projectile")
		var effect := art.get("feedback_remains") as EnemyFeedback01Remains
		check(actor.health.terminal and accepted.size() == 3 and effect.accepted_starts == 1, "three HP commits produce one original-chain death")
		var early := await observe_leaf(species+"-early")
		check(early.source_is_atlas and early.visible_pixels > 20, "original chain early actual Atlas pixels visible")
		var atlas := effect.source as AtlasTexture
		check(effect.get("_fragment_texture") == atlas.atlas and effect.get("_uv_origin") == atlas.region.position, "fragment polygon uses original atlas and region-local UV origin")
		var guard := 0
		while effect.age < .1 and effect.active and guard < 20:
			await ticks(1,"independent_original_atlas_natural_burst")
			guard += 1
		var fragments := await observe_leaf(species+"-fragments")
		check(effect.phase != &"flash" and effect.active and effect.age >= .1 and effect.age < .2 and fragments.visible_pixels > 0, "actual original Atlas fragment phase draws visible pixels after .1s")
		await ticks(70,"independent_original_atlas_natural_expiry")
		var ended := await observe_leaf(species+"-ended")
		check(not effect.active and effect.phase == &"spent" and ended.visible_pixels == 0, "actual original Atlas effect fully disappears without persistent pixels")
		await cleanup()
	var file := FileAccess.open(OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"task":"ENEMY-FEEDBACK-01","reviewed_commit":"3c5338552b2f7ac275203c4bbf1003e29520a312","checks":checks,"failures":failures,"observations":observations,"scope":"two original EnemyPresentation Atlas consumers, actual Router/projectile lethal events, early/fragment/spent pixels; independent temporary review driver, no production/test edits"},"\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_REVIEW_OLD_ATLAS checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
