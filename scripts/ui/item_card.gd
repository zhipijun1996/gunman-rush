class_name ItemCard
extends PanelContainer
## Shared by reward choices, shop preview and pause inventory.
signal selected(item_id: StringName)
var item: ItemDefinition
var selectable:=false
var count:=1
func _ready() -> void:
	theme=UnderworldUI.create_theme()
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size=Vector2(252,260)
	var style:=StyleBoxFlat.new()
	style.bg_color=UnderworldUI.PANEL
	style.border_color=[Color("83a69e"),Color("a694b0"),UnderworldUI.BRASS][item.rarity]
	style.set_border_width_all(2);style.set_corner_radius_all(2)
	for side: int in 4: style.set_content_margin(side,14)
	add_theme_stylebox_override("panel",style)
	var rows:=VBoxContainer.new();rows.add_theme_constant_override("separation",10);add_child(rows)
	var badge:=Label.new();badge.text=["普通 / BLUE","稀有 / PURPLE","顶级 / GOLD"][item.rarity]+(" ×%s" % count if count>1 else "");badge.add_theme_font_override("font",UnderworldUI.FONT);badge.modulate=style.border_color;rows.add_child(badge)
	var image:=TextureRect.new();image.texture=ItemPresentation.icon(item.icon_key);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size=Vector2(100,90);rows.add_child(image)
	for text: String in [item.display_name,item.description,ItemPresentation.effects(item)]:
		var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=222;label.add_theme_font_override("font",UnderworldUI.FONT);label.add_theme_font_size_override("font_size",16);label.add_theme_color_override("font_color",UnderworldUI.TEXT);rows.add_child(label)
	if selectable:
		var button:=Button.new();button.text="选择 / PICK "+item.display_name;button.custom_minimum_size.y=44;button.add_theme_font_override("font",UnderworldUI.FONT);button.pressed.connect(func(): selected.emit(item.stable_id));rows.add_child(button)
		if get_index()==0: button.grab_focus()
