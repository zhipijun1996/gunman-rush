class_name ThornForestRegionAssembler
extends PlainsRegionAssembler
## Consumes the forest manifest verbatim. No RNG, player motion or resource grants here.
var forest_platforms: Array[Dictionary] = []
var hook_targets: Dictionary = {}
var support_bodies: Dictionary = {}
var vine_shape: CollisionShape2D
var vine_body: StaticBody2D
var _target_host_presentation: Dictionary = {}
var _reward_shortcut_shapes: Dictionary = {}

func build(recorded: Dictionary, tuning: PlayerTuning) -> Dictionary:
	if not is_inside_tree() or not forest_platforms.is_empty() or not ThornForestRegionGenerator.new().validate(recorded,tuning):
		return {"ok":false,"error":"Invalid forest manifest or occupied assembler"}
	manifest = recorded.duplicate(true)
	if manifest.get("layout_version") in [ForestTargetHosts.LAYOUT,"forest-bible-world-v15","forest-branching-expedition-v16","forest-varied-bible-v17","forest-exploration-places-v18"]:
		_target_host_presentation=ForestTargetHosts.build(manifest)
	bounds = ThornForestRegionGenerator._rect(manifest.world_bounds)
	for row: Dictionary in manifest.platforms: forest_platforms.append(row.duplicate(true))
	for group: Dictionary in _support_groups():
		var body := StaticBody2D.new()
		var members: Array = group.members
		var ids: Array[String] = []
		var rect: Rect2 = group.rect
		body.name = str(members[0].id)
		body.position = rect.get_center()
		body.collision_layer = 1
		if bool(group.one_way): body.add_to_group(&"one_way_platform")
		# One collision owner for overlapping same-height branches. Preserve every
		# original rectangle exactly; only the body ownership is normalized.
		members.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.rect[3]) > float(b.rect[3]))
		for index: int in members.size():
			var row: Dictionary = members[index]
			var original := ThornForestRegionGenerator._rect(row.rect)
			var shape := CollisionShape2D.new()
			shape.name = "CollisionShape2D" if index == 0 else "SupportShape_%s" % index
			var rectangle := RectangleShape2D.new()
			rectangle.size = original.size
			shape.shape = rectangle
			shape.position = original.get_center()-rect.get_center()
			shape.one_way_collision = bool(row.one_way)
			if shape.one_way_collision: shape.one_way_collision_margin = 4.0
			body.add_child(shape)
			support_bodies[row.id] = body
			ids.append(str(row.id))
		body.set_meta("support_ids", ids)
		body.set_meta("support_world_rect", rect)
		add_child(body)
	for row: Dictionary in manifest.hook_anchors:
		var target: GrappleAnchor
		var mount := ForestTargetHosts.mount_for(_target_host_presentation,str(row.id))
		var runtime_fruit: bool = bool(mount.get("resolved",false)) and mount.get("presentation")=="runtime_rooted_fruit"
		var is_fruit: bool = manifest.get("layout_version") in ["forest-fruit-routes-v14","forest-bible-world-v15","forest-branching-expedition-v16","forest-varied-bible-v17","forest-exploration-places-v18"] and (row.get("fruit_presentation") == "rooted_fruit" or runtime_fruit)
		if is_fruit:
			var fruit := ForestFruitAnchor.new()
			fruit.fruit_role = str(row.fruit_role)
			if ForestBiblePresentation.enabled(manifest): fruit.set("bible_presentation", true)
			var stem: Array = mount.stem_root if runtime_fruit else row.fruit_stem_root
			fruit.stem_root = Vector2(stem[0],stem[1]) - Vector2(row.position[0],row.position[1])
			target = fruit
		else:
			target = GrappleAnchor.new()
		target.name = row.id
		target.position = Vector2(row.position[0],row.position[1])
		target.hang_enabled = bool(row.get("hang_enabled",false))
		if manifest.get("layout_version") in ["forest-fruit-routes-v14","forest-bible-world-v15","forest-branching-expedition-v16","forest-varied-bible-v17","forest-exploration-places-v18"] and row.get("fruit_role") == "optional" and not is_fruit:
			target.modulate = Color(0.72,0.76,0.67,0.78)
		add_child(target)
		hook_targets[row.id] = target
	for row: Dictionary in manifest.get("training_bells", []):
		var bell := ForestPracticeBell.new()
		bell.name = str(row.id)
		if not bell.configure(row):
			bell.free()
			return {"ok":false,"error":"Invalid forest practice bell"}
		var state_key := "practice_bell/" + str(row.id)
		if region_state != null and region_state.mechanisms.has(state_key):
			var saved: Variant = region_state.mechanisms[state_key]
			if not saved is Dictionary or not bell.restore_state(saved):
				bell.free()
				return {"ok":false,"error":"Recorded forest practice bell rejected"}
		add_child(bell)
		hook_targets[row.id] = bell
	var gate := ThornForestRegionGenerator._rect(manifest.vine_gate.rect)
	vine_body = StaticBody2D.new()
	vine_body.name = "CrownVineGate"
	vine_body.position = gate.get_center()
	vine_body.collision_layer = 1
	vine_shape = CollisionShape2D.new()
	var gate_rectangle := RectangleShape2D.new()
	gate_rectangle.size = gate.size
	vine_shape.shape = gate_rectangle
	vine_shape.disabled = region_state != null and region_state.opened.has("crown_vine")
	vine_body.add_child(vine_shape)
	add_child(vine_body)
	for row: Dictionary in manifest.get("forest_shortcuts", []):
		var body := StaticBody2D.new()
		body.name = str(row.id)
		body.collision_layer = 1
		var rect := ThornForestRegionGenerator._rect(row.rect)
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		shape.disabled = region_state != null and region_state.opened.has(str(row.opened_key))
		body.add_child(shape)
		add_child(body)
		_reward_shortcut_shapes[str(row.id)] = shape
	resolve_reward_shortcuts()
	queue_redraw()
	return {"ok":true,"error":""}

