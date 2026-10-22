extends SceneTree
## Frozen pre-optimization oracle. Exact ordered values, not area/hash-only checks.
const OLD := preload("res://tests/underworld_plains/terrain_borders_reference.gd")
var failures: Array[String] = []
var assertions := 0
var worlds := false
var output := "res://build/underworld_plains/border-equivalence.json"
var rows: Array[Dictionary] = []
func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg == "--world": worlds = true
  elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
 run.call_deferred()
func check(value: bool,label: String) -> void:
 assertions += 1
 if not value and failures.size()<20: failures.append(label)
func compare(label: String,solids: Array[Rect2]) -> void:
 var unique: Dictionary = {}
 var old_us := 0
 var new_us := 0
 for index: int in solids.size():
  var rect := solids[index]
  var started := Time.get_ticks_usec()
  var expected: Dictionary = OLD.plan(rect,solids)
  old_us += Time.get_ticks_usec()-started
  started = Time.get_ticks_usec()
  var actual := PlainsTerrainBorders.plan(rect,solids)
  new_us += Time.get_ticks_usec()-started
  check(var_to_bytes(expected)==var_to_bytes(actual),label+"/ordered_plan/"+str(index))
  if not rect.has_area(): continue
  for face: Dictionary in expected.faces:
   var a: Vector2 = face.start
   var b: Vector2 = face.finish
   if face.side in ["bottom","left"]:
    var swap := a
    a=b
    b=swap
   unique[Vector4(a.x,a.y,b.x,b.y)]=true
 var edges := PlainsTileComposer.merge_edges(PackedVector4Array(unique.keys()))
 var expected_geometry := {"edges":edges,"pieces":PlainsTileComposer.pieces_from_edges(edges)}
 var actual_geometry := PixelFormalTerrain.geometry_plan(solids)
 check(var_to_bytes(expected_geometry)==var_to_bytes(actual_geometry),label+"/ordered_final_geometry")
 rows.append({"case":label,"solids":solids.size(),"old_plan_us":old_us,"new_plan_us":new_us,"edges":edges.size(),"pieces":expected_geometry.pieces.size()})
func run() -> void:
 var cases: Array[Array] = [
  [Rect2(0,0,32,32),Rect2(32,0,32,32)],
  [Rect2(-32,-32,32,32),Rect2(0,0,32,32)],
  [Rect2(0,0,32,32),Rect2(32.0001,0,32,32)],
  [Rect2(0,0,32,32),Rect2(32,15,0.0001,1)],
  [Rect2(0,0,128,128),Rect2(16,16,32,32),Rect2(0,0,128,128)],
  [Rect2(0,0,40,60),Rect2(999,11,40,12)],
  [Rect2(0,0,32,0),Rect2(32,0,16,32)],
  [Rect2(0,0,-32,32),Rect2(-32,0,32,32)],
  [Rect2(-0.125,0.375,32.25,32.5),Rect2(32.125,0.375,16.125,32.5)],
  [Rect2(0,0,48,16),Rect2(0,16,16,48),Rect2(32,16,16,48)]
 ]
 for index: int in cases.size():
  var solids: Array[Rect2]=[]
  solids.assign(cases[index])
  compare("edge_case_"+str(index),solids)
  solids.reverse()
  compare("reversed_"+str(index),solids)
 var rng := RandomNumberGenerator.new()
 rng.seed=918477
 for index: int in 40:
  var solids: Array[Rect2]=[]
  for unused: int in 8:
   solids.append(Rect2(float(rng.randi_range(-80,80))/8.0,float(rng.randi_range(-80,80))/8.0,float(rng.randi_range(1,60))/8.0,float(rng.randi_range(1,60))/8.0))
  solids.append(solids[0])
  compare("random_"+str(index),solids)
 if worlds:
  for map_index: int in [1,2]:
   var seed_value := "plains-ef9b74c58ef7a04256941ca06caddbe1" if map_index==1 else "forest-places-01"
   var result := ThornForestRegionGenerator.new().generate_version(ThornForestRegionGenerator.DEPTH_VERSION,ThornForestRegionGenerator.seed_for(seed_value,map_index),PlayerTuning.load_default(),map_index,{"forest_layout_version":"forest-exploration-places-v18","grapple":true,"abilities":["grapple"]})
   check(result.get("ok",false),"actual_world_generation_"+str(map_index)+"/"+str(result.get("error","")))
   if not result.get("ok",false): continue
   var solids: Array[Rect2]=[]
   for row: Dictionary in result.manifest.platforms:
    if not bool(row.one_way):solids.append(ThornForestRegionGenerator._rect(row.rect))
   compare("actual_forest_map_"+str(map_index),solids)
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var report := {"scope":"exact ordered plan faces/corners and final edges/pieces against frozen pre-optimization oracle; not ART/FUN", "assertions":assertions,"failures":failures,"worlds":worlds,"rows":rows}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("TERRAIN BORDER EQUIVALENCE: ",assertions," assertions / ",failures.size()," failures / world=",worlds)
 quit(0 if failures.is_empty() else 1)
