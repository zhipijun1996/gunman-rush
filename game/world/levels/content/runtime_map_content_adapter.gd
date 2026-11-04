class_name RuntimeMapContentAdapter
extends RefCounted
## Full-map object conversion. Source geometry stays materialized and unchanged.
const ENEMIES := {"patrol_drone":"patrol","plains_charger":"charger","plains_diver":"diver","plains_hopper":"hopper","plains_sentry":"sentry","plains_fan_sentry":"fan_sentry","plains_root_bell":"root_bell"}
const EXTRA_FIELDS := ["ports","routes","original_pickups","original_region_chests","original_tuning_profile","original_fixture_profile","refresh_reopenable_latches","refresh_carried_enemies","refresh_carrier_warmup_frames","review029_wave","review040_release","retractable_groups"]
const LATCH_FIELDS := ["id","bell","gate","open_seconds","prompt","kind","link_color","sequence_offset","paired_gate","initial_open","return_access","return_access_side_policy","additional_pair_access","ferry_id","actuator_id","carrier_mount","carrier_dock"]
const LATCH_KINDS := ["safe_lesson","remote","timed","ferry_bell","sequence","shot_recoil_combo","toggle_ferry","retractable_gears/v1",""]

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
		for key: String in ["return_access","additional_pair_access"]:
			if raw.has(key) and not LevelContentValidation.point(raw[key]):return "invalid access bell"
		if raw.has("paired_gate") and (not LevelContentValidation.rectangle(raw.paired_gate) or raw.get("initial_open") not in ["A","B"]):return "invalid paired gate"
		if raw.has("carrier_dock") and (not raw.carrier_dock is Dictionary or not LevelContentValidation.rectangle(raw.carrier_dock.get("rect")) or not _carrier_ids(content).has(str(raw.carrier_dock.get("platform_id")))):return "invalid carrier dock"
		for key: String in ["ferry_id","actuator_id","carrier_mount"]:
			if raw.has(key) and not _carrier_ids(content).has(str(raw[key])):return "missing native carrier: "+str(raw[key])
		if raw.has("return_access_side_policy") and raw.return_access_side_policy not in ["any","left","right"]:return "invalid access side"
		if raw.has("link_color") and (not raw.link_color is String or not Color.html_is_valid(raw.link_color)): return "invalid latch color"
	return ""

static func validation_error(content: Dictionary) -> String:
	var error := latch_error(content)
	if not error.is_empty(): return error
	for key: String in ["hooks"]:
		if not content.get(key,[]) is Array or not content.get(key,[]).is_empty(): return "unsupported full-map content: "+key
	var extension_error:=_extension_error(content)
	if not extension_error.is_empty():return extension_error
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
	var fields:=RuntimeMapShotLatchAdapter.SNAPSHOT_FIELDS.duplicate()
	if source.has("paired_gate"):fields.append("pair_open_a")
	if not data is Dictionary or data.size()!=fields.size():return "invalid full-map latch snapshot"
	for key: String in fields:
		if not data.has(key):return "missing latch clock/state"
	for key: String in ["clock","opened_at","sequence_step","open_count","motion_clock"]:
		if not LevelContentValidation.number(data[key]):return "invalid latch clock/count"
	if float(data.clock)<0 or float(data.opened_at)<-1 or float(data.opened_at)>float(data.clock) or not data.is_open is bool or not data.motion_running is bool or float(data.motion_clock)<0:return "invalid latch state"
	if not source.has("ferry_id") and not source.has("targets") and (data.motion_running or float(data.motion_clock)!=0):return "unexpected motion state"
	if float(data.open_count)<0 or float(data.open_count)!=floorf(float(data.open_count)):return "invalid opening count"
	if source.has("paired_gate") and (not data.pair_open_a is bool or data.pair_open_a!=data.is_open):return "invalid paired state"
	var steps: Array=[0.0,1.0] if source.has("sequence_offset") else [0.0]
	if float(data.sequence_step) not in steps:return "invalid sequence phase"
	return ""

static func _carrier_ids(content: Dictionary) -> Dictionary:
	var ids: Dictionary={}
	for row: Dictionary in content.get("moving_platforms",[]):ids[str(row.get("platform_id",""))]=true
	return ids

