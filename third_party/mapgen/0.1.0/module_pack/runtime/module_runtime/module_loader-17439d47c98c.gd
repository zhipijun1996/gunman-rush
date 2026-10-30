extends Node2D
## Instantiate fixed compiled data. No player, search, resource reset or route solver.
const CELLS=preload("plains_cells-d3785510bb80.gd")
const REWARDS=preload("local_rewards-f35c3226b1f0.gd")
const PAIRS=preload("runtime_v3-998af01cc01d.gd")
var content: Dictionary={}
var module: PlatformingModule
var cells
var rewards
var pairs
var scope
var setup_error:=""
var bound:=false
var _owned_scope:=false
var instance_key:=""

class GameScope extends RefCounted:
	var frame:=0
	var module: PlatformingModule
	var policy: FrameDamagePolicy
	var lifetime: DemoLifetime

func _ready() -> void:
	process_physics_priority=1100
	add_to_group(&"foundation_module_packages")
	var folder:=scene_file_path.get_base_dir()
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("godot-package.json")))
	if not manifest is Dictionary or FileAccess.get_sha256(folder.path_join("compiled-content.json"))!=manifest.get("artifacts",{}).get("compiled-content.json","") or FileAccess.get_sha256(folder.path_join("module.mapnote.json"))!=manifest.get("source",{}).get("module_sha256",""):
		setup_error="stale_or_changed_package";push_error(setup_error);return
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("compiled-content.json")))
	if not raw is Dictionary or raw.get("schema","")!="pcg/compiled-module-content/v1":
		setup_error="invalid_compiled_content";push_error(setup_error);return
	content=raw
	var definition:=PlatformingModuleDefinition.new();definition.module_id=StringName(content.stable_id)
	definition.world_bounds=Rect2(content.world_bounds[0],content.world_bounds[1],content.world_bounds[2],content.world_bounds[3])
	for value: Array in content.platforms:definition.platforms.append(Rect2(value[0],value[1],value[2],value[3]))
	for index: Variant in content.one_way_platform_indices:definition.one_way_platform_indices.append(int(index))
	definition.entry_port=PlatformingModulePort.new();definition.entry_port.port_id=&"entry"
	definition.entry_port.position=Vector2(content.entry_port[0],content.entry_port[1])
	definition.exit_port=PlatformingModulePort.new();definition.exit_port.port_id=&"exit"
	definition.exit_port.position=Vector2(content.exit_port[0],content.exit_port[1])
	definition.anchors.append(definition.entry_port.position);definition.anchors.append(definition.exit_port.position)
	if not definition.is_valid():setup_error="invalid_original_definition";push_error(setup_error);return
	module=PlatformingModule.new();module.name="Content";module.definition=definition;module.authoring_debug=false;add_child(module)
	for index: Variant in content.wall_platform_indices:module.get_node("Platform"+str(int(index))).add_to_group(&"wall_climbable")

func bind_player(player: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, wallet: RunWallet, existing_scope=null, instance_id: String="") -> Dictionary:
	if bound:return {"ok":false,"reason":"already_bound"}
	if not setup_error.is_empty() or not is_instance_valid(module):return {"ok":false,"reason":setup_error}
	if not is_instance_valid(player) or policy==null or lifetime==null or wallet==null:return {"ok":false,"reason":"explicit_game_services_required"}
	# The authored package is translated, never scaled/rotated/mirrored implicitly.
	if not global_transform.x.is_equal_approx(Vector2.RIGHT) or not global_transform.y.is_equal_approx(Vector2.DOWN):return {"ok":false,"reason":"uncertified_transform"}
	if existing_scope!=null:
		if existing_scope.module!=module:return {"ok":false,"reason":"scope_module_mismatch"}
		scope=existing_scope
	else:
		scope=GameScope.new();scope.module=module;scope.policy=policy;scope.lifetime=lifetime;_owned_scope=true
	instance_key=instance_id if not instance_id.is_empty() else str(get_path())
	for other: Node in get_tree().get_nodes_in_group(&"foundation_module_packages"):
		if other!=self and other.bound and other.instance_key==instance_key:return {"ok":false,"reason":"duplicate_instance_identity"}
	var ordinary: Dictionary=PAIRS.ordinary_case(content)
	cells=CELLS.new();cells.owner_runner=self;add_child(cells);cells.setup(ordinary,self,player,scope)
	rewards=REWARDS.new();rewards.owner_runner=self;rewards.content_host=self;rewards.instance_key=instance_key;rewards.wallet=wallet;add_child(rewards);rewards.setup(ordinary,self,player,scope,cells)
	pairs=PAIRS.new();add_child(pairs);pairs.setup(content,self,player,scope,cells)
	bound=setup_error.is_empty()
	return {"ok":bound,"reason":setup_error,"terrain_count":content.platforms.size(),"latches":cells.latches.size(),"reward_sites":content.reward_sites.size(),"player_spawned":false,"resources_reset":false}

func _physics_process(_delta: float) -> void:
	if bound and _owned_scope:
		scope.frame=Engine.get_physics_frames()
		rewards.capture()

func capture() -> void:
	if bound:rewards.capture()

func snapshot() -> Dictionary:
	if not bound:return {"bound":false,"error":setup_error}
	return {"bound":true,"plains":cells.snapshot(),"workshop":rewards.snapshot(),"paired_gates":pairs.snapshot()}

func world_port(port_id: String) -> Dictionary:
	for port: Dictionary in content.get("ports",[]):
		if str(port.id)==port_id:
			var at: Variant=port.get("position",{})
			var point:=Vector2(float(at.x),float(at.y)) if at is Dictionary else Vector2(at[0],at[1])
			return {"ok":true,"position":to_global(point),"definition":port.duplicate(true)}
	return {"ok":false,"reason":"unknown_port"}

func _exit_tree() -> void:
	if bound:
		for latch: ShotLatch in cells.latches:
			if is_instance_valid(latch):latch.cancel()
