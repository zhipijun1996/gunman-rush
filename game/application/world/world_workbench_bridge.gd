class_name WorldWorkbenchBridge
extends RefCounted
## Explicit browser authoring session. The model edits data, never JavaScript.
signal message_sent(message: Dictionary)
const CHANNEL := "gunman-workbench"
var app: FixedWorldApp
var enabled := false
var loading := false
var revision := -1
var last_event: Dictionary = {}
var _callback: JavaScriptObject

func setup(application: FixedWorldApp) -> void:
	app = application
	if not OS.has_feature("web"): return
	enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('workbench') === '1'"))
	if not enabled: return
	_callback = JavaScriptBridge.create_callback(_receive_js)
	JavaScriptBridge.eval("""
	window.__gunmanWorkbenchInstall = function(receive) {
	  if (window.__gunmanWorkbenchListener) window.removeEventListener('message', window.__gunmanWorkbenchListener);
	  window.__gunmanWorkbenchListener = function(event) {
	    if (event.origin !== window.location.origin || event.source !== window.parent) return;
	    var message = event.data;
	    if (!message || message.channel !== 'gunman-workbench') return;
	    receive(JSON.stringify(message));
	  };
	  window.addEventListener('message', window.__gunmanWorkbenchListener);
	  document.addEventListener('visibilitychange', function() {
	    if (document.hidden) receive(JSON.stringify({channel:'gunman-workbench', type:'pause', request_id:'visibility'}));
	  });
	};
	window.__gunmanWorkbenchEmit = function(serialized) {
	  window.parent.postMessage(JSON.parse(serialized), window.location.origin);
	};
	""")
	var window := JavaScriptBridge.get_interface("window")
	window.__gunmanWorkbenchInstall(_callback)
	_emit_ready()

func _receive_js(arguments: Array) -> void:
	if arguments.is_empty() or not arguments[0] is String: return
	var raw: String = arguments[0]
	if raw.length() > 4000000:
		_emit({"type":"error", "code":"message_too_large", "request_id":""})
		return
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary: return
	_handle.call_deferred(parsed)

func _emit_ready(request_id := "") -> void:
	_emit({"type":"ready", "request_id":request_id, "bridge_version":1,
		"base_content_version":app.content.workbench_base_version(),
		"content_version":str(app.content.data.get("content_version", "")),
		"room_ids":app.content.workbench_available_room_ids(),
		"implemented_room_ids":app.content.workbench_formal_room_ids(),
		"catalog_error":app.content.workbench_catalog_error})

func _emit(message: Dictionary) -> void:
	message["channel"] = CHANNEL
	if not message.has("revision"): message["revision"] = revision
	last_event = message.duplicate(true)
	message_sent.emit(message)
	if enabled and OS.has_feature("web"):
		var window := JavaScriptBridge.get_interface("window")
		window.__gunmanWorkbenchEmit(JSON.stringify(message))

func _error(request: Dictionary, code: String, detail := "") -> void:
	_emit({"type":"error", "request_id":str(request.get("request_id", "")),
		"requested_revision":request.get("revision", -1), "code":code, "detail":detail})

func _handle(message: Dictionary) -> void:
	if not enabled or message.get("channel") != CHANNEL: return
	var request_id := str(message.get("request_id", ""))
	if request_id.length() > 128: return
	match str(message.get("type", "")):
		"hello", "ping": _emit_ready(request_id)
		"load_draft": await _load(message)
		"pause":
			if loading or app.busy: _error(message, "runtime_busy");return
			if app.controller != null and not app.paused and not app._pause_world():
				_error(message, "pause_deferred_by_gameplay");return
			_emit({"type":"paused", "request_id":request_id, "paused":app.paused})
		"play", "resume":
			if loading or app.busy or app.controller == null or app.room == null:
				_error(message, "room_not_ready");return
			app._close_panel()
			_emit({"type":"playing", "request_id":request_id, "room_id":app.room.room_id, "paused":false})
		"capture": await _capture(message)
		"leave":
			if loading or app.busy: _error(message, "runtime_busy");return
			app.review.leave()
			if app.review.active: _error(message, "leave_rejected");return
			app.content.restore_workbench_base()
			app.services.definitions = app.content.data.get("demo_services", {})
			revision = -1
			_emit({"type":"left", "request_id":request_id})
		_: _error(message, "unknown_command")