func _support_groups() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for row: Dictionary in forest_platforms:
		var rect := ThornForestRegionGenerator._rect(row.rect)
		var current := {"rect":rect,"one_way":bool(row.one_way),"members":[row]}
		var changed := true
		while changed and (bool(current.one_way) or manifest.get("scene_language_version")==ForestSceneLanguage.VERSION):
			changed = false
			for i: int in range(groups.size()-1,-1,-1):
				var other: Dictionary = groups[i]
				var a: Rect2 = current.rect
				var b: Rect2 = other.rect
				if bool(other.one_way)!=bool(current.one_way) or absf(a.position.y-b.position.y) > 0.001: continue
				if a.position.x > b.end.x+0.001 or b.position.x > a.end.x+0.001: continue
				current.rect = a.merge(b)
				current.members.append_array(other.members)
				groups.remove_at(i)
				changed = true
		groups.append(current)
	return groups

func resolve_hook_action(traversal: TraversalAbility) -> bool:
	if region_state == null or region_state.opened.has("crown_vine") or traversal.state != &"hook_kick": return false
	var key := str(manifest.vine_gate.key_anchor)
	if traversal.hook_target != hook_targets.get(key) or not is_instance_valid(traversal.hook_target): return false
	region_state.opened["crown_vine"] = true
	vine_shape.set_deferred("disabled", true)
	GameAudio.cue(self, &"door")
	print("FOREST_UI_EVENT ", JSON.stringify({"event":"vine_gate_opened","source":"accepted_hook_contact","anchor":key}))
	queue_redraw()
	return true

