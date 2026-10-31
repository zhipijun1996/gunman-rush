extends SceneTree
## Meaningful standalone Control/lifecycle contracts. No Home integration,
## physical device, natural discovery or actual economy claims.
const CODEX := preload("res://game/presentation/ui/home_item_codex.gd")
var assertions := 0
var failures: Array[String] = []
var codex: HomeItemCodex
var unlocks: Array = []
var selections: Array = []
var closes := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)

func frames(count: int = 4) -> void:
	for unused: int in count: await process_frame

func snapshot() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item: ItemDefinition in ItemCatalogV5.all_items():
		rows.append({"item":item,"id":item.stable_id,"discovered":item.stable_id != &"G01","unlocked":item.stable_id == &"P24","price":5,"available":item.stable_id != &"G01","reason":"requires_discovered" if item.stable_id == &"G01" else "","selected":item.stable_id == &"P24"})
	return rows

func tile(id: StringName) -> Button:
	return codex.find_child("CodexTile_"+str(id),true,false) as Button

func action() -> Button:
	var selecting := codex.find_child("CodexSelect",true,false) as Button
	return selecting if selecting != null else codex.find_child("CodexUnlock",true,false) as Button

func choose(id: StringName) -> void:
	var target := tile(id)
	check(target != null,"catalog tile exists: "+str(id))
	if target != null: target.pressed.emit()
	await frames(2)

func unknown_contract() -> void:
	await choose(&"G01")
	var unknown := tile(&"G01")
	check(unknown.find_children("*","TextureRect",true,false).is_empty(),"undiscovered tile resolves no identifying image")
	check(not unknown.tooltip_text.contains(ItemCatalogV5.get_item(&"G01").display_name),"undiscovered tooltip hides the actual name")
	check(codex.find_child("CodexUnknownDetail",true,false) != null and codex.find_child("CodexDetailCard",true,false) == null,"undiscovered detail uses? instead of an ItemCard/effect/rarity")
	check(action() == null,"seen-only policy exposes no unlock or select action for undiscovered items")
	check(unlocks.is_empty() and selections.is_empty(),"unknown navigation never submits economy/loadout requests")

func transaction_contract(rows: Array[Dictionary]) -> void:
	await choose(&"B03")
	var detail := codex.find_child("CodexDetailCard",true,false) as ItemCard
	check(detail != null and detail.level == 1 and detail.item.stable_id == &"B03","known detail reuses the real Lv1 ItemCard")
	check(detail != null and not detail.find_children("*","TextureRect",true,false).is_empty(),"discovered detail displays its actual icon")
	var unlock := action()
	check(unlock != null and not unlock.disabled and unlock.name == &"CodexUnlock","eligible discovered item exposes permanent notes unlock")
	unlock.pressed.emit()
	unlock.pressed.emit()
	check(unlocks == [[&"B03",7]],"one view emits one unlock request carrying the frozen profile revision")
	check(codex._notes == 12 and not bool(codex._rows[&"B03"].unlocked) and codex._selected_id == &"P24","request does not modify authoritative notes/unlock/selected state")
	codex.show_error("错误测试：请重试。")
	var status := codex.find_child("CodexStatus",true,false) as Label
	check(status != null and status.visible and status.text.contains("错误测试"),"backend error is presented without changing state")
	var obsolete_detail := action()
	# Emit while detached-but-not-yet-freed, matching a stale GUI callback.
	tile(&"P24").pressed.emit()
	obsolete_detail.pressed.emit()
	await frames(2)
	check(unlocks.size() == 1,"detached detail callback cannot submit after selecting another item")
	var selected := action()
	check(selected != null and selected.text.contains("取消"),"selected permanent item exposes a clear choice")
	selected.pressed.emit()
	selected.pressed.emit()
	check(selections == [[&"",7]],"clear carries emptyID and revision exactly once")
	# Reopen with unchanged profile revision; old controls must still be stale.
	codex.show_codex(rows,12,&"P24",7)
	selected.pressed.emit()
	check(selections.size() == 1 and unlocks.size() == 1,"UI generation rejects old controls after same-revision reopen")
	await frames()
	await choose(&"B03")
	var old_revision := action()
	codex.show_codex(rows,12,&"P24",8)
	old_revision.pressed.emit()
	check(unlocks.size() == 1,"refreshed profile invalidates the old revision callback")
	await frames()
	# Caller mutation cannot turn the already displayed frozen view into a buy.
	codex.show_codex(rows,1,&"P24",9)
	await frames()
	await choose(&"B03")
	var insufficient := action()
	check(insufficient != null and insufficient.disabled,"insufficient notes disables unlock independently of an optimistic available field")
	insufficient.pressed.emit()
	check(unlocks.size() == 1,"manually emitted disabled action cannot spend unavailable notes")
	await choose(&"P24")
	var old_close := codex.find_child("CodexClose",true,false) as Button
	var old_select := action()
	codex.hide_codex()
	old_select.pressed.emit()
	old_close.pressed.emit()
	check(selections.size() == 1 and closes == 0,"hide cancels old select and close callbacks")
	await frames()
	check(not codex.opened and codex.get_child_count() == 0,"hide releases all modal nodes and touch adapters")

