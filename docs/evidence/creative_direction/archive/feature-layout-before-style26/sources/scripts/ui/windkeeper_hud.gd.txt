class_name WindkeeperHud
extends Control
## Read-only HealthState view; no timers survive encounter disposal.
const FONT := UnderworldUI.FONT
var intro_only:=false
var encounter: WindkeeperEncounter
var delayed_hp := 0.0
var _last_hp := -1.0
var _hold := 0.0
var _alpha := 0.0
var _name: Label
var _objective: Label
var _intro_name: Label
var _hit_hint := ""
var _hint_age := 0.0
var _skip: Button
var _bell_bar_width := 550.0
var _bell_map: Control
var _bell_menu: Control
var _bell_status: Control
var _bell_controls_scanned := false
var _bound_bell := false
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UnderworldUI.create_theme()
	position = Vector2(540, 18)
	size = Vector2(570, 100)
	_name = Label.new()
	_name.text = "牧风者 / THE WINDKEEPER"
	_name.add_theme_font_size_override("font_size", 20)
	add_child(_name)
	_objective = Label.new()
	_objective.position.y = 52
	_objective.add_theme_font_size_override("font_size", 12)
	add_child(_objective)
	_intro_name = Label.new()
	_intro_name.position = Vector2(-140, 185)
	_intro_name.size = Vector2(580, 90)
	_intro_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_name.add_theme_font_size_override("font_size", 30)
	_intro_name.add_theme_color_override("font_outline_color",Color("172c28"))
	_intro_name.add_theme_constant_override("outline_size",4)
	_intro_name.text = "牧风者\nTHE WINDKEEPER"
	add_child(_intro_name)
	_skip = Button.new()
	_skip.position = Vector2(85, 285)
	_skip.text = "SKIP / 跳过登场"
	_skip.pressed.connect(func() -> void:
		if is_instance_valid(encounter): encounter.skip_intro())
	add_child(_skip)
func bind(value: WindkeeperEncounter) -> void:
	if encounter == value: return
	var was_bell := _bound_bell
	if is_instance_valid(encounter):
		if encounter.armour_hit.is_connected(_armour_hit): encounter.armour_hit.disconnect(_armour_hit)
		if encounter.health.changed.is_connected(_core_damage): encounter.health.changed.disconnect(_core_damage)
	encounter = value
	_bound_bell = is_instance_valid(value) and value is BellstriderEncounter
	_last_hp = -1
	_alpha = 0
	_hit_hint = ""
	_hint_age = 0.0
	_bell_map = null
	_bell_menu = null
	_bell_status = null
	_bell_controls_scanned = false
	if was_bell and not _bound_bell:
		_restore_legacy_layout()
	if is_instance_valid(value):
		delayed_hp = value.health.current
		value.armour_hit.connect(_armour_hit)
		value.health.changed.connect(_core_damage)

func _armour_hit(_point: Vector2) -> void:
	if encounter is BellstriderEncounter:
		_hit_hint = "登场预告 / PREPARE" if encounter.mode == &"intro" else "装甲挡弹，瞄准上端主铃 / ARMOUR — AIM AT THE UPPER BELL"
		_hint_age = 1.2
		return
	if is_instance_valid(encounter) and (encounter.definition as WindkeeperDefinition).continuous_combat:
		_hit_hint = "登场预告 / PREPARE" if encounter.mode == &"intro" else "检查攻击范围 / CHECK YOUR RANGE"
		_hint_age = 0.8
		return
	_hit_hint = "护甲挡弹：等发光铃芯暴露，再瞄准铃芯"
	if encounter!=null and encounter.core_open and encounter.stage_phase>=2 and (encounter.definition as WindkeeperDefinition).storm_profile:
		_hit_hint="背铃只接受上侧射击：上台向下瞄准"
		if encounter.stage_phase==3:
			_hit_hint="先踏亮当前草台，再起跳向下射铃" if encounter.rune_platform!=encounter.chase_segment else "第三阶段：起跳后向下瞄准铃芯"
	_hint_age = 1.6

func _core_damage(result: ActorResourceResult) -> void:
	if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED:
		var hit_label := "命中 -%s / HIT" if is_instance_valid(encounter) and (encounter.definition as WindkeeperDefinition).continuous_combat else "核心命中 -%s / CORE HIT"
		if encounter is BellstriderEncounter:
			hit_label = "主铃命中 -%s / BELL HIT"
		_hit_hint = hit_label % snappedf(absf(result.amount_applied),.01)
		_hint_age = 0.8