# A real accepted cache/discovery transaction is the only unlock source.
func resolve_reward_shortcuts() -> int:
	if region_state == null: return 0
	var opened := 0
	for row: Dictionary in manifest.get("forest_shortcuts", []):
		var key := str(row.opened_key)
		if region_state.opened.has(key): continue
		var accepted := false
		if row.has("unlock_reward_id"):
			var source := "thorn_forest/map_%s/%s" % [manifest.map_index, row.unlock_reward_id]
			accepted = region_state.claimed.get(source, false) == true
		elif row.has("unlock_discovery_id"):
			accepted = region_state.claimed.get(str(row.unlock_discovery_id), false) == true
		if not accepted: continue
		region_state.opened[key] = true
		var shape: CollisionShape2D = _reward_shortcut_shapes.get(str(row.id))
		if is_instance_valid(shape): shape.set_deferred("disabled", true)
		opened += 1
		GameAudio.cue(self, &"door")
		print("FOREST_UI_EVENT ", JSON.stringify({"event":"reward_shortcut_opened","id":str(row.id),"source":"accepted_reward_claim"}))
	if opened > 0: queue_redraw()
	return opened

func setup_damage(_controller: PlayerController, _policy: FrameDamagePolicy, _lifetime: DemoLifetime) -> void:
	# Static hazard emitters are installed by the shared formal DemoApp coordinator.
	pass

func world_anchors() -> Array[Vector2]:
	var output: Array[Vector2] = [world_entry()]
	for area: Dictionary in manifest.areas:
		if area.role not in ["boss", "challenge_reward"]: output.append(Vector2(area.position[0],area.position[1]))
	return output

func world_static_dangers() -> Array[Rect2]:
	var output: Array[Rect2] = []
	for r: Array in manifest.dangers: output.append(ThornForestRegionGenerator._rect(r))
	return output

func world_static_hazard_records() -> Array[Dictionary]:
	# Forest builds real rectangles directly, not PlatformingModules. Keep
	# manifest order exactly aligned with generated_spikes_N in DemoApp.
	# These are authored forest thorns; the plains pit-plane heuristic does
	# not apply to a large recovery-root hazard or a thin hanging thorn band.
	var output: Array[Dictionary] = []
	var presentations: Array = manifest.get("danger_presentations", [])
	for index: int in manifest.dangers.size():
		var presentation: Dictionary = presentations[index] if index < presentations.size() and presentations[index] is Dictionary else {}
		output.append({
			"rect": ThornForestRegionGenerator._rect(manifest.dangers[index]),
			"role": "surface",
			"module_id": str(presentation.get("host_structure_id", "thorn_forest")),
			"authored_id": "forest_thorn_%s" % index,
			"source_kind": "forest_thorn",
			"host_support_id": str(presentation.get("host_support_id", "")),
		})
	return output

func world_dangers() -> Array[Rect2]: return world_static_dangers()

func presentation_host_audit() -> Dictionary:
	return _target_host_presentation.duplicate(true)

func module_index_at(point: Vector2) -> int:
	for i: int in forest_platforms.size():
		if ThornForestRegionGenerator._rect(forest_platforms[i].rect).grow(80).has_point(point): return i
	return -1

