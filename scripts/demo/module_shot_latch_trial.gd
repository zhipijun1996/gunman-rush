class_name ModuleShotLatchTrial
extends Node2D
## Two fixed practice switches; this content is excluded from random pools.
var lab: ModuleLab
var latches: Array[ShotLatch] = []
var _label: Label
func setup(owner_lab: ModuleLab) -> void:
	lab = owner_lab
	for data: Array in [[Vector2(270, 535), Rect2(460, 330, 24, 270)], [Vector2(790, 640), Rect2(960, 330, 24, 270)]]:
		var latch := ShotLatch.new()
		latch.link_id = "A" if latches.is_empty() else "B"
		latch.link_color = Color("e8bd65") if latches.is_empty() else Color("8bcfdf")
		add_child(latch)
		latch.setup(lab.controller, lab.lifetime, data[0], data[1])
		latch.opened.connect(_opened)
		latches.append(latch)
	_label = Label.new()
	_label.position = Vector2(80, 245)
	_label.add_theme_font_size_override("font_size", 18)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = "SHOOT THE BRASS BELL / ONE SHOT OPENS ITS GATE\nThen: aim DOWN at the well bell / recoil UP. Opening first is allowed."
	add_child(_label)

func all_open() -> bool:
	return latches.size() == 2 and latches[0].is_open and latches[1].is_open
func _opened() -> void:
	lab._status = "WINDCHIME / %s of 2 gates open. State stays open on segment return." % (int(latches[0].is_open) + int(latches[1].is_open))
func cancel_pending() -> void:
	if is_instance_valid(lab.controller):
		lab.controller.shoot_ability.clear_projectiles()
	for latch: ShotLatch in latches:
		latch.cancel_pending()
func cancel() -> void:
	if lab != null and is_instance_valid(lab.controller):
		lab.controller.shoot_ability.clear_projectiles()
	for latch: ShotLatch in latches:
		latch.cancel()
func _exit_tree() -> void:
	cancel()