func _process(delta: float) -> void:
	var valid := is_instance_valid(encounter)
	var shown := valid and encounter.active and not encounter.health.terminal
	if not get_tree().paused:
		_alpha = move_toward(_alpha, 1.0 if shown else 0.0, delta * 3)
		if valid:
			var hp := encounter.health.current
			if hp != _last_hp:
				_hold = 0.32
				_last_hp = hp
			_hold = maxf(0, _hold - delta)
			if encounter.health.terminal: delayed_hp = 0
			elif _hold <= 0: delayed_hp = move_toward(delayed_hp, hp, delta * encounter.health.capacity * 2)
	modulate.a = _alpha
	visible = _alpha > 0
	var intro := shown and encounter.mode == &"intro"
	_name.visible=not intro_only
	_objective.visible=not intro_only
	var transition:bool=shown and encounter.mode==&"phase_transition" and (encounter.definition as WindkeeperDefinition).platform_trials
	_intro_name.visible = intro or transition
	_skip.visible = intro
	if shown:
		_name.text=(encounter.definition as WindkeeperDefinition).display_name
		_intro_name.text=("风车苏醒 / II\nCLIMB / AIM DOWN" if encounter.stage_phase==2 else "风暴追逐 / III\nLIT SHELF / JUMP / AIM DOWN") if transition else (encounter.definition as WindkeeperDefinition).display_name.replace(" / ","\n")
		var continuous := (encounter.definition as WindkeeperDefinition).continuous_combat
		if continuous and transition:
			_intro_name.text = "风车苏醒 / II\nWATCH THE LANDINGS" if encounter.stage_phase == 2 else "风暴追逐 / III\nDODGE & KEEP ATTACKING"
		if not get_tree().paused: _hint_age = maxf(0, _hint_age - delta)
		var state := "铃芯开放 %.1fs / SHOOT THE GLOWING BELL" % maxf(0, encounter.clock) if encounter.core_open else "护甲关闭 / 等待铃芯发光"
		if continuous:
			state = "登场预告 / PREPARE" if intro else "可持续攻击 / KEEP ATTACKING"
			if encounter is WindkeeperPressureEncounter:
				state = "整组收招 / COUNTER NOW" if encounter.mode == &"recover" else "连招未结束 / KEEP MOVING" if encounter.mode == &"link" else state
		if encounter is BellstriderEncounter:
			state = "登场预告 / PREPARE" if intro else "上端主铃始终可击 / UPPER BELL ALWAYS VULNERABLE"
		var detail := encounter.objective()
		var first := _hit_hint if _hint_age > 0 else state
		_objective.text = first + "\n" + detail
		if encounter is BellstriderEncounter:
			# Observe already reports the permanent weakpoint; do not print it twice.
			_objective.text = first if detail == first or (intro and _hint_age <= 0) else first + "\n" + detail
			_layout_bell_plate()
		_objective.modulate = Color("ffe3a0") if encounter is BellstriderEncounter or continuous or encounter.core_open else Color("c1d4cb")
	queue_redraw()
