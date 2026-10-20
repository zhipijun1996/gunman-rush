extends SceneTree
## Candidate metadata, old replay and target physics. Not Motor or art approval.
const OLD := preload("res://scripts/generation/thorn_forest_region_v2_v13.gd")
const NEW := preload("res://scripts/generation/thorn_forest_region_v2_v14.gd")
const FRUIT := preload("res://scripts/generation/forest_fruit_routes.gd")
const TARGET := preload("res://scripts/world/forest_fruit_anchor.gd")
var checks: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var output := "res://build/forest_fruit/contract.json"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	run.call_deferred()

func check(passed: bool, label: String) -> void:
	checks.append({"passed": passed, "label": label})
	if not passed: printerr("FOREST FRUIT FAIL: " + label)

func run() -> void:
	var tuning := PlayerTuning.load_default()
	var old := OLD.new()
	var candidate := NEW.new()
	var registry := ThornForestRegionGenerator.new()
	var equality := RandomStageGenerator.new()
	check(FRUIT.RETIRED_ANCHORS == ["thorn_mouth__rest_ring", "upper_spiral__rest_ring"], "only the two individually ablated auxiliary rest targets retire; return catch stays")
	for root_index: int in 10:
		for map_index: int in [1, 2]:
			var seed_value := "fruit-contract-%02d/thorn_forest/map_%s" % [root_index, map_index]
			var capabilities := {"grapple": true, "abilities": ["grapple"]}
			var previous: Dictionary = old.generate(seed_value, tuning, map_index, capabilities)
			var generated: Dictionary = candidate.generate(seed_value, tuning, map_index, capabilities)
			check(previous.get("ok", false) and generated.get("ok", false), "both exact versions generate " + seed_value)
			if not previous.get("ok", false) or not generated.get("ok", false): continue
			var m: Dictionary = generated.manifest
			check(m.layout_version == "forest-fruit-routes-v14" and candidate.validate(m, tuning), "new strict identity " + seed_value)
			for field: String in ["platforms", "dangers", "connections", "geometry_instances", "areas", "routes", "enemies", "enemy_drops", "rewards", "pickups", "vine_gate", "boss_arena", "boss_contract", "streams", "stream_positions", "choices"]:
				check(equality._same_data(m[field], previous.manifest[field]), "retained real data / " + field + " / " + seed_value)
			var previous_anchors: Dictionary = {}
			for row: Dictionary in previous.manifest.hook_anchors: previous_anchors[row.id] = row
			var old_bindings: Dictionary = FRUIT._route_bindings(previous.manifest)
			for retired: String in FRUIT.RETIRED_ANCHORS:
				check(previous_anchors.has(retired) and old_bindings.get(retired,[]).is_empty() and not previous_anchors[retired].has("recovery_role") and retired != previous.manifest.vine_gate.key_anchor, "retired auxiliary has no actual route/available edge or recovery/gate consumer / " + retired)
			check(m.hook_anchors.any(func(row: Dictionary) -> bool: return row.id == "broken_arch__return_catch_ring"), "explicit return-catch target retained / " + seed_value)
			var boughs: Dictionary = {}
			for bough: Dictionary in m.fruit_boughs:
				boughs[str(bough.id)] = bough
				var hosts: Array = m.platforms.filter(func(p: Dictionary) -> bool: return p.id == bough.host_support_id)
				check(hosts.size() == 1 and bough.points[0] == bough.root and bough.standing_edge == false, "bough has a retained real host and no standing edge / " + str(bough.id))
				for branch: Array in bough.get("branches",[]):
					check(branch.size() >= 2 and branch[0] in bough.points, "sapling side branch joins the continuous rooted main stem / " + str(bough.id))
				if hosts.size() == 1:
					var r: Array = hosts[0].rect
					var rect := Rect2(r[0],r[1],r[2],r[3])
					var root_point := Vector2(bough.root[0],bough.root[1])
					var perimeter := is_equal_approx(root_point.x,rect.position.x) or is_equal_approx(root_point.x,rect.end.x) or is_equal_approx(root_point.y,rect.position.y) or is_equal_approx(root_point.y,rect.end.y)
					check(rect.grow(0.01).has_point(root_point) and perimeter, "continuous bough roots on the actual support perimeter / " + str(bough.id))
			var proposed: Array[String] = []
			var roles: Dictionary = {}
			var target_roles: Array[Dictionary] = []
			for row: Dictionary in m.hook_anchors:
				var base: Dictionary = previous_anchors.get(row.id, {})
				check(not base.is_empty() and row.position == base.position and bool(row.get("hang_enabled", false)) == bool(base.get("hang_enabled", false)), "target retains exact position and held behavior / " + str(row.id))
				check(row.fruit_role in ["recommended", "optional", "recovery", "gate", "boss"], "target has a real declared role / " + str(row.id))
				roles[row.fruit_role] = int(roles.get(row.fruit_role, 0)) + 1
				target_roles.append({"id": row.id, "role": row.fruit_role, "basis": row.fruit_role_basis, "route_bindings": row.fruit_route_bindings.duplicate(), "presentation": row.fruit_presentation})
				var recommended := false
				for binding: String in row.fruit_route_bindings:
					if binding.begins_with("fast:") or binding.begins_with("growth:"): recommended = true
				check(not str(row.fruit_role_basis).is_empty() and (row.fruit_role != "recommended" or recommended), "recommendation backed by actual fast/growth target / " + str(row.id))
				if row.fruit_presentation == "rooted_fruit":
					var matching: Array = m.platforms.filter(func(p: Dictionary) -> bool: return p.id == row.fruit_host_support_id)
					check(matching.size() == 1, "stem host is an actual retained support / " + str(row.id))
					if matching.size() == 1:
						var r: Array = matching[0].rect
						var point := Vector2(row.fruit_stem_root[0], row.fruit_stem_root[1])
						var rect := Rect2(r[0], r[1], r[2], r[3])
						var on_edge := is_equal_approx(point.x, rect.position.x) or is_equal_approx(point.x, rect.end.x) or is_equal_approx(point.y, rect.position.y) or is_equal_approx(point.y, rect.end.y)
						if row.has("fruit_bough_id"):
							var bough: Dictionary = boughs.get(str(row.fruit_bough_id), {})
							var on_wood: bool = row.fruit_stem_root in bough.get("points",[])
							for branch: Array in bough.get("branches",[]):
								if row.fruit_stem_root in branch: on_wood = true
							check(not bough.is_empty() and bough.host_support_id == row.fruit_host_support_id and bough.attachments.get(str(row.id),[]) == row.fruit_stem_root and on_wood and point.y <= float(row.position[1])-18.0 and point.distance_to(Vector2(row.position[0],row.position[1])) <= 32.0, "fruit hangs briefly below an explicit real-rooted bough / " + str(row.id))
						else:
							check(rect.grow(0.01).has_point(point) and on_edge and point.y <= float(row.position[1])-18.0 and point.distance_to(Vector2(row.position[0], row.position[1])) < 128.0, "short hanging stem ends on actual upper perimeter / " + str(row.id))
				else:
					proposed.append(str(row.id))
					check(row.fruit_presentation == "existing_marker_pending_local_support" and not row.has("fruit_stem_root"), "unsupported placement stays explicit proposed / " + str(row.id))
			check(proposed == m.fruit_routes_contract.pending_spatial_redesign, "all unsupported positions disclosed " + seed_value)
			check(m.hook_anchors.size() == previous.manifest.hook_anchors.size() - FRUIT.RETIRED_ANCHORS.size(), "only explicit individually reviewed retirements " + seed_value)
			var edited := m.duplicate(true)
			edited.hook_anchors[0].position[0] += 1.0
			edited.manifest_hash = NEW._hash(edited)
			check(not candidate.validate(edited, tuning), "coherent rehash cannot move target " + seed_value)
			edited = m.duplicate(true)
			edited.fruit_routes_contract.max_local_stem = 1000.0
			edited.manifest_hash = NEW._hash(edited)
			check(not candidate.validate(edited, tuning), "coherent rehash cannot invent long stem policy " + seed_value)
			var pinned: Dictionary = registry.generate(seed_value, tuning, map_index, {"grapple": true, "abilities": ["grapple"], "forest_layout_version": "forest-interwoven-canopy-v13"})
			check(equality._same_data(pinned, previous), "complete old v13 pin still matches frozen output " + seed_value)
			cases.append({"seed": seed_value, "map": map_index, "previous_hash": previous.manifest.manifest_hash, "candidate_hash": m.manifest_hash, "targets": m.hook_anchors.size(), "pending_spatial_redesign": proposed, "roles": roles, "target_roles": target_roles})
	var target := TARGET.new()
	target.hang_enabled = true
	root.add_child(target)
	check(target.collision_layer == 8 and target.collision_mask == 0 and target.is_in_group(&"grapple_target") and target.hang_enabled, "fruit inherits actual target eligibility and held behavior")
	var shape: CollisionShape2D
	for child: Node in target.get_children():
		if child is CollisionShape2D: shape = child as CollisionShape2D
	check(shape != null and shape.shape is CircleShape2D and is_equal_approx((shape.shape as CircleShape2D).radius, 12.0), "fruit inherits actual unchanged twelve-unit catch radius")
	target.free()
	var failures := checks.filter(func(row: Dictionary) -> bool: return not row.passed).size()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "v14_candidate_contracts_not_Motor_or_art_acceptance", "checks": checks, "cases": cases, "failures": failures}))
	file.close()
	print("FOREST FRUIT CONTRACT: %s checks / %s failures" % [checks.size(), failures])
	quit(0 if failures == 0 else 1)
