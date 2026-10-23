extends "res://tests/enemy_feedback_01_v6_extent.gd"
## Review-only supported right-side and elevated-right fixtures. Real shots only.
const REVIEW_OUT := "res://build/enemy-feedback-01/v6-review/reverse-diagonal"
var diagonal := false

func arena() -> void:
	super.arena()
	if diagonal:
		var support := StaticBody2D.new()
		support.position = Vector2(580,302)
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(160,12)
		collision.shape = shape
		support.add_child(collision)
		world.add_child(support)

func setup(path: String, underworld: bool) -> void:
	await super.setup(path,underworld)
	# One initial supported fixture placement before any request, never recoil
	# compensation or repositioning an effect/actor to make a shot land.
	player.reset_at(Vector2(512,278) if diagonal else Vector2(512,362))
	await ticks(2,"independent_supported_right_fixture")
	check(player.is_on_floor(),"actual right/elevated fixture has Motor floor support before firing")

func frozen_receipt() -> Dictionary:
	var value := super.frozen_receipt()
	value["actual_accepted_hit_directions"] = accepted.map(func(c: Dictionary): return c.get("hit_direction",Vector2.ZERO))
	value["review_fixture"] = "elevated-right" if diagonal else "right"
	return value

func run() -> void:
	root.size = Vector2i(1280,720)
	RenderingServer.set_default_clear_color(Color("26362f"))
	frozen_sources = exact_source_hashes()
	for mode: bool in [false,true]:
		diagonal = mode
		extent_output = REVIEW_OUT.path_join("diagonal" if mode else "reverse")
		DirAccess.make_dir_recursive_absolute(extent_output)
		for path: String in SOURCES:
			for underworld: bool in [false,true]:
				await visibility_pair(&"hit",2,underworld,path)
				var row: Dictionary = measurements.back()
				var directions: Array = row.state_before.actual_accepted_hit_directions
				check(directions.size() == 1,"one actual accepted projectile drives direction sample")
				if not directions.is_empty():
					var direction: Vector2 = directions.front()
					check(direction.x < -.2,"actual accepted projectile came from target right")
					if mode: check(direction.y > .2,"actual accepted elevated projectile has a downward diagonal")
	var final_sources := exact_source_hashes()
	check(frozen_sources == final_sources,"listed review sources stay frozen")
	var file := FileAccess.open(REVIEW_OUT.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"task":"ENEMY-FEEDBACK-01","source_commit":"73556539d4337065eb73537ce2fc2c03d7729c18","checks":checks,"failures":failures,"driver_sha256":FileAccess.get_sha256(get_script().resource_path),"base_observer_sha256":FileAccess.get_sha256("res://tests/enemy_feedback_01_v6_extent.gd"),"source_sha256":frozen_sources,"source_sha256_after":final_sources,"measurements":measurements,"scope":"eight explicit supported initial right/elevated-right fixtures; real Router projectile and frozen same-age visibility pairs across two species/two presentation chains; not natural traversal or user approval"},"\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_REVIEW_REVERSE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
