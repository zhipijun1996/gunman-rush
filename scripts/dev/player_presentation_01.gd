extends DemoApp
## Standalone review consumer; ordinary formal entry and input remain intact.
const SAMPLE_SEED := "underworld-formal-integrated"
var _sample_damage_serial := 0
var _recovery_enabled := true
var _recovery_button: Button

func _ready() -> void:
	meta_persistence_enabled = false
	set_meta("cloud_preview_host", true)
	super._ready()
	var layer := CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(370, 8)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var caption := Label.new()
	caption.text = "PLAYER SAMPLE · Move / aim / shoot normally"
	box.add_child(caption)
	var row := HBoxContainer.new()
	box.add_child(row)
	_recovery_button = Button.new()
	_recovery_button.focus_mode = Control.FOCUS_NONE
	_recovery_button.text = "RECOVERY ON"
	_recovery_button.pressed.connect(_toggle_recovery)
	row.add_child(_recovery_button)
	var hurt := Button.new()
	hurt.focus_mode = Control.FOCUS_NONE
	hurt.text = "HURT FIXTURE"
	hurt.pressed.connect(_sample_hurt)
	row.add_child(hurt)
	var restart := Button.new()
	restart.focus_mode = Control.FOCUS_NONE
	restart.text = "RESTART SAMPLE"
	restart.pressed.connect(_restart_sample)
	row.add_child(restart)
	call_deferred("_restart_sample")

func _restart_sample() -> void:
	if get_tree().paused: get_tree().paused = false
	if lifetime.active: abandon_run()
	for tick: int in 3: await get_tree().physics_frame
	if director.state != DemoRunDirector.State.HOME: return
	if start_plains(SAMPLE_SEED):
		for tick: int in 8: await get_tree().physics_frame
		_apply_recovery_switch()
		print("PLAYER SAMPLE: actual formal entry ready recovery=", _recovery_enabled)

func _apply_recovery_switch() -> void:
	if not is_instance_valid(player): return
	var renderer := player.get_node_or_null("PixelPlainsActor") as UnderworldPlayer
	if renderer != null: renderer.recover_weapon_anchor = _recovery_enabled

func _toggle_recovery() -> void:
	_recovery_enabled = not _recovery_enabled
	_recovery_button.text = "RECOVERY ON" if _recovery_enabled else "RECOVERY OFF"
	_apply_recovery_switch()

func _sample_hurt() -> void:
	if not is_instance_valid(player) or not lifetime.active or get_tree().paused: return
	_sample_damage_serial += 1
	_submit_damage(&"player_sample_explicit_fixture", DamageRequest.Kind.MONSTER, 1,
		StringName("player_sample_fixture_%s" % _sample_damage_serial), Vector2.RIGHT)