func _load(message: Dictionary) -> void:
	if loading or app.busy: _error(message, "runtime_busy");return
	if not message.get("draft") is Dictionary: _error(message, "draft_missing");return
	var draft: Dictionary = message.draft
	var requested: Variant = draft.get("revision", message.get("revision", -1))
	if not WorldRoomDraft.number(requested) or float(requested) != floorf(float(requested)) or int(requested) < 0:
		_error(message, "revision_invalid");return
	if int(requested) < revision:
		_error(message, "stale_revision", "The running room has a newer accepted draft.");return
	if message.has("revision") and int(message.revision) != int(requested):
		_error(message, "revision_mismatch");return
	if app.controller != null and not app.review.active:
		_error(message, "formal_game_active", "Enter the workbench from its dedicated page.");return
	var stage := str(message.get("stage", "base"))
	if stage not in ["base", "h", "hd", "hwdq"]: _error(message, "stage_invalid");return
	var old_room := app.review.selected_room
	var old_entry := app.review.selected_entry
	var old_stage := app.review.stage
	var was_active := app.review.active
	var was_paused := app.paused
	var previous := app.content.workbench_snapshot()
	var started := Time.get_ticks_msec()
	var install_error := app.content.install_workbench_draft(draft)
	if not install_error.is_empty(): _error(message, "draft_rejected", install_error);return
	var id := str(draft.room_id)
	var entry := str(message.get("entry_id", ""))
	if not entry.is_empty() and not app.state.valid_entry(id, entry):
		app.content.restore_workbench_snapshot(previous)
		_error(message, "entry_missing");return
	loading = true
	app.services.definitions = app.content.data.get("demo_services", {})
	var accepted := await app.review.begin(id, entry, stage)
	if not accepted:
		# Review storage is disposable. Leave while its matching contract is active,
		# then restore the last accepted room; never save a draft into formal storage.
		var reason := app.status
		app.review.leave()
		app.content.restore_workbench_snapshot(previous)
		app.services.definitions = app.content.data.get("demo_services", {})
		if was_active:
			await app.review.begin(old_room, old_entry, old_stage)
			if was_paused: app._pause_world()
		loading = false
		_error(message, "room_load_failed", reason)
		return
	revision = int(requested)
	var pause_after := bool(message.get("paused", true))
	if pause_after:
		for attempt: int in 4:
			if app.paused or app._pause_world(): break
			await app.get_tree().process_frame
	loading = false
	_emit({"type":"draft_loaded", "request_id":str(message.get("request_id", "")),
		"revision":revision, "room_id":id, "entry_id":entry, "stage":stage,
		"content_version":str(app.content.data.content_version),
		"preview_only":bool(app.room.contract.get("preview_only", false)),
		"draft_hash":app.content.workbench_draft_hash(id),
		"geometry_hash":JSON.stringify({"geometry":app.room.contract.world_geometry,"doors":app.room.contract.doors}, "", true).sha256_text(),
		"elapsed_ms":Time.get_ticks_msec()-started, "paused":app.paused})

func _capture(message: Dictionary) -> void:
	if loading or app.busy or app.room == null: _error(message, "room_not_ready");return
	await RenderingServer.frame_post_draw
	var picture := app.get_viewport().get_texture().get_image()
	if picture == null or picture.is_empty(): _error(message, "capture_failed");return
	_emit({"type":"captured", "request_id":str(message.get("request_id", "")),
		"room_id":app.room.room_id, "width":picture.get_width(), "height":picture.get_height(),
		"player_position":[app.player.position.x, app.player.position.y],
		"camera_position":[app.camera.global_position.x, app.camera.global_position.y],
		"png_data_url":"data:image/png;base64,"+Marshalls.raw_to_base64(picture.save_png_to_buffer())})
