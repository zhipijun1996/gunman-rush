class_name AudioDirectorLabPickup
extends Area2D
## Development fixture: actual contact, original icon and official reward services.
var kind: StringName = &"coin"
var expected_player: PlayerMotor
var claim: Callable
var claimed := false
var _sprite: Sprite2D
var _age := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 17
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = UnderworldActors.icon_texture(kind)
	if _sprite.texture != null:
		_sprite.scale = Vector2(24, 24) / _sprite.texture.get_size()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	body_entered.connect(_contact)

func _contact(body: Node) -> void:
	if claimed or body != expected_player or not claim.is_valid(): return
	if claim.call(kind, self) == true:
		claimed = true
		set_deferred("monitoring", false)
		hide()

func _process(delta: float) -> void:
	_age += delta
	if is_instance_valid(_sprite): _sprite.position.y = sin(_age * 3.5) * 3.0
