class_name FixedWorldUI
extends CanvasLayer
## Shared UI components; all mutations are commands owned by the application/domain.
signal command(kind: String,id: String)
var world: FixedWorldState
var content: FixedWorldProvider
var title: FixedWorldTitle
var hud: DemoGameHud
var mini: FixedWorldMap
var shell: DemoUiModalShell
var interact: Button
var pause_button: Button
var interact_host: ScrollContainer
var pause_host: ScrollContainer
var notice: Label
var curtain: ColorRect
var _transition_tween: Tween
var root: Control
var page := ""
var equipment: WorldEquipment
var heal: Button
var heal_host: ScrollContainer
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer=30
	title=FixedWorldTitle.new()
	add_child(title)
	title.world_requested.connect(func(kind: String) -> void: command.emit(kind,""))
	title.show_title()
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.theme=DemoClockworkTheme.create_theme()
	add_child(root)
	hud=DemoGameHud.new()
	root.add_child(hud)
	hud.hide()
	mini=FixedWorldMap.new()
	mini.world=world;mini.content=content
	mini.open_requested.connect(func() -> void: command.emit("map",""))
	root.add_child(mini)
	pause_button=Button.new();pause_button.text=WorldText.text("world_ui.00")
	pause_button.pressed.connect(func() -> void: command.emit("pause",""))
	pause_host=_touch_host(pause_button)
	heal=Button.new();heal.name="FocusHeal";heal.focus_mode=Control.FOCUS_NONE
	heal.button_down.connect(func() -> void: command.emit("heal_hold","1"))
	heal.button_up.connect(func() -> void: command.emit("heal_hold","0"))
	heal_host=_touch_host(heal)
	heal_host.get_child(1).connect("forwarded",func(phase: StringName) -> void:
		if phase not in [&"press",&"drag"]: command.emit("heal_hold","0"))
	interact=Button.new();interact.name="ContextInteract"
	interact.pressed.connect(func() -> void: command.emit("interact",""))
	interact_host=_touch_host(interact)
	notice=DemoClockworkTheme.label("",18,DemoClockworkTheme.PAPER)
	notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	root.add_child(notice)
	curtain=ColorRect.new()
	curtain.color=Color.BLACK
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(curtain)
	curtain.hide()
	equipment=WorldEquipment.new()
	root.add_child(equipment)
	equipment.layer=31
	equipment.requested_resume.connect(func() -> void: command.emit("close",""))
	root.hide()
func bind(actor: PlayerController) -> void:
	title._hide()
	root.show()
	hud.bind(actor)
func unbind() -> void:
	close()
	hud.unbind();root.hide();title.show_title()
func panel(kind: String,heading: String,detail: String) -> DemoUiModalShell:
	close()
	page=kind
	interact_host.hide();pause_host.hide()
	shell=DemoUiModalShell.new()
	root.add_child(shell)
	root.show()
	shell.heading(heading,detail)
	shell.cancel_requested.connect(func() -> void: command.emit("close",""))
	return shell
func close() -> void:
	if equipment!=null: equipment._hide()
	if is_instance_valid(shell):
		shell.restore_focus()
		shell.hide();shell.queue_free()
	shell=null
	page=""
func show_pause() -> void:
	var modal:=panel("pause",WorldText.text("world_ui.01"),WorldText.text("world_ui.02"))
	for row: Array in [[WorldText.text("world_ui.03"),"close"],[WorldText.text("world_ui.04"),"map"],[WorldText.text("world_ui.05"),"inventory"],[WorldText.text("world_ui.06"),"settings"],[WorldText.text("world_ui.07"),"title"]]:
		modal.button(row[0],func() -> void: command.emit(row[1],""))
	modal.focus_first()
