class_name WindkeeperHud
extends Control
## Read-only HealthState view; no timers survive encounter disposal.
const FONT := preload("res://assets/fonts/windkeeper_ui.ttf")
var encounter: WindkeeperEncounter
var delayed_hp := 0.0
var _last_hp := -1.0
var _hold := 0.0
var _alpha := 0.0
var _name: Label
var _objective: Label
var _intro_name: Label
var _skip: Button
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font = FONT
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
	encounter = value
	_last_hp = -1
	_alpha = 0
	if is_instance_valid(value): delayed_hp = value.health.current
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
	_intro_name.visible = intro
	_skip.visible = intro
	if shown: _objective.text = encounter.objective()
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(encounter): return
	var bar := Rect2(0, 32, 550, 14)
	draw_rect(bar.grow(3), Color("283b39"))
	draw_rect(bar, Color("182925"))
	var capacity := maxf(1, encounter.health.capacity)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * delayed_hp / capacity, bar.size.y)), Color("ba8355"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * encounter.health.current / capacity, bar.size.y)), Color("efcd7b"))
	var definition := encounter.definition as WindkeeperDefinition
	for threshold: float in [definition.phase_two_health, definition.phase_three_health]:
		var x := bar.size.x * threshold
		draw_line(Vector2(x, 32), Vector2(x, 46), Color("344840"), 2)
	if not encounter.core_open:
		# Shield silhouette communicates armour even in muted/low effects mode.
		draw_colored_polygon(PackedVector2Array([Vector2(557,32),Vector2(568,32),Vector2(568,40),Vector2(562,47),Vector2(557,40)]), Color("98a9a5"))
