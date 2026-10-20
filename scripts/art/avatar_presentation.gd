class_name AvatarPresentation
extends Node
## Session appearance only. The original CourierVisual still owns arm/muzzle state.
const CATALOG := "res://resources/art/avatars.json"
var selected_id := "courier"
var _app: Node
var _visual: CourierVisual
var _painted: Node2D
var _selector: OptionButton
var _definitions: Array[Dictionary] = []
var _source_path := ""
var _source_sha := ""
var _texture_sha := ""
var _active_spec: Dictionary = {}
var _observed_original: Dictionary = {}
var _last_rejection := ""

func configure(app: Node) -> void:
	_app=app

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not parsed is Dictionary:
		push_error("Avatar identity catalog is invalid");return
	for entry: Dictionary in parsed.get("avatars",[]):_definitions.append(entry)
	var layer := CanvasLayer.new()
	layer.layer=21;layer.name="AvatarSelectorLayer";add_child(layer)
	_selector=OptionButton.new()
	_selector.name="AvatarSelector"
	_selector.focus_mode=Control.FOCUS_NONE
	_selector.tooltip_text="选择人物外观；玩法与能力保持一致"
	_selector.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_selector.offset_left=-220;_selector.offset_right=-20
	_selector.offset_top=126;_selector.offset_bottom=162
	for entry: Dictionary in _definitions:
		_selector.add_item("外观 · "+str(entry.display_name))
		_selector.set_item_disabled(_selector.item_count-1,not _available(entry))
	layer.add_child(_selector)
	_selector.item_selected.connect(_selected)
	_selector.gui_input.connect(_selector_gui_input)
	_selector.get_popup().about_to_popup.connect(_cancel_ui_input)
	_selector.get_popup().popup_hide.connect(_cancel_ui_input)
	var requested := str(_app.get("avatar_selection_id"))
	if not select_avatar(requested):
		push_error("Requested avatar is unavailable: "+requested)
		_sync_selector()

func _available(entry: Dictionary) -> bool:
	if str(entry.id)=="courier":return true
	var spec := _specification(entry)
	return not spec.is_empty() and ResourceLoader.exists(str(spec.get("texture","")))

func _definition(id: String) -> Dictionary:
	for entry: Dictionary in _definitions:
		if str(entry.id)==id:return entry
	return {}

func _specification(entry: Dictionary) -> Dictionary:
	var path := str(entry.get("calibration",""))
	if path.is_empty() or not FileAccess.file_exists(path):return {}
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed.get("hero",{}) if parsed is Dictionary else {}

func _selected(index: int) -> void:
	if not select_avatar(str(_definitions[index].id)):_sync_selector()

func _selector_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		_cancel_ui_input()

func _cancel_ui_input() -> void:
	if not is_instance_valid(_visual):return
	var controller := _visual.get_parent().get_node_or_null("Controller") as PlayerController
	if controller!=null:controller.router.clear("avatar_selector")

func _numbers(raw: Variant, length: int) -> bool:
	if not raw is Array or raw.size()!=length:return false
	for number: Variant in raw:
		if not (number is int or number is float) or not is_finite(float(number)):return false
	return true

func _region_valid(raw: Variant, size: Vector2) -> bool:
	return _numbers(raw,4) and float(raw[0])>=0 and float(raw[1])>=0 and float(raw[2])>0 and float(raw[3])>0 and float(raw[0])+float(raw[2])<=size.x and float(raw[1])+float(raw[3])<=size.y

func validate_specification(spec: Dictionary) -> Dictionary:
	var source := str(spec.get("texture",""))
	if source.is_empty() or not ResourceLoader.exists(source):return {"ok":false,"reason":"missing_texture"}
	var texture := load(source) as Texture2D
	if texture==null:return {"ok":false,"reason":"invalid_texture"}
	var raw_scale: Variant=spec.get("uniform_scale",0)
	if not _numbers([raw_scale],1):return {"ok":false,"reason":"invalid_scale"}
	var factor := float(raw_scale)
	if not is_finite(factor) or factor<=0:return {"ok":false,"reason":"invalid_scale"}
	var states: Variant=spec.get("states",{})
	if not states is Dictionary or not states.has("idle"):return {"ok":false,"reason":"missing_idle"}
	for animation: Variant in states.values():
		if not animation is Dictionary:return {"ok":false,"reason":"invalid_animation"}
		var fps: Variant=animation.get("fps",8)
		if not _numbers([fps],1) or float(fps)<=0:return {"ok":false,"reason":"invalid_fps"}
		var frames: Variant=animation.get("frames",[])
		if not frames is Array or frames.is_empty():return {"ok":false,"reason":"empty_frames"}
		for frame: Variant in frames:
			if not frame is Dictionary or not _region_valid(frame.get("region"),texture.get_size()):return {"ok":false,"reason":"frame_region_out_of_bounds"}
			var pivot: Variant=frame.get("pivot")
			if not _numbers(pivot,2) or float(pivot[0])<0 or float(pivot[1])<0 or float(pivot[0])>float(frame.region[2]) or float(pivot[1])>float(frame.region[3]):return {"ok":false,"reason":"invalid_pivot"}
	var weapon: Variant=spec.get("weapon",{})
	if not weapon is Dictionary:return {"ok":false,"reason":"invalid_weapon"}
	if not weapon.is_empty():
		var gun_path := str(weapon.get("texture",source))
		var gun_texture := load(gun_path) as Texture2D if ResourceLoader.exists(gun_path) else null
		if gun_texture==null or not _region_valid(weapon.get("region"),gun_texture.get_size()):return {"ok":false,"reason":"weapon_region_out_of_bounds"}
		for key: String in ["muzzle","barrel_base"]:
			var point: Variant=weapon.get(key)
			if not _numbers(point,2) or float(point[0])<0 or float(point[1])<0 or float(point[0])>float(weapon.region[2]) or float(point[1])>float(weapon.region[3]):return {"ok":false,"reason":"invalid_weapon_anchor"}
		if Vector2(weapon.muzzle[0],weapon.muzzle[1]).distance_to(Vector2(weapon.barrel_base[0],weapon.barrel_base[1]))<.001:return {"ok":false,"reason":"zero_barrel_length"}
	return {"ok":true,"reason":"valid"}