func removed_selection_contract(rows: Array[Dictionary]) -> void:
	var disabled: Array[Dictionary] = []
	for original: Dictionary in rows:
		var row := original.duplicate()
		if row.id == &"P24":
			row.available = false
			row.reason = "home_item_disabled"
		disabled.append(row)
	codex.show_codex(disabled,12,&"P24",20)
	await frames()
	var clear := codex.find_child("CodexClearSelection",true,false) as Button
	check(clear != null and clear.is_visible_in_tree() and not clear.disabled,"global clear remains available when the selected item is disabled")
	var before := selections.size()
	await choose(&"P24")
	var selected_action := action()
	check(selected_action != null and not selected_action.disabled and selected_action.text.contains("取消"),"selected disabled detail still permits cancellation")
	selected_action.pressed.emit()
	clear.pressed.emit()
	check(selections.size() == before+1 and selections[-1] == [&"",20],"detail/global cancellation share one versioned request latch")
	# The profile may retain an old ID whose definition no longer has any row.
	var removed: Array[Dictionary] = []
	for original: Dictionary in rows:
		if original.id != &"P24": removed.append(original.duplicate())
	codex.show_codex(removed,12,&"P24",21)
	await frames()
	clear = codex.find_child("CodexClearSelection",true,false) as Button
	check(tile(&"P24") == null and clear != null and not clear.disabled,"a fully removed selected definition can still be cleared globally")
	before = selections.size()
	clear.pressed.emit()
	clear.pressed.emit()
	check(selections.size() == before+1 and selections[-1] == [&"",21],"missing-definition clear does not require a catalog row or mutate the selected snapshot")
	var obsolete_clear := clear
	codex.hide_codex()
	codex.show_codex(removed,12,&"P24",21)
	obsolete_clear.pressed.emit()
	check(selections.size() == before+1,"same-revision reopen invalidates an obsolete global clear callback")
	await frames()
	codex.show_codex(rows,12,&"",22)
	await frames()
	clear = codex.find_child("CodexClearSelection",true,false) as Button
	before = selections.size()
	check(clear != null and clear.disabled,"global clear is visible but disabled when already carrying nothing")
	clear.pressed.emit()
	check(selections.size() == before,"empty selection cannot emit a redundant clear even via a manually emitted button")
	# A selected but undiscovered row must not reveal identity merely to clear it.
	codex.show_codex(rows,12,&"G01",23)
	await frames()
	await choose(&"G01")
	clear = codex.find_child("CodexClearSelection",true,false) as Button
	before = selections.size()
	check(codex.find_child("CodexUnknownDetail",true,false) != null and clear != null and not clear.disabled,"an unknown selected row stays hidden while global cancellation remains available")
	clear.pressed.emit()
	check(selections.size() == before+1 and selections[-1] == [&"",23],"unknown-item cancellation uses only the current view/revision")
	codex.hide_codex()
	await frames()

func _detail_contains_identity(id: StringName) -> bool:
	var definition := ItemCatalogV5.get_item(id)
	var detail := codex.find_child("CodexDetail",true,false)
	if detail == null: return false
	if codex.find_child("CodexDetailCard",true,false) != null: return true
	if not detail.find_children("*","TextureRect",true,false).is_empty(): return true
	for node: Node in detail.find_children("*","Label",true,false):
		var text := (node as Label).text
		if text.contains(definition.display_name) or text.contains(ItemPresentation.effects(definition,1)): return true
	return false

