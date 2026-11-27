extends Node2D
## Both mouths show the same forest gate. The bolt sits on the F08 side.
const ID := "d223"
const POST := "res://rooms/world/p02_connections/forest_gate_post.png"
const LEAF := "res://rooms/world/p02_connections/forest_gate_leaf.png"
var session: OrdinaryRoomSession
var row: Dictionary
var latch := Vector2.INF
var wall := StaticBody2D.new()
var leaf := Sprite2D.new()
var hint := Label.new()
var opened := false
var failed := false

static func mount(owner_session: OrdinaryRoomSession, doc: Dictionary) -> void:
	var gate := new()
	gate.name = "ForestShortcutGate"
	gate.session = owner_session
	gate.row = owner_session.content_catalog.lookup("doors",ID).row
	if doc.room_id == gate.row.one_way_from:
		gate.latch = FixedWorldProvider.point(doc.sites[ID].at)
	var opening: Dictionary = doc.exits[ID]
	var normal := FixedWorldProvider.point(opening.direction)
	var inset := 19.0 if gate.latch.is_finite() else 43.0
	gate.position = FixedWorldProvider.point(opening.point) - normal*inset + Vector2.DOWN*18
	owner_session.room.add_child(gate)

func _ready() -> void:
	session.controller.router.set_meta(&"world_up_interaction",true)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 3
	wall.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32,100)
	collision.shape = shape
	collision.position.y = -shape.size.y*.5
	wall.add_child(collision)
	add_child(wall)
	var post := Sprite2D.new()
	post.texture = load(POST)
	post.centered = false
	post.position = Vector2(-20,-108)
	add_child(post)
	leaf.texture = load(LEAF)
	leaf.centered = false
	leaf.position = Vector2(-16,-100)
	add_child(leaf)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -310
	hint.offset_right = 310
	hint.offset_top = -88
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font",EquipmentMenu.UI_FONT)
	hint.add_theme_font_size_override("font_size",22)
	hint.add_theme_constant_override("outline_size",5)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.hide()
	session.state.committed.connect(_refresh)
	session.controller.interact_requested.connect(_interact)
	_refresh(session.state.revision)

func _refresh(_revision: int) -> void:
	var unlocked := session.state.has(row.unlock_flag)
	wall.collision_layer = 0 if unlocked else 1
	if unlocked and not opened and Engine.get_physics_frames() > 0 and hint.visible:
		var swing := create_tween()
		swing.tween_property(leaf,"scale:x",.12,.20).set_trans(Tween.TRANS_SINE)
	else:
		leaf.scale.x = .12 if unlocked else 1.0
	opened = unlocked
	hint.visible = false

func _at_latch() -> bool:
	return latch.is_finite() and session.player.position.distance_squared_to(latch)<=50.0*50.0

func _physics_process(_delta: float) -> void:
	hint.hide()
	if opened or not session.lifetime.active or not session.controller.active: return
	if session.player.position.distance_squared_to(position+Vector2.UP*18)>92.0*92.0:
		failed = false
		return
	if _at_latch():
		hint.text = session.controller.router.interact_prompt("再试门闩" if failed else "提起林缘栅门的内闩")
	elif not latch.is_finite():
		hint.text = "林缘栅门的横闩在另一侧。"
	else:
		return
	hint.show()

func _interact() -> void:
	if opened or not _at_latch() or not session.player.is_on_floor(): return
	if not session.lifetime.active or not session.controller.active or session.controller.has_pending_damage(): return
	var next := session.content_catalog.shortcut_candidate(session.state,session.room.room_id,ID)
	if next.is_empty(): return
	failed = not session.state.commit(next,session.state.revision)
	if not failed: GameAudio.cue(self,&"door")
