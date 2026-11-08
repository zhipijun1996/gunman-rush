class_name PlainsBossEffects
extends Node2D
## Painted effects consume accepted attack clocks/contacts; no damage or movement.
const BELL := preload("res://assets/plains_boss_fx_142/bellstrider_fx.png")
const WIND := preload("res://assets/plains_boss_fx_142/windkeeper_fx.png")
const HUB := preload("res://game/presentation/actors/art/plains_windmill_anchors.gd")
var family := &"bell"
var row := 2
var age := 0.0
var seconds := .32
var facing := 1.0
var effect_scale := Vector2.ONE
var _owner_ref: WeakRef
var _epoch := -1

static func spawn(parent: Node, owner: Node, point: Vector2, kind: StringName, clip: int = 2, duration: float = .32, size := Vector2.ONE) -> PlainsBossEffects:
	if not is_instance_valid(parent) or not parent.is_inside_tree(): return null
	if parent.get_tree().get_nodes_in_group(&"plains_boss_effects").size() >= 48: return null
	var fx := PlainsBossEffects.new()
	fx.family = kind; fx.row = clip; fx.seconds = duration; fx.effect_scale = size
	if is_instance_valid(owner):
		fx._owner_ref = weakref(owner); fx._epoch = owner.attack_epoch
	parent.add_child(fx); fx.global_position = point
	return fx

func _ready() -> void:
	add_to_group(&"plains_boss_effects")
	set_meta(&"item_v5_world_entity",true)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 9
	var surface := CanvasItemMaterial.new()
	surface.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = surface

func _physics_process(delta: float) -> void:
	if _owner_ref != null:
		var owner := _owner_ref.get_ref() as Node
		if not is_instance_valid(owner) or not owner.active or owner.health.terminal or owner.attack_epoch != _epoch:
			queue_free(); return
	age += delta
	if age >= seconds: queue_free(); return
	queue_redraw()

func _draw() -> void:
	paint(self, family, row, age / seconds, Vector2.ZERO, effect_scale * Vector2(facing, 1))

static func paint(canvas: Node2D, kind: StringName, clip: int, progress: float, at := Vector2.ZERO, size := Vector2.ONE, angle := 0.0) -> void:
	var frame := clampi(int(progress * 4), 0, 3)
	canvas.draw_set_transform(at.round(), angle, size)
	canvas.draw_texture_rect_region(WIND if kind == &"wind" else BELL, Rect2(-80,-32,160,64), Rect2(frame*160,clip*64,160,64))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func windmill_origin(frame: Dictionary) -> Vector2:
	var animation: PlainsActorAnimation = frame.animation
	var index := animation.frame_index(frame.clip, frame.progress)
	return frame.origin + HUB.POINTS[clampi(index,0,26)] * Vector2(frame.face,1)

static func paint_gust(canvas: Node2D, frame: Dictionary, age_seconds: float, reach: float, side: float) -> void:
	var origin := windmill_origin(frame)
	# Draw a connected head-to-wind-zone stream; gaps keep the player readable.
	var end := Vector2(side * reach * .82, -55)
	var axis := end-origin
	for index: int in 3:
		var t := float(index)/3.0
		var point := origin.lerp(end,t)
		paint(canvas,&"wind",3,fposmod(age_seconds*12+index*.25,1),point,Vector2(.95,.75),axis.angle())
