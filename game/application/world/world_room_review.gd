class_name WorldRoomReview
extends RefCounted
## Explicit review fixtures use the normal application and an isolated memory save.
class MemorySave extends WorldSaveService:
	var saved: Dictionary = {}
	var saved_revision := 0
	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":saved.duplicate(true),"revision":saved_revision}
	func commit(payload: Dictionary, revision: int) -> bool:
		if revision < 1 or (payload_validator.is_valid() and not payload_validator.call(payload)): return false
		saved = payload.duplicate(true)
		saved_revision = revision
		return true
	func _exists(_backup: bool) -> bool:
		return not saved.is_empty()

var app: FixedWorldApp
var active := false
var launching := false
var invincible := false
var stage := "base"
var formal_storage: WorldSaveService
var selected_room := "P-R03"
var selected_entry := ""

func requested() -> void:
	var args: Dictionary = {}
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval("JSON.stringify(Object.fromEntries(new URLSearchParams(location.search)))")
		if raw is String:
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Dictionary: args = parsed
	else:
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--") and "=" in arg:
				var pair := arg.trim_prefix("--").split("=",true,1)
				args[pair[0]] = pair[1]
	if args.has("review"):
		begin.call_deferred(str(args.review),str(args.get("entry","")),str(args.get("stage","base")),str(args.get("invincible","0"))=="1")

func show() -> void:
	if launching or app.busy: return
	if app.controller != null and not app.paused and not app._pause_world(): return
	if active and app.room != null:
		selected_room = app.room.room_id
		selected_entry = str(app.state.value.entry)
	var modal := app.ui.panel("room_review",WorldText.text("review.title"),WorldText.text("review.detail"))
	var rooms := OptionButton.new()
	rooms.name = "ReviewRoom"
	rooms.custom_minimum_size = Vector2(320,48)
	var ids: Array = app.content.data.rooms.keys()
	ids.sort()
	for id: String in ids:
		rooms.add_item(WorldText.text("review.room")+" · "+id+" · "+str(app.content.room(id).name))
		rooms.set_item_metadata(rooms.item_count-1,id)
		if id == selected_room: rooms.select(rooms.item_count-1)
	modal.rows.add_child(rooms)
	var entries := OptionButton.new()
	entries.name = "ReviewEntry"
	entries.custom_minimum_size = Vector2(320,48)
	modal.rows.add_child(entries)
	var fill_entries := func() -> void:
		selected_room = str(rooms.get_selected_metadata())
		entries.clear()
		entries.add_item(WorldText.text("review.entry")+" · "+WorldText.text("review.default_entry"))
		entries.set_item_metadata(0,"")
		for door: Dictionary in app.content.room(selected_room).doors:
			if not door.target_implemented: continue
			entries.add_item("从 "+str(app.content.room(door.target_room).name)+"进入")
			entries.set_item_metadata(entries.item_count-1,str(door.id))
			if door.id == selected_entry: entries.select(entries.item_count-1)
	rooms.item_selected.connect(func(_index: int) -> void: selected_entry="";fill_entries.call())
	fill_entries.call()
	var stages := OptionButton.new()
	stages.name = "ReviewStage"
	stages.custom_minimum_size = Vector2(320,48)
	for id: String in ["base","h","hd","hwdq"]:
		stages.add_item(WorldText.text("review.stage")+" · "+WorldText.text("review."+id))
		stages.set_item_metadata(stages.item_count-1,id)
		if id == stage: stages.select(stages.item_count-1)
	modal.rows.add_child(stages)
	var protection := CheckButton.new()
	protection.name = "ReviewInvincible"
	protection.text = WorldText.text("review.invincible")
	protection.custom_minimum_size = Vector2(320,48)
	protection.button_pressed = invincible
	protection.toggled.connect(func(enabled: bool) -> void:
		if active: set_invincible(enabled)
	)
	modal.rows.add_child(protection)
	modal.button(WorldText.text("review.enter"),func() -> void: begin(str(rooms.get_selected_metadata()),str(entries.get_selected_metadata()),str(stages.get_selected_metadata()),protection.button_pressed))
	if active:
		var current_room := app.room.room_id
		var current_entry := str(app.state.value.entry)
		modal.button(WorldText.text("review.retry"),func() -> void: begin(current_room,current_entry,stage,protection.button_pressed))
		var link := LineEdit.new()
		link.editable = false
		link.visible = false
		modal.rows.add_child(link)
		modal.button(WorldText.text("review.link"),func() -> void:
			var suffix := "?review="+str(rooms.get_selected_metadata()).uri_encode()+"&entry="+str(entries.get_selected_metadata()).uri_encode()+"&stage="+str(stages.get_selected_metadata())+"&invincible="+("1" if protection.button_pressed else "0")
			link.text = "https://zhipijun1996.github.io/gunman-rush/"+suffix
			if OS.has_feature("web"):
				link.text = str(JavaScriptBridge.eval("location.origin+location.pathname"))+suffix
				JavaScriptBridge.eval("if(navigator.clipboard){navigator.clipboard.writeText("+JSON.stringify(link.text)+").catch(()=>console.info('Clipboard unavailable; link remains selectable.'))}")
			else: DisplayServer.clipboard_set(link.text)
			link.show()
			link.grab_focus()
			link.select_all()
		)
		modal.button(WorldText.text("review.leave"),leave)
	modal.button(WorldText.text("review.back"),app._close_panel)
	for picker: OptionButton in [rooms,entries,stages]:
		picker.get_popup().about_to_popup.connect(func() -> void: modal.cancel_touch(&"popup_open"))
		var touch := PopupTouchAdapter.new()
		touch.popup = picker.get_popup()
		picker.get_popup().add_child(touch)
	modal.focus_first()

