class_name RuntimeMapContentAdapter
extends RefCounted
## Full-map object conversion. Source geometry stays materialized and unchanged.
const ENEMIES := {"patrol_drone":"patrol","plains_charger":"charger","plains_diver":"diver","plains_hopper":"hopper","plains_sentry":"sentry","plains_fan_sentry":"fan_sentry","plains_root_bell":"root_bell"}
const LATCH_FIELDS := ["id","bell","gate","open_seconds","prompt","kind","link_color","sequence_offset"]
const LATCH_KINDS := ["safe_lesson","remote","timed","ferry_bell","sequence","shot_recoil_combo",""]

static func latch_error(content: Dictionary) -> String:
	if not content.get("latches") is Array: return "latches must be an array"
	for row: Variant in content.get("moving_platforms",[]):
		if row is Dictionary and row.has("designState") and row.designState not in ["FROZEN_EXAMPLE","MOVING_EXAMPLE"]: return "unsupported moving platform design hint"
	var seen := {}
	for raw: Variant in content.latches:
		if not raw is Dictionary: return "invalid latch record"
		for key: Variant in raw:
			if str(key) not in LATCH_FIELDS: return "unsupported latch field: "+str(key)
		if not LevelContentValidation.identity(raw.get("id")) or seen.has(raw.id): return "invalid/duplicate latch identity"
		seen[raw.id]=true
		if not LevelContentValidation.point(raw.get("bell")) or not LevelContentValidation.rectangle(raw.get("gate")): return "invalid latch geometry"
		if not LevelContentValidation.number(raw.get("open_seconds")) or float(raw.open_seconds)<0: return "invalid latch duration"
		if str(raw.get("kind","")) not in LATCH_KINDS: return "unsupported latch kind"
		if raw.has("sequence_offset") and not LevelContentValidation.point(raw.sequence_offset): return "invalid sequence offset"
		if raw.has("link_color") and (not raw.link_color is String or not Color.html_is_valid(raw.link_color)): return "invalid latch color"
	return ""

static func validation_error(content: Dictionary) -> String:
	var error := latch_error(content)
	if not error.is_empty(): return error
	for key: String in ["hooks","approved_hq_cells","wall_platform_indices"]:
		if not content.get(key,[]) is Array or not content.get(key,[]).is_empty(): return "unsupported full-map content: "+key
	for field: String in ["enemies","reward_sites","thorns"]:
		if not content.get(field) is Array: return "missing full-map array: "+field
	var seen := {}
	for row: Variant in content.enemies:
		if not row is Dictionary: return "invalid enemy row"
		for key: Variant in row:
			if str(key) not in ["id","definition","position","initial_idle_cooldown"]: return "unsupported enemy field: "+str(key)
		if not LevelContentValidation.identity(row.get("id")) or seen.has(row.id) or not ENEMIES.has(str(row.get("definition",""))) or not LevelContentValidation.point(row.get("position")): return "invalid enemy identity/definition/position"
		if row.has("initial_idle_cooldown") and (not LevelContentValidation.number(row.initial_idle_cooldown) or float(row.initial_idle_cooldown)<0): return "invalid enemy initial cooldown"
		seen[row.id]=true
	seen.clear()
	for row: Variant in content.reward_sites:
		if not row is Dictionary: return "invalid reward row"
		for key: Variant in row:
			if str(key) not in ["id","position","region","amount"]: return "unsupported reward field: "+str(key)
		if not LevelContentValidation.identity(row.get("id")) or seen.has(row.id) or not LevelContentValidation.point(row.get("position")) or not LevelContentValidation.rectangle(row.get("region")) or not LevelContentValidation.number(row.get("amount")) or float(row.amount)<=0 or float(row.amount)!=floorf(float(row.amount)): return "invalid reward identity/geometry/amount"
		seen[row.id]=true
	seen.clear()
	for row: Variant in content.thorns:
		if not row is Dictionary: return "invalid thorn row"
		for key: Variant in row:
			if str(key) not in ["surface_id","platform_index","face","start_offset","length","depth"]: return "unsupported thorn field"
		if not LevelContentValidation.identity(row.get("surface_id")) or seen.has(row.surface_id) or str(row.get("face","")) not in ["top","left","right","bottom"]: return "invalid thorn identity/face"
		for key: String in ["platform_index","start_offset","length","depth"]:
			if not LevelContentValidation.number(row.get(key)): return "invalid thorn parameter"
		if float(row.platform_index)!=floorf(float(row.platform_index)): return "invalid thorn platform index"
		seen[row.surface_id]=true
	return ""

