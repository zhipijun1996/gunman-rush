class_name WorldRoomInteraction
extends Node2D
## One authored physical host for one canonical world action.
@export var action_id := ""
@export var section_id := "main"
@export var label := "拾取"
@export var visual := "time_gear"
@export var radius := 60.0
var animation: WorldSpriteAnimation
var state: FixedWorldState
var action: Dictionary = {}
func bind(value: FixedWorldState) -> void:
	state=value;action=state.content.action(action_id)
	if action.is_empty(): push_error("Unknown action host: "+action_id);return
	if str(action.get("section_id","main"))!=section_id: push_error("Action section mismatch: "+action_id)
	animation=WorldSpriteAnimation.new();animation.asset_id=visual;animation.position=Vector2(0,18);add_child(animation)
	state.committed.connect(_refresh)
	_refresh(0)
func _refresh(_revision: int) -> void:
	var done: bool=state.value.receipts.has(action_id)
	visible=visual in ["clock_altar","pulley_switch"] or bool(action.get("repeat",false)) or not done
	if animation!=null:animation.activated=done
	modulate=Color.WHITE if state.holds(action.get("requires",[])) else Color(.65,.7,.7)
func available(player_position: Vector2,section: String) -> bool:
	return visible and state!=null and (bool(action.get("repeat",false)) or not state.value.receipts.has(action_id)) and section==section_id and player_position.distance_to(position)<=radius and state.holds(action.get("requires",[]))
func celebrate() -> void:
	if animation!=null:animation.play_event()
	var burst:=WorldSpriteAnimation.new();burst.asset_id="collection_burst";burst.disposable=true;burst.position=position;burst.z_index=10
	get_parent().add_child(burst)
