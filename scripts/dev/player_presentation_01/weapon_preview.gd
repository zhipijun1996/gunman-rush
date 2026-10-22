class_name PlayerWeaponFeelPreview
extends PlayerMotionCandidatePreview
## Actual Home/Plains hero; equipment menu is explicitly this dev sample only.
@export var weapon_enabled := true
@export var weapon_profile: PlayerWeaponFeelProfile = preload("res://resources/player_presentation_01/weapon_feel_v1.tres")
var weapon_audio: PlayerWeaponFeelAudio
var weapon_feel: PlayerWeaponFeel
var weapon_picker: OptionButton
var training_targets: Array[Damageable] = []
var _weapon_panel: PanelContainer

func _ready() -> void:
	start_home_sample=true
	super._ready()
	var old := motion_audio
	weapon_audio=PlayerWeaponFeelAudio.new()
	weapon_audio.volume=old.volume
	remove_child(old)
	old.free()
	add_child(weapon_audio)
	motion_audio=weapon_audio
	# Keep already-reviewed movement candidate identical in weapon ON/OFF.
	set_motion_enabled(true)
	for connection: Dictionary in _switch.pressed.get_connections(): _switch.pressed.disconnect(connection.callable)
	_switch.pressed.connect(func()->void:set_weapon_enabled(not weapon_enabled))
	_motion_status.text="WEAPON FEEL / actual player / movement candidate unchanged"
	var layer := CanvasLayer.new()
	layer.layer=115
	add_child(layer)
	_weapon_panel=PanelContainer.new()
	_weapon_panel.position=Vector2(16,612)
	_weapon_panel.theme=DemoMenu.create_theme()
	_weapon_panel.theme.default_font=preload("res://assets/fonts/foundry_notes.otf")
	layer.add_child(_weapon_panel)
	var box := VBoxContainer.new()
	_weapon_panel.add_child(box)
	var title := Label.new()
	title.text="WEAPON SAMPLE · stationary training targets · Space / mouse / F / Q"
	box.add_child(title)
	weapon_picker=OptionButton.new()
	weapon_picker.focus_mode=Control.FOCUS_NONE
	weapon_picker.custom_minimum_size=Vector2(420,34)
	for i: int in WeaponCatalog.IDS.size():
		var definition := WeaponCatalog.get_loadout(i)
		weapon_picker.add_item("Lv.%s %s" % [definition.tier,definition.display_name],i)
	box.add_child(weapon_picker)
	var touch := PopupTouchAdapter.new()
	touch.popup=weapon_picker.get_popup()
	weapon_picker.get_popup().add_child(touch)
	weapon_picker.get_popup().about_to_popup.connect(func()->void:
		if is_instance_valid(weapon_feel): weapon_feel.controller.router.clear("weapon_sample_menu"))
	weapon_picker.get_popup().popup_hide.connect(func()->void:
		if is_instance_valid(weapon_feel): weapon_feel.controller.router.clear("weapon_sample_menu_closed")
		get_viewport().set_input_as_handled())
	weapon_picker.item_selected.connect(select_weapon)
	set_weapon_enabled(weapon_enabled)

func set_weapon_enabled(value: bool) -> void:
	weapon_enabled=value
	if is_instance_valid(_switch): _switch.text="WEAPON FX ON" if value else "ORIGINAL WEAPON FX"
	if is_instance_valid(weapon_feel): weapon_feel.set_candidate_enabled(value)

func select_weapon(index: int) -> void:
	if not is_instance_valid(weapon_feel): return
	var definition := WeaponCatalog.get_loadout(index)
	if definition==null or definition.id==weapon_feel.controller.shoot_ability.weapon.id: return
	weapon_feel.controller.shoot_ability.equip(definition)
	weapon_picker.select(index)
	print("WEAPON SAMPLE: selected ",definition.id)

func _attach_feel() -> void:
	super._attach_feel()
	var actor := motion_visual.motor
	var old := actor.get_node_or_null("WeaponFeel")
	if old!=null: old.free()
	weapon_feel=PlayerWeaponFeel.new()
	weapon_feel.name="WeaponFeel"
	weapon_feel.controller=motion_visual.controller
	weapon_feel.audio=weapon_audio
	weapon_feel.profile=weapon_profile
	weapon_feel.enabled_candidate=weapon_enabled
	actor.add_child(weapon_feel)
	if is_instance_valid(weapon_picker): weapon_picker.select(WeaponCatalog.IDS.find(String(weapon_feel.controller.shoot_ability.weapon.id)))
	if is_instance_valid(_weapon_panel): _weapon_panel.show()
	if is_instance_valid(home_scene): _add_training_targets()
	print("WEAPON SAMPLE: actual player ready")

func _add_training_targets() -> void:
	training_targets.clear()
	for child: Node in home_scene.get_children():
		if child.has_meta("weapon_sample_target"): child.free()
	for x: float in [355.0,600.0]:
		var target := StaticBody2D.new()
		target.set_meta("weapon_sample_target",true)
		target.position=Vector2(x,350)
		target.collision_layer=2
		target.collision_mask=0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size=Vector2(24,160)
		shape.shape=rectangle
		target.add_child(shape)
		var receiver := Damageable.new()
		receiver.name="Damageable"
		receiver.max_health=1000 # Explicit training target initialization,not actor HP.
		receiver.faction=&"enemy"
		target.add_child(receiver)
		var art := Polygon2D.new()
		art.polygon=PackedVector2Array([Vector2(-12,-80),Vector2(12,-80),Vector2(12,80),Vector2(-12,80)])
		art.color=Color("645c47")
		target.add_child(art)
		var label := Label.new()
		label.text="TRAINING"
		label.position=Vector2(-35,-110)
		target.add_child(label)
		home_scene.add_child(target)
		training_targets.append(receiver)

func return_full_game() -> void:
	if is_instance_valid(_weapon_panel): _weapon_panel.hide()
	if is_instance_valid(weapon_feel): weapon_feel.free()
	weapon_feel=null
	if is_instance_valid(home_scene):
		for child: Node in home_scene.get_children():
			if child.has_meta("weapon_sample_target"): child.free()
	training_targets.clear()
	super.return_full_game()

func restart_sample() -> void:
	if _restart_pending: return
	if is_instance_valid(weapon_feel): weapon_feel.free()
	weapon_feel=null
	training_targets.clear()
	super.restart_sample()
