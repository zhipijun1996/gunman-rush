extends Node2D
## Integer horizontal strips preserve the root while the upper 55% sways.

@export var amplitude := 2.0
@export var phase := 0.0
@export var sprite_height := 40
@export var world_anchor_x := 0.0
@export var top_y := 0.0

func _process(_delta: float) -> void:
	var study := get_tree().current_scene
	if study == null or study.get("data") == null or study.data.is_empty():
		return
	var tip_rows := maxi(1, int(floorf(sprite_height * 0.55)))
	var affected: bool = study.patch_intersects(world_anchor_x, top_y, top_y + tip_rows)
	var t: float = study.local_time(affected)
	var sway := sin(t * 1.55 - world_anchor_x * 0.012 + phase)
	for strip in get_children():
		var base: Vector2 = strip.get_meta("base_position")
		var weight := pow(clampf(1.0 - base.y / tip_rows, 0.0, 1.0), 2.0)
		# floor(v + .5) agrees with JavaScript Math.round for negative half values.
		var dx := floorf(sway * amplitude * weight + 0.5)
		strip.position = base + Vector2(dx, 0.0)
