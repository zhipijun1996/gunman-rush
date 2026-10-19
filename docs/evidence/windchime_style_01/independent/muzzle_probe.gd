extends SceneTree
func _init() -> void: _run.call_deferred()
func _run() -> void:
 var lab := preload("res://scenes/demo/windchime_lab.tscn").instantiate() as WindchimeLab
 root.add_child(lab)
 for i: int in 30: await physics_frame
 var visual := lab.player.get_node("CourierVisual") as CourierVisual
 for aim: Vector2 in [Vector2.RIGHT, Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,-1).normalized()]:
  var visible_muzzle := lab.player.global_position + Vector2(3 if aim.x>=0 else -3,-1) + aim*23
  var physical_muzzle := visual.muzzle_position(aim)
  print("MUZZLE aim=",aim," visible=",visible_muzzle-lab.player.global_position," shared=",physical_muzzle-lab.player.global_position," delta=",physical_muzzle.distance_to(visible_muzzle))
 lab.queue_free()
 for i: int in 10: await process_frame
 print("MUZZLE_REVIEW completed")
 quit()
