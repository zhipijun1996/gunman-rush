@static_unload
class_name PlayerControlGuide
extends RefCounted
## Shared read-only descriptions. Gameplay adapters continue owning input.
const BUNDLE := "res://build/world/runtime.json"
static var _fallback: Dictionary = {}
static func text(id: String) -> String:
	var key:="guide."+id
	if WorldText.catalog.has(key):return WorldText.text(key)
	# Standalone legacy menus share the same compiled catalog. Raw authoring
	# config is not a runtime dependency, including in exported Web packages.
	if _fallback.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(BUNDLE))
		if parsed is Dictionary:_fallback=parsed.get("ui_texts",{}).get("strings",{})
	return str(_fallback.get(key,id))

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
		"pickup": return key(profile,"up") if device==&"keyboard_mouse" else text("left_stick")+" ↑" if device==&"gamepad" else text("touch_left")+" ↑"
		"drop": return (key(profile,"down") if device==&"keyboard_mouse" else text("left_stick")+" ↓" if device==&"gamepad" else text("touch_left")+" ↓")+" + "+jump
		"heal": return OS.get_keycode_string(int(heal.get("keyboard_key",KEY_C))) if device==&"keyboard_mouse" else pad_face(int(heal.get("gamepad_button",JOY_BUTTON_B)),style) if device==&"gamepad" else text("touch_heal")
		"look": return key(profile,"up")+" / "+key(profile,"down") if device==&"keyboard_mouse" else text("left_stick")+" ↑ ↓" if device==&"gamepad" else text("touch_left")+" ↑ ↓"
		"map": return "M / Esc" if device==&"keyboard_mouse" else "View / Start" if device==&"gamepad" else text("touch_menu")
		"hook": return mouse(MOUSE_BUTTON_RIGHT)+" / E" if device==&"keyboard_mouse" else "L1" if device==&"gamepad" and style=="ps" else "L" if device==&"gamepad" and style=="switch" else "LB" if device==&"gamepad" and style=="xbox" else "L1 / LB" if device==&"gamepad" else text("touch_hook")
		"skill": return "Q" if device==&"keyboard_mouse" else pad_face(JOY_BUTTON_Y,style) if device==&"gamepad" else text("touch_skill")
		"item": return "R" if device==&"keyboard_mouse" else "R2" if device==&"gamepad" and style=="ps" else "ZR" if device==&"gamepad" and style=="switch" else "RT" if device==&"gamepad" else text("touch_item")
	return ""

static func rows(device: StringName, profile: Dictionary, features: Dictionary = {}, heal: Dictionary = {}, style: String = "generic") -> Array[Dictionary]:
	var ids := ["move","jump","shoot","recoil","pickup","drop","heal","look","map"]
	for optional: String in ["heal","look"]:
		if features.has(optional) and not bool(features[optional]):ids.erase(optional)
	for ability: String in ["hook","double","wall","skill","item"]:
		if bool(features.get(ability,false)): ids.append(ability)
	var result: Array[Dictionary] = []
	for id: String in ids:
		var detail := String(device)+"."+id if id in ["move","shoot","hook"] else id+".detail"
		var title:=text(id)
		if id in ["skill","item"] and not str(features.get(id+"_name","")).is_empty():title=str(features[id+"_name"])+" · "+title
		result.append({"id":id,"title":title,"binding":binding(id,device,profile,heal,style),"detail":text(detail)})
	return result

static func hint(lesson: String, device: StringName, profile: Dictionary, style: String) -> Dictionary:
	var detail := "hint."+String(device)+"."+lesson if lesson in ["move","shoot"] else "hint."+lesson
	return {"lesson":lesson,"title":text("goal."+lesson),"binding":binding(lesson,device,profile,{},style),"detail":text(detail)}
