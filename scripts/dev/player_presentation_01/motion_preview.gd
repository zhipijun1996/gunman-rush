class_name PlayerMotionCandidatePreview
extends DemoApp
## Standalone actual formal consumer. Main, scenes, shared body and input intact.
var motion_visual: PlayerMotionCandidateVisual
var motion_enabled := true
var _switch: Button
var _motion_status: Label
var _restart_generation := 0
var _restart_pending := false

func _ready() -> void:
	meta_persistence_enabled = false
	set_meta("cloud_preview_host",true)
	super._ready()
	var layer := CanvasLayer.new()
	layer.layer = 115
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(350,8)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_motion_status = Label.new()
	_motion_status.text = "MOTION CANDIDATE · idle / scarf / takeoff / landing"
	box.add_child(_motion_status)
	var row := HBoxContainer.new()
	box.add_child(row)
	_switch = Button.new()
	_switch.text = "CANDIDATE ON"
	_switch.focus_mode = Control.FOCUS_NONE
	_switch.pressed.connect(func() -> void: set_motion_enabled(not motion_enabled))
	row.add_child(_switch)
	var restart := Button.new()
	restart.text = "RESTART SAMPLE"
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(restart_sample)
	row.add_child(restart)
	var home := Button.new()
	home.text = "HOME / FULL GAME"
	home.focus_mode = Control.FOCUS_NONE
	home.pressed.connect(return_full_game)
	row.add_child(home)
	set_motion_enabled(motion_enabled)
	restart_sample.call_deferred()

func set_motion_enabled(value: bool) -> void:
	motion_enabled = value
	_switch.text = "CANDIDATE ON" if value else "ORIGINAL"
	if is_instance_valid(motion_visual): motion_visual.set_candidate_enabled(value)

func restart_sample() -> void:
	if _restart_pending: return
	_restart_pending = true
	_restart_generation += 1
	var request := _restart_generation
	motion_visual = null
	if get_tree().paused: get_tree().paused = false
	if lifetime.active: abandon_run()
	for unused: int in 3:
		await get_tree().physics_frame
		if request != _restart_generation: return
	if not start_plains("player-presentation-01/motion-01"):
		_restart_pending = false
		return
	var run_epoch := lifetime.epoch
	for unused: int in 120:
		await get_tree().physics_frame
		if request != _restart_generation: return
		if not lifetime.active or lifetime.epoch != run_epoch:
			_restart_pending = false
			return
		if not _stage_pending and stage is PlainsRegionStage: break
	_restart_pending = false
	if _stage_pending or not stage is PlainsRegionStage:
		push_error("Motion candidate formal stage did not become ready")
		return
	var original := player.get_node_or_null("PixelPlainsActor") as UnderworldPlayer
	if original == null:
		push_error("Motion candidate missing actual Underworld consumer")
		return
	# Only this dev scene substitutes the inherited visual leaf after real assembly.
	# Motor, Controller, level, camera, collision and gameplay node ownership stay.
	player.remove_child(original)
	original.free()
	motion_visual = PlayerMotionCandidateVisual.new()
	motion_visual.name = "PixelPlainsActor"
	motion_visual.motor = player
	motion_visual.controller = controller
	player.add_child(motion_visual)
	motion_visual.set_candidate_enabled(motion_enabled)
	print("MOTION CANDIDATE: actual formal player ready")

func return_full_game() -> void:
	_restart_generation += 1
	_restart_pending = false
	motion_visual = null
	abandon_run()
