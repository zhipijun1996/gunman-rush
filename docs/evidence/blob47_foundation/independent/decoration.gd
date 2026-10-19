extends SceneTree
var checks := 0
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func ck(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL ",message)
func run() -> void:
	var props := Blob47Decoration.new()
	root.add_child(props)
	for index: int in 10:
		var data := Blob47Layout.generate("independent-decor-%02d"%index)
		var keepouts: Array[Rect2] = []
		keepouts.assign(data.keepouts)
		var before := data.duplicate(true)
		seed(98765)
		var expected_randi := randi()
		seed(98765)
		props.configure(data.cells,keepouts,data.seed)
		ck(randi() == expected_randi,"cosmetics does not consume global RNG")
		ck(data == before,"cosmetics does not mutate gameplay data")
		var buckets: Dictionary = {}
		for item: Dictionary in props.placements:
			var totals: Vector2i = buckets.get(item.bucket,Vector2i.ZERO)
			buckets[item.bucket] = totals + Vector2i(1,1 if item.kind==4 else 0)
			for avoid: Rect2 in keepouts: ck(not avoid.grow(10).intersects(item.bounds),"full prop kept out")
			for other: Dictionary in props.placements:
				if item==other: continue
				var distance: float = item.position.distance_to(other.position)
				ck(distance >= Blob47Rules.DECORATION_PROFILE.min_spacing,"prop min spacing")
				if item.kind==4 and other.kind==4: ck(distance >= 160,"lamps have no overlapping 50-radius glows")
		for totals: Vector2i in buckets.values(): ck(totals.x<=12 and totals.y<=2,"actual bucket caps")
		var covered: Array[Rect2] = [data.bounds.grow(100)]
		props.configure(data.cells,covered,data.seed)
		ck(props.placements.is_empty(),"full keepout negative leaves no decoration")
	var module: Dictionary = Blob47Layout.module_catalog()[0]
	for field: String in ["family_ids","tile_size","ports_and_halo","density_profile","background_profile","visual_role","exceptions"]:
		var bad := module.duplicate(true); bad.erase(field)
		ck(not Blob47Layout.validate_module(bad).ok,"missing card field rejected: "+field)
	props.free()
	await process_frame
	await process_frame
	print("INDEPENDENT_DECORATION checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
