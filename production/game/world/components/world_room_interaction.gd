class_name WorldRoomInteraction
extends Node2D
## One authored physical host for one canonical world action.
@export var action_owner_id := ""
@export var action_id := ""
@export var section_id := "main"
@export var label := "拾取"
@export var visual := "time_gear"
@export var radius := 60.0
var chest_sprite: Sprite2D
var animation: WorldSpriteAnimation
var state: FixedWorldState
var action: Dictionary = {}
var _opening_age:=10.0
var _chest_rest_position := Vector2.ZERO
var _coin_session: OrdinaryRoomSession
var _coin_surface: Rect2
var _prompt: Label
func bind(value: FixedWorldState) -> void:
	state=value;action=state.content.action(action_id)
	if action.is_empty(): push_error("Unknown action host: "+action_id);return
	if str(action.get("section_id","main"))!=section_id: push_error("Action section mismatch: "+action_id)
	if not action_owner_id.is_empty():
		visible = false
		return
	if visual=="chest":
		chest_sprite=Sprite2D.new();add_child(chest_sprite)
	else:
		animation=WorldSpriteAnimation.new();animation.asset_id=visual;animation.position=Vector2(0,18);add_child(animation)
	state.committed.connect(_refresh)
	_refresh(0)
func _refresh(_revision: int) -> void:
	var done: bool=state.value.receipts.has(action_id)
	visible=visual in ["clock_altar","pulley_switch","chest"] or bool(action.get("repeat",false)) or not done
	if animation!=null:animation.activated=done
	if chest_sprite!=null:
		UnderworldObjects.place_chest(chest_sprite,Vector2(0,18),done)
		_chest_rest_position = chest_sprite.position
	modulate=Color.WHITE if state.holds(action.get("requires",[])) else Color(.65,.7,.7)
func bind_coin_chest(session: OrdinaryRoomSession) -> void:
	_coin_session = session
	var index := session.room.platform_index(action.support_id)
	_coin_surface = session.room.platforms[index]
	session.controller.router.set_meta(&"world_up_interaction",true)
	_prompt = Label.new()
	_prompt.position = Vector2(-85,-65)
	_prompt.size.x = 170
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_override("font",EquipmentMenu.UI_FONT)
	_prompt.add_theme_font_size_override("font_size",14)
	_prompt.add_theme_constant_override("outline_size",4)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.hide()
	add_child(_prompt)

func _on_coin_chest_support() -> bool:
	if not _coin_session.lifetime.active or not _coin_session.controller.active or _coin_session.controller.has_pending_damage(): return false
	var player := _coin_session.player
	if not player.grounded_contact(): return false
	for index in player.get_slide_collision_count():
		var hit := player.get_slide_collision(index)
		var body := hit.get_collider() as CollisionObject2D
		if body != null and hit.get_normal().y < -.7 and body.get_meta(&"world_ground",Rect2()) == _coin_surface:
			return true
	return false

func available(player_position: Vector2,section: String) -> bool:
	if not visible or state==null or section!=section_id or player_position.distance_to(position)>radius: return false
	if not bool(action.get("repeat",false)) and state.value.receipts.has(action_id): return false
	return state.holds(action.get("requires",[])) and (_coin_session==null or _on_coin_chest_support())
func celebrate() -> void:
	if chest_sprite!=null:
		_opening_age=0
		GameAudio.cue(self,&"chest_reveal")
		return
	if animation!=null:animation.play_event()
	var burst:=WorldSpriteAnimation.new();burst.asset_id="collection_burst";burst.disposable=true;burst.position=position;burst.z_index=10
	get_parent().add_child(burst)

func _process(delta:float) -> void:
	if _prompt != null:
		var player := _coin_session.player
		_prompt.visible = available(player.position,_coin_session.room.section_at(player.position))
		if _prompt.visible:
			_prompt.text = _coin_session.controller.router.interact_prompt(label)
	if _opening_age>=.9:return
	_opening_age+=delta
	if chest_sprite!=null:
		# A brisk lid/chest recoil, then a damped settle; no parallel tween.
		var hop:=-sin(clampf(_opening_age/.18,0,1)*PI)*4
		chest_sprite.position = _chest_rest_position + Vector2.DOWN*hop
	queue_redraw()

func _draw() -> void:
	if state == null or not action_owner_id.is_empty(): return
	# A grounded socket frames the authored action artwork. The reward, lever
	# or chest animation keeps its own silhouette and committed-action timing.
	var width := 48.0 if visual in ["chest","clock_altar"] else 28.0
	MechanismRegionArt.panel(self,Rect2(-width/2,15,width,8))
	MechanismRegionArt.stamp(self,"finial",Vector2(-width/2+3,11),Vector2(10,18))
	if chest_sprite!=null and _opening_age<.9:
		PixelVfx.clip(self,&"chest-rays",Vector2(0,0),_opening_age/.9)

func _exit_tree() -> void:
	GameAudio.stop_origin(self,false)