func show_map() -> void:
	var modal:=panel("map",WorldText.text("world_ui.08"),WorldText.text("world_ui.09"))
	var map:=FixedWorldMap.new()
	map.expanded=true;map.world=world;map.content=content
	map.current_room=mini.current_room
	map.local_player=mini.local_player
	var physical_factor:=clampf(1.0/DemoUiModalMetrics.ui_scale(get_viewport()),1,1.8)
	map.custom_minimum_size=Vector2(320,clampf(get_viewport().get_visible_rect().size.y/physical_factor-300,120,280))
	map.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	modal.rows.add_child(map)
	map.touch_clip=modal.scroll
	modal.register_touch_region(map)
	var buttons:=HBoxContainer.new();modal.rows.add_child(buttons)
	for entry: Array in [["−",0.8],["＋",1.25]]:
		var b:=Button.new();b.text=entry[0];b.custom_minimum_size=Vector2(80,54)
		b.pressed.connect(func() -> void: map.zoom_at(entry[1],map.size/2))
		buttons.add_child(b)
	modal.button(WorldText.text("world_ui.10"),func() -> void: command.emit("close",""))
	modal.focus_first()
func present(actor: PlayerController,room_id: String,location: String,status: String,context: String,gold: int,reduced: bool=false,healing_progress: float=0,heal_available: bool=false) -> void:
	if actor==null:
		return
	mini.current_room=room_id
	mini.local_player=actor.motor.position
	var safe:=DemoUiModalMetrics.safe_rect(get_viewport())
	var factor:=clampf(1.0/DemoUiModalMetrics.ui_scale(get_viewport()),1,1.8)
	mini.scale=Vector2.ONE*factor
	mini.size=Vector2(200,135)
	mini.position=Vector2(safe.end.x-210*factor,safe.position.y+16*factor)
	pause_button.custom_minimum_size=Vector2(100,48)*factor
	pause_host.position=Vector2(safe.end.x-110*factor,mini.position.y+145*factor)
	pause_host.size=pause_button.get_combined_minimum_size()
	pause_host.visible=page.is_empty()
	interact.custom_minimum_size=Vector2(220,54)*factor
	interact_host.position=Vector2(safe.get_center().x-110*factor,safe.end.y-90*factor)
	interact_host.size=interact.get_combined_minimum_size()
	interact.text=context
	interact.visible=not context.is_empty() and page.is_empty()
	interact_host.visible=interact.visible
	notice.text=status
	notice.position=Vector2(safe.get_center().x-260*factor,safe.position.y+18*factor)
	notice.size=Vector2(520,80)*factor
	notice.visible=page.is_empty()
	hud.present_context(location,gold,0,reduced)
	hud._money.text=WorldText.text("hud.gold") % gold
	hud._resonance_text.text=WorldText.text("heal.resonance") % [actor.combat_energy.current,actor.combat_energy.capacity()]
	heal.custom_minimum_size=Vector2(180,60)*factor
	var heal_bottom:=280 if actor.router.touch_enabled else 100
	heal_host.position=Vector2(safe.position.x+24*factor,safe.end.y-heal_bottom*factor)
	heal_host.size=heal.get_combined_minimum_size()
	heal_host.visible=page.is_empty()
	heal.disabled=not heal_available
	heal.tooltip_text=WorldText.text("heal.controls")
	var cost:=int(content.data.player.focus_heal.cost)
	heal.text=WorldText.text("heal.progress") % int(healing_progress*100) if healing_progress>0 else WorldText.text("heal.control") % cost
	if actor.actor_resources.health.current>=actor.actor_resources.health.capacity: heal.text=WorldText.text("heal.full")
	elif actor.combat_energy.current<cost: heal.text=WorldText.text("heal.insufficient") % cost
	hud._wallet_plate.position=Vector2(safe.end.x-hud._wallet_plate.size.x*hud._wallet_plate.scale.x-24*factor,pause_host.position.y+pause_host.size.y+8*factor)

func _touch_host(button: Button) -> ScrollContainer:
	var host:=ScrollContainer.new()
	host.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	host.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(host)
	host.add_child(button)
	var touch:=preload("res://game/presentation/ui/menu_scroll_touch_adapter.gd").new()
	touch.scroll=host
	host.add_child(touch)
	return host

func begin_transition() -> void:
	if _transition_tween!=null and _transition_tween.is_valid(): _transition_tween.kill()
	curtain.color=Color.BLACK
	curtain.mouse_filter=Control.MOUSE_FILTER_STOP
	curtain.show()
func finish_transition() -> void:
	_transition_tween=create_tween()
	_transition_tween.tween_property(curtain,"color:a",0.0,.08)
	await _transition_tween.finished
	curtain.hide()
