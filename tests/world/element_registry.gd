extends SceneTree
var failures:=0
var checks:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("REGISTRY FAIL: "+label)
func run()->void:
	check(WorldRoomDocument.view({"schema":3}).has("error"),"malformed input rejected before access")
	check(WorldRoomDocument.view({"schema":2}).has("error"),"old runtime protocol rejected")
	var catalog:=WorldElementCatalog.catalog()
	for id:String in catalog.definitions:
		var definition:Dictionary=catalog.definitions[id]
		if not definition.get("placeable",false):continue
		var made:=WorldElementCatalog.instantiate_definition(id,"registry-test",Vector2(128,160))
		check(not made.has("error"),id+" factory")
		if made.has("error"):continue
		var document:Dictionary={"schema":3,"room_id":"T-TEST","root":{"definition_id":"room.standard","definition_version":1,"properties":{}},"entities":made.entities}
		var result:=WorldRoomDocument.instantiate(document)
		check(not result.has("error"),id+" fresh room: "+str(result.get("error","")))
		if result.has("room"):
			var packed:=PackedScene.new();packed.pack(result.room);result.room.free()
			var roundtrip:=WorldRoomDocument.extract(packed)
			var expected:=WorldRoomDocument.view(document)
			check(JSON.parse_string(JSON.stringify(expected))==JSON.parse_string(JSON.stringify(roundtrip)),id+" factory roundtrip")
	var doc:=WorldRoomDocument.read("res://config/world/rooms/P-R14.json")
	check(doc.root.definition_id=="room.standard" and not doc.root.properties.has("boss_binding"),"Boss is a registered host, not root authoring")
	var duplicate:=WorldElementCatalog.instantiate_definition("encounter.windkeeper","duplicate-boss",Vector2.ZERO)
	doc.entities.merge(duplicate.entities)
	check(WorldRoomDocument.instantiate(doc).has("error"),"duplicate service owners rejected")
	var polygon:=WorldElementCatalog.instantiate_definition("terrain.polygon","polygon",Vector2(128,160))
	check(polygon.entities.polygon.properties.points[0]==[128.0,160.0],"polygon factory translates actual vertices")
	print("ELEMENT REGISTRY RUNTIME: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
