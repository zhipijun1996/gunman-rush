class_name ItemShopModal
extends CanvasLayer
signal purchase_requested
signal closed
var opened:=false
var _root: Control
func show_offer(offer: ShopOffer, coins: int, eligible: bool) -> void:
	close();opened=true;layer=30;process_mode=Node.PROCESS_MODE_ALWAYS
	_root=Control.new();_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(_root)
	var shade:=ColorRect.new();shade.color=Color(0.025,.035,.04,.82);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_root.add_child(shade)
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_root.add_child(center)
	var rows:=VBoxContainer.new();rows.theme=DemoMenu.create_theme();rows.add_theme_constant_override("separation",12);center.add_child(rows)
	var title:=Label.new();title.text="CAMP SHOP / COINS %s / STOCK %s" % [coins,offer.stock];title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;rows.add_child(title)
	var card:=ItemCard.new();card.item=offer.item;rows.add_child(card)
	var buy:=Button.new();buy.text="BUY / %s COINS" % offer.price;buy.custom_minimum_size.y=46;buy.disabled=not eligible or coins<offer.price or offer.stock<1;buy.pressed.connect(func(): purchase_requested.emit());rows.add_child(buy)
	var back:=Button.new();back.text="KEEP EXPLORING";back.custom_minimum_size.y=44;back.pressed.connect(func(): closed.emit());rows.add_child(back);(back if buy.disabled else buy).grab_focus()
func close() -> void:
	opened=false
	if is_instance_valid(_root): remove_child(_root);_root.queue_free()
	_root=null
