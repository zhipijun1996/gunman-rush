@tool
extends RefCounted
## Keep author guidance with the editable contracts. Numeric defaults and validation come from the catalog.
const BOOKS := ["失序之钟_基本机关库.md", "失序之钟_预组与组合推荐.md"]
static var _sections := {}
static var _codes := {}
static var _labels := {}

static func read_books() -> void:
	if not _labels.is_empty(): return
	_labels = JSON.parse_string(FileAccess.get_file_as_string("res://addons/mechanism_library/zh_fields.json"))
	var heading := RegEx.create_from_string("^#{3,4} ([CGP][0-9]{2}) ")
	var token := RegEx.create_from_string("`([^`]+)`")
	for name: String in BOOKS:
		var path := ProjectSettings.globalize_path("res://").path_join("../docs/data").path_join(name)
		if not FileAccess.file_exists(path): continue
		var code := ""
		var map := false
		for raw: String in FileAccess.get_file_as_string(path).split("\n"):
			if raw.begins_with("#"):
				code = ""
				map = raw.contains("定义 ID 对照")
				var found := heading.search(raw)
				if found:
					code = found.get_string(1)
					_sections[code] = {}
			if not raw.begins_with("|"): continue
			var cols := raw.trim_prefix("|").trim_suffix("|").split("|")
			if cols.size() < 2: continue
			if map:
				var ids := token.search_all(cols[1])
				var codes := cols[0].strip_edges().split("、")
				if codes.size() == 1 and str(codes[0]).contains("～"):
					var first := str(codes[0]).split("～")[0]
					codes.clear()
					for i in ids.size(): codes.append(first[0]+"%02d"%(int(first.substr(1))+i))
				if ids.size() == codes.size():
					for i in ids.size(): _codes[ids[i].get_string(1)] = codes[i]
			elif code != "" and cols.size() >= 4:
				for field: RegExMatch in token.search_all(cols[0]):
					_sections[code][field.get_string(1)] = {"type":cols[1].strip_edges(), "rule":cols[3].strip_edges().replace("`","")}

static func palette(region: String, query: String) -> Array:
	read_books()
	var available := WorldElementCatalog.mechanism_palette(region)
	var found := []
	for scope: String in ["common","regional"]:
		for id: String in available.get(scope,[]):
			var d: Dictionary = WorldElementCatalog.catalog().definitions[id]
			var caption := "%s %s" % [_codes.get(id,""),d.name]
			if not (caption+" "+id).to_lower().contains(query.strip_edges().to_lower()): continue
			found.append({"id":id,"caption":caption.strip_edges(),"scope":scope})
	found.sort_custom(func(a,b): return a.caption < b.caption)
	return found

static func fields(d: Dictionary) -> Dictionary:
	read_books()
	var schema: Dictionary = d.get("creation_fields",{}) if d.has("members") else WorldElementCatalog.catalog().behaviors[d.component].get("fields",{})
	var notes: Dictionary = _sections.get(_codes.get(d.id,""),{})
	var result := {}
	for key: String in schema:
		if key in ["id","element_id","time_profile"]: continue
		var field: Dictionary = schema[key].duplicate(true)
		var contract: Dictionary = notes.get(key,{})
		var title := str(field.get("label",key))
		if title == key: title = _labels.get(key,key)
		field.label = title
		if not field.has("unit"): field.unit = contract.get("type","")
		var limits := PackedStringArray()
		if field.get("required",false): limits.append("必填")
		if field.get("integer",false): limits.append("整数")
		if field.get("positive",false): limits.append("正数")
		if field.has("min"): limits.append("≥ "+str(field.min))
		if field.has("max"): limits.append("≤ "+str(field.max))
		if field.has("min_component"): limits.append("每个分量 ≥ "+str(field.min_component))
		if not contract.is_empty(): limits.append(contract.rule)
		field.hint = " · ".join(limits)
		if d.get("defaults",{}).has(key): field.default = d.defaults[key]
		result[key] = field
	return result

static func route_length(endpoint: Array, points: Array) -> float:
	var last := Vector2.ZERO
	var length := 0.0
	for point: Array in ([endpoint] if points.is_empty() else points):
		var next := Vector2(point[0],point[1])
		length += last.distance_to(next)
		last = next
	return length

