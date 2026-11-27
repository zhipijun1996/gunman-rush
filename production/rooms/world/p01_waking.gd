class_name PlainsOpening
extends Node2D
## The ordinary room ledger owns the wake and acquisition. This component only
## advances the original character poses, shows the world item and accepts input.
const SITE := "p01_sidearm"
const WAKE := "p01_wake"
const TAKE := "p01_take_sidearm"
const GUN := preload("res://assets/plains_v3/hero/weapon.png")
const GUN_ART := Rect2(292,218,1040,601)
var session: OrdinaryRoomSession
var body: UnderworldPlayer
var waking := false
var awake_time := 0.0
var retry_in := 0.0
var pickup_feedback := 0.0
var prompt := Label.new()

func install(owner_session: OrdinaryRoomSession, point: Vector2) -> void:
	session = owner_session
	position = point
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	session.room.add_child(self)
	var overlay := CanvasLayer.new()
	session.add_child(overlay)
	overlay.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	prompt.offset_top = 64
	prompt.offset_bottom = 103
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_theme_font_override("font",EquipmentMenu.UI_FONT)
	prompt.add_theme_font_size_override("font_size",19)
	prompt.add_theme_constant_override("outline_size",5)
	prompt.add_theme_color_override("font_outline_color",Color("252b2d"))
	prompt.hide()
	session.controller.router.set_meta(&"world_up_interaction",true)
	if session.state.has("p01_awake"):
		awake_time = 1.0
	else:
		waking = true
		session.controller.router.clear("wake")
		session.controller.active = false
		body = PlayerPresentationRuntime.current_body(session.player)
		body.authored_pose.begin_wake(session.controller)
		remember_wake()

func remember_wake() -> bool:
	if session.state.has("p01_awake"): return true
	var next := session.state.action_candidate(WAKE,session.room.room_id)
	return not next.is_empty() and session.state.commit(next,session.state.revision)

func _physics_process(delta: float) -> void:
	if not session.lifetime.active or session.controller.actor_resources.health.terminal:
		prompt.hide()
		set_physics_process(false)
		return
	if waking:
		awake_time += delta
		if awake_time<PlayerAuthoredPoses.WAKE_SECONDS: return
		body.authored_pose.clear()
		waking = false
		session.controller.router.clear("wake_finished")
		session.controller.active = true
		awake_time = 0.0
		return
	if not session.controller.active:
		prompt.hide()
		return
	awake_time += delta
	retry_in -= delta
	if not session.state.has("p01_awake") and retry_in<=0:
		retry_in = 1.0
		remember_wake()
	if session.state.has("gun"):
		pickup_feedback -= delta
		if pickup_feedback<=0:
			prompt.hide()
			set_physics_process(false)
		return
	if pickup_feedback>0.0:
		pickup_feedback -= delta
		return
	if awake_time<1.0:
		prompt.text = "我在哪？"
	elif can_reach():
		prompt.text = "地上的枪　·　点「互动」拾取" if session.controller.router.touch_enabled else "地上的枪　·　按 ↑ / W 拾取"
	else:
		prompt.text = "向左回到草地上的枪旁" if session.player.position.x>position.x+32 else "走近草地上的枪"
	prompt.visible = session.player.position.distance_to(position)<265

func can_reach() -> bool:
	return session.player.is_on_floor() and session.player.position.distance_squared_to(position)<=32.0*32.0

func interact() -> bool:
	if waking or session.state.has("gun") or not session.lifetime.active or not session.controller.active or session.controller.has_pending_damage() or not can_reach(): return false
	if remember_wake():
		var next := session.state.action_candidate(TAKE,session.room.room_id)
		if not next.is_empty() and session.state.commit(next,session.state.revision):
			session.controller.router.clear("sidearm_picked_up")
			GameAudio.cue(session,&"confirm")
			prompt.text = "枪拿到了。跳起，向下瞄准后松手射击。" if session.controller.router.touch_enabled else "枪拿到了。跳起后朝脚下开枪，试试反冲。"
			prompt.show()
			pickup_feedback = 2.4
			queue_redraw()
			return true
	prompt.text = "未能保存拾取，稍后再试。"
	prompt.show()
	pickup_feedback = 1.3
	return true

func _draw() -> void:
	if session==null or session.state.has("gun"): return
	draw_set_transform(Vector2(0,18),0,Vector2.ONE)
	draw_line(Vector2(-16,-1),Vector2(13,-1),Color("21251fb0"),2)
	draw_texture_rect_region(GUN,Rect2(-18,-21,36,21),GUN_ART)
	PixelVfx.glint(self,Vector2(9,-20),2.0,Color("efd089"),.7)
	draw_set_transform(Vector2.ZERO)
