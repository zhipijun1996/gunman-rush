class_name WorldGamepadCalibration
extends Node
## Explicit physical-position capture; no guessed brand remapping or global SDL edits.
signal progressed
var roles: Array[String]=["jump","heal","jump_trigger","map"]
var step:=0
var device: int=-1
var bindings: Dictionary={}
var pending: Dictionary={}
var error:=""
var capture_profile:=InputProfile.load_default()
var revision:=0
var ui:FixedWorldUI
var settings:WorldSettings
var applied:Callable
var status:Label
var save_button:Button
var skip_button:Button

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_connection_changed)

func _input(event:InputEvent) -> void:
	if not event is InputEventJoypadButton and not event is InputEventJoypadMotion:return
	if step>=roles.size():return
	get_viewport().set_input_as_handled()
	capture(event)

func capture(event:InputEvent) -> void:
	if step>=roles.size() or (device>=0 and device!=event.device):return
	var candidate:Dictionary={}
	if pending.is_empty():
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index in [JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_START]:return
			candidate={"kind":"button","index":event.button_index}
		elif roles[step]=="jump_trigger" and event is InputEventJoypadMotion and event.axis>=4 and event.axis<JOY_AXIS_MAX and event.axis_value>=float(capture_profile.values.gamepad_trigger_threshold):
			candidate={"kind":"axis","index":event.axis}
		if candidate.is_empty():return
		for prior:Dictionary in bindings.values():
			if prior==candidate:error=WorldText.text("gamepad_calibration.used");_refresh();return
		device=event.device;pending=candidate;error="";_refresh();return
	var released:bool=(event is InputEventJoypadButton and pending.kind=="button" and event.button_index==int(pending.index) and not event.pressed) or (event is InputEventJoypadMotion and pending.kind=="axis" and event.axis==int(pending.index) and event.axis_value<=float(capture_profile.values.gamepad_jump_trigger_release_threshold))
	if released:
		bindings[roles[step]]=pending.duplicate();pending.clear();step+=1;_refresh()

func skip_map() -> void:
	if step!=3 or not pending.is_empty():return
	bindings.map={"kind":"none","index":-1};step+=1;_refresh()

func _connection_changed(id:int,connected:bool) -> void:
	if not connected and id==device:
		device=-1;step=0;bindings.clear();pending.clear();error=WorldText.text("gamepad_calibration.disconnected");_refresh()

func _refresh() -> void:
	progressed.emit()
	if not is_instance_valid(status):return
	var name:=Input.get_joy_name(device) if device>=0 else WorldText.text("gamepad_calibration.connect")
	var instruction:=WorldText.text("gamepad_calibration.done")
	if step<roles.size():
		instruction=WorldText.text("gamepad_calibration.step") % (step+1)+"\n"+WorldText.text("gamepad_calibration."+roles[step])
		if not pending.is_empty():instruction+="\n"+WorldText.text("gamepad_calibration.release")
	status.text=name+"\n\n"+instruction
	if not error.is_empty():status.text+="\n\n"+error
	save_button.disabled=step<roles.size();skip_button.visible=step==3

static func show(ui_value:FixedWorldUI,settings_value:WorldSettings,apply:Callable) -> WorldGamepadCalibration:
	var modal:=ui_value.panel("gamepad_calibration",WorldText.text("gamepad_calibration.title"),WorldText.text("gamepad_calibration.detail"))
	var wizard:=WorldGamepadCalibration.new();wizard.ui=ui_value;wizard.settings=settings_value;wizard.applied=apply;wizard.revision=settings_value.revision
	wizard.capture_profile.configure(settings_value.value.input)
	modal.add_child(wizard)
	wizard.status=modal.text("",20,UnderworldUI.BRASS)
	wizard.skip_button=modal.button(WorldText.text("gamepad_calibration.skip"),wizard.skip_map)
	wizard.save_button=modal.button(WorldText.text("gamepad_calibration.save"),wizard.save_bindings)
	modal.button(WorldText.text("world_settings_view.09"),func() -> void:ui_value.command.emit("settings",""))
	wizard._refresh();return wizard

func save_bindings() -> void:
	if step!=roles.size() or device<0 or settings.revision!=revision:return
	var candidate:=settings.value.duplicate(true)
	if not candidate.input.has("gamepad_device_bindings"):candidate.input.gamepad_device_bindings={}
	candidate.input.gamepad_device_bindings[InputProfile.gamepad_key(device)]=bindings.duplicate(true)
	if settings.save(candidate):applied.call()
	else:error=WorldText.text("world_settings_view.08")+settings.error;_refresh()