func _sync_selector() -> void:
	if not is_instance_valid(_selector):return
	for i: int in _definitions.size():
		if str(_definitions[i].id)==selected_id:_selector.select(i)

func select_avatar(id: String) -> bool:
	var entry := _definition(id)
	if entry.is_empty() or not _available(entry):
		_last_rejection="unknown_or_unavailable_avatar";return false
	if id!="courier":
		var spec := _specification(entry)
		var validation := validate_specification(spec)
		if not bool(validation.ok):
			_last_rejection=str(validation.reason);return false
	_last_rejection=""
	selected_id=id
	_app.set("avatar_selection_id",id)
	_sync_selector()
	if is_instance_valid(_visual):_apply_selected()
	return true

func bind_player(player: Node2D) -> void:
	var next := player.get_node_or_null("CourierVisual") as CourierVisual
	if next==_visual and (selected_id=="courier" or is_instance_valid(_painted)):return
	_dispose_painted()
	_visual=next
	_observed_original.clear()
	_apply_selected()

func _dispose_painted() -> void:
	if is_instance_valid(_painted):
		_painted.set_process(false);_painted.hide()
		if _painted.get_parent()!=null:_painted.get_parent().remove_child(_painted)
		_painted.queue_free()
	_painted=null
	_restore_default_body()

func _default_body() -> CanvasItem:
	if not is_instance_valid(_visual):return null
	# A formal consumer may keep CourierVisual alive only as its authoritative
	# weapon anchor. Its generated body owns the default appearance instead.
	for child: Node in _visual.get_parent().get_children():
		if child is PixelPlainsActor and not child.is_queued_for_deletion():return child
	return _visual

func _restore_default_body() -> void:
	var body := _default_body()
	if body == null:return
	_visual.visible = body == _visual
	body.show()

func _apply_selected() -> void:
	if not is_instance_valid(_visual):return
	if selected_id=="courier":
		_dispose_painted()
		_source_path="";_source_sha="";_texture_sha="";_active_spec={}
		return
	var entry := _definition(selected_id)
	_try_apply_specification(_specification(entry),str(entry.calibration))

func _try_apply_specification(spec: Dictionary, source_path: String) -> bool:
	var validation := validate_specification(spec)
	if not bool(validation.ok):
		_last_rejection=str(validation.reason);return false
	if not is_instance_valid(_visual):return false
	var texture := load(str(spec.texture)) as Texture2D
	if texture==null:
		_last_rejection="invalid_texture";return false
	# Validation and loading succeed before the current owner is touched.
	_dispose_painted()
	var body := VisualLanguageSample.PaintedHero.new()
	body.name="SelectedAvatarBody"
	body.visual=_visual;body.catalog=spec;body.texture=texture
	body.position=_visual.position
	body.set_meta("avatar_presentation_owned",true)
	_visual.get_parent().add_child(body)
	body._process(0.0) # Prime the existing pose/gun even when the player is paused.
	_painted=body
	_default_body().hide()
	_visual.hide()
	_source_path=source_path
	_source_sha=FileAccess.get_sha256(_source_path)
	_texture_sha=FileAccess.get_sha256(str(spec.texture))
	_active_spec=spec
	_last_rejection=""
	return true

func _process(_delta: float) -> void:
	if selected_id=="courier" and is_instance_valid(_visual) and not get_tree().paused:
		var key := str(_visual.state)
		_observed_original[key]=int(_observed_original.get(key,0))+1

func snapshot() -> Dictionary:
	var entry := _definition(selected_id)
	var spec := _active_spec
	var keys: Array=spec.get("states",{}).keys()
	if selected_id=="courier" and is_instance_valid(_visual):
		var original: Dictionary=_visual.get("_painted_states").duplicate()
		original.merge(_visual.get("_action_catalog").get("states",{}),true)
		keys=original.keys()
	var missing: Array[String]=[]
	for state: StringName in CourierVisual.STATES:
		if not keys.has(str(state)):missing.append(str(state))
	var count := 0
	if is_instance_valid(_visual):
		for child: Node in _visual.get_parent().get_children():
			if child.has_meta("avatar_presentation_owned"):count+=1
	return {"selected_id":selected_id,"display_name":entry.get("display_name",selected_id),"source_calibration":_source_path,"source_sha256":_source_sha,"texture_source":spec.get("texture","original CourierVisual"),"texture_sha256":_texture_sha,"hero_states":keys,"hero_missing_states":missing,"observed_hero_states":_painted.get("observed_states").duplicate(true) if is_instance_valid(_painted) else _observed_original.duplicate(true),"painted_owner_count":count,"original_visual_visible":_visual.visible if is_instance_valid(_visual) else false,"last_rejection":_last_rejection,"session_only":true,"gameplay_changed":false}

func _exit_tree() -> void:
	_dispose_painted()
