@static_unload
class_name PlayerControlGuide
extends RefCounted
## Shared read-only descriptions. Gameplay adapters continue owning input.
const STRINGS := preload("res://config/control_guide.json")
static func text(id:String) -> String:
	return str(STRINGS.data.get(id,id))

static func key(profile: Dictionary, action: String) -> String:
	var names := PackedStringArray()
	for code: int in profile.keyboard.get(action,[]): names.append({KEY_LEFT:"←",KEY_RIGHT:"→",KEY_UP:"↑",KEY_DOWN:"↓"}.get(code,OS.get_keycode_string(code)))
	return " / ".join(names) if not names.is_empty() else text("unbound")

static func mouse(button: int) -> String:
	return text("mouse_left") if button==MOUSE_BUTTON_LEFT else text("mouse_right") if button==MOUSE_BUTTON_RIGHT else text("mouse_middle") if button==MOUSE_BUTTON_MIDDLE else text("mouse_other") % button

static func family(device_name: String = "") -> String:
	var value := device_name.to_lower()
	if "dualsense" in value or "dualshock" in value or "playstation" in value or "ps4" in value or "ps5" in value: return "ps"
	if "nintendo" in value or "switch" in value or "joy-con" in value: return "switch"
	if "xbox" in value or "xinput" in value: return "xbox"
	return "generic"

static func pad_face(button: int, style: String) -> String:
	var glyphs := {"ps":["×","○","□","△"],"xbox":["A","B","X","Y"],"switch":["B","A","Y","X"]}
	var positions := ["south","east","west","north"]
	if button>=0 and button<4: return str(glyphs[style][button]) if glyphs.has(style) else text(positions[button])
	return "#"+str(button)

static func binding(action: String, device: StringName, profile: Dictionary, heal: Dictionary = {}, style: String = "generic") -> String:
	if device==&"gamepad":profile=_calibrated_profile(profile)
	var trigger := "L2" if style=="ps" else "ZL" if style=="switch" else "LT" if style=="xbox" else "LT / L2"
	var jump := key(profile,"jump") if device==&"keyboard_mouse" else pad_face(int(profile.gamepad_jump_button),style)+" / "+trigger if device==&"gamepad" else text("touch_jump")
	match action:
		"jump","double","wall": return jump
		"recoil": return jump+" → "+binding("shoot",device,profile,heal,style)
		"move": return key(profile,"left")+" · "+key(profile,"right") if device==&"keyboard_mouse" else text("left_stick") if device==&"gamepad" else text("touch_left")
		"shoot":
			if device==&"keyboard_mouse":
				var mapped := key(profile,"shoot")
				return mouse(int(profile.mouse_shoot_button))+(" / "+mapped if not profile.keyboard.shoot.is_empty() else "")
			return text("right_stick")+" + "+("R1" if style=="ps" else "R" if style=="switch" else "RB" if style=="xbox" else "R1 / RB") if device==&"gamepad" else text("touch_right")
		"pickup": return key(profile,"up") if device==&"keyboard_mouse" else text("left_stick")+" ↑" if device==&"gamepad" else "互动"
		"drop": return (key(profile,"down") if device==&"keyboard_mouse" else text("left_stick")+" ↓" if device==&"gamepad" else text("touch_left")+" ↓")+" + "+jump
		"heal": return OS.get_keycode_string(int(heal.get("keyboard_key",KEY_C))) if device==&"keyboard_mouse" else pad_face(int(profile.get("gamepad_heal_button",JOY_BUTTON_B)),style) if device==&"gamepad" else "按住回复"
		"look": return key(profile,"up")+" / "+key(profile,"down") if device==&"keyboard_mouse" else text("left_stick")+" ↑ ↓" if device==&"gamepad" else text("touch_left")+" ↑ ↓"
		"map": return "M" if device==&"keyboard_mouse" else ("暂停 → 地图" if profile.get("gamepad_map_disabled",false) else "View / Select") if device==&"gamepad" else "地图"
		"pause": return "Esc" if device==&"keyboard_mouse" else "Start / Options" if device==&"gamepad" else "暂停"
		"context": return "F" if device==&"keyboard_mouse" else pad_face(JOY_BUTTON_X,style) if device==&"gamepad" else "情境动作键"
		"hook": return mouse(MOUSE_BUTTON_RIGHT)+" / E" if device==&"keyboard_mouse" else "L1" if device==&"gamepad" and style=="ps" else "L" if device==&"gamepad" and style=="switch" else "LB" if device==&"gamepad" and style=="xbox" else "L1 / LB" if device==&"gamepad" else text("touch_hook")
		"skill": return "Q" if device==&"keyboard_mouse" else pad_face(JOY_BUTTON_Y,style) if device==&"gamepad" else text("touch_skill")
		"item": return text("unbound") if device==&"gamepad" and profile.get("gamepad_item_disabled",false) else "R" if device==&"keyboard_mouse" else "R2" if device==&"gamepad" and style=="ps" else "ZR" if device==&"gamepad" and style=="switch" else "RT" if device==&"gamepad" else text("touch_item")
	return ""

