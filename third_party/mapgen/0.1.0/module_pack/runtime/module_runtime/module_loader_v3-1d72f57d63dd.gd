extends Node2D
## Instantiate fixed compiled data. No player, search, resource reset or route solver.
const CELLS=preload("plains_cells-d3785510bb80.gd")
const REWARDS=preload("local_rewards-f35c3226b1f0.gd")
const PAIRS=preload("runtime_v3-998af01cc01d.gd")
const MOUNT=preload("mount_v1-8cd97b468685.gd")
const OCCUPANCY=preload("binding_v1-937afa378b6c.gd")
const DOCK=preload("dock_binding_v11-66a888cc03dd.gd")
const ATTACK_RELAY=preload("attack_relay_v1-6c856e958df9.gd")
var world: Node2D
var controller: PlayerController
var context
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
	var parsed_content: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("compiled-content.json")))
	if not parsed_content is Dictionary or parsed_content.get("schema","")!="pcg/compiled-module-content/v1":
		setup_error="invalid_compiled_content";push_error(setup_error);return
	content=parsed_content
	var definition:=PlatformingModuleDefinition.new();definition.module_id=StringName(content.stable_id)
	definition.world_bounds=Rect2(content.world_bounds[0],content.world_bounds[1],content.world_bounds[2],content.world_bounds[3])
	for value: Array in content.platforms:definition.platforms.append(Rect2(value[0],value[1],value[2],value[3]))
	for value: Array in content.hazards:definition.danger_bounds.append(Rect2(value[0],value[1],value[2],value[3]))
	for raw: Dictionary in content.moving_platforms:
		var value:=ModuleMovingPlatformDefinition.new()
		for key: String in ["platform_id","travel_duration","dwell_duration","initial_phase"]:
			if raw.has(key):value.set(key,raw[key])
		for key: String in ["start","finish","size"]:
			if raw.has(key):value.set(key,Vector2(raw[key][0],raw[key][1]))
		definition.ferries.append(value)
	for raw: Dictionary in content.saws:
		var value:=ModuleSawDefinition.new()
		for key: String in ["source_id","radius","period","initial_phase","damage","contact_interval"]:
			if raw.has(key):value.set(key,raw[key])
		for key: String in ["origin","travel"]:
			if raw.has(key):value.set(key,Vector2(raw[key][0],raw[key][1]))
		definition.saws.append(value)
	for raw: Dictionary in content.thorns:
		var value:=PlatformThornDefinition.new()
		for key: String in ["surface_id","platform_index","start_offset","length","depth"]:
			if raw.has(key):value.set(key,raw[key])
		var face: Variant=raw.get("face","top")
		value.face=["top","left","right","bottom"].find(face) if face is String else int(face)
		definition.surface_thorns.append(value)
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
	world=self;controller=player;context=scope
	module.setup_damage(player,policy,lifetime)
	for hazard: ModuleSawHazard in module.hazards:hazard.runtime_source_id=StringName("module/"+instance_key.uri_encode()+"/"+str(hazard.definition.source_id).uri_encode())
	for hook: Dictionary in content.hooks:
		var anchor:=GrappleAnchor.new();anchor.position=Vector2(hook.x,hook.y);anchor.hang_enabled=hook.get("kind","hang")=="hang"
		if hook.has("source_id"):anchor.name=str(hook.source_id)
		add_child(anchor)
	for record: Dictionary in module.world_static_hazard_records():
		var bounds: Rect2=record.rect
		var emitter:=DemoContactEmitter.new();emitter.controller=player;emitter.policy=policy;emitter.kind=DamageRequest.Kind.ENVIRONMENT
		emitter.source_id=StringName("module/"+instance_key.uri_encode()+"/"+str(record.authored_id).uri_encode());emitter.position=module.to_local(bounds.get_center());emitter.half_size=bounds.size/2.
		for raw: Dictionary in content.thorns:
			if raw.get("surface_id","")==record.authored_id:emitter.amount=float(raw.get("damage",emitter.amount));emitter.interval=float(raw.get("contact_interval",emitter.interval))
		module.add_child(emitter)
	var ordinary: Dictionary=PAIRS.ordinary_case(content)
	ordinary.latches=[]
	for spec: Dictionary in content.latches:
		if not spec.has("paired_gate") and not spec.has("sequence_offset") and not spec.has("occupancy") and not spec.has("carrier_dock") and not spec.has("attack_relay"):ordinary.latches.append(spec)
	cells=CELLS.new();cells.owner_runner=self;add_child(cells);cells.setup(ordinary,self,player,scope)
	rewards=REWARDS.new();rewards.owner_runner=self;rewards.content_host=self;rewards.instance_key=instance_key;rewards.wallet=wallet;add_child(rewards);rewards.setup(ordinary,self,player,scope,cells)
	pairs=PAIRS.new();add_child(pairs);pairs.setup(content,self,player,scope,cells)
	OCCUPANCY.install(self,content);DOCK.install(self,content)
	for spec: Dictionary in content.latches:
		if spec.has("sequence_offset"):
			var latch:=ShotLatch.new();latch.link_id=str(spec.id);latch.formal_presentation=true;latch.open_seconds=float(spec.get("open_seconds",0))
			latch.sequence_offset=Vector2(spec.sequence_offset[0],spec.sequence_offset[1])
			var gate: Array=spec.get("sequence_gate",[0,0,0,0]);latch.sequence_gate_rect=Rect2(gate[0],gate[1],gate[2],gate[3]);add_child(latch)
			latch.setup(player,lifetime,Vector2(spec.bell[0],spec.bell[1]),Rect2(spec.gate[0],spec.gate[1],spec.gate[2],spec.gate[3]))
			if spec.has("return_access"):latch.add_access_bell(Vector2(spec.return_access[0],spec.return_access[1]),false,true)
			latch.opened.connect(cells._bell_open.bind(latch,str(spec.id)));cells.latches.append(latch)
		if spec.has("attack_relay"):
			var actor: EnemyActor
			for i: int in cells.enemies.size():
				if str(content.enemies[i].id)==str(spec.attack_relay.enemy_id):actor=cells.enemies[i]
			if actor==null or actor.attack_behavior==null:setup_error="attack_relay_missing_native_enemy";return {"ok":false,"reason":setup_error}
			var latch=ATTACK_RELAY.new();latch.link_id=str(spec.id);latch.open_seconds=float(spec.get("open_seconds",0));add_child(latch)
			latch.setup(player,lifetime,Vector2(spec.bell[0],spec.bell[1]),Rect2(spec.gate[0],spec.gate[1],spec.gate[2],spec.gate[3]))
			latch.bind_enemy(actor,str(spec.attack_relay.enemy_id),cells);latch.opened.connect(cells._bell_open.bind(latch,str(spec.id)));cells.latches.append(latch)
	for spec: Dictionary in content.latches:
		for latch: ShotLatch in cells.latches:
			if str(latch.link_id)!=str(spec.id):continue
			if spec.has("link_color"):latch.link_color=Color(str(spec.link_color))
			if spec.has("prompt"):latch.prompt_text=str(spec.prompt)
	MOUNT.install(self,content)
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
