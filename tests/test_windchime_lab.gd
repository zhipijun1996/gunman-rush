extends SceneTree
var checks := 0
var failures: Array[String] = []
func _init() -> void: _run.call_deferred()
func expect(value: bool, message: String) -> void:
 checks += 1
 if not value: failures.append(message); printerr("FAIL: "+message)
func _run() -> void:
 var lab := preload("res://experiments/terrain/entries/windchime_lab.tscn").instantiate() as WindchimeLab
 root.add_child(lab)
 for i: int in 60: await physics_frame
 expect(lab.player.is_on_floor(),"actual actor supported at entry")
 expect(lab._enemy_motors.size()==2,"real enemy consumers installed")
 expect(lab.policy._targets.size()==3,"player and both damageable targets registered")
 expect(lab.terrain.get_used_cells().size()==lab.layout.cells.size(),"rendered occupancy matches collision source")
 var source := lab.terrain.tile_set.get_source(0) as TileSetAtlasSource
 expect(source.get_tiles_count()==141,"real new atlas has all masks and variants")
 expect(source.texture==WindchimeTerrain.ATLAS,"new texture consumed by actual layer")
 var before := lab.layout.duplicate(true)
 var decor := lab.decoration.placements.duplicate(true)
 var keepouts: Array[Rect2] = []
 keepouts.assign(lab.layout.keepouts)
 keepouts.append(Rect2(lab.layout.spawn-Vector2(40,50),Vector2(80,90)))
 lab.decoration.configure(lab.layout.cells,keepouts,lab.seed_text)
 expect(decor==lab.decoration.placements,"decoration coordinate deterministic")
 expect(before==lab.layout,"cosmetics do not mutate gameplay map")
 expect(not decor.is_empty(),"actual map contains new prop family")
 for item: Dictionary in decor:
  for box: Rect2 in keepouts:
   expect(not box.grow(10).intersects(item.bounds),"full prop bounds avoid gameplay keepouts")
 lab._toggle_catalog()
 expect(paused and lab._catalog.visible,"catalog pauses real actors")
 lab.restart()
 expect(not paused and not lab._catalog.visible,"restart dismisses catalog and resumes")
 lab._toggle_catalog()
 lab._toggle_material_map()
 expect(not paused and not lab._catalog.visible,"material switch dismisses catalog")
 for i: int in 30: await physics_frame
 expect(lab.player.is_on_floor(),"material map spawn supported")
 expect(lab._enemy_motors.is_empty(),"sample enemies not carried into material map")
 expect(lab.policy._targets.size()==1,"no stale freed actor registry on switch")
 lab._toggle_material_map()
 for i: int in 30: await physics_frame
 expect(lab._enemy_motors.size()==2 and lab.policy._targets.size()==3,"re-enter builds fresh actual enemies")
 var enemy := lab._enemy_motors[0].get_node("Actor") as EnemyActor
 expect(enemy.damageable.damage_sink.is_valid(),"existing projectile damage sink bound")
 lab._toggle_pause()
 expect(paused,"manual pause")
 lab.restart()
 expect(not paused,"restart resumes manual pause")
 lab.queue_free()
 for i: int in 10: await process_frame
 expect(not paused,"free leaves global pause clear")
 print("WINDCHIME_LAB checks=%d failures=%d" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
