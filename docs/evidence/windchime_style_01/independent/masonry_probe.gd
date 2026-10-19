extends SceneTree
var checks := 0
var failures: Array[String] = []
func _init() -> void: _run.call_deferred()
func expect(ok: bool,label: String) -> void:
 checks += 1
 if not ok: failures.append(label); printerr("FAIL ",label)
func _run() -> void:
 var cases: Array[Dictionary] = [WindchimeLayout.build_map().cells, WindchimeLayout.material_map().cells]
 var negative: Dictionary = {}
 for y: int in range(-4,4):
  for x: int in range(-7,3):
   if not (x>-5 and x<0 and y>-3 and y<2): negative[Vector2i(x,y)]=&"windchime_stone"
 cases.append(negative)
 for cells: Dictionary in cases:
  var immutable := cells.duplicate(true)
  var a := WindchimeMasonry.new()
  a.configure(cells)
  expect(cells==immutable,"masonry does not alter actual occupancy")
  expect(not a.patches.is_empty() and not a.grain.is_empty(),"actual patch and grain consumers populated")
  for item: Dictionary in a.patches:
   var centroid := Vector2.ZERO
   for point: Vector2 in item.points: centroid += point
   centroid /= item.points.size()
   var cell := Vector2i(floori(centroid.x / Blob47Rules.CELL),floori(centroid.y / Blob47Rules.CELL))
   expect(cells.has(cell),"clipped stone patch never fills a collision hole")
   if cells.has(cell):
    var clip: Rect2 = a._interior(cell,cells).grow(.0001)
    for point: Vector2 in item.points: expect(clip.has_point(point),"patch vertices remain within occupied interior guard")
  for point: Vector3 in a.grain:
   var start := Vector2(point.x,point.y)
   var cell := Vector2i(floori(start.x / Blob47Rules.CELL),floori(start.y / Blob47Rules.CELL))
   expect(cells.has(cell),"grain begins on actual stone")
   if cells.has(cell): expect(a._interior(cell,cells).grow(.0001).has_point(start+Vector2(1+point.z*.4,.4)),"grain stays inside surface boundary")
  var b := WindchimeMasonry.new()
  b.configure(cells)
  expect(a.patches==b.patches and a.grain==b.grain,"cosmetic details reproducible")
  a.free();b.free()
 print("WINDCHIME_MASONRY_REVIEW checks=%d failures=%d" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