static func rows(device: StringName, profile: Dictionary, features: Dictionary, heal: Dictionary, style: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in ["move","look","pickup","jump","shoot","recoil","drop","hook","wall","double","context","skill","item","heal","map","pause"]:
		if id in ["hook","wall","double","context","skill","item"] and not features.get(id,true): continue
		var detail := id+".detail"
		if id in ["shoot","recoil","move"] and STRINGS.data.has(id+"."+String(device)): detail=id+"."+String(device)
		result.append({"id":id,"title":text(id),"binding":binding(id,device,profile,heal,style),"detail":text(detail)})
	return result

static func _calibrated_profile(profile: Dictionary) -> Dictionary:
	for device: int in Input.get_connected_joypads():
		var mapped: Dictionary=profile.get("gamepad_device_bindings",{}).get(InputProfile.gamepad_key(device),{})
		if mapped.is_empty():continue
		var result:=profile.duplicate()
		# Calibration labels name physical positions, never normalized raw button IDs.
		result.gamepad_jump_button=JOY_BUTTON_A;result.gamepad_heal_button=JOY_BUTTON_B
		result.gamepad_map_disabled=mapped.map.kind=="none"
		result.gamepad_item_disabled=mapped.item_trigger.kind=="none"
		return result
	return profile

static func build(shell: Node) -> Control:
	var guide := VBoxContainer.new()
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.add_theme_constant_override("separation",8)
	var tabs := HBoxContainer.new()
	guide.add_child(tabs)
	var diagram := preload("res://game/presentation/ui/controls/control_guide_diagram.gd").new()
	guide.add_child(diagram)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0,164)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	guide.add_child(scroll)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(lines)
	var settings := WorldSettings.current()
	var profile: Dictionary = settings.value.get("input",InputProfile.load_default().values)
	var features := {}
	var device: StringName = &"keyboard_mouse"
	var world := shell.get("world") as WorldGameHost
	if is_instance_valid(world) and world.active!=null:
		var s := world.active
		var router := s.controller.router
		profile = router.profile.values
		device = router.current_device
		features = {"context":router.weapon_context_available,"skill":router.weapon_skill_available,"item":router.item_skill_available,
			"hook":router.grapple_available,"wall":s.state.has("W"),"double":s.state.has("D")}
	elif not Input.get_connected_joypads().is_empty(): device=&"gamepad"
	elif OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available(): device=&"touch"
	var input:=shell.get_node_or_null("WorldShellInput")
	if input!=null and not str(input.menu_device).is_empty(): device=StringName(input.menu_device)
	var pads := Input.get_connected_joypads()
	var style := family(Input.get_joy_name(pads[0])) if not pads.is_empty() else "generic"
	var heal: Dictionary = preload("res://config/focus_heal.json").data
	diagram.profile=profile
	diagram.style=style
	diagram.reduced=bool(settings.value.get("reduced",false))
	var switch_page := func(selected: StringName) -> void:
		for child in lines.get_children():
			lines.remove_child(child)
			child.queue_free()
		for tab: Button in tabs.get_children(): tab.set_pressed_no_signal(tab.get_meta("device")==selected)
		diagram.device=selected
		diagram.queue_redraw()
		for row: Dictionary in rows(selected,profile,features,heal,style):
			var label := DemoClockworkTheme.label("%s　%s　　%s" % [row.title,row.binding,row.detail],17)
			label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			label.focus_mode=Control.FOCUS_ALL
			label.focus_entered.connect(func()->void:label.add_theme_color_override("font_color",DemoClockworkTheme.BRASS))
			label.focus_exited.connect(func()->void:label.remove_theme_color_override("font_color"))
			lines.add_child(label)
		scroll.scroll_vertical=0
	var group := ButtonGroup.new()
	for choice:Array in [[&"keyboard_mouse","键鼠"],[&"gamepad","手柄"],[&"touch","触屏"]]:
		var tab := Button.new()
		tab.text=choice[1]
		tab.set_meta("device",choice[0])
		tab.toggle_mode=true
		tab.button_group=group
		tabs.add_child(tab)
		tab.pressed.connect(switch_page.bind(choice[0]))
	switch_page.call(device)
	return guide
