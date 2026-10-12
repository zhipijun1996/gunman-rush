class_name PlainsRoomGrammar
extends RefCounted
## Authored action phrases. Only verified module geometry is substituted;
## separators are real resource-restoring floors, never generated green bridges.
const VERSION := 1
const PATH := "res://config/plains_room_templates.json"
const STREAM_VERSION := "room-template-bag-v1"
static var _catalog: Dictionary = {}

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _catalog

static func fingerprint() -> String:
	return FileAccess.get_file_as_string(PATH).sha256_text()

static func template_for(id: String) -> Dictionary:
	for entry: Dictionary in catalog().templates:
		if entry.id == id: return entry
	return {}

static func plan(run_seed: String, stage_index: int, stage_type: StringName) -> Dictionary:
	var bag: Array = catalog().templates.duplicate(true)
	var stream := RunRandomStream.new(run_seed, "room_template", "plains", STREAM_VERSION)
	var used: Array[String] = []
	var selected := "none"
	for slot: int in range(1, mini(stage_index, 6) + 1):
		selected = "none"
		var eligible: Array[String] = []
		for entry: Dictionary in bag:
			var skeleton: String = PlainsBlueprintSchedule.plan(run_seed, slot, &"combat").blueprint_id
			var needs_recoil: bool = entry.variants.any(func(ids: Array): return ids.any(func(id: String): return id.begins_with("plains_recoil_")))
			if needs_recoil and skeleton == "windmill_ascent": continue
			if slot >= int(entry.introduced_at) and str(entry.id) not in used:
				eligible.append(str(entry.id))
		if not eligible.is_empty():
			selected = eligible[stream.next_int(eligible.size())]
			used.append(selected)
	if stage_index >= 7 or stage_type in [&"shop", &"health_reward", &"boss"]: selected = "none"
	return {"version": VERSION, "stream_version": STREAM_VERSION, "catalog_hash": fingerprint(), "template_id": selected}

static func available(phrase: Array, prefix: Array, index: int, tuning: PlayerTuning, g: RandomStageGenerator) -> bool:
	var ids := prefix + phrase
	var recoil := 0
	var ferry := 0
	var hazards := 0
	var budget := PlainsBranchLayout.new().budget()
	for id: String in ids:
		var d := g.definition_for(id)
		if d == null or not d.supports(tuning): return false
		if id in PlainsBranchLayout.TIMED_GEARS and (index < int(budget.gear_introduction_stage) or id == "plains_gear_glade" and index < int(budget.large_gear_introduction_stage)): return false
		if not d.ferries.is_empty() and index < int(budget.ferry_introduction_stage): return false
		recoil += 1 if d.requires_burst else 0
		ferry += 1 if not d.ferries.is_empty() else 0
		hazards += 1 if g._hazardous(d) else 0
	return recoil <= int(budget.max_recoil_per_route) and ferry <= int(budget.max_ferry_modules_per_route) and hazards <= int(budget.max_hazards_per_route)

static func steady_modules(variant: int, type: StringName) -> Array:
	var result: Array = catalog().steady_variants[variant % catalog().steady_variants.size()].duplicate()
	# Coin rooms retain their longer exploration route, without adding pressure.
	if type == &"coin_reward": result.append("plains_perch_rise" if variant % 2 == 0 else "plains_skip_stones")
	return result

static func choose(index: int, type: StringName, prefix: Array, tuning: PlayerTuning, g: RandomStageGenerator, rng: RandomNumberGenerator, preferred := "", variant_override := -1) -> Dictionary:
	var none := {"template_id": "none", "variant": -1, "reason": "introduction_or_respite"}
	if index < 3 or index == 7 or type in [&"shop", &"health_reward"]: return none
	var candidates: Array = catalog().templates.duplicate()
	var start := rng.randi_range(0, candidates.size() - 1)
	var rotated: Array = candidates.slice(start) + candidates.slice(0, start)
	if not template_for(preferred).is_empty():
		rotated = rotated.filter(func(entry: Dictionary): return entry.id != preferred)
		rotated.push_front(template_for(preferred))
	for entry: Dictionary in rotated:
		if index < int(entry.introduced_at): continue
		var eligible: Array[int] = []
		for variant: int in entry.variants.size():
			if (variant_override < 0 or variant == variant_override) and available(entry.variants[variant], prefix, index, tuning, g): eligible.append(variant)
		if eligible.is_empty(): continue
		var variant: int = eligible[rng.randi_range(0, eligible.size() - 1)]
		return {"template_id": str(entry.id), "variant": variant, "reason": "" if preferred.is_empty() or preferred == entry.id else "capability_or_budget", "upper": entry.variants[variant].duplicate(), "lower": steady_modules(variant, type)}
	none.reason = "capability_or_budget"
	return none

