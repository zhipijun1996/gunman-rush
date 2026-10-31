extends SceneTree
## Real engine feature-override resolution; framebuffer/input checks belong to
## the exported Web browser test. These are not physical-device FPS results.
var assertions := 0
var failures := 0
func _initialize() -> void:
 var setting := "display/window/dpi/allow_hidpi"
 check(ProjectSettings.get_setting(setting) == true, "native high-DPI default stays enabled")
 check(ProjectSettings.get_setting_with_override_and_custom_features(setting, PackedStringArray(["web"])) == true, "actual Web feature override preserves high-DPI detail")
 for feature: String in ["linux", "windows", "macos"]:
  check(ProjectSettings.get_setting_with_override_and_custom_features(setting, PackedStringArray([feature])) == true, "native feature is unaffected: " + feature)
 check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1280 and ProjectSettings.get_setting("display/window/size/viewport_height") == 720, "logical viewport is preserved")
 check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "logical world and UI stretch policy is preserved")
 check(ProjectSettings.get_setting_with_override_and_custom_features("display/window/stretch/mode",PackedStringArray(["web"])) == "viewport", "Web preserves all1280x720 game pixels in a bounded shared render target")
 print("WEB PIXEL DENSITY: %s assertions, %s failures" % [assertions, failures])
 quit(1 if failures else 0)
func check(condition: bool, message: String) -> void:
 assertions += 1
 if not condition:
  failures += 1
  push_error(message)
