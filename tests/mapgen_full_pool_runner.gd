extends SceneTree
const PRELOAD_JOB=preload("res://addons/mapgen/preload_job.gd")
const PREPARED=preload("res://addons/mapgen/prepared_library.gd")
const TRANSFORM=preload("res://addons/mapgen/content_transform.gd")
const GEO=preload("res://addons/mapgen/geometry.gd")
var checks:=0
var failures:=0
var bindings_tested:=0
var results:Array=[]
var active_world:Node2D
class FixtureStage extends PlainsRegionStage:
 func _ready():pass
 func _process(_delta):pass
 func _physics_process(_delta):pass
 func _exit_tree():pass
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func frames(n:int):
 for i:int in n:await physics_frame
func _initialize():run.call_deferred()
func run():
 DirAccess.make_dir_recursive_absolute("res://build/mapgen_full_pool")
 var profile=RuntimeMapGenerationProfile.read_profile()
 var job=PRELOAD_JOB.create(profile.lock.module_package.path,profile.lock.module_package.sha256)
 while not job.is_done():job.advance(128);await process_frame
 var req=profile.request.duplicate(true);req.player.abilities=["jump","double_jump","shot_recoil","grapple","wall_climb"];req.module_filter={"regions":["平原"],"include_ids":[],"exclude_ids":[]}
 var prepared=PREPARED.new();prepared.begin(job.result().library,req,profile.config)
 var observations:Array=[]
 var published:bool=preload("res://game/world/generation/mapgen/runtime_map_verified_library_cache.gd").publish(profile.lock,job)
 check(published,"original SDK-verified immutable library published")
 for entry: Dictionary in prepared.entries.values():
  var template:Dictionary=prepared.adapt(entry.id,entry,{})
  for mirror:bool in [false,true]:
   var content:Dictionary=RuntimeMapV2Provider._copy_memory_keys(TRANSFORM.materialize(template,mirror,128))
   var instance:Dictionary={"id":"fixture","module_id":entry.id,"content_version":entry.contentVersion,"role":"traversal","origin_blocks":[0,0],"size_blocks":entry.sizeBlocks,"ports":[],"connected_port_ids":[],"seals":[],"transform":{"mirror_x":mirror,"content_is_materialized":true}}
   for port: Dictionary in GEO.placed_ports(template,0,0,mirror,true).values():instance.ports.append({"id":port.id,"face":port.face,"surface":port.surface,"permission":port.permission,"local_position_pixels":[port.local2[0]*64,port.local2[1]*64]})
   var error:=RuntimeMapContentAdapter.validation_error(content)
   if error.is_empty():error=RuntimeMapV2Provider._content_error(RuntimeMapContentAdapter.geometry_view(content),instance)
   var definition:PlatformingModuleDefinition
   if error.is_empty():
    definition=RuntimeMapV2Provider._definition(RuntimeMapContentAdapter.geometry_content(content),instance);RuntimeMapContentAdapter.configure_definition(definition,content)
    var request:=LevelRequest.new();request.tuning=PlayerTuning.load_default();request.capabilities={"collision_half_extents":[12,18]}
    var resolved:=RuntimeMapPortAdmission.resolve_complete(definition,content,instance,{},[],request,Vector2.INF)
    if not resolved.ok:error=resolved.error
    elif not definition.is_valid():error="native definition invalid"
   var ports:Dictionary={}
   if error.is_empty():
    for port:Dictionary in instance.ports:
     var bank:=RuntimeMapPortAdmission._bank(definition,content,port,Vector2(12,18),true)
     if not bank.ok:ports[str(port.id)]=bank.error
   check(error.is_empty(),entry.id+" native geometry and content admission: "+error)
   check(ports.is_empty(),entry.id+" actual Port staging: "+str(ports))
   if error.is_empty() and include_binding(content):await binding_case(definition,content,instance,mirror)
   observations.append({"id":entry.id,"mirror":mirror,"error":error,"ports":ports})
   if not error.is_empty() or not ports.is_empty():print("CATALOG ",entry.id," mirror=",mirror," error=",error," ports=",ports)
 var file:=FileAccess.open("res://build/mapgen_full_pool/"+get_script().resource_path.get_file().get_basename()+"_catalog.json",FileAccess.WRITE);file.store_string(JSON.stringify(observations,"\t"));file.close()
 print("FULL POOL CATALOG ",observations.size()," bindings=",bindings_tested)
 var cache=preload("res://game/world/generation/mapgen/runtime_map_verified_library_cache.gd")
 var ids:Array=prepared.entries.keys()
 var base:Dictionary=cache.capacity_filter(profile.lock,ids,1,1)
 var extended:Dictionary=cache.capacity_filter(profile.lock,ids,2,2)
 check(base.excluded.size()==2 and extended.ids.size()==106,"real action capacity screens original two-shot qualification without shrinking the supported library")
 var report:=FileAccess.open("res://build/mapgen_full_pool/"+get_script().resource_path.get_file().get_basename()+"_bindings.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"checks":checks,"failures":failures,"bindings":bindings_tested,"cases":results,"scope":"all 106 original modules, both SDK mirrors, native component binding and state reconstruction; fixture placement, not solver output or full-route certification"},"\t"));report.close()
 print("MAPGEN FULL POOL: ",checks," assertions, ",failures," failures")
 quit(1 if failures else 0)

func binding_case(definition:PlatformingModuleDefinition,content:Dictionary,instance:Dictionary,mirror:bool):
 var world:=Node2D.new();root.add_child(world);active_world=world
 var lifetime:=DemoLifetime.new()
 var player:PlayerMotor=preload("res://game/player/player.tscn").instantiate();player.position=initial_spawn(definition,content,instance);world.add_child(player)
 player.get_node("KeyboardMouseAdapter").process_mode=Node.PROCESS_MODE_DISABLED
 var controller:=player.get_node("Controller") as PlayerController
 var policy:=FrameDamagePolicy.new();policy.lifetime=lifetime;world.add_child(policy);policy.register_target(&"player",controller.actor_resources.health,true);policy.register_player_controller(controller)
 var stage:=FixtureStage.new();world.add_child(stage)
 var state:=PlainsRegionState.new();stage.region_state=state;stage.bound_policy=policy;stage.bind_player(controller)
 var plan:=LevelPlan.new();plan.region_id=&"plains";plan.source_id=&"real_module_binding_fixture";plan.map_hash=JSON.stringify(content,"",true,true).sha256_text();plan.spawn=definition.entry_port.position;plan.bounds=definition.world_bounds;plan.set_meta("runtime_map_complete",true)
 var placement:=LevelModulePlacement.new();placement.instance_id="fixture";placement.template_id=definition.module_id;placement.definition=definition;plan.modules.append(placement)
 RuntimeMapContentAdapter.append_objects(plan,content,instance,Vector2.ZERO)
 stage.level_plan=plan;stage.pickups.assign(LevelRuntime.restore_pickups(plan.pickups,state.claimed));state.bind_map(plan.map_hash)
 var assembled:=LevelRuntime.assemble(stage,plan,state)
 check(assembled.ok,str(instance.module_id)+" native runtime assembly")
 if not assembled.ok:world.free();active_world=null;return
 var assembler:PlainsRegionAssembler=assembled.assembler;stage.assembler=assembler
 for index:int in content.get("wall_platform_indices",[]):
  check(assembler.modules[0].get_node("Platform%s" % index).is_in_group("wall_climbable"),"actual source wall uses existing traversal collision group")
 for row:Dictionary in plan.actors:
  var enemy:=LevelRuntime.create_actor(row);stage.add_child(enemy);stage.enemies.append(enemy);stage.enemy_manifest.append(row.duplicate(true))
 var encounter:=RuntimeMapShotLatchEncounter.new();stage.add_child(encounter)
 var ok:=encounter.setup(plan,assembler,controller,lifetime,state)
 check(ok,str(instance.module_id)+" full behavior binding: "+encounter.error)
 if ok:
  await frames(2)
  await exercise(stage,encounter,controller,lifetime,policy,content,instance)
  encounter.capture_state()
  var before:=state.snapshot()
  check(RuntimeMapShotLatchEncounter.validation_error(plan,state).is_empty(),str(instance.module_id)+" saved phases validate")
  for row:Dictionary in encounter._runtime_modules:
   check(RuntimeMapContentAdapter.runtime_state_error(content,state.mechanisms.get("fixture/runtime",{})).is_empty(),"source-bound runtime phases")
  encounter.cancel();encounter.free()
  var restored:=PlainsRegionState.new();check(restored.restore(before,plan.map_hash),"detached native state JSON-shaped snapshot restores")
  var replacement:=RuntimeMapShotLatchEncounter.new();stage.add_child(replacement)
  check(replacement.setup(plan,assembler,controller,lifetime,restored),str(instance.module_id)+" behavior restores before new inputs: "+replacement.error)
  for index:int in replacement.latches.size():
   var saved:Dictionary=restored.mechanisms[replacement.state_keys[index]]
   check(replacement.latches[index].region_snapshot()==saved,str(instance.module_id)+" exact latch transaction and motion phase reconstructed")
  check(player.get_instance_id()==controller.motor.get_instance_id() and player.tuning.max_jumps==1 and player.tuning.max_air_shots==1,"binding preserves actual player and basic action capacity")
  replacement.cancel()
  bindings_tested+=1
 results.append({"id":instance.module_id,"mirror":mirror,"bound":ok,"error":encounter.error if is_instance_valid(encounter) else ""})
 await preload("res://tests/audio_teardown.gd").drain_world(world)
 world.free();active_world=null;await frames(1)

func include_binding(_content:Dictionary)->bool:return true
func initial_spawn(definition:PlatformingModuleDefinition,_content:Dictionary,_instance:Dictionary)->Vector2:return definition.entry_port.position
func exercise(_stage:PlainsRegionStage,_encounter:RuntimeMapShotLatchEncounter,_controller:PlayerController,_lifetime:DemoLifetime,_policy:FrameDamagePolicy,_content:Dictionary,_instance:Dictionary):pass
