External GUI evidence controller, frozen runtime commit:
fbcfed72a5c6c266228c3f8f32eaf56a1739fa0d

Script extends the frozen original tests/item_v5_ui_input_runner.gd and only
overrides its capture_menu_png hook. All original setup, assertions and default
flow remain inherited. Source under scripts/, tests/, tools/ is not modified.

The 960x540 cases send actual Input.parse_input_event ScreenTouch/ScreenDrag:
- return detail scroll to its top with reverse gestures;
- drag detail scroll to its actual bottom;
- if necessary reverse-adjust until the complete real EquipItem rect is visible;
- touch the center of that enabled real button;
- assert exactly one equipment_requested signal with original revision/session;
- invoke the unchanged parent post-draw PNG save.

This proves actual GUI control reachability and signal submission only. The menu
snapshot is an explicit 72-item fixture. It does not submit BuildState equipment,
prove applied effects, natural ownership or physical Android use. GL is software
rendering/mobile-layout proxy. No direct scroll assignment, ensure_visible,
button.pressed.emit, menu input callback invocation or synthetic screenshot.

Prepared only, not run. Root schedules a GL window after the frozen final movie.
Example under an existing DISPLAY:
bash tools/godot.sh --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 --path . --script res://build/item_v5/ui-control-fixture/ui_detail_touch_capture.gd -- --capture-dir=res://build/item_v5/ui-control-fbcfed72-01

Additional evidence is embedded per screenshot in capture-manifest.json and in
external-touch-control-trace.json, including external fixture SHA256 and frozen
runtime commit. fixture.sha256 records the prepared external controller hash.
