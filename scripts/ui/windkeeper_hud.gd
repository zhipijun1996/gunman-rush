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
	if is_instance_valid(encounter):
		if encounter.armour_hit.is_connected(_armour_hit): encounter.armour_hit.disconnect(_armour_hit)
		if encounter.health.changed.is_connected(_core_damage): encounter.health.changed.disconnect(_core_damage)
	encounter = value
	_last_hp = -1
	_alpha = 0
	_hit_hint = ""
	_hint_age = 0.0
	if is_instance_valid(value):
		delayed_hp = value.health.current
		value.armour_hit.connect(_armour_hit)
		value.health.changed.connect(_core_damage)

func _armour_hit(_point: Vector2) -> void:
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
		_objective.text = (_hit_hint if _hint_age > 0 else state) + "\n" + encounter.objective()
		_objective.modulate = Color("ffe3a0") if continuous or encounter.core_open else Color("c1d4cb")
	queue_redraw()
func _draw() -> void:
	if is_instance_valid(encounter) and encounter.active and encounter.mode in [&"intro",&"phase_transition"] and (encounter.definition as WindkeeperDefinition).platform_trials:
		draw_rect(Rect2(-position.x,-position.y,1280,54),Color(0.03,.07,.06,.7))
		draw_rect(Rect2(-position.x,666-position.y,1280,54),Color(0.03,.07,.06,.7))
		if encounter.stage_phase>=2 and not (encounter.definition as WindkeeperDefinition).continuous_combat:PlainsInteractiveArt.draw_aim(self,Vector2(150,165),66)
	if intro_only: return
	if not is_instance_valid(encounter): return
	var bar := Rect2(0, 32, 550, 14)
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
	if protected_state:
		# Shield silhouette communicates an actually protected state even in muted/low effects mode.
		draw_colored_polygon(PackedVector2Array([Vector2(557,32),Vector2(568,32),Vector2(568,40),Vector2(562,47),Vector2(557,40)]), Color("98a9a5"))