static func phrase(modules: Array, rng: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
	result.append(PlainsBranchLayout.SAFE[rng.randi_range(0, PlainsBranchLayout.SAFE.size() - 1)])
	for id: String in modules:
		result.append(id)
		result.append(PlainsBranchLayout.SAFE[rng.randi_range(0, PlainsBranchLayout.SAFE.size() - 1)])
	return result

static func recording(m: Dictionary, choice: Dictionary) -> Dictionary:
	var result := {"version": VERSION, "catalog_hash": fingerprint(), "skeleton": str(m.blueprint_id), "template_id": str(choice.get("template_id", "none")), "variant": int(choice.get("variant", -1)), "reason": str(choice.get("reason", "introduction_or_respite")), "segments": []}
	if result.template_id == "none": return result
	for branch: int in 2:
		var modules: Array = choice.upper if branch == 0 else choice.lower
		var start: int = choice.upper_start if branch == 0 else choice.lower_start
		var path: Array = m.terminal_paths[branch]
		var nodes: Array = path.slice(start, start + modules.size() * 2 + 1)
		var beats: Array = []
		for slot: int in nodes.size():
			beats.append({"node": nodes[slot], "role": "observation" if slot == 0 else "recovery" if slot % 2 == 0 else "challenge" if branch == 0 else "steady", "module_id": m.nodes[int(nodes[slot])].module_id})
		result.segments.append({"branch": branch, "nodes": nodes, "beats": beats})
	return result

static func validate(m: Dictionary, tuning: PlayerTuning, g: RandomStageGenerator) -> bool:
	var data: Variant = m.get("room_grammar")
	if not data is Dictionary or data.get("version") != VERSION or data.get("catalog_hash") != fingerprint() or data.get("skeleton") != m.blueprint_id or data.get("reason") not in ["", "introduction_or_respite", "capability_or_budget", "bounded_layout_fallback"]: return false
	if data.get("template_id") == "none":
		var respite: bool = m.branch_stage_index < 3 or m.branch_stage_index == 7 or m.branch_stage_type in ["shop", "health_reward"]
		if data.reason == "introduction_or_respite" and not respite or data.reason == "bounded_layout_fallback" and m.branch_fallback_reason.is_empty() or data.reason == "": return false
		if data.reason == "capability_or_budget":
			var prefix: Array = []
			for index: int in m.common_path: prefix.append(m.nodes[index].module_id)
			var upper: Array = m.terminal_paths[0]
			var count := 3 if m.nodes[int(upper[0])].module_id == "plains_windchime_well" and upper.size() >= 3 and m.nodes[int(upper[2])].module_id == "plains_recoil_step" else 1
			for slot: int in count: prefix.append(m.nodes[int(upper[slot])].module_id)
			for entry: Dictionary in catalog().templates:
				if m.branch_stage_index < entry.introduced_at: continue
				for phrase_modules: Array in entry.variants:
					if available(phrase_modules, prefix, int(m.branch_stage_index), tuning, g): return false
		return g._same_data(data, recording(m, {"template_id": "none", "variant": -1, "reason": data.reason}))
	if data.reason not in ["", "capability_or_budget"]: return false
	var entry := template_for(str(data.get("template_id")))
	if entry.is_empty() or not g._numeric(data.get("variant")) or data.variant != floorf(data.variant) or data.variant < 0 or data.variant >= entry.variants.size() or m.branch_stage_index < entry.introduced_at or m.branch_stage_index == 7 or m.branch_stage_type in ["shop", "health_reward"] or not data.get("segments") is Array or data.segments.size() != 2: return false
	var choice := {"template_id": entry.id, "variant": int(data.variant), "reason": data.reason, "upper": entry.variants[int(data.variant)], "lower": steady_modules(int(data.variant), StringName(m.branch_stage_type))}
	for branch: int in 2:
		var segment: Variant = data.segments[branch]
		if not segment is Dictionary or not segment.get("nodes") is Array or segment.nodes.is_empty(): return false
		var path: Array = m.terminal_paths[branch]
		var start := path.find(segment.nodes[0])
		if start < 0: return false
		choice["upper_start" if branch == 0 else "lower_start"] = start
		var expected: Array = choice.upper if branch == 0 else choice.lower
		if segment.nodes.size() != expected.size() * 2 + 1 or not g._same_data(segment.nodes, path.slice(start, start + segment.nodes.size())): return false
		for slot: int in segment.nodes.size():
			var id: String = m.nodes[int(segment.nodes[slot])].module_id
			if slot % 2 == 0 and id not in PlainsBranchLayout.SAFE or slot % 2 == 1 and id != expected[slot / 2]: return false
	return g._same_data(data, recording(m, choice))