static func snapshot_error(data: Variant, source: Dictionary) -> String:
	if not data is Dictionary or data.size()!=RuntimeMapShotLatchAdapter.SNAPSHOT_FIELDS.size(): return "invalid full-map latch snapshot"
	for key: String in RuntimeMapShotLatchAdapter.SNAPSHOT_FIELDS:
		if not data.has(key): return "missing latch clock/state"
	for key: String in ["clock","opened_at","sequence_step","open_count","motion_clock"]:
		if not LevelContentValidation.number(data[key]): return "invalid latch clock/count"
	if float(data.clock)<0 or float(data.opened_at)<-1 or float(data.opened_at)>float(data.clock) or not data.is_open is bool or data.motion_running!=false or float(data.motion_clock)!=0: return "invalid latch state"
	if float(data.open_count)<0 or float(data.open_count)!=floorf(float(data.open_count)): return "invalid opening count"
	var steps: Array=[0.0,1.0] if source.has("sequence_offset") else [0.0]
	if float(data.sequence_step) not in steps: return "invalid sequence phase"
	return ""

static func geometry_content(content: Dictionary) -> Dictionary:
	var resolved := content.duplicate(true)
	var defaults := ModuleSawDefinition.new()
	for row: Variant in resolved.get("saws",[]):
		if not row is Dictionary: continue
		if not row.has("damage"): row["damage"]=defaults.damage
		if not row.has("contact_interval"): row["contact_interval"]=defaults.contact_interval
	for row: Variant in resolved.get("moving_platforms",[]):
		if row is Dictionary and row.get("trajectory_kind")=="clockwise_ellipse/v1" and not row.has("ellipse_x_sign"):
			row["ellipse_x_sign"]=RuntimeMapEllipseDefinition.new().x_sign
	return resolved

static func geometry_view(content: Dictionary) -> Dictionary:
	# These fields have their own validators/consumers above. This view feeds
	# the original geometry validator; the plan retains the complete source.
	var view := geometry_content(content)
	for key: String in ["enemies","reward_sites","thorns","latches"]: view[key]=[]
	# Authored presentation hints remain in source metadata; native motion is
	# defined exclusively by the retained trajectory fields.
	for row: Dictionary in view.moving_platforms: row.erase("designState")
	return view

static func configure_definition(definition: PlatformingModuleDefinition, content: Dictionary) -> void:
	for raw: Dictionary in content.thorns:
		var thorn := PlatformThornDefinition.new()
		thorn.surface_id=StringName(raw.surface_id)
		thorn.platform_index=int(raw.platform_index)
		thorn.face={"top":0,"left":1,"right":2,"bottom":3}[str(raw.face)]
		thorn.start_offset=float(raw.start_offset)
		thorn.length=float(raw.length)
		thorn.depth=float(raw.depth)
		definition.surface_thorns.append(thorn)

static func append_objects(plan: LevelPlan, content: Dictionary, instance: Dictionary, origin: Vector2) -> void:
	var prefix := "plains/map_%s/%s/" % [plan.map_index,instance.id]
	for raw: Dictionary in content.enemies:
		plan.actors.append({"id":prefix+str(raw.id),"behavior_id":StringName(ENEMIES[str(raw.definition)]),"position":origin+Vector2(raw.position[0],raw.position[1]),"overrides":{},"initial_idle_cooldown":float(raw.get("initial_idle_cooldown",0))})
	for raw: Dictionary in content.reward_sites:
		if instance.role=="target_reward": continue
		var point := origin+Vector2(raw.position[0],raw.position[1])
		# The source's explicit amount is a coin entitlement, never an item roll.
		plan.pickups.append({"id":prefix+str(raw.id),"kind":"coin","amount":int(raw.amount),"position":point})