func begin(id: String, entry: String, ability_stage: String, invincible_mode: bool = false) -> bool:
	if launching or app.busy or app.content.room(id).is_empty() or ability_stage not in ["base","h","hd","hwdq"]: return false
	if not entry.is_empty() and not app.state.valid_entry(id,entry): return false
	launching = true
	if app.controller != null:
		app.return_title()
		if app.controller != null: launching=false;return false
		await app.get_tree().process_frame
	if not active:
		formal_storage = app.state.storage
		active = true
	var storage := MemorySave.new()
	storage.payload_validator = app.state.valid
	storage.content_version = str(app.content.data.content_version)
	app.state.storage = storage
	var health := preload("res://resources/actors/prototype_health.tres") as HealthDefinition
	var candidate := app.state.fresh(health.max_health)
	if id!="P-R03":candidate.flags.append_array(["intro_gun","intro_move","intro_shoot"])
	if id not in ["P-R03","P-R21","P-R22"]:candidate.flags.append("intro_complete")
	if id not in ["P-R03","P-R21","P-R22","P-R23","P-R24"]:candidate.flags.append("station_briefed")
	if ability_stage in ["h","hd","hwdq"]: candidate.flags.append("H")
	if ability_stage in ["hd","hwdq"]: candidate.flags.append("D")
	if ability_stage == "hwdq": candidate.flags.append_array(["W","Q"])
	# A declared arrival simulates only the non-reward flags needed to have crossed that door.
	if not entry.is_empty():
		for doorway:Dictionary in app.content.room(id).doors:
			if doorway.id!=entry:continue
			for group:Array in doorway.requires:
				for flag:String in group:
					if flag in ["intro_complete","station_briefed","clockheart_briefed","s06"] and flag not in candidate.flags:candidate.flags.append(flag)
	candidate.room = id
	candidate.entry = entry
	if not app.state.commit(candidate,app.state.revision): launching=false;return false
	selected_room=id;selected_entry=entry;stage=ability_stage
	app.ui.close()
	invincible = invincible_mode
	app._create_player()
	await app.load_room(id,entry)
	if app.room != null and app.room.room_id == id and not app.busy:
		candidate = app._snapshot()
		candidate.rest = {"room":id,"entry":entry,"point":[app.entry_anchor.x,app.entry_anchor.y]}
		app.state.commit(candidate,app.state.revision)
	app.ui.review_mode = true
	set_invincible(invincible_mode)
	launching = false
	return app.room != null and app.room.room_id == id and not app.busy

func leave() -> void:
	if launching or app.busy: return
	if app.controller != null: app.return_title()
	if app.controller != null: return
	if active: app.state.storage = formal_storage
	active = false
	invincible = false
	app.ui.review_mode = false
	app.ui.close()
	app.ui.root.hide()

func set_invincible(enabled: bool) -> void:
	invincible = active and enabled
	app.ui.review_stage = stage.to_upper() if stage != "base" else "基础"
	if invincible: app.ui.review_stage += " · "+WorldText.text("review.invincible_badge")

func protects(request: DamageRequest) -> bool:
	if not active or not invincible: return false
	# The policy already checked lifetime/actor/HP epochs. Keep the existing
	# deferred entering-side recovery, without committing damage or hit feedback.
	if request.kind == DamageRequest.Kind.ENVIRONMENT: app._return = true
	return true
