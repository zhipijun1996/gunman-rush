extends SceneTree
var checks := 0
var failures := 0
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures += 1; printerr("FAIL "+message)
func _init() -> void: run.call_deferred()
func run() -> void:
 for map_index: int in [1,2]:
  var generator := PlainsRegionGenerator.new()
  generator.root_bell_mode = "v3"
  var result := generator.generate("pixel-formal-actors",PlayerTuning.load_default(),false,"","intro" if map_index==1 else "advanced")
  expect(result.ok,"formal generation")
  var stage := PlainsRegionStage.new()
  stage.map_index = map_index
  stage.configure(map_index,&"boss",[])
  stage.configure_generated(result,PlayerTuning.load_default())
  root.add_child(stage)
  await process_frame
  stage.process_mode = Node.PROCESS_MODE_DISABLED
  var manifest_before := JSON.stringify(stage.generated.manifest)
  var snapshots: Array = []
  for motor: EnemyMotor in stage.enemies:
   var actor := motor.get_node("Actor") as EnemyActor
   snapshots.append([motor.get_instance_id(),actor.get_instance_id(),actor.health.get_instance_id(),actor.definition.get_instance_id(),motor.collision_layer,motor.collision_mask,(motor.get_node("CollisionShape2D") as CollisionShape2D).shape.get_instance_id()])
  var first := PixelFormalActors.install(stage)
  var second := PixelFormalActors.install(stage)
  expect(second.enemies==0,"installation idempotent")
  expect(stage.visual_layer.pixel_style,"actual formal pickup layer opted in")
  var boss := stage.boss.get_node("Presentation")
  expect(boss.pixel_style,"actual formal boss opted in")
  for index: int in stage.enemies.size():
   var motor := stage.enemies[index]
   var actor := motor.get_node("Actor") as EnemyActor
   expect(motor.get_node("Presentation") is PixelPlainsEnemy,"actual formal enemy skin")
   expect(snapshots[index]==[motor.get_instance_id(),actor.get_instance_id(),actor.health.get_instance_id(),actor.definition.get_instance_id(),motor.collision_layer,motor.collision_mask,(motor.get_node("CollisionShape2D") as CollisionShape2D).shape.get_instance_id()],"identity health definition collision unchanged")
  expect(JSON.stringify(stage.generated.manifest)==manifest_before,"manifest unchanged")
  for kind: StringName in [&"coin",&"heart",&"note",&"door",&"chest",&"merchant"]:
   var texture := PixelFormalActors.icon_texture(kind)
   expect(texture.get_width()>0 and texture.get_height()>0,"icon present "+str(kind))
   expect(texture==PixelFormalActors.icon_texture(kind),"icon cached "+str(kind))
  stage.queue_free()
  for i: int in 8: await process_frame
 print("PIXEL_FORMAL_ACTORS checks=%d failures=%d"%[checks,failures])
 quit(0 if failures==0 else 1)