func _draw() -> void:
	if is_instance_valid(encounter) and encounter.active and encounter.mode in [&"intro",&"phase_transition"] and (encounter.definition as WindkeeperDefinition).platform_trials:
		draw_rect(Rect2(-position.x,-position.y,1280,54),Color(0.03,.07,.06,.7))
		draw_rect(Rect2(-position.x,666-position.y,1280,54),Color(0.03,.07,.06,.7))
		if not encounter is BellstriderEncounter and encounter.stage_phase>=2 and not (encounter.definition as WindkeeperDefinition).continuous_combat:PlainsInteractiveArt.draw_aim(self,Vector2(150,165),66)
	if intro_only: return
	if not is_instance_valid(encounter): return
	var bell := encounter is BellstriderEncounter
	if bell:
		var plate := Rect2(Vector2(-8,-6),Vector2(_bell_bar_width+16,size.y+12))
		draw_rect(plate,Color(0.06,0.10,0.09,0.76))
		draw_rect(plate,Color(UnderworldUI.BORDER,0.75),false,1)
	var bar := Rect2(0, 32, _bell_bar_width if bell else 550.0, 14)
	draw_rect(bar.grow(3), UnderworldUI.BORDER)
	draw_rect(bar, UnderworldUI.INK)
	var capacity := maxf(1, encounter.health.capacity)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * delayed_hp / capacity, bar.size.y)), Color("ba8355"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * encounter.health.current / capacity, bar.size.y)), UnderworldUI.BRASS)
	var definition := encounter.definition as WindkeeperDefinition
	var thresholds: Array=[definition.phase_two_health] if encounter is BellstriderEncounter else [definition.phase_two_health,definition.phase_three_health]
	for threshold: float in thresholds:
		var x := bar.size.x * threshold
		draw_line(Vector2(x, 32), Vector2(x, 46), Color("344840"), 2)
	var protected_state := not encounter.accepts_combat_damage() if definition.continuous_combat else not encounter.core_open
	if encounter is BellstriderEncounter:
		protected_state = not encounter.accepts_combat_damage()
	if protected_state:
		# Shield silhouette communicates an actually protected state even in muted/low effects mode.
		var shield_x := _bell_bar_width-15.0 if bell else 557.0
		draw_colored_polygon(PackedVector2Array([Vector2(shield_x,32),Vector2(shield_x+11,32),Vector2(shield_x+11,40),Vector2(shield_x+5,47),Vector2(shield_x,40)]), Color("98a9a5"))

func _layout_bell_plate() -> void:
	# Read the existing UI owners. Boss UI never moves player status/navigation.
	if not _bell_controls_scanned:
		for sibling: Node in get_parent().get_children():
			if sibling.has_method("status_draw_controls"): _bell_status=sibling as Control
			if sibling is Button and sibling.text == "MENU": _bell_menu=sibling
	if not _bell_controls_scanned:
		var cursor := encounter.get_parent()
		while is_instance_valid(cursor):
			for property: Dictionary in cursor.get_property_list():
				if property.name == "map_view":
					_bell_map=cursor.get("map_view") as Control
			if is_instance_valid(_bell_map): break
			cursor=cursor.get_parent()
	_bell_controls_scanned=true
	var viewport := get_viewport_rect()
	var left := viewport.position.x+clampf(viewport.size.x*0.24,260.0,320.0)
	var right := viewport.end.x-228.0
	var top := viewport.position.y+18.0
	if is_instance_valid(_bell_status) and _bell_status.is_visible_in_tree():
		for control: Control in _bell_status.call("status_draw_controls"):
			var bounds := control.get_global_rect()
			if bounds.position.y<120 and bounds.end.y>top:
				left=maxf(left,bounds.end.x+18)
	for navigation: Control in [_bell_map,_bell_menu]:
		if is_instance_valid(navigation) and navigation.is_visible_in_tree():
			var bounds := navigation.get_global_rect()
			if bounds.position.y<120 and bounds.end.y>top:
				right=minf(right,bounds.position.x-18)
	# Very short canvases use a second row; 1280 and960 retain the middle slot.
	if right-left<240:
		left=viewport.position.x+24
		right=viewport.end.x-24
		top=viewport.position.y+148
	_bell_bar_width=maxf(1,minf(560,right-left))
	position=Vector2(floorf(left+(right-left-_bell_bar_width)*0.5),top)
	scale=Vector2.ONE
	_name.add_theme_font_size_override("font_size",18 if viewport.size.x<1100 else 20)
	_name.clip_text=true
	_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.size=Vector2(_bell_bar_width,26)
	_objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_objective.clip_text=true
	_objective.max_lines_visible=3
	_objective.size=Vector2(_bell_bar_width,54)
	size=Vector2(_bell_bar_width,52+minf(54,_objective.get_minimum_size().y))
	_intro_name.position=Vector2(viewport.get_center().x-position.x-290,185)
	_skip.position=Vector2(viewport.get_center().x-position.x-_skip.get_combined_minimum_size().x*0.5,285)

func _restore_legacy_layout() -> void:
	position=Vector2(540,18)
	size=Vector2(570,100)
	scale=Vector2.ONE
	_name.add_theme_font_size_override("font_size",20)
	_name.clip_text=false
	_name.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
	_name.size=Vector2.ZERO
	_objective.autowrap_mode=TextServer.AUTOWRAP_OFF
	_objective.clip_text=false
	_objective.max_lines_visible=-1
	_objective.size=Vector2.ZERO
	_intro_name.position=Vector2(-140,185)
	_skip.position=Vector2(85,285)
