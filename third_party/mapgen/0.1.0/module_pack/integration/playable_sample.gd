extends Node2D
## Example host: creates its player once, then gives that existing actor to the package.
const REGISTRY=preload("module_registry.gd")
const CAPABILITIES=preload("player_capabilities.gd")
const PLAYER=preload("res://scenes/player/player.tscn")
const PROFILE=preload("../runtime/module_runtime/native_profile_v5-eeef5b9dc854.gd")
var registry=REGISTRY.new()
var player: PlayerController
var motor: PlayerMotor
var policy: FrameDamagePolicy
var lifetime:=DemoLifetime.new()
var wallet:=RunWallet.new()
var instance: Node2D
var ticks:=0
var verify_sample:=false
var ready_ok:=false
var jumps:=0
var shots:=0
var label: Label

func _ready() -> void:
 var folder:=scene_file_path.get_base_dir().get_base_dir()
 var opened: Dictionary=registry.open(folder)
 if not opened.ok:push_error(str(opened));get_tree().quit(2);return
 var args:=OS.get_cmdline_user_args();var chosen: String=registry.catalog.modules[0].id
 for i: int in args.size():
  if args[i]=="--module" and i+1<args.size():chosen=args[i+1]
  if args[i]=="--verify-sample":verify_sample=true
 var entry: Dictionary={}
 for candidate: Dictionary in registry.catalog.modules:
  if candidate.id==chosen:entry=candidate;break
 if entry.is_empty():push_error("unknown_sample_module");get_tree().quit(2);return
 var route: Dictionary=entry.routes[0];var spawn: Array=route.get("initialConditions",{}).get("spawn",entry.ports[0].get("stagingPosition",entry.ports[0].position))
 var offset: Array=entry.sceneOriginOffsetPixels
 motor=PLAYER.instantiate();motor.position=Vector2(spawn[0]+offset[0],spawn[1]+offset[1]);add_child(motor)
 player=motor.get_node("Controller");player.enable_shot_energy()
 player.jump_ability.jumped.connect(func():jumps+=1)
 player.shoot_ability.shot_fired.connect(func(_direction: Vector2,_id: int):shots+=1)
 var config: Dictionary=entry.initialConfiguration
 if config.nativeFixture is Dictionary:
  var initialized: Dictionary=PROFILE.new().initialize_once(player,config.nativeTuning,config.nativeFixture)
  if not initialized.ok:push_error(str(initialized));get_tree().quit(2);return
 elif config.nativeTuning is Dictionary:
  if not FoundryCatalog.apply_profile(player,str(config.nativeTuning.id)):get_tree().quit(2);return
 var applied: Dictionary=CAPABILITIES.apply(player,route.validation.availableAbilities)
 if not applied.ok:push_error(str(applied));get_tree().quit(2);return
 policy=FrameDamagePolicy.new();policy.lifetime=lifetime;add_child(policy);policy.register_player_controller(player);policy.register_target(&"player",player.actor_resources.health,true)
 var services:={"policy":policy,"lifetime":lifetime,"wallet":wallet,"meta":MetaProgression.new(),"region_state":PlainsRegionState.new()}
 var bound: Dictionary=registry.instantiate_module(chosen,"sample/map-node-0",Vector2i.ZERO,self,player,services)
 if not bound.ok:push_error(str(bound));get_tree().quit(2);return
 instance=bound.instance
 var camera:=Camera2D.new();motor.add_child(camera);camera.make_current()
 var hud:=CanvasLayer.new();add_child(hud);label=Label.new();label.position=Vector2(16,12);hud.add_child(label)
 label.text="A/D move | Space jump | release mouse to shoot | E interact | R restart\n"+str(entry.title)
 ready_ok=true

func _physics_process(_delta: float) -> void:
 if not ready_ok:return
 ticks+=1
 if verify_sample:
  if ticks==3:key(KEY_D,true)
  if ticks==8:key(KEY_SPACE,true)
  if ticks==12:key(KEY_SPACE,false)
  if ticks==15:mouse(true)
  if ticks==18:mouse(false)
  if ticks==25:key(KEY_D,false)
 if verify_sample and ticks>=30:
  var good: bool=is_instance_valid(instance) and instance.bound and is_instance_valid(player) and player.actor_resources.health.current>0 and jumps>0 and shots>0
  print("MODULE_PLAYABLE_SAMPLE ",JSON.stringify({"passed":good,"ticks":ticks,"bound_external_player":instance.rewards.actor==player,"hp":player.actor_resources.health.current,"grounded":motor.is_on_floor(),"actual_jumps":jumps,"actual_shots":shots,"human_playtest":false}));get_tree().quit(0 if good else 4)

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo:return
 if event.physical_keycode==KEY_R:get_tree().reload_current_scene()
 if event.physical_keycode==KEY_E and is_instance_valid(instance):
  if instance.has_method("request_native_region_interaction") and not instance.content.get("original_region_chests",[]).is_empty():instance.request_native_region_interaction()
  elif instance.has_method("request_native_pickup_interaction"):instance.request_native_pickup_interaction()

func key(code: Key,pressed: bool) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func mouse(pressed: bool) -> void:
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=Vector2(650,200);event.global_position=event.position;Input.parse_input_event(event)