func _draw() -> void:
	for anchor: Dictionary in manifest.get("hook_anchors",[]):
		var mount := ForestTargetHosts.mount_for(_target_host_presentation,str(anchor.id))
		if bool(anchor.get("hang_enabled",false)) and anchor.has("tether_origin") and not (manifest.get("layout_version") in ["forest-fruit-routes-v14","forest-bible-world-v15","forest-branching-expedition-v16","forest-varied-bible-v17","forest-exploration-places-v18"] and (anchor.get("fruit_presentation") == "rooted_fruit" or bool(mount.get("resolved",false)))):
			draw_line(Vector2(anchor.tether_origin[0],anchor.tether_origin[1]),Vector2(anchor.position[0],anchor.position[1]),Color("527e5a"),3.0,true)
	if ForestBiblePresentation.enabled(manifest):
		ForestBiblePresentation.draw_structure_backdrops(self, manifest)
	elif manifest.get("scene_language_version", 0) == ForestSceneLanguage.VERSION:
		ForestSceneLanguage.draw_structure_backdrops(self, manifest)
	if manifest.get("layout_version") in ["forest-fruit-routes-v14","forest-bible-world-v15","forest-branching-expedition-v16","forest-varied-bible-v17","forest-exploration-places-v18"]:
		for bough: Dictionary in manifest.get("fruit_boughs", []):
			if ForestBiblePresentation.enabled(manifest): ForestBiblePresentation.draw_bough(self, bough)
			else: ForestFruitBough.draw(self,bough)
		ForestTargetHosts.draw(self,_target_host_presentation)
	if is_instance_valid(vine_shape) and not vine_shape.disabled:
		var gate := ThornForestRegionGenerator._rect(manifest.vine_gate.rect)
		if ForestBiblePresentation.enabled(manifest): ForestBiblePresentation.draw_gate(self, gate)
		else:
			draw_rect(gate,Color("5c5542"))
			for i: int in int(gate.size.y/32):
				var at := gate.position+Vector2(8,i*32)
				draw_line(at+Vector2(-15,0),at+Vector2(15,18),Color("ca9670"),5,true)
	for shortcut: Dictionary in manifest.get("forest_shortcuts", []):
		if region_state != null and region_state.opened.has(str(shortcut.opened_key)): continue
		var rect := ThornForestRegionGenerator._rect(shortcut.rect)
		ForestBiblePresentation.draw_gate(self, rect)
	if ForestBiblePresentation.enabled(manifest):
		ForestBiblePresentation.draw_surfaces(self, manifest)
	for row: Dictionary in forest_platforms:
		if ForestBiblePresentation.enabled(manifest): continue
		if manifest.get("scene_language_version", 0) == ForestSceneLanguage.VERSION and row.has("scene_kind"):
			ForestSceneLanguage.draw_surface(self, row)
			continue
		var rect := ThornForestRegionGenerator._rect(row.rect)
		var one_way: bool = row.one_way
		draw_rect(rect, Color("586544") if one_way else Color("394e38"))
		draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color("c9cd89"),3,true)
		draw_line(Vector2(rect.position.x,rect.end.y),rect.end,Color("293f30"),3,true)
		if one_way:
			# Branch supports have no false solid sidewalls below their one-way tops.
			for i: int in range(1, int(rect.size.x/34)):
				var x := rect.position.x+i*34
				draw_line(Vector2(x,rect.end.y),Vector2(x+9,rect.end.y+8),Color("44563a"),3,true)
		else:
			for i: int in range(1, int(rect.size.x/90)):
				var x := rect.position.x+i*90
				draw_line(Vector2(x,rect.position.y+12),Vector2(x-28,rect.end.y),Color("304532"),5,true)
	if ForestBiblePresentation.enabled(manifest):
		ForestBibleThorns.draw(self, manifest)
		return
	var dangers := world_static_dangers()
	var presentations: Array = manifest.get("danger_presentations", [])
	for danger_index: int in dangers.size():
		var hazard: Rect2 = dangers[danger_index]
		if danger_index < presentations.size() and presentations[danger_index] is Dictionary:
			var facing := str(presentations[danger_index].get("facing", ""))
			if facing in ["up", "down"]:
				_draw_oriented_thorns(hazard, facing == "down")
				continue
		# Historical v1 presentation remains the fallback for its recorded data.
		for i: int in int(hazard.size.x/14):
			var at := hazard.position+Vector2(i*14,0)
			draw_colored_polygon(PackedVector2Array([at+Vector2(0,18),at+Vector2(7,0),at+Vector2(14,18)]),Color("ba7767"))

func _draw_oriented_thorns(hazard: Rect2, downward: bool) -> void:
	# The tinted envelope is harmful too, including the gaps between the teeth.
	# Its extent comes from the same rectangle as the formal damage emitter.
	draw_rect(hazard, Color(0.73, 0.36, 0.29, 0.25))
	var base_y := hazard.position.y if downward else hazard.end.y
	var tip_y := hazard.end.y if downward else hazard.position.y
	for index: int in int(ceil(hazard.size.x/14.0)):
		var left := hazard.position.x+index*14.0
		var right := minf(left+14.0, hazard.end.x)
		draw_colored_polygon(PackedVector2Array([
			Vector2(left, base_y), Vector2((left+right)*0.5, tip_y), Vector2(right, base_y)
		]), Color("ba7767"))
	draw_rect(hazard, Color("e4a788"), false, 1.0)