func unknown_policy_contract(rows: Array[Dictionary]) -> void:
	var permitted: Array[Dictionary] = []
	for original: Dictionary in rows:
		var row := original.duplicate()
		if row.id == &"G01":
			row.requires_discovered = false
			row.price = 9
			row.available = true
			row.reason = ""
		permitted.append(row)
	codex.show_codex(permitted,12,&"",30)
	await frames()
	await choose(&"G01")
	var unlock := action()
	check(codex.find_child("CodexUnknownDetail",true,false) != null and not _detail_contains_identity(&"G01"),"requires_discovered=false keeps unknown name/icon/effects hidden")
	check(unlock != null and not unlock.disabled and unlock.name == &"CodexUnlock" and unlock.text.contains("9"),"configured policy permits unknown unlock at its actual note price")
	var before_unlock := unlocks.size()
	unlock.pressed.emit()
	unlock.pressed.emit()
	check(unlocks.size() == before_unlock+1 and unlocks[-1] == [&"G01",30],"unknown unlock emits only one current revision request")
	check(codex._notes == 12 and not bool(codex._rows[&"G01"].unlocked) and not bool(codex._rows[&"G01"].discovered),"unknown unlock request does not reveal or mutate economic/discovery state")
	# Simulate only the next authoritative backend snapshot, not UI-owned state.
	for row: Dictionary in permitted:
		if row.id == &"G01": row.unlocked = true
	codex.show_codex(permitted,12,&"",31)
	await frames()
	await choose(&"G01")
	var select := action()
	check(select != null and not select.disabled and select.name == &"CodexSelect" and not _detail_contains_identity(&"G01"),"permitted unlocked unknown item is selectable while its identity remains hidden")
	var before_select := selections.size()
	select.pressed.emit()
	check(selections.size() == before_select+1 and selections[-1] == [&"G01",31] and codex._selected_id.is_empty(),"unknown selection sends a request instead of mutating the carried choice")
	codex.show_codex(permitted,12,&"",31)
	select.pressed.emit()
	check(selections.size() == before_select+1,"same-revision refresh rejects a prior unknown selection callback")
	await frames()
	for row: Dictionary in permitted:
		if row.id == &"G01": row.available = false
	codex.show_codex(permitted,12,&"",32)
	await frames()
	await choose(&"G01")
	select = action()
	before_select = selections.size()
	check(select != null and select.disabled,"unknown policy does not override backend unavailable selection")
	select.pressed.emit()
	check(selections.size() == before_select,"manually emitted unavailable unknown selection stays rejected")
	codex.show_codex(permitted,12,&"G01",33)
	await frames()
	await choose(&"G01")
	select = action()
	check(select != null and not select.disabled and select.text.contains("取消") and not _detail_contains_identity(&"G01"),"selected unavailable unknown item can be cleared without revealing its identity")
	select.pressed.emit()
	check(selections.size() == before_select+1 and selections[-1] == [&"",33],"unknown selected item retains the explicit clearing exception")
	for row: Dictionary in permitted:
		if row.id == &"G01": row.unlocked = false
	codex.show_codex(permitted,12,&"",34)
	await frames()
	await choose(&"G01")
	unlock = action()
	before_unlock = unlocks.size()
	check(unlock != null and unlock.disabled,"unavailable unknown unlock remains disabled under the permissive discovery policy")
	unlock.pressed.emit()
	check(unlocks.size() == before_unlock,"unavailable unknown unlock cannot dispatch even when its pressed signal is emitted")
	codex.hide_codex()
	await frames()

func layout_contract(rows: Array[Dictionary]) -> void:
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		codex.show_codex(rows,12,&"P24",11)
		await frames(8)
		var close := codex.find_child("CodexClose",true,false) as Button
		var scroll := codex.find_child("CodexCatalogScroll",true,false) as ScrollContainer
		var grid := codex.find_child("CodexGrid",true,false) as GridContainer
		var safe := DemoUiModalMetrics.safe_rect(root)
		var scale := DemoUiModalMetrics.ui_scale(root)
		check(close != null and safe.grow(1).encloses(close.get_global_rect()),"close remains inside the landscape safe area at "+str(dimensions))
		check(close != null and close.size.y*scale >= 47.9,"close retains its48-unit logical touch target at "+str(dimensions))
		check(scroll != null and scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page,"full catalog uses the original scrolling control at "+str(dimensions))
		check(grid != null and grid.get_child_count() == rows.size(),"all catalog entries remain reachable at "+str(dimensions))
		var known := tile(&"B03")
		check(known != null and not known.focus_neighbor_bottom.is_empty() and not known.focus_neighbor_right.is_empty(),"gamepad has explicit grid focus routing at "+str(dimensions))
		var last := tile(rows[-1].id)
		if last != null: last.grab_focus()
		await frames()
		check(last != null and root.gui_get_focus_owner() == last,"gamepad/keyboard can focus the last catalog entry")
		check(scroll != null and scroll.scroll_vertical > 0,"follow_focus scrolls to the last entry without a custom fake grid")
		close.pressed.emit()
		close.pressed.emit()
		check(closes == (1 if dimensions.x == 1280 else 2),"close request is idempotent per view")
		codex.hide_codex()
		await frames()

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var prior := Button.new()
	prior.text = "Home fixture focus"
	root.add_child(prior)
	prior.grab_focus()
	codex = CODEX.new()
	root.add_child(codex)
	codex.requested_unlock.connect(func(id: StringName,revision: int) -> void: unlocks.append([id,revision]))
	codex.requested_select.connect(func(id: StringName,revision: int) -> void: selections.append([id,revision]))
	codex.requested_close.connect(func() -> void: closes += 1)
	var rows := snapshot()
	codex.show_codex(rows,12,&"P24",7)
	await frames()
	await unknown_contract()
	await transaction_contract(rows)
	check(root.gui_get_focus_owner() == prior,"closing restores the previous Home focus owner")
	await layout_contract(rows)
	await removed_selection_contract(rows)
	await unknown_policy_contract(rows)
	codex.free()
	prior.free()
	ItemArtLibrary.clear_cache()
	await frames()
	print("HOME ITEM CODEX UI: %s assertions, %s failures" % [assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
