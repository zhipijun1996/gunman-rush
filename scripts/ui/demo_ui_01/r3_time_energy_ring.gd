class_name DemoTimeEnergyRing
extends Control
## Read-only, actor-following view of the one official aim-time reserve.
const COLORS := preload("res://scripts/ui/demo_ui_01/clockwork_theme.gd")
var actor: PlayerController
var screen_center := Vector2.ZERO
var radius := 38.0
var current: float:
	get:
		return actor.air_focus_ability.stamina_state.current if is_instance_valid(actor) else 0.0
var capacity: float:
	get:
		return actor.air_focus_ability.stamina_state.capacity if is_instance_valid(actor) else 0.0
var fill_ratio: float:
	get:
		return clampf(current / maxf(capacity, 0.001), 0.0, 1.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

func bind(value: PlayerController) -> void:
	actor = value
	_refresh()

func unbind() -> void:
	actor = null
	hide()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	visible = is_instance_valid(actor) and is_instance_valid(actor.motor) and actor.active and not actor.actor_resources.health.terminal and actor.air_focus_ability.active and not get_tree().paused
	if not visible: return
	# PlayerController is a Node; its actual Motor is the visible actor's CanvasItem.
	var world_to_canvas := actor.motor.get_global_transform_with_canvas()
	var canvas_to_local := get_global_transform_with_canvas().affine_inverse()
	screen_center = canvas_to_local * (world_to_canvas * Vector2.ZERO)
	var collision := actor.motor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var half_height := UnderworldActors.HUMANOID_HEIGHT * 0.5
	if collision != null and collision.shape is RectangleShape2D:
		half_height = (collision.shape as RectangleShape2D).size.y * 0.5
	radius = maxf(24.0, (canvas_to_local.basis_xform(world_to_canvas.basis_xform(Vector2(0, half_height)))).length() + 10.0)
	queue_redraw()

func _draw() -> void:
	if not visible or fill_ratio <= 0: return
	draw_arc(screen_center, radius, -PI * 0.5, PI * 1.5, 64, Color(COLORS.INK, 0.65), 5, false)
	draw_arc(screen_center, radius, -PI * 0.5, -PI * 0.5 + TAU * fill_ratio, maxi(2, ceili(64 * fill_ratio)), COLORS.BRASS, 3, false)
	var end := screen_center + Vector2.from_angle(-PI * 0.5 + TAU * fill_ratio) * radius
	draw_circle(end, 2.0, COLORS.PAPER, true, -1, false)
