extends SceneTree
## Explicit native fixtures; recording uses actual Router/projectile hits separately.
var assertions:=0
var failures:Array[String]=[]
var samples:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 assertions+=1
 if not ok:failures.append(label);printerr("FAIL: "+label)
func frames(count:int)->void:
 for _i:int in count:await physics_frame
func run()->void:
 var motion:Dictionary=await load("res://tests/plains_motion_loot_02_motion.gd").run(self)
 assertions+=int(motion.assertions);failures.append_array(motion.failures);samples.append(motion)
 var loot:Dictionary=await load("res://tests/plains_motion_loot_02_loot.gd").run(self)
 assertions+=int(loot.assertions);failures.append_array(loot.failures);samples.append(loot)
 var audio:Dictionary=await load("res://tests/plains_motion_loot_02_audio.gd").run(self)
 assertions+=int(audio.assertions);failures.append_array(audio.failures);samples.append(audio)
 var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
 await frames(3)
 check(app.start_plains("plains-motion-loot-02"),"actual formal plains accepts normal start")
 await frames(8)
 var inventory:Array=[]
 if app.stage is GeneratedDemoStage:
  var stage:=app.stage as GeneratedDemoStage
  for i:int in stage.enemies.size():
   var actor:=stage.enemies[i].get_node("Actor") as EnemyActor
   inventory.append({"id":stage.enemy_manifest[i].id,"behavior":String(actor.definition.behavior_id),"position":[stage.enemies[i].position.x,stage.enemies[i].position.y],"drop":stage.generated.manifest.enemy_drops.get(stage.enemy_manifest[i].id,{})})
 samples.append({"actual_app_inventory":inventory})
 var app_report:Dictionary=await load("res://tests/plains_motion_loot_02_app.gd").run(self,app)
 assertions+=int(app_report.assertions);failures.append_array(app_report.failures);samples.append(app_report)
 print("ACTUAL PLAINS LOOT INVENTORY count=%s"%inventory.size())
 if not await load("res://tests/audio_teardown.gd").drain_world(app):failures.append("App audio teardown")
 app.free();await process_frame
 DirAccess.make_dir_recursive_absolute("res://build/plains_motion_loot_02")
 var output:=FileAccess.open("res://build/plains_motion_loot_02/native.json",FileAccess.WRITE)
 output.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"samples":samples},"\t"));output.close()
 print("PLAINS MOTION LOOT02: %s assertions, %s failures"%[assertions,failures.size()]);quit(0 if failures.is_empty() else 1)
