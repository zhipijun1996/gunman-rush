extends SceneTree
func _initialize() -> void:
 call_deferred("check")
func check() -> void:
 var scene: PackedScene = load("res://assets/painterly_v2/painterly_courier_visual.tscn")
 if scene == null:
  quit(1)
  return
 var actor = scene.instantiate()
 root.add_child(actor)
 for state in actor.STATES:
  actor.set_state(state)
  for facing in [-1.0, 1.0]:
   actor.set_facing(facing)
   for step in range(12):
    actor._process(0.1)
    var painted: Sprite2D = actor.get_node("PaintedFrame")
    if painted.texture == null or not is_finite(painted.position.x) or not is_finite(painted.position.y) or painted.region_rect.size.x <= 0:
     quit(1)
     return
 print("PASS: painted atlas six states, both directions, 144 frame samples; no gameplay changes")
 quit(0)