static func mechanisms(content: Dictionary) -> Array[Dictionary]:
	var values: Array[Dictionary]=[]
	for raw: Dictionary in content.get("latches",[]):
		if raw.get("kind")!="retractable_gears/v1":values.append(raw.duplicate(true))
	for raw: Dictionary in content.get("retractable_groups",[]):
		var spec:=raw.duplicate(true);spec["kind"]="retractable_gears";spec["gate"]=[-4096,-4096,8,8];spec["open_seconds"]=0;values.append(spec)
	for raw: Dictionary in content.get("approved_hq_cells",[]):
		if raw.kind not in ["group_motion","reward_pair","retract_thorns"]:continue
		var spec:=raw.duplicate(true);spec["open_seconds"]=0
		if not spec.has("gate"):spec["gate"]=[-4096,-4096,8,8]
		if not spec.has("bell"):spec["bell"]=[-4096,-4096]
		if raw.kind=="retract_thorns":spec["id"]="target-bell"
		values.append(spec)
	return values

static func _extension_error(content: Dictionary) -> String:
	var carriers:=_carrier_ids(content)
	for index: Variant in content.get("wall_platform_indices",[]):
		if not index is int or index<0 or index>=content.platforms.size() or index in content.one_way_platform_indices:return "invalid climbable wall index"
	for key: String in ["original_pickups","original_region_chests"]:
		if not content.get(key,[]) is Array or not content.get(key,[]).is_empty():return "unhandled original reward declaration: "+key
	for key: String in ["original_tuning_profile","original_fixture_profile"]:
		if content.has(key) and not content[key] is Dictionary:return "invalid source qualification metadata"
	if not content.get("approved_hq_cells",[]) is Array:return "invalid special object array"
	for raw: Variant in content.get("approved_hq_cells",[]):
		if not raw is Dictionary or raw.get("kind") not in ["group_motion","reward_pair","hit_turret","native_one_way_carriers","support_start_motion","projectile_barrier","retract_thorns","rigid_mounted_bell"]:return "unsupported special object kind"
		match str(raw.kind):
			"group_motion","native_one_way_carriers":
				var ids: Variant=raw.get("targets" if raw.kind=="group_motion" else "ids")
				if not ids is Array or ids.is_empty():return "missing carrier group"
				for id: Variant in ids:
					if not carriers.has(str(id)):return "missing group carrier"
				if raw.kind=="group_motion" and (not LevelContentValidation.point(raw.get("bell")) or not raw.get("access") is Array):return "invalid group bell"
			"support_start_motion","projectile_barrier":
				if not carriers.has(str(raw.get("id"))):return "missing special carrier"
			"rigid_mounted_bell":
				if not carriers.has(str(raw.get("mount"))) or not LevelContentValidation.point(raw.get("offset")):return "invalid rigid mount"
			"reward_pair":
				if not LevelContentValidation.rectangle(raw.get("gate")) or not LevelContentValidation.rectangle(raw.get("paired_gate")) or raw.get("initial_open") not in ["A","B"]:return "invalid reward pair"
				if not content.reward_sites.any(func(row:Dictionary):return row.id==raw.get("reward_id")):return "missing pair reward"
			"hit_turret":
				if not LevelContentValidation.rectangle(raw.get("rect")) or not LevelContentValidation.point(raw.get("muzzle")) or not LevelContentValidation.point(raw.get("direction")):return "invalid turret geometry"
				for key: String in ["cooldown","delay","speed","lifetime"]:
					if not LevelContentValidation.number(raw.get(key)) or float(raw[key])<0:return "invalid turret parameter"
			"retract_thorns":
				if not LevelContentValidation.point(raw.get("bell")) or not LevelContentValidation.point(raw.get("access")) or not _bands_valid(raw.get("hazards")):return "invalid retractable thorns"
	for raw: Variant in content.get("retractable_groups",[]):
		if not raw is Dictionary or not LevelContentValidation.identity(raw.get("id")) or not LevelContentValidation.point(raw.get("bell")) or not _bands_valid(raw.get("bands")) or not raw.get("initial_extended") is bool:return "invalid retractable gears"
	for raw: Variant in content.get("refresh_carried_enemies",[]):
		if not raw is Dictionary or not carriers.has(str(raw.get("carrier"))) or not content.enemies.any(func(row:Dictionary):return row.id==raw.get("enemy")):return "invalid carried enemy binding"
	for id: Variant in content.get("refresh_reopenable_latches",[]):
		if not content.latches.any(func(row:Dictionary):return row.id==id and float(row.open_seconds)>0):return "invalid reopenable latch"
	if content.has("review040_release"):
		var release: Variant=content.review040_release
		if not release is Dictionary or not release.get("platform_index") is int or release.platform_index<0 or release.platform_index>=content.platforms.size() or release.get("rect")!=content.platforms[release.platform_index] or not content.reward_sites.any(func(row:Dictionary):return row.id==release.get("reward_id")):return "invalid reward release plate"
	if content.has("review029_wave"):
		var wave: Variant=content.review029_wave
		if not wave is Dictionary or not LevelContentValidation.rectangle(wave.get("rect")) or not LevelContentValidation.number(wave.get("targetX")) or not LevelContentValidation.number(wave.get("speed")) or float(wave.speed)<0 or wave.get("oneShot")!=true:return "invalid ambush wave"
	return ""

