extends SceneTree
const GOLDEN = preload("res://tests/plains_redesign_golden_runner.gd")
var outcomes: Array = []
var errors: Array = []
func _initialize() -> void: run.call_deferred()
func observe(ok: bool, message: String) -> void:
 if not ok: errors.append(message)
func run() -> void:
 for mode: String in ["no_bell_collision", "remote_gate_stays_solid"]:
  var trace = GOLDEN.RecordedTrace.new()
  trace.tree=self;trace.check=observe
  await trace.install("main" if mode=="no_bell_collision" else "high",true,false,0.375)
  var module: PlatformingModule=trace.stage.modules[0 if mode=="no_bell_collision" else 1]
  var latch: ShotLatch=trace.shot_latch_encounter.for_module(module)
  if mode=="no_bell_collision":
   latch.bell_body.collision_layer=0
   var reached: bool=await trace.forward_module(module)
   outcomes.append({"mode":mode,"reached":reached,"ticks":trace.trace_ticks,"shots":trace.shots,"gate_open":latch.is_open,"gate_disabled":latch.gate_shape.disabled,"pass":not reached and not latch.is_open and not latch.gate_shape.disabled})
  else:
   # Reach the remote module by the same real initial step; no teleport.
   var step: PlatformingModule=trace.stage.modules[0]
   var step_ok: bool=await trace.traverse_phrase(step,true)
   step_ok=step_ok and await trace.settle()
   step_ok=step_ok and await trace.move_to(module.world_entry().x)
   latch.opened.connect(func():
    latch.gate_body.collision_layer=1
    latch.gate_shape.disabled=false)
   var reached: bool=await trace.traverse_phrase(module,true)
   outcomes.append({"mode":mode,"step_reached":step_ok,"reached":reached,"ticks":trace.trace_ticks,"shots":trace.shots,"gate_open":latch.is_open,"gate_disabled":latch.gate_shape.disabled,"position":[trace.motor.global_position.x,trace.motor.global_position.y],"pass":step_ok and not reached and latch.is_open and not latch.gate_shape.disabled})
  trace.world.free()
 var file:=FileAccess.open("res://build/plains_redesign/review_actions/physical_counterexamples.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"outcomes":outcomes,"observed_driver_failures":errors}));file.close()
 var passed: bool=outcomes.all(func(v: Dictionary):return v.pass)
 print("REVIEW PHYSICAL COUNTEREXAMPLES: ",passed," ",outcomes)
 quit(0 if passed else 1)