## Inputs are validated, expanded rows. A frequently edited member is never regenerated from a preset.
static func derived(row: Dictionary) -> Dictionary:
	var d: Dictionary = WorldElementCatalog.catalog().definitions[row.definition_id]
	var p: Dictionary = d.get("defaults",{}).duplicate(true)
	p.merge(row.properties,true)
	var data := {}
	var drive := str(p.get("drive_id",""))
	var time: String = d.get("time_profiles",{}).get(str(p.get("motion_mode","")),d.get("time_profile","incompatible"))
	data["时间附魔"] = "跟随运动所有者" if drive != "" else ("作用于机关" if time == "mechanism" else "不适用")
	if drive != "": data["运动驱动"] = drive
	if row.has("assembly_id"): data["预组来源"] = "%s · v%s" % [row.assembly_definition_id,row.get("assembly_definition_version",1)]
	match str(row.definition_id):
		"platform.moving":
			if drive == "" and p.motion_mode in ["cycle","call_dock"]:
				var length := route_length(p.endpoint,p.route)
				data["单程路径（px）"] = length
				data["单程平均移动速度（px/s）"] = 2.0*length/p.period
				data["完整往返（s）"] = p.period+2*p.endpoint_dwell
		"hazard.gear": data["完整往返（s）"] = p.period+2*p.endpoint_dwell
		"traversal.hook","traversal.hook_point","traversal.moving_hook":
			if p.has("reactivate_warning_s"): data["有效复明预告（s）"] = minf(p.reactivate_warning_s,p.cooldown_s)
		"platform.windchime_dandelion":
			data["完整往返（s）"] = p.period+2*p.endpoint_dwell
			data["单程路径（px）"] = route_length(p.endpoint,p.route)
		"hazard.area":
			if p.hazard_mode == "cycle": data["名义周期（s）"] = p.inactive_s+p.warning_s+p.active_s
		"surface.projectile_mirror":
			if p.orientation_mode == "indexed" and p.normal_angles_deg.size() > 1:
				var speeds := []
				for i: int in p.normal_angles_deg.size():
					var next: float = p.normal_angles_deg[(i+1)%p.normal_angles_deg.size()]
					speeds.append(absf(wrapf(next-p.normal_angles_deg[i],-180,180))/p.turn_s)
				data["各相邻档角速度（°/s）"] = speeds
		"platform.crumble":
			if p.trigger_mode == "cycle": data["名义周期（s）"] = p.solid_s+p.crack_s+p.absent_s+p.reform_s
		"hazard.retracting_spikes":
			if p.mode == "cycle": data["名义周期（s）"] = p.retracted_s+p.warning_s+p.extend_s+p.exposed_s+p.retract_s
		"platform.shot_rail":
			var durations := []
			for i: int in range(1,p.stations.size()):
				var a: Array = p.stations[i-1]
				var b: Array = p.stations[i]
				durations.append(Vector2(a[0],a[1]).distance_to(Vector2(b[0],b[1]))/p.move_speed)
			data["各站间行程（s）"] = durations
		"hazard.cyclic_press":
			data["名义周期（s）"] = p.top_hold+p.warning_time+p.stroke/p.down_speed+p.bottom_hold+p.stroke/p.up_speed
		"traversal.rising_bubble": data["名义上升时间（s）"] = p.rise_distance/p.rise_speed
		"environment.local_light":
			if p.light_mode == "guide":
				data["单程路径（px）"] = route_length(p.endpoint,p.route)
				data["单程移动时间（s，不含停留）"] = data["单程路径（px）"]/p.move_speed
		"internal.counterweight":
			var speeds := []
			for distance: float in p.stroke: speeds.append(distance*p.loaded_rate)
			data["各台单侧承重速度（px/s）"] = speeds
		"internal.route_switch":
			data["A / B 组成员数"] = [p.groups.A.size(),p.groups.B.size()]
		"internal.mechanism_orbit":
			data["载台数量"] = p.angle_offsets_deg.size()
			data["角速度（°/s）"] = 360.0/p.period
			data["初始相位"] = fposmod(p.initial_angle_deg/360.0,1.0)
		"internal.sequence_wave":
			var count := int(p.members_order.size())
			data["栈板数量"] = count
			data["相邻稳定重叠（s）"] = maxf(0,p.hold_duration-p.start_interval)
			data["相邻稳定空档（s）"] = maxf(0,p.start_interval-p.hold_duration)
			data["名义总时长（s）"] = p.warning_duration+maxi(0,count-1)*p.start_interval+p.deploy_duration+p.hold_duration+p.retract_duration
		"zone.environment":
			if p.mode == "wind" and p.wind_pattern == "vortex":
				data["旋涡中心（px）"] = [p.bounds[0]+p.bounds[2]/2.0,p.bounds[1]+p.bounds[3]/2.0]
				data["旋涡半径（px）"] = p.bounds[2]/2.0
		"internal.permanent_result":
			data["终态目标"] = p.result_target_id
			data["最终状态"] = {"open_gate":"门开启","lower_beam":"梁到达姿态 0","settle_block":"重物落稳"}.get(p.result_kind,p.result_kind)
		"interaction.action":
			if p.get("action_id","") != "": data["世界行动"] = p.action_id
	return data