static func runtime_state_error(content: Dictionary,value: Variant) -> String:
	if not value is Dictionary:return "invalid module runtime snapshot"
	for key: Variant in value:
		if str(key) not in ["platforms","support_started","wave_triggered","turrets"]:return "unknown module runtime field"
	if not value.get("platforms",{}) is Dictionary:return "invalid carrier snapshot table"
	var carriers:=_carrier_ids(content)
	for id: Variant in value.get("platforms",{}):
		var phase: Variant=value.platforms[id]
		if not carriers.has(str(id)) or not phase is Dictionary or phase.size()!=3 or not LevelContentValidation.number(phase.get("clock")) or float(phase.clock)<0 or not phase.get("running") is bool or not phase.get("controlled") is bool:return "invalid carrier snapshot"
	if value.has("wave_triggered") and (not content.has("review029_wave") or not value.wave_triggered is bool):return "invalid wave snapshot"
	if not value.get("support_started",[]) is Array:return "invalid support-start snapshot"
	for id: Variant in value.get("support_started",[]):
		if not content.get("approved_hq_cells",[]).any(func(row:Dictionary):return row.kind=="support_start_motion" and row.id==id):return "unknown support-start carrier"
	if not value.get("turrets",{}) is Dictionary:return "invalid turret snapshot table"
	for id: Variant in value.get("turrets",{}):
		if not content.get("approved_hq_cells",[]).any(func(row:Dictionary):return row.kind=="hit_turret" and row.id==id):return "unknown saved turret"
		var phase: Variant=value.turrets[id]
		if not phase is Dictionary or phase.size()!=3:return "invalid turret snapshot"
		for key: String in ["clock","next_hit","serial"]:
			if not LevelContentValidation.number(phase.get(key)) or float(phase[key])<0:return "invalid turret phase"
		if float(phase.serial)!=floorf(float(phase.serial)):return "invalid turret serial"
	return ""

static func _bands_valid(value: Variant) -> bool:
	if not value is Array or value.is_empty():return false
	for row: Variant in value:
		if not row is Dictionary or not LevelContentValidation.identity(row.get("id")) or not LevelContentValidation.rectangle(row.get("rect")):return false
	return true

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
	for key: String in ["enemies","reward_sites","thorns","latches","wall_platform_indices","approved_hq_cells"]: view[key]=[]
	for key: String in EXTRA_FIELDS:view.erase(key)
	# Authored presentation hints remain in source metadata; native motion is
	# defined exclusively by the retained trajectory fields.
	for row: Dictionary in view.moving_platforms: row.erase("designState")
	return view

static func configure_definition(definition: PlatformingModuleDefinition, content: Dictionary) -> void:
	definition.set_meta("runtime_map_wall_indices",content.get("wall_platform_indices",[]).duplicate())
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
