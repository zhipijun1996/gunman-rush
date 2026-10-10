class_name PlainsStageVisual
extends Node2D
## Cosmetic consumer only; collection and transitions remain stage/App owned.
var stage: Node2D
var _time := 0.0
var _pickups: Array[Sprite2D] = []
var _pickup_by_id: Dictionary = {}
var _doors: Array[Sprite2D] = []
var _boss_door: Sprite2D
func configure(source: Node2D) -> void:
	stage = source
func _ready() -> void:
	_sync_pickups()
	for location: Vector2 in stage.exit_positions:
		_doors.append(_make_door(location))
	if stage.stage_type == &"boss":
		_boss_door = _make_door(stage.reward_position)
func _pickup_size(kind: String) -> Vector2:
	if kind == "coin":
		return Vector2(16, 16)
	if kind == "heart":
		return Vector2(27, 27)
	return Vector2(14, 21)
func _sync_pickups() -> void:
	# Drops can arrive after ready. Stable IDs retain their sprite when the
	# consumer reorders or removes entries; presentation never claims a reward.
	var live_ids: Dictionary = {}
	_pickups.clear()
	for index: int in stage.pickups.size():
		var pickup: Dictionary = stage.pickups[index]
		var key := str(pickup.get("id", "initial_%s" % index))
		live_ids[key] = true
		if not _pickup_by_id.has(key):
			var sprite := Sprite2D.new()
			sprite.texture = PlainsRefreshAssets.object_texture(StringName(pickup.kind))
			sprite.scale = _pickup_size(pickup.kind) / sprite.texture.get_size()
			add_child(sprite)
			_pickup_by_id[key] = sprite
		_pickups.append(_pickup_by_id[key])
	for key: String in _pickup_by_id.keys():
		if not live_ids.has(key):
			(_pickup_by_id[key] as Sprite2D).queue_free()
			_pickup_by_id.erase(key)
func _make_door(location: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = PlainsRefreshAssets.object_texture(&"door")
	sprite.scale = Vector2(60, 80) / sprite.texture.get_size()
	sprite.position = location + Vector2(0, -22)
	add_child(sprite)
	return sprite
func _process(delta: float) -> void:
	if not is_instance_valid(stage):
		return
	_time += delta
	_sync_pickups()
	for index: int in _pickups.size():
		var data: Dictionary = stage.pickups[index]
		var sprite := _pickups[index]
		sprite.visible = not data.claimed
		sprite.position = data.position + Vector2(0, sin(_time * 2.8 + index * 0.73) * 2)
		if data.kind == "coin":
			sprite.scale.x = 16.0 / sprite.texture.get_width() * (0.25 + 0.75 * absf(cos(_time * 2 + index)))
		elif data.kind == "heart":
			# A soft two-beat pulse and float identify contact healing without text.
			var phase := _time * 4.5 + index * 0.73
			var pulse := 1.0 + 0.07 * pow(maxf(0.0, sin(phase)), 4.0) + 0.035 * pow(maxf(0.0, sin(phase + 0.65)), 8.0)
			sprite.scale = _pickup_size("heart") / sprite.texture.get_size() * pulse
			sprite.position = data.position + Vector2(0, sin(_time * 2.4 + index) * 3)
		else:
			sprite.rotation = sin(_time * 2 + index) * 0.10
			sprite.modulate = Color(1, 0.91 + sin(_time * 3 + index) * 0.07, 1)
	for door: Sprite2D in _doors:
		door.modulate = Color(1, 1, 1, 1) if stage.completed else Color(0.63, 0.67, 0.60, 1)
	if is_instance_valid(_boss_door):
		_boss_door.visible = stage.reward_available
		_boss_door.position = stage.reward_position + Vector2(0, -22)
