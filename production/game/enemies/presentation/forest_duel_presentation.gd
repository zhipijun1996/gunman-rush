extends Node2D
## Pixel poses share a sole baseline with each owner's physical body.
@export var actor: EnemyActor
@export var atlas: Texture2D
var hit_flash := 0.0
var frame := 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.damageable.damaged.connect(_damaged)

func _damaged(_context: Dictionary) -> void:
	hit_flash = .11

func _process(delta: float) -> void:
	hit_flash = maxf(0.0,hit_flash-delta)
	frame = 0
	if actor.attack_behavior:
		var behavior := actor.attack_behavior
		if behavior.state == &"telegraph": frame = 1
		if behavior.state == &"attack": frame = 2 if behavior.attack_goal.y < behavior.home.y else 1
	modulate = Color(1.5,1.2,1.1) if hit_flash > 0 else Color.WHITE
	visible = not actor.health.terminal
	queue_redraw()

func _draw() -> void:
	if not atlas or not actor or not actor.definition: return
	var cell := Vector2(atlas.get_width()/3.0,atlas.get_height())
	draw_set_transform(Vector2.ZERO,0.0,Vector2(actor.brain.direction,1))
	draw_texture_rect_region(atlas,Rect2(Vector2(-cell.x/2,actor.definition.collision_size.y/2-cell.y),cell),Rect2(Vector2(frame*cell.x,0),cell))
