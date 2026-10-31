extends SceneTree
## Run from an empty directory with --main-pack <actual export.pck> --script
## <absolute path to this file>. No repository source fallback is permitted.
const SOURCE := "res://resources/enemies/legacy/plains_charger_v2.tres"
const EXPECTED := "1afd5e34d497e3850d794b028fd5fe5407d3722fcd451d862f4c14a67ca98fc0"
var assertions := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok:
		failures+=1
		printerr("RECORDED ENEMY PACK: "+label)
func run() -> void:
	check(not DirAccess.dir_exists_absolute("res://.git"),"probe has no repository checkout at its resource root")
	var bytes := FileAccess.get_file_as_bytes(SOURCE)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	check(not bytes.is_empty() and digest.finish().hex_encode()==EXPECTED,"actual PCK exposes exact retained source bytes to FileAccess")
	var remap := ConfigFile.new()
	check(remap.load(SOURCE+".remap")==OK,"normal Godot text-resource conversion remap is still present")
	var target: String=remap.get_value("remap","path","")
	check(not target.is_empty() and target.ends_with(".res") and FileAccess.file_exists(target),"actual converted binary target exists in PCK")
	var definition := ResourceLoader.load(SOURCE) as EnemyDefinition
	var converted := ResourceLoader.load(target) as EnemyDefinition if not target.is_empty() else null
	check(definition!=null and converted!=null,"normal ResourceLoader resolves both the source path and converted target")
	if definition!=null and converted!=null:
		check(definition.stable_id==&"plains_charger" and definition.definition_version==2 and definition.collision_size==Vector2(28,32) and definition.is_valid(),"remapped source retains complete original Definition identity and body")
		check(converted.stable_id==definition.stable_id and converted.definition_version==definition.definition_version and converted.collision_size==definition.collision_size,"retained bytes and converted ResourceLoader behavior agree")
	check(EnemyBehaviorRegistry.definition_path(&"charger",EXPECTED)==SOURCE,"actual revision resolver succeeds against PCK bytes")
	check(EnemyFactory.create_for_behavior(&"charger",{},"unknown")==null,"unknown PCK revision still cannot fall back")
	var world := Node2D.new()
	root.add_child(world)
	for revision: String in [EXPECTED,""]:
		var motor := EnemyFactory.create_for_behavior(&"charger",{},revision)
		check(motor!=null,"PCK factory resolves explicit historical/current selection")
		if motor==null: continue
		world.add_child(motor)
		var actual := (motor.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
		check(actual!=null and actual.size==(Vector2(28,32) if revision==EXPECTED else Vector2(28,28)),"actual exported actor collision follows its selected resource revision")
	world.free()
	print("RECORDED ENEMY PACK TESTS: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures==0 else 1)
