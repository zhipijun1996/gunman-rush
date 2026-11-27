class_name WorldContentMenu
extends CanvasLayer
var sites: WorldContentSites
var panel := PanelContainer.new()
var stack := VBoxContainer.new()
var heading := Label.new()
var message := Label.new()
var choices := VBoxContainer.new()
var dismiss := Button.new()
var active_npc := ""

func _ready() -> void:
	layer=26
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(panel)
	panel.set_anchor(SIDE_LEFT,.23)
	panel.set_anchor(SIDE_RIGHT,.77)
	panel.set_anchor(SIDE_TOP,.23)
	panel.set_anchor(SIDE_BOTTOM,.89)
	var skin := StyleBoxFlat.new()
	skin.bg_color=Color("21252cf7")
	skin.border_color=Color("a48a59")
	skin.set_border_width_all(2)
	for side: int in 4: skin.set_content_margin(side,14)
	panel.add_theme_stylebox_override("panel",skin)
	var font_theme := Theme.new()
	font_theme.default_font=EquipmentMenu.UI_FONT
	font_theme.default_font_size=17
	panel.theme=font_theme
	panel.add_child(stack)
	heading.add_theme_font_size_override("font_size",22)
	heading.modulate=Color("eed39a")
	stack.add_child(heading)
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(message)
	body.add_child(choices)
	dismiss.text="收起"
	dismiss.pressed.connect(close)
	stack.add_child(dismiss)
	panel.hide()

func visible_panel() -> bool: return panel.visible

func _show(title: String, text: String) -> void:
	heading.text=title
	message.text=text
	panel.show()
	sites.session.controller.router.clear("content_site")
	get_tree().paused=true
	dismiss.grab_focus()

func _clear_choices() -> void:
	for button: Node in choices.get_children():
		choices.remove_child(button)
		button.queue_free()

func notice(title: String, text: String) -> void:
	active_npc=""
	_clear_choices()
	_show(title,text)

func actions(ids: Array[String]) -> void:
	notice("交互","")
	for id: String in ids:
		var option := Button.new()
		option.text=WorldContentSites.title(sites.rows[id].data)
		option.pressed.connect(sites.interact_site.bind(id))
		choices.add_child(option)

func stations(origin: String) -> void:
	_clear_choices()
	var station: Dictionary = sites.rows[origin].data
	var ticket: int = sites.session.state.revision
	var destinations := 0
	for target: Dictionary in sites.session.content_catalog.object("transport").value.stations:
		if target.id == origin or not sites.session.state.value.receipts.has(target.id): continue
		var button := Button.new()
		button.text = target.name
		button.pressed.connect(depart.bind(origin,str(target.id),ticket))
		choices.add_child(button)
		destinations += 1
	_show(station.name,"选择已敲响的站钟。" if destinations else "站钟已经敲响。抵达另一站并敲钟后，就可以在两站间往返。")

func depart(origin: String, destination: String, revision: int) -> void:
	close()
	sites.station_departure.emit(origin,destination,revision)

func shop(id: String, feedback := "") -> void:
	active_npc=id
	_clear_choices()
	var revision := sites.session.state.revision
	var ledger := sites.session.services.ledger()
	var note := feedback+"\n" if not feedback.is_empty() else ""
	var greeting := sites.text_for(id)
	if not greeting.is_empty(): note+=greeting+"\n"
	_show(WorldContentSites.title(sites.rows[id].data),note+"金币　"+str(int(ledger.gold)))
	for event: String in sites.giver_events(id):
		var option:=Button.new()
		option.text=WorldContentSites.title(sites.rows[event].data)
		option.pressed.connect(sites.interact_site.bind(event))
		choices.add_child(option)
	if "equipment_upgrade" in sites.rows[id].data.services:
		var service:=Button.new()
		service.text="强化已有装备"
		service.pressed.connect(func(): close(); sites.session.equipment_menu.open("smith"))
		choices.add_child(service)
	var exchanges:=sites.exchange_offers(id)
	if not exchanges.is_empty():
		var carried: int=sites.session.state.value.gear_ids.carried.size()
		var delivered: int=sites.session.state.value.gear_ids.delivered.size()
		var deposit:=Button.new()
		deposit.text="交付携带的 %d 枚失步齿轮　已交付 %d 枚" % [carried,delivered]
		deposit.disabled=carried==0
		deposit.pressed.connect(func(): shop(id,"已交付。" if sites.deliver_gears(id,revision) else "未能交付。"))
		choices.add_child(deposit)
		for exchange: Dictionary in exchanges:
			var reward:=sites.session.content_catalog.lookup("rewards",exchange.reward_key)
			var option:=Button.new()
			option.text="兑取%s　累计交付 %d 枚" % [WorldContentSites.title(reward.row),int(exchange.requires_delivered.lost_gear)]
			option.disabled=delivered<int(exchange.requires_delivered.lost_gear) or sites.done(exchange.reward_key)
			option.pressed.connect(_exchange.bind(id,str(exchange.id),revision))
			choices.add_child(option)
	for offer: Dictionary in sites.offers(id):
		var quote := sites.session.content_catalog.shop_quote(offer.id)
		if not quote.ok: continue
		var source:=sites.session.content_catalog.lookup("rewards",quote.reward_id)
		if not source.ok: continue
		var owned: bool = ledger.owned.has(quote.equipment_id) or sites.done(quote.reward_id)
		var button := Button.new()
		button.text=WorldContentSites.title(source.row)+"　"+("已售出" if owned else "%d 金币" % quote.price)
		button.tooltip_text=str(offer.description)
		button.disabled=owned or quote.price>ledger.gold or not sites.eligible(offer) or not sites.eligible(source.row)
		button.pressed.connect(_purchase.bind(id,str(offer.id),revision))
		choices.add_child(button)

func _exchange(npc: String, id: String, revision: int) -> void:
	shop(npc,"已兑取。" if sites.exchange(npc,id,revision) else "这次未能兑取。")

func endings(site_id: String) -> void:
	notice("世界钟心","选择想要完成的结局。")
	for ending: Dictionary in sites.available_endings(site_id):
		var button:=Button.new()
		button.text=str(ending.title)
		if sites.session.state.value.receipts.has("ending:"+str(ending.id)): button.text+="　回看"
		button.pressed.connect(_confirm_page.bind(site_id,ending))
		choices.add_child(button)

func _confirm_page(site_id: String, ending: Dictionary) -> void:
	notice(str(ending.title),"确认后记录此结局，之后仍可继续探索。")
	var button:=Button.new()
	button.text="确认"
	var revision:=sites.session.state.revision
	button.pressed.connect(func():
		if sites.confirm_ending(site_id,str(ending.id),revision):
			var paragraphs:=PackedStringArray(ending.paragraphs)
			paragraphs.append_array(ending.aftermath)
			notice(str(ending.title),"\n\n".join(paragraphs))
		else: notice(str(ending.title),"记录未保存，请重试。")
	)
	choices.add_child(button)

func _purchase(npc: String, offer: String, revision: int) -> void:
	if not visible_panel() or npc!=active_npc: return
	var purchased := sites.buy(npc,offer,revision)
	shop(npc,"已领取。" if purchased else "交易未完成。")

func close() -> void:
	if not panel.visible: return
	panel.hide()
	active_npc=""
	sites.session.controller.router.clear("content_site")
	get_tree().paused=false

func _input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _exit_tree() -> void:
	if panel.visible: get_tree().paused=false
