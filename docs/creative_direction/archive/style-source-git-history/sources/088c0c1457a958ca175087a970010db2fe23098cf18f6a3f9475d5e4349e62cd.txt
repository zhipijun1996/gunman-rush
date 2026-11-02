class_name DemoApp
extends Node2D

const EXIT_MODAL := preload("res://scripts/ui/stage_exit_modal.gd")
const PLAYER := preload("res://scenes/player/player.tscn")
const JUMP_ITEM := preload("res://resources/items/jump_blue.tres")
const SHOT_ITEM := preload("res://resources/items/shot_purple.tres")
const COIN_REWARD := preload("res://resources/rewards/demo_coins.tres")
const HEAL_REWARD := preload("res://resources/rewards/demo_heal.tres")
const DAMAGE_ITEM := preload("res://resources/items/damage_blue.tres")
const RECOIL_ITEM := preload("res://resources/items/recoil_purple.tres")
const HEALTH_ITEM := preload("res://resources/items/health_blue.tres")
const GOLD_ITEM := preload("res://resources/items/power_gold.tres")
const FOREST_GOLD_ITEM := preload("res://resources/items/forest_heart_gold.tres")
const MODULE_LAB := preload("res://scenes/demo/module_lab.tscn")
var meta_persistence_enabled := true
var generated_plains := false
var home_scene: HomeScene
var debug_hud := false
var _run_receipt_prefix := ""
var _meta_purchase_sequence := 0
var _run_camera: StageCameraRig
var _lab: ModuleLab
var _action_studio: ActionStudio
var _foundation_lab: Blob47Lab
var _windchime_lab: WindchimeLab
var _pixel_plains: PixelPlainsPreview
var _style_lab: Node
var _foundry: FoundryLab
var _preview: RandomStagePreview
var lifetime := DemoLifetime.new()
var director := DemoRunDirector.new(lifetime)
var meta := MetaProgression.new()
var build: BuildState
var wallet: RunWallet
var rewards: RewardService
var shop: ShopService
var player: PlayerMotor
var controller: PlayerController
var stage: DemoStage
var policy: FrameDamagePolicy
var segment: SegmentRespawn
var overlay: TouchOverlay
var current_reward: RewardOffer
var _completion_rule: StageCompletionRule
var _completion_target: HealthState
var _enemy_drops: EnemyDropService
var _gold_claimed := false
var _stage_pending := false
var _sequence := 0
var _input_revision := 0
var _queued_actions: Array[Dictionary] = []
var _hazard_contact: DemoContactEmitter
var _enemy_contacts: Array[DemoContactEmitter] = []
var _enemy_contact: DemoContactEmitter
var _boss_started := false
var _boss_intros_seen: Dictionary={}
var _reduced_effects := false
var _boss_was_in_core := false
var _boss_eligible_shots: Dictionary = {}
var _boss_contact: DemoContactEmitter
var _status := "Choose a route and put your recoil to work."
var _hud_frame: Panel
var _debug_button: Button
var _canvas: CanvasLayer
var menu: DemoMenu
var simple_reward: SimpleRoomReward
var catalog := DemoRewardCatalog.new()
var _session_input := InputProfile.load_default().values.duplicate(true)
var _title: Label
var _status_label: Label
var _hud: Label
var _hint: Label
var _resources_hud: ActorResourcesHud
var _region_ui_positions: Dictionary = {}
var _demo_hud: DemoGameHud
var _ui_run_report: Dictionary = {}
var _actions: HBoxContainer
var _pause_button: Button
var _boss_status: Label
var _windkeeper_hud: WindkeeperHud
var _music: GameMusic
var _shown_actions := ""
var exit_modal: EXIT_MODAL
var _offered_exit: StringName = &""
var _exit_prompt_token: DemoToken
var _dismissed_exits: Dictionary = {}
var reward_modal: StageRewardModal
var _pending_exit: StringName = &""
var _reward_token: DemoToken

func _ready() -> void:
	# Official Web templates forbid command-line scene overrides. Only an explicit
	# development launch redirects; bootstrap-owned Apps keep the real menu/loop.
	if "--cloud-preview" in OS.get_cmdline_user_args() and not has_meta("cloud_preview_host"):
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		get_tree().call_deferred("change_scene_to_file", "res://scenes/dev/cloud_preview.tscn")
		return
	plains_environment_candidate_requested = plains_environment_candidate_requested or "--plains-environment-candidate" in OS.get_cmdline_user_args()
	plains_places_candidate_requested = plains_places_candidate_requested or "--plains-places-candidate" in OS.get_cmdline_user_args()
	plains_joint_recoil_candidate_requested = plains_joint_recoil_candidate_requested or "--plains-joint-recoil-candidate" in OS.get_cmdline_user_args()
	if plains_joint_recoil_candidate_requested:
		plains_regional_art_candidate_requested = true
		meta_persistence_enabled = false
	if plains_places_candidate_requested: plains_environment_candidate_requested = true
	if plains_environment_candidate_requested: meta_persistence_enabled = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sound_effects := PlayerWeaponFeelAudioV2.new()
	add_child(sound_effects)
	_music = GameMusic.new()
	_music.volume_source = sound_effects
	add_child(_music)
	_music.request_track(&"home")
	process_physics_priority = 900
	lifetime.end() # TITLE/Home do not own an active Run token.
	var backdrop := UnderworldParallax.new()
	backdrop.name = "PixelPlainsParallax"
	add_child(backdrop)
	var legacy_backdrop := PlainsBackground.new()
	legacy_backdrop.name = "PlainsBackground"
	legacy_backdrop.hide()
	add_child(legacy_backdrop)
	director.stage_entered.connect(_stage_entered)
	director.run_ended.connect(_run_ended)
	if meta_persistence_enabled:
		meta.configure_persistence("user://plains_meta.json")
	_make_ui()
	var avatar_script := load("res://scripts/art/avatar_presentation.gd") as Script
	var avatar: Node=avatar_script.new()
	avatar.call("configure",self)
	set_meta("avatar_presentation",avatar)
	add_child(avatar)
	_refresh_home_meta()
	_hide_run_hud()
	menu.show_title()
	var style_lab_requested := "--style-lab" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		style_lab_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('styles')"))
	if style_lab_requested:
		_open_style_lab.call_deferred()
		return
	var foundation_requested := "--blob47" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		foundation_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('foundation')"))
	if foundation_requested: _open_foundation.call_deferred()
	var windchime_requested := "--windchime" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		windchime_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('windchime')"))
	if windchime_requested: _open_windchime.call_deferred()
	var pixel_requested := "--pixel-plains" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		pixel_requested=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('pixel_plains')"))
	if pixel_requested: _open_pixel_plains.call_deferred()
	var plains_requested := "--plains" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		plains_requested=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('plains')"))
	if plains_requested: start_plains.call_deferred("level-design-v2-baseline/08")
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('pixel_inspect')")):
		var inspector := PixelFormalInspector.new()
		inspector.app = self
		inspector.second_map = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('pixel_inspect') === '2'"))
		add_child(inspector)

var active_region_id: StringName = &"plains"
var campaign := RunCampaignProgression.new()
var progression_modal: RegionProgressionModal
var _progression_token: DemoToken
var _debug_region: StringName = &""
var _debug_map := 1
var connected_region := false
# Explicit pilot request is read only at run start; saved map hashes can replay v10.
var root_bell_space_pilot_requested := false
var root_bell_pilot_requested := false
# Explicit local spatial experiment; ordinary generation and saves stay separate.
var visual_language_open_meadow_requested := false # Explicit A/E matching geometry, independent of visual treatment.
var visual_language_sample_path := "" # Explicit candidate only; ordinary consumers load no candidate assets.
var avatar_selection_id := "courier" # Session appearance, never a save/stat/ability field.
var p1_random_plains_requested := false # Ordinary generated map presentation only; no golden geometry.
var plains_environment_candidate_requested := false
var plains_places_candidate_requested := false
var plains_regional_art_candidate_requested := false
var plains_joint_recoil_candidate_requested := false
var plains_environment_variant := "A"
var plains_environment_mutation := ""
var spatial_golden_requested := false
var spatial_golden_mutation := ""
var _root_bell_run_mode := "legacy_v10"
var forest_content_version := ThornForestRegionGenerator.VERSION
var _forest_layout_version := ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT
var _forest_v9_north_return := true
var _requested_forest_version := ""
var _requested_forest_layout := ""
var region_state: PlainsRegionState
var region_states: Dictionary = {}
var _region_loaded_map := 0
var map_modal: PlainsRegionMapModal
var _region_pending_claim := false
var _region_chest := -1
var _region_offer: RewardOffer
var _terrain_study_requested := false
var _region_offer_token: DemoToken
var shop_modal: ItemShopModal
var item_toast: ItemAcquiredToast
var _shop_offer: ShopOffer
var _shop_token: DemoToken

func _explicit_plains_candidate() -> bool:
	return spatial_golden_requested or plains_environment_candidate_requested or plains_regional_art_candidate_requested or bool(get_meta("plains_world_rebuild_candidate",false))

func start_plains(seed_value: String = "plains-run") -> bool:
	_debug_region = &""
	return start_demo(seed_value, true)

func start_debug_region(region: StringName, map_index: int, seed_value: String, content_version: String = "", layout_version: String = "") -> bool:
	if region not in [&"plains", &"thorn_forest"] or map_index not in [1,2]: return false
	if not content_version.is_empty() and (region != &"thorn_forest" or not ThornForestRegionGenerator.supported(content_version)): return false
	if not layout_version.is_empty() and (region != &"thorn_forest" or content_version != ThornForestRegionGenerator.DEPTH_VERSION or not ThornForestRegionGenerator.DEPTH_LAYOUT_SCRIPTS.has(layout_version)): return false
	# Rejected entries must not replace the next run's region/version request.
	if director.state != DemoRunDirector.State.HOME or seed_value.is_empty() or is_instance_valid(_lab) or is_instance_valid(_preview) or is_instance_valid(_foundry) or is_instance_valid(_style_lab): return false
	_debug_region = region
	_debug_map = map_index
	_requested_forest_version = content_version
	_requested_forest_layout = layout_version
	var accepted := start_demo(seed_value,true)
	if accepted: print("FOREST_UI_EVENT " + JSON.stringify({"event":"debug_entry","region":String(region),"map_index":map_index,"seed":seed_value,"natural_progression":false}))
	return accepted

func _region_seed() -> String:
	return director.seed + "/thorn_forest/map_%s" % director.region_map_index if active_region_id == &"thorn_forest" else PlainsRegionCampaign.seed_for(director.seed,director.region_map_index)

func _region_prefix() -> String:
	return "%s/map_%s/" % [active_region_id,director.region_map_index]

func _region_name() -> String:
	return "THORN FOREST" if active_region_id == &"thorn_forest" else "WINDCHIME PLAINS"

func _pixel_projectiles(_direction: Vector2, _shot_id: int) -> void:
	if not is_instance_valid(controller) or not _uses_pixel_plains_presentation(): return
	for projectile: PlayerProjectile in controller.shoot_ability.get_projectiles():
		if is_instance_valid(projectile.presentation):continue
		var visual := PixelPlainsProjectile.new()
		visual.projectile = projectile
		projectile.presentation = visual
		projectile.add_child(visual)

func start_demo(seed_value: String = "gunman-demo-1", region_map: bool = false) -> bool:
	if director.state != DemoRunDirector.State.HOME or seed_value.is_empty() or is_instance_valid(_lab) or is_instance_valid(_preview) or is_instance_valid(_foundry) or is_instance_valid(_style_lab):
		return false
	if _explicit_plains_candidate(): meta_persistence_enabled = false
	if plains_environment_candidate_requested or plains_regional_art_candidate_requested:
		region_map = true
		# A candidate property set after home startup must also isolate its Meta service.
		meta = MetaProgression.new()
	_remove_home_scene()
	active_region_id = _debug_region if region_map and not _debug_region.is_empty() else &"plains"
	forest_content_version = _requested_forest_version if not _requested_forest_version.is_empty() else ThornForestRegionGenerator.VERSION
	_forest_layout_version = _requested_forest_layout if not _requested_forest_layout.is_empty() else ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT
	_forest_v9_north_return = true
	_requested_forest_version = ""
	_requested_forest_layout = ""
	campaign = RunCampaignProgression.new()
	campaign.debug_entry = region_map and not _debug_region.is_empty()
	if active_region_id == &"thorn_forest": campaign.abilities.append(&"grapple")
	_progression_token = null
	_root_bell_run_mode = "v3" if root_bell_space_pilot_requested else "v2" if root_bell_pilot_requested else "v3" if PlainsRootBellEncounterV3.PRODUCTION_ADMITTED else "v2" if PlainsRootBellEncounterV2.PRODUCTION_ADMITTED else "legacy_v10"
	generated_plains = region_map
	connected_region = region_map
	region_state = PlainsRegionState.new() if connected_region else null
	region_states.clear()
	_region_loaded_map = 0
	_region_chest = -1
	_region_offer = null
	_boss_intros_seen.clear()
	_run_receipt_prefix = meta.new_run_receipt_prefix()
	director.biome_id = active_region_id if generated_plains else &"demo_ruins"
	get_tree().paused = false
	player = PLAYER.instantiate()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	controller.shoot_ability.shot_fired.connect(_pixel_projectiles)
	if connected_region and not controller.enable_shot_energy(): return false
	if active_region_id == &"thorn_forest": controller.traversal.grant(&"grapple")
	controller.interact_requested.connect(interact)
	controller.shoot_ability.shot_fired.connect(_record_boss_shot)
	controller.router.reconfigure(_session_input)
	(get_meta("avatar_presentation") as Node).call("bind_player",player)
	overlay = InputSetup.attach(player, controller.router)
	overlay.hide_reset_button = true
	overlay.pause_label = "MENU"
	overlay.pause_requested.connect(toggle_pause)
	overlay.reset_requested.connect(toggle_pause)
	var vignette := FocusVignette.new()
	vignette.name = "FocusVignette"
	vignette.ability = controller.air_focus_ability
	player.add_child(vignette)
	var aim_guide := DemoAimGuide.new()
	aim_guide.controller = controller
	player.add_child(aim_guide)
	if generated_plains:
		controller.actor_resources.health_definition = meta.fresh_health_definition(controller.actor_resources.health_definition)
		controller.actor_resources.health.configure(controller.actor_resources.health_definition)
	build = BuildState.new()
	build.configure(controller)
	catalog.configure(build, &"plains" if connected_region else director.biome_id)
	wallet = RunWallet.new()
	rewards = RewardService.new()
	rewards.configure(lifetime, build)
	shop = ShopService.new()
	shop.configure(lifetime, build, wallet)
	_resources_hud.bind(controller.actor_resources, controller.air_focus_ability, controller)
	_demo_hud.bind(controller)
	_resources_hud.set_region_compact(connected_region)
	_gold_claimed = false
	_sequence = 0
	_input_revision = 0
	menu.hide_home()
	_resources_hud.show()
	_hud_frame.show()
	_pause_button.show()
	return director.start(seed_value, RunProfile.formal() if connected_region else RunProfile.development()).accepted()

func _stage_entered(_result: DemoRunResult) -> void:
	if campaign.debug_entry and director.stage_index == 1:
		director.region_map_index = _debug_map
		director.manifest.enable_campaign()
		director.manifest.record_output(1,&"debug_entry",{"region":String(active_region_id),"map_index":_debug_map,"natural_progression":false})
	if is_instance_valid(shop_modal): shop_modal.close()
	if is_instance_valid(item_toast): item_toast.clear()
	if director.stage_index > 1: GameAudio.cue(self, &"door")
	_stage_pending = true
	controller.router.clear("stage_transition")
	controller.air_focus_ability.stop()
	call_deferred("_load_stage")

func _load_stage() -> void:
	if connected_region and stage is PlainsRegionStage:
		(stage as PlainsRegionStage).capture_state()
		lifetime.invalidate_actor()
	_cancel_enemy_attacks()
	_cancel_stage_shot_latches(true)
	if not lifetime.active:
		return
	if is_instance_valid(policy):
		remove_child(policy)
		policy.queue_free()
	segment = null
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	if connected_region and _region_loaded_map != director.stage_index:
		_region_loaded_map=director.stage_index
		region_state=region_states.get(_region_loaded_map,PlainsRegionState.new())
		region_states[_region_loaded_map]=region_state
		_region_chest=-1
		_region_offer=null
		_gold_claimed=false
	var loading_token := lifetime.token()
	if bool(get_meta("plains_world_rebuild_candidate",false)):
		# Explicit isolated new world contract. Keep actual Run/Player/Combat;
		# bypass only the old connected-region map, boss and shop consumers.
		connected_region = false
		var world_generator := load("res://scripts/generation/plains_world_rebuild.gd") as Script
		var world: Dictionary = world_generator.generate(director.seed,int(get_meta("plains_world_rebuild_variant",0)))
		var world_errors: Array = world_generator.validate(world)
		if not world_errors.is_empty():
			push_error("New plains world refused: " + str(world_errors))
			abandon_run()
			return
		var world_stage_script := load("res://scripts/demo/plains_world_rebuild_stage.gd") as Script
		stage = world_stage_script.new() as GeneratedDemoStage
		stage.call("configure_world",world,controller.motor.tuning)
	elif plains_regional_art_candidate_requested:
		var planner := load("res://scripts/generation/plains_region_art_plan.gd") as Script
		var actual_seed := PlainsRegionCampaign.seed_for(director.seed,director.stage_index)
		var candidate: Dictionary = planner.generate(actual_seed,controller.motor.tuning,"intro" if director.stage_index==1 else "advanced","",plains_joint_recoil_candidate_requested,str(get_meta("plains_art_language_candidate","")))
		if not candidate.get("ok",false):
			push_error(str(candidate.get("error","Regional art generation failed")))
			abandon_run()
			return
		stage = PlainsRegionStage.new()
		(stage as PlainsRegionStage).region_state = region_state
		(stage as PlainsRegionStage).map_index = director.stage_index
		(stage as GeneratedDemoStage).configure_generated(candidate,controller.motor.tuning)
	elif plains_environment_candidate_requested:
		var generator: Script = load("res://scripts/generation/plains_place_plan.gd") if plains_places_candidate_requested else load("res://scripts/generation/plains_environment_plan.gd")
		var candidate: Dictionary = generator.generate(director.seed,controller.motor.tuning,plains_environment_variant,plains_environment_mutation)
		if not candidate.ok:
			push_error(str(candidate.error))
			abandon_run()
			return
		stage = generator.create_stage()
		(stage as PlainsRegionStage).region_state = region_state
		(stage as PlainsRegionStage).map_index = director.stage_index
		(stage as GeneratedDemoStage).configure_generated(candidate,controller.motor.tuning)
	elif spatial_golden_requested:
		var golden := PlainsSpatialGolden.generate(director.seed,spatial_golden_mutation,visual_language_open_meadow_requested or not visual_language_sample_path.is_empty())
		if not golden.ok:
			push_error(str(golden.error))
			abandon_run()
			return
		stage = PlainsSpatialGolden.create_stage()
		if not visual_language_sample_path.is_empty():
			stage.set_meta("visual_language_sample_path",visual_language_sample_path)
		(stage as PlainsRegionStage).region_state = region_state
		(stage as PlainsRegionStage).map_index = director.stage_index
		(stage as GeneratedDemoStage).configure_generated(golden,controller.motor.tuning)
	elif generated_plains:
		var region_generator := PlainsRegionGenerator.new()
		region_generator.root_bell_mode = _root_bell_run_mode
		var actual_seed := _region_seed()
		var difficulty := "intro" if director.region_map_index==1 else "advanced"
		var forest_capability := {"grapple":controller.traversal.hook_enabled,"weapon_id":"pulse_gun","abilities":Array(campaign.abilities),"items":build.item_ids(),"forest_content_version":forest_content_version,"forest_layout_version":_forest_layout_version,"forest_v9_north_return":_forest_v9_north_return}
		var generated := ThornForestRegionGenerator.new().generate(actual_seed,controller.motor.tuning,director.region_map_index,forest_capability) if active_region_id == &"thorn_forest" else region_generator.generate(actual_seed, controller.motor.tuning,false,"",difficulty)
		# A pre-existing map owns its content version. Match the actual old hash;
		# never overwrite old actors/claims with a new layout or silently clear it.
		if active_region_id == &"thorn_forest" and region_state != null and not region_state.manifest_hash.is_empty() and generated.ok and region_state.manifest_hash != generated.manifest.manifest_hash:
			var recorded_version := ""
			for recorded: Dictionary in ThornForestRegionGenerator.recorded_variants():
				var prior_capability := forest_capability.duplicate(true)
				prior_capability.forest_layout_version = recorded.layout
				prior_capability.forest_v9_north_return = recorded.get("north_return",true)
				var prior := ThornForestRegionGenerator.new().generate_version(recorded.version,actual_seed,controller.motor.tuning,director.region_map_index,prior_capability)
				if prior.ok and prior.manifest.manifest_hash == region_state.manifest_hash:
					generated = prior
					recorded_version = recorded.version
					_forest_layout_version = str(prior.manifest.get("layout_version",ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT))
					_forest_v9_north_return = bool(prior_capability.forest_v9_north_return)
					forest_capability.forest_layout_version = _forest_layout_version
					forest_capability.forest_v9_north_return = _forest_v9_north_return
					break
			if recorded_version.is_empty():
				generated = {"ok":false,"error":"Recorded forest hash does not match a supported content version"}
			else:
				forest_content_version = recorded_version
				forest_capability.forest_content_version = recorded_version
		# Hash-bound replay of both prior admitted versions; no save rewrite.
		if active_region_id == &"plains" and region_state != null and not region_state.manifest_hash.is_empty() and generated.ok and region_state.manifest_hash != generated.manifest.manifest_hash:
			var matched_saved_map := false
			for prior_mode: String in [_root_bell_run_mode,"v2", "legacy_v10"]:
				region_generator.root_bell_mode = prior_mode
				for historical_focus: bool in [false,true]:
					var prior_generated := region_generator.generate_before_focus_15(actual_seed,controller.motor.tuning,false,"",difficulty) if historical_focus else region_generator.generate(actual_seed,controller.motor.tuning,false,"",difficulty)
					if prior_generated.ok and prior_generated.manifest.manifest_hash == region_state.manifest_hash:
						generated = prior_generated
						matched_saved_map = true
						break
				if matched_saved_map: break
			if not matched_saved_map:
				generated = {"ok":false,"error":"Recorded plains hash does not match a supported content/tuning version"}
		if not generated.ok:
			_status = "GENERATION FAILED / " + str(generated.error)
			abandon_run()
			return
		stage = ThornForestRegionStage.new() if active_region_id == &"thorn_forest" else PlainsRegionStage.new()
		if connected_region:
			(stage as PlainsRegionStage).region_state = region_state
			(stage as PlainsRegionStage).map_index=director.region_map_index
		(stage as GeneratedDemoStage).configure_generated(generated, controller.motor.tuning)
		if connected_region: print("PLAINS REGION: family=%s areas=%d fallback=%s" % [generated.manifest.family,generated.manifest.areas.size(),generated.manifest.fallback_id])
	else:
		stage = DemoStage.new()
	stage.configure(director.stage_index, director.stage_type_id, director.offers)
	_completion_rule = StageTypeDefinition.registry()[director.stage_type_id].rule(generated_plains or director.stage_type_id == &"combat")
	_completion_target = null
	_enemy_drops = EnemyDropService.new()
	if not _enemy_drops.configure(director.seed, "plains_region" if connected_region else "stage_%s" % director.stage_index):
		push_error("Invalid enemy drop configuration")
		abandon_run()
		return
	if director.stage_index == 1:
		if generated_plains:
			if connected_region:
				if active_region_id == &"thorn_forest": director.manifest.enable_campaign()
				elif (not _explicit_plains_candidate() or plains_regional_art_candidate_requested) and not director.manifest.enable_plains_region((stage as GeneratedDemoStage).generated.stage_generator_version):
					_status = "UNSUPPORTED REGION CONTENT VERSION"
					abandon_run()
					return
			else:
				director.manifest.enable_development_generation((stage as GeneratedDemoStage).generated.stage_generator_version)
		var initial_character := {"id": "prototype_player", "weapon": "release_shot", "max_jumps": controller.motor.tuning.max_jumps, "max_air_shots": controller.motor.tuning.max_air_shots, "input_values": _session_input.duplicate(true)}
		var config_hashes := {"physics": FileAccess.get_sha256("res://config/player_tuning.json"), "input": FileAccess.get_sha256("res://config/input_profile.json"), "health": FileAccess.get_sha256("res://resources/actors/prototype_health.tres")}
		config_hashes.enemy_drops = FileAccess.get_sha256(EnemyDropService.CONFIG_PATH)
		if generated_plains:
			var meta_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/meta_upgrades.json"))
			initial_character.current_health = controller.actor_resources.health.current
			initial_character.maximum_health = controller.actor_resources.health.capacity
			initial_character.permanent_upgrades = meta.snapshot().upgrades.duplicate(true)
			initial_character.meta_content_version = meta_config.version
			initial_character.meta_save_schema_version = MetaSaveService.SCHEMA_VERSION
			config_hashes.meta_upgrades = FileAccess.get_sha256("res://config/meta_upgrades.json")
		director.manifest.record_configuration([
			{"id": "plains_generated_layout" if generated_plains else "demo_fixed_layout", "version": 1},
			{"id": String(JUMP_ITEM.stable_id), "version": JUMP_ITEM.definition_version},
			{"id": String(SHOT_ITEM.stable_id), "version": SHOT_ITEM.definition_version},
			{"id": String(GOLD_ITEM.stable_id), "version": GOLD_ITEM.definition_version},
			{"id": String(FOREST_GOLD_ITEM.stable_id), "version": FOREST_GOLD_ITEM.definition_version},
			{"id": String(DAMAGE_ITEM.stable_id), "version": DAMAGE_ITEM.definition_version},
			{"id": String(RECOIL_ITEM.stable_id), "version": RECOIL_ITEM.definition_version},
			{"id": String(HEALTH_ITEM.stable_id), "version": HEALTH_ITEM.definition_version},
			{"id": String(COIN_REWARD.stable_id), "version": COIN_REWARD.definition_version},
			{"id": String(HEAL_REWARD.stable_id), "version": HEAL_REWARD.definition_version}],
			config_hashes, initial_character)
	add_child(stage)
	_sync_region_presentation()
	if stage is PlainsRegionStage and active_region_id == &"plains" and not _explicit_plains_candidate() and (p1_random_plains_requested or "--p1-random-plains" in OS.get_cmdline_user_args()):
		var p1_random := P1RandomPlainsSample.new()
		stage.add_child(p1_random)
		p1_random.install(stage as PlainsRegionStage)
	if _terrain_study_requested and active_region_id == &"plains" and stage is PlainsRegionStage:
		(stage as PlainsRegionStage).terrain_art.enable_comparison()
	if connected_region: (stage as PlainsRegionStage).map_view.open_requested.connect(open_region_map)
	if generated_plains:
		var random_stage := stage as GeneratedDemoStage
		if not random_stage.assembly_ok:
			abandon_run()
			return
		if not is_instance_valid(_run_camera):
			_run_camera = PlainsSpatialGolden.create_camera(random_stage.generated.golden_manifest.camera) if spatial_golden_requested else StageCameraRig.new()
			add_child(_run_camera)
		if connected_region: player.z_index = 5
		_run_camera.region_composition = connected_region and not _explicit_plains_candidate()
		if active_region_id == &"thorn_forest":
			# Keep short jumps inside a stable view; a continuous climb still follows.
			_run_camera.use_stable_forest_view()
		if plains_environment_candidate_requested:
			_run_camera.viewing_zoom = float(random_stage.generated.environment_plan.camera.zoom)
		if plains_regional_art_candidate_requested:
			_run_camera.viewing_zoom = 1.25
		if spatial_golden_requested:
			_run_camera.viewing_zoom = float(random_stage.generated.golden_manifest.camera.zoom)
			_run_camera.dead_zone.y = float(random_stage.generated.golden_manifest.camera.dead_zone_y)
			_run_camera.response_time.y = float(random_stage.generated.golden_manifest.camera.response_y)
		_run_camera.configure(player, random_stage.bounds)
	controller.return_to_segment(stage.spawn)
	if _uses_shared_region_pixel_presentation():
		var presentation:=load("res://scripts/underworld_plains/underworld_presentation.gd") as Script
		presentation.attach(stage,stage,player)
		if _uses_pixel_plains_presentation():
			(get_node("PixelPlainsParallax") as UnderworldParallax).configure(_run_camera,stage.bounds,(stage as PlainsRegionStage).generated.manifest)
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	add_child(policy)
	policy.register_target(&"player", controller.actor_resources.health, true)
	policy.register_player_controller(controller)
	policy.player_fatal.connect(_player_fatal)
	policy.environment_return_requested.connect(_environment_return)
	policy.batch_resolved.connect(_damage_resolved.bind(policy, lifetime.stage_epoch, lifetime.epoch))
	segment = SegmentRespawn.new()
	segment.configure(controller, lifetime)
	segment.add_anchor(&"entry", stage.spawn)
	segment.add_anchor(&"midpoint", stage.anchor_position)
	if generated_plains:
		var random_stage := stage as GeneratedDemoStage
		for index: int in random_stage.anchors.size():
			segment.add_anchor(StringName("generated_%s" % index), random_stage.anchors[index])
		segment.danger_bounds = random_stage.assembler.world_dangers()
		random_stage.assembler.setup_damage(controller, policy, lifetime)
		if not random_stage.setup_shot_latches(controller,lifetime):
			_status = "GENERATION FAILED / invalid windchime layout"
			abandon_run()
			return
		if connected_region:
			(random_stage.assembler as PlainsRegionAssembler).attack_shortcut_opened.connect(_record_attack_shortcut_opened.bind(lifetime.stage_epoch,lifetime.epoch))
		director.manifest.record_output(director.stage_index, &"shot_latch_layout", random_stage.generated.manifest.shot_latch_plan)
		var static_records: Array[Dictionary] = []
		if connected_region: static_records.assign(random_stage.assembler.world_static_hazard_records())
		var static_dangers := random_stage.assembler.world_static_dangers()
		for index: int in static_dangers.size():
			var danger: Rect2 = static_dangers[index]
			var emitter := _contact(stage, StringName("generated_spikes_%s" % index), DamageRequest.Kind.ENVIRONMENT, danger.size / 2)
			emitter.position = danger.get_center()
			if connected_region:
				var record: Dictionary = static_records[index]
				emitter.fall_plane = record.role == "fall_plane"
				emitter.set_meta("hazard_role",record.role)
				emitter.set_meta("hazard_module",record.module_id)
				emitter.set_meta("hazard_authored_id",record.authored_id)
	else:
		segment.danger_bounds = [Rect2(780, 530, 80, 110)]
	await get_tree().physics_frame
	if not lifetime.accepts(loading_token) or not is_instance_valid(stage):
		return
	if not segment.activate_anchor(&"entry"):
		_status = "CONTENT ERROR / unsafe generated or fixed entry"
		abandon_run()
		return
	_hazard_contact = null
	if not generated_plains:
		_hazard_contact = _contact(stage, &"saw", DamageRequest.Kind.ENVIRONMENT, Vector2(25, 25))
		_hazard_contact.position = stage.hazard_position
	_enemy_contact = null
	_boss_contact = null
	_boss_started = false
	_boss_was_in_core = false
	_boss_eligible_shots.clear()
	policy.protect_player()
	current_reward = null
	if connected_region and not region_state.boss_state.is_empty() and float(region_state.boss_state.health)<=0:
		director.stage_complete=false
	simple_reward = null
	_pending_exit = &""
	_reward_token = null
	_offered_exit = &""
	_exit_prompt_token = null
	_dismissed_exits.clear()
	_enemy_contacts.clear()
	if generated_plains:
		var encounter_stage := stage as GeneratedDemoStage
		for index: int in encounter_stage.enemies.size():
			var drone: EnemyMotor = encounter_stage.enemies[index]
			var actor := drone.get_node("Actor") as EnemyActor
			var id := StringName(encounter_stage.enemy_manifest[index].id)
			policy.bind_damageable(id, actor.damageable, actor.health)
			var protected_points: Array[Vector2] = encounter_stage.anchors.duplicate()
			protected_points.append(encounter_stage.spawn)
			protected_points.append_array(encounter_stage.exit_positions)
			actor.bind_encounter(controller, policy, lifetime, id, protected_points)
			var placement: Dictionary = encounter_stage.enemy_manifest[index]
			if actor.attack_behavior is ForestCrossbranchBehavior:
				var migration := actor.attack_behavior as ForestCrossbranchBehavior
				var shore_rows: Variant=placement.get("shore_rows")
				var valid_shores: bool=shore_rows is Array and shore_rows.size()==2
				var configured_shores: Array[Dictionary]=[]
				if valid_shores:
					for raw: Variant in shore_rows:
						if not raw is Dictionary or not raw.get("id") is String or not raw.get("rect") is Array or not raw.get("position") is Array:
							valid_shores=false;break
						if raw.rect.size()!=4 or raw.position.size()!=2:
							valid_shores=false;break
						for value: Variant in raw.rect+raw.position:
							if not (value is int or value is float) or not is_finite(float(value)):valid_shores=false
						if not valid_shores:break
						configured_shores.append({"id":raw.id,"rect":Rect2(raw.rect[0],raw.rect[1],raw.rect[2],raw.rect[3]),"position":Vector2(raw.position[0],raw.position[1])})
				var restoring: bool=connected_region and region_state.actors.has(String(id))
				if not valid_shores or not migration.configure_shores(configured_shores,not restoring):
					push_error("Recorded forest migration shores rejected")
					abandon_run()
					return
				if restoring and not region_state.actors[String(id)].has("depth_state"):
					push_error("Recorded forest migration state missing")
					abandon_run()
					return
			if actor.attack_behavior != null and actor.attack_behavior.has_method("configure_transfer_points"):
				var transfers: Array[Vector2] = []
				for point: Array in placement.get("transfer_points",[]): transfers.append(Vector2(point[0],point[1]))
				actor.attack_behavior.call("configure_transfer_points",transfers)
			if actor.attack_behavior is ForestBibleWeaverBehavior:
				if not (actor.attack_behavior as ForestBibleWeaverBehavior).configure_strands(placement.get("web_strands", [])):
					push_error("Recorded forest alternating web geometry rejected")
					abandon_run()
					return
				if connected_region and region_state.actors.has(String(id)) and not region_state.actors[String(id)].get("depth_state") is Dictionary:
					push_error("Recorded forest alternating web state missing")
					abandon_run()
					return
			elif actor.attack_behavior != null and actor.attack_behavior.has_method("configure_line"):
				var first: Array = placement.get("line_start",[])
				var last: Array = placement.get("line_end",[])
				if first.size()!=2 or last.size()!=2 or not actor.attack_behavior.call("configure_line",Vector2(first[0],first[1]),Vector2(last[0],last[1])):
					push_error("Recorded forest thread geometry rejected")
					abandon_run()
					return
			if connected_region and region_state.actors.has(String(id)) and actor.attack_behavior!=null:
				var saved: Dictionary=region_state.actors[String(id)]
				if not actor.attack_behavior is ForestCrossbranchBehavior:
					actor.attack_behavior.state=StringName(saved.get("state","idle"))
					actor.attack_behavior.state_time=float(saved.get("state_time",0.0))
					actor.attack_behavior.cooldown=float(saved.get("cooldown",0.0))
					actor.attack_behavior._serial=int(saved.get("serial",0))
					if saved.has("home"): actor.attack_behavior.home=Vector2(saved.home[0],saved.home[1])
					for field: String in ["locked_direction","attack_goal","attack_origin"]:
						if saved.has(field): actor.attack_behavior.set(field,Vector2(saved[field][0],saved[field][1]))
					actor.brain.direction=int(saved.get("direction",1))
				if saved.has("depth_state") and actor.attack_behavior.has_method("restore_depth_state"):
					if not actor.attack_behavior.call("restore_depth_state",saved.depth_state):
						push_error("Recorded forest actor state rejected")
						abandon_run()
						return
			if actor.attack_behavior: actor.attack_behavior.max_concurrent_attacks = (1 if director.region_map_index==1 else 2) if connected_region else (1 if director.stage_index<=3 else 2)
			_enemy_contacts.append(_contact(drone, StringName(str(id) + "_contact"), DamageRequest.Kind.MONSTER, actor.definition.collision_size / 2.0 + Vector2.ONE))
		if not encounter_stage.enemies.is_empty():
			_completion_target = (encounter_stage.enemies[0].get_node("Actor") as EnemyActor).health
		director.manifest.record_output(director.stage_index, &"enemy_layout", encounter_stage.encounter_plan)
	elif stage.enemy != null:
		var actor := stage.enemy.get_node("Actor") as EnemyActor
		_completion_target = actor.health
		policy.bind_damageable(&"drone", actor.damageable, actor.health)
		_enemy_contact = _contact(stage.enemy, &"drone_contact", DamageRequest.Kind.MONSTER, Vector2(14, 16))
	if stage.boss != null:
		var encounter := stage.boss.get_node("Encounter")
		_completion_target = encounter.health
		if generated_plains:
			(stage.boss.get_node("Damageable") as Damageable).damage_sink = func(_context: Dictionary) -> bool: return false
		else:
			policy.bind_damageable(&"boss", stage.boss.get_node("Damageable"), encounter.health)
		if generated_plains:
			var arena := (stage as GeneratedDemoStage).boss_arena
			encounter.configure_arena(arena.position.x + 25, arena.end.x - 25, player)
			if encounter.has_method("configure_forest_floor"): encounter.call("configure_forest_floor",arena.end.y)
			if encounter.has_method("bind_duel"):
				if not encounter.call("bind_duel",(stage as GeneratedDemoStage).generated.manifest.get("boss_geometry",{}),controller,policy,lifetime):
					push_error("Forest duel geometry or local damage targets rejected")
					abandon_run()
					return
			if connected_region and not (stage as PlainsRegionStage).restored_boss.is_empty():
				var saved: Dictionary=(stage as PlainsRegionStage).restored_boss
				if encounter.has_method("bind_duel"):
					if not _restore_forest_duel(encounter,saved):
						push_error("Recorded forest duel state rejected after physical target binding")
						abandon_run()
						return
				else: stage.boss.position=Vector2(saved.position[0],saved.position[1])
		else:
			encounter.configure_arena(890.0, 1240.0, player)
		if generated_plains and encounter is WindkeeperEncounter:
			for arena_module: PlatformingModule in (stage as GeneratedDemoStage).assembler.modules:
				if arena_module.definition.module_id == &"plains_boss_arena":
					var arena_consumer: WindkeeperArena = encounter.bind_stage_geometry(arena_module,controller,policy,lifetime,segment,(stage as GeneratedDemoStage).assembler.ground_supports)
					if connected_region and encounter.stage_phase==3: arena_consumer._phase_changed(3)
		if connected_region:
			var region:=stage as PlainsRegionStage
			region.boss_seal=BossArenaSeal.new()
			if region is ThornForestRegionStage and region.generated.manifest.get("layout_version")==ForestTargetHosts.LAYOUT:
				region.boss_seal.world_status_text_enabled=false
			region.add_child(region.boss_seal)
			region.boss_seal.setup(region.boss_arena,region.bounds,controller,encounter,lifetime)
			region.boss_seal.restore_closed(bool(region.restored_boss.get("seal_closed",false)))
			var boss_entry := (region as ThornForestRegionStage).forest_boss_entry_position() if region is ThornForestRegionStage else Vector2(region.boss_arena.position.x+70,region.boss_arena.end.y-18)
			segment.add_anchor(&"boss_enter",boss_entry)
			if region.boss_seal.closed:segment.activate_anchor(&"boss_enter")
		encounter.projectile_created.connect(_boss_projectile_created)
		if not generated_plains:
			encounter.activate()
		var boss_contact_half: Vector2 = Vector2(72,62).min(encounter.definition.collision_size/2) if encounter is WindkeeperEncounter else Vector2(25,27)
		if encounter.has_method("bind_duel"): boss_contact_half = encounter.definition.collision_size/2
		_boss_contact = _contact(stage.boss, &"boss_contact", DamageRequest.Kind.MONSTER,boss_contact_half)
		if encounter is WindkeeperEncounter:
			_boss_contact.contact_rect_provider = encounter.body_contact_rect
		_boss_contact.enabled = not generated_plains
	if director.stage_type_id == &"item_reward":
		var candidates: Array[ItemDefinition] = []
		if director.profile.development_only:
			candidates.assign([JUMP_ITEM, SHOT_ITEM])
		else:
			candidates = catalog.choose_candidates(director.seed, "stage_%s" % director.stage_index)
		current_reward = rewards.create_offer(_stage_id("items"), candidates, _stage_id("room_reward"))
		if current_reward == null:
			push_error("No two valid distinct item candidates: content pool error")
			abandon_run()
			return
		director.manifest.record_output(director.stage_index, &"reward_catalog", {"version": DemoRewardCatalog.CONTENT_VERSION if not director.profile.development_only else "quick_pair_v1", "pool": DemoRewardCatalog.PLAINS_CONTENT_VERSION if generated_plains else "default"})
	elif director.stage_type_id == &"shop":
		shop.add_offer(_stage_id("shop_jump"), DAMAGE_ITEM if generated_plains else JUMP_ITEM, 5, 1)
	var simple_definitions := {&"coin_reward": COIN_REWARD, &"health_reward": HEAL_REWARD}
	if simple_definitions.has(director.stage_type_id):
		simple_reward = SimpleRoomReward.new()
		simple_reward.configure(simple_definitions[director.stage_type_id], lifetime, controller.actor_resources.health, wallet)
		stage.reward_available = true
		director.manifest.record_output(director.stage_index, &"simple_reward", {"id": String(simple_definitions[director.stage_type_id].stable_id), "kind": simple_definitions[director.stage_type_id].kind, "amount": simple_definitions[director.stage_type_id].amount})
	if generated_plains:
		var random_stage := stage as GeneratedDemoStage
		var tuning_snapshot: Dictionary = {}
		var tuning_keys: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
		for key: String in tuning_keys:
			tuning_snapshot[key] = controller.motor.tuning.get(key)
		director.manifest.record_output(director.stage_index, &"stage_tuning", tuning_snapshot)
		director.manifest.record_output(director.stage_index, &"generated_layout", random_stage.generated.manifest)
		director.manifest.record_output(director.stage_index, &"pickups", random_stage.manifest_pickups())
		director.manifest.record_output(director.stage_index, &"stage_generator", {"version": random_stage.generated.stage_generator_version})
	else:
		director.manifest.record_output(director.stage_index, &"fixed_layout", {"version": 1, "layout_id": "demo_fixed_1", "spawn": [100, 580], "anchor": [660, 580], "hazard": "oscillating_saw_1", "enemy": "patrol_drone" if stage.enemy != null else "", "boss": "clockwork_guardian" if stage.boss != null else ""})
	director.manifest.record_output(director.stage_index, &"capability_snapshot", {"max_jumps": controller.motor.tuning.max_jumps, "max_air_shots": controller.motor.tuning.max_air_shots, "items": build.item_ids(), "abilities":Array(campaign.abilities)})
	if current_reward != null:
		_record_reward()
	if director.stage_type_id == &"shop":
		var initial_quote := shop.quote(_stage_id("shop_jump"))
		director.manifest.record_output(director.stage_index, &"shop_stock", {"offer": String(initial_quote.offer_id), "item": String(initial_quote.item.stable_id), "price": initial_quote.price, "stock": initial_quote.stock, "quote_version": initial_quote.quote_version})
	if connected_region and (not _explicit_plains_candidate() or plains_regional_art_candidate_requested):
		var stock: Dictionary=(stage as PlainsRegionStage).generated.manifest.shop
		shop.add_offer(_region_shop_id(),load("res://resources/items/%s.tres" % stock.item) as ItemDefinition,int(stock.price),int(stock.stock))
		director.manifest.record_output(director.stage_index,&"region_map",{"version":(stage as GeneratedDemoStage).generated.stage_generator_version if active_region_id == &"thorn_forest" else PlainsRegionCampaign.VERSION,"map_index":director.region_map_index,"seed":_region_seed(),"instance_prefix":_region_prefix(),"boss_role":PlainsRegionCampaign.role(director.region_map_index)})
	if connected_region and (not _explicit_plains_candidate() or plains_regional_art_candidate_requested):
		var boss_definition: BossDefinition=(stage.boss.get_node("Encounter") as BossEncounter).definition
		director.manifest.record_output(director.stage_index,&"boss_layout",{"id":String(boss_definition.stable_id),"version":boss_definition.definition_version,"health":boss_definition.health_definition.max_health})
	if not _bind_forest_discoveries():
		abandon_run()
		return
	_status = ("Explore forest branches / fixed rings stay after enemies die / gold flags lead to the guardian" if active_region_id == &"thorn_forest" else "Explore freely / gold flags lead to Windkeeper / no enemy-clear requirement") if connected_region else "Room %s: %s. Reach markers and use Interact." % [director.stage_index, director.stage_type_id]
	_shown_actions = ""
	_stage_pending = false
	if connected_region:
		# Report the actually assembled consumer after generation, binding and
		# restore have succeeded; an accepted menu request alone proves none of it.
		var actual_manifest: Dictionary=(stage as GeneratedDemoStage).generated.manifest
		var actual_boss: BossEncounter=stage.boss.get_node("Encounter") as BossEncounter
		print("FOREST_UI_EVENT " + JSON.stringify({"event":"region_assembled","region":String(active_region_id),"map_index":director.region_map_index,"seed":_region_seed(),"content_version":actual_manifest.version,"layout_version":actual_manifest.get("layout_version", ""),"manifest_hash":actual_manifest.manifest_hash,"boss_definition":actual_boss.definition.resource_path,"boss_scene":stage.boss.scene_file_path,"abilities":Array(campaign.abilities),"debug_entry":campaign.debug_entry}))

func _physics_process(_delta: float) -> void:
	if get_tree().paused or _stage_pending or not lifetime.active or not is_instance_valid(stage) or not is_instance_valid(controller):
		return
	if director.state != DemoRunDirector.State.IN_STAGE:
		return
	var position_now := player.global_position
	if is_instance_valid(segment) and position_now.distance_to(stage.anchor_position) < 50:
		segment.activate_anchor(&"midpoint")
	if generated_plains:
		var random_stage := stage as GeneratedDemoStage
		if DamageBoundary.should_return(player, random_stage.bounds):
			_submit_damage(&"bounds", DamageRequest.Kind.ENVIRONMENT, 1.0)
		if player.is_on_floor():
			for index: int in random_stage.anchors.size():
				if position_now.distance_to(random_stage.anchors[index]) < 38:
					segment.activate_anchor(StringName("generated_%s" % index))
		for index: int in random_stage.pickups.size():
			var pickup: Dictionary = random_stage.pickups[index]
			if not pickup.claimed and position_now.distance_to(pickup.position) < 46:
				_queue_action(_commit_pickup.bind(index))
	else:
		if position_now.y > 690 or position_now.y < -350:
			_submit_damage(&"bounds", DamageRequest.Kind.ENVIRONMENT, 1.0)
	if is_instance_valid(_hazard_contact):
		_hazard_contact.position = stage.hazard_position
	if is_instance_valid(_enemy_contact):
		_enemy_contact.enabled = not stage.enemy.get_node("Actor").health.terminal
	for contact: DemoContactEmitter in _enemy_contacts:
		if is_instance_valid(contact):
			contact.enabled = not (contact.get_parent().get_node("Actor") as EnemyActor).health.terminal
	if is_instance_valid(_boss_contact):
		if generated_plains:
			var in_core := _in_boss_core()
			if _boss_was_in_core and not in_core:
				_boss_eligible_shots.clear()
			_boss_was_in_core = in_core
			if not _boss_started and in_core and not controller.actor_resources.health.terminal:
				_start_generated_boss()
			var boss_state := stage.boss.get_node("Encounter") as BossEncounter
			if connected_region and _boss_started and in_core and (stage as PlainsRegionStage).boss_seal.arm():segment.activate_anchor(&"boss_enter")
			_boss_contact.enabled = _boss_started and in_core and bool(boss_state.call("body_contact_enabled"))
		else:
			_boss_contact.enabled = not stage.boss.get_node("Encounter").health.terminal

func _submit_damage(source: StringName, kind: DamageRequest.Kind, amount: float, event: StringName = &"", hit_direction: Vector2 = Vector2.ZERO) -> void:
	var request := DamageRequest.new()
	request.token = lifetime.token()
	request.event_id = _next_id(str(source)) if event.is_empty() else event
	request.source_id = source
	request.target_id = &"player"
	request.kind = kind
	request.amount = amount
	request.hit_direction = hit_direction
	request.health_epoch = controller.actor_resources.health.epoch
	request.actor_epoch = lifetime.actor_epoch
	policy.submit(request)

func _boss_projectile_created(projectile: Node) -> void:
	projectile.hit.connect(func(body: Node, event_id: StringName, amount: float) -> void:
		if body == player and lifetime.active and is_instance_valid(policy) and (not generated_plains or (_boss_started and _in_boss_core())):
			_submit_damage(&"boss_projectile", DamageRequest.Kind.MONSTER, amount, event_id, projectile.direction)
	)

func _damage_resolved(_results: Array[DamageResult], batch_policy: FrameDamagePolicy = null, batch_stage_epoch: int = -1, batch_run_epoch: int = -1) -> void:
	if not lifetime.active:
		_queued_actions.clear()
		return
	# Director advances synchronously; the old stage can emit an empty batch
	# before deferred loading, or while the next stage waits for its first frame.
	if _stage_pending or director.state != DemoRunDirector.State.IN_STAGE:
		return
	if batch_policy != null and (batch_policy != policy or batch_stage_epoch != lifetime.stage_epoch or batch_run_epoch != lifetime.epoch):
		return
	var was_complete := director.stage_complete
	var claimed := (current_reward != null and rewards.get_offer(current_reward.offer_id).claimed) or (simple_reward != null and simple_reward.claimed)
	var completed_now := _completion_rule.evaluate(player.global_position, _completion_target, claimed)
	if generated_plains:
		var random_stage := stage as GeneratedDemoStage
		# Ordinary rooms allow leaving living enemies behind; Boss remains terminal-only.
		match _completion_rule.goal:
			StageCompletionRule.Goal.REACH_FINISH:
				completed_now = random_stage.reached_finish(player.global_position)
			StageCompletionRule.Goal.CLAIM_AND_REACH:
				completed_now = random_stage.reached_finish(player.global_position)
			StageCompletionRule.Goal.CLAIM:
				completed_now = random_stage.reached_finish(player.global_position)
	if completed_now:
		_complete_room()
	if not was_complete and director.stage_complete:
		if stage.boss != null:
			if not connected_region or director.region_map_index==2:
				current_reward = rewards.create_gold_offer(_stage_id("gold"), FOREST_GOLD_ITEM if active_region_id == &"thorn_forest" else GOLD_ITEM, _stage_id("boss_defeat"))
			stage.reward_position = stage.boss.global_position
			var defeated_encounter := stage.boss.get_node("Encounter")
			if defeated_encounter.has_method("reward_stand_position"): stage.reward_position = defeated_encounter.call("reward_stand_position")
			stage.reward_available = true
			if connected_region:
				var region:=stage as PlainsRegionStage
				var animate:bool=not region.restored_boss.has("health") or float(region.restored_boss.health)>0
				region.reward_ready_at=region.clock+(.9 if animate else 0)
				region.boss_seal.release()
				if active_region_id == &"plains": (region.visual_layer as PlainsStageVisual).play_boss_defeat(stage.boss.global_position,director.region_map_index==1,animate)

			if current_reward!=null: _record_reward()
			if generated_plains:
				(stage as GeneratedDemoStage).show_boss_reward_portal()
			_status = "Boss defeated. Approach the GOLD gate and confirm to claim." if generated_plains else "Boss defeated. Claim the guaranteed GOLD item to finish."
			if connected_region and director.region_map_index==1: _status="MINI BOSS CLEAR / approach MAP 2 gate / build and coins carry over"
	# Fixed demo reward remains a defeat fixture, independent of the newly-open
	# door policy. Opening an ordinary room must not grant entry-time money.
	if not generated_plains and stage.enemy != null and (stage.enemy.get_node("Actor") as EnemyActor).health.terminal:
		wallet.grant(10, _stage_id("combat_coins"))
	_settle_enemy_drops()
	_flush_actions()
	# Contact is observed only after this frame's damage batch and queued intents.
	if generated_plains and _can_interact() and director.stage_complete and (not connected_region or stage.clock>=stage.reward_ready_at):
		var exit_index := stage.nearby_exit(player.global_position)
		if exit_index >= 0:
			_commit_exit(stage.exits[exit_index].exit_id)
		elif current_reward != null and current_reward.gold and player.global_position.distance_to(stage.reward_position) < 100:
			_offer_generated_exit(&"boss_home")
		elif connected_region and director.region_map_index==1 and stage.reward_available and player.global_position.distance_to(stage.reward_position)<100:
			_offer_generated_exit(&"boss_home")
		_rearm_exit_prompts()

func _settle_enemy_drops() -> void:
	if not _can_interact() or not stage is GeneratedDemoStage or _enemy_drops == null:
		return
	var random_stage := stage as GeneratedDemoStage
	for index: int in random_stage.enemies.size():
		var enemy_motor: EnemyMotor = random_stage.enemies[index]
		var actor := enemy_motor.get_node("Actor") as EnemyActor
		if not actor.health.terminal:
			continue
		var enemy_id := StringName(random_stage.enemy_manifest[index].id)
		if connected_region and region_state.drops.has(String(enemy_id)): continue
		var output: Dictionary = random_stage.generated.manifest.enemy_drops[String(enemy_id)].duplicate(true) if connected_region else _enemy_drops.settle(enemy_id)
		if output.is_empty():
			continue
		var location := random_stage.safe_drop_position(enemy_motor.global_position)
		output.position = [location.x, location.y]
		output.spawn_origin=[enemy_motor.global_position.x,enemy_motor.global_position.y]
		output.born_at=random_stage.clock
		if connected_region: region_state.drops[String(enemy_id)] = output.duplicate(true)
		if output.kind != "none":
			random_stage.pickups.append({"id": "drop_" + String(enemy_id), "kind": output.kind, "amount": output.amount, "position": location, "claimed": false, "source": String(enemy_id),"spawn_origin":enemy_motor.global_position,"born_at":random_stage.clock,"ready_at":random_stage.clock+.65})
		director.manifest.record_output(director.stage_index, StringName("enemy_drop_" + String(enemy_id)), output)
		random_stage.queue_redraw()

func _complete_room() -> void:
	if not director.stage_complete and director.complete_stage(lifetime.token()):
		stage.set_completed(true)
		_status = "Room complete. Choose an exit to continue."

func _environment_return() -> void:
	_cancel_enemy_attacks()
	_cancel_stage_shot_latches()
	_cancel_exit_ui("environment_return")
	if is_instance_valid(segment) and segment.return_to_anchor():
		policy.protect_player()
		_status = "Environment damage: returned to this segment; rewards and enemies persist."

func _player_fatal() -> void:
	_cancel_enemy_attacks()
	_cancel_stage_shot_latches(true)
	controller.die()
	director.end_failure(_next_id("death"))

func _commit_interact() -> void:
	if not _can_interact():
		return
	if connected_region:
		_region_interact()
		return
	if not generated_plains and simple_reward != null and not simple_reward.claimed and player.global_position.distance_to(stage.reward_position) < 130:
		_commit_room_reward()
		return
	if not generated_plains and not stage.supply_claimed and player.global_position.distance_to(stage.supply_position) < 80:
		var result := SupplyHealEffect.apply(controller.actor_resources.health, 2.0, _stage_id("supply"))
		if result.accepted():
			stage.mark_supply_used()
			_status = "Supply used once. +%.0f HP" % result.amount_applied
		return
	var index := stage.nearby_exit(player.global_position)
	if index >= 0:
		_commit_exit(stage.exits[index].exit_id)

func _commit_exit(id: StringName) -> bool:
	if not _can_interact():
		return false
	var index := stage.nearby_exit(player.global_position)
	if index < 0 or stage.exits[index].exit_id != id:
		return false
	if generated_plains:
		return _offer_generated_exit(id)
	return director.select_exit(lifetime.token(), id, _next_id("exit")).accepted()

func _commit_claim(option_id: StringName) -> bool:
	if generated_plains or not _can_interact() or current_reward == null or player.global_position.distance_to(stage.reward_position) > 130:
		return false
	var request := RewardClaimRequest.new()
	request.token = lifetime.token()
	request.offer_id = current_reward.offer_id
	request.option_id = option_id
	request.claim_id = _next_id("claim")
	var receipt := rewards.claim(request)
	if not receipt.accepted():
		return false
	GameAudio.cue(self, &"confirm")
	director.manifest.record_output(director.stage_index, &"reward_claim", {"offer": String(current_reward.offer_id), "item": String(receipt.item_id)})
	_status = "Acquired %s. Build modifiers are reversible." % option_id
	if current_reward.gold:
		_gold_claimed = true
		if director.profile.development_only:
			director.finish_success(lifetime.token(), _next_id("success"), _gold_claimed)
		else:
			director.finish_biome(lifetime.token(), _next_id("biome_complete"), _gold_claimed)
	_shown_actions = ""
	return true

func _commit_purchase() -> bool:
	if connected_region:
		return _region_purchase()
	if not _can_interact() or director.stage_type_id != &"shop" or player.global_position.distance_to(stage.reward_position) > 130:
		return false
	var quote := shop.quote(_stage_id("shop_jump"))
	var request := ShopPurchaseRequest.new()
	request.token = lifetime.token()
	request.shop_id = quote.shop_id
	request.offer_id = quote.offer_id
	request.quote_version = quote.quote_version
	request.transaction_id = _next_id("purchase")
	var receipt := shop.purchase(request)
	if receipt.accepted():
		director.manifest.record_output(director.stage_index, &"shop_purchase", {"offer": String(quote.offer_id), "item": String(receipt.item_id), "coins": receipt.coins})
	GameAudio.cue(self, &"confirm" if receipt.accepted() else &"denied")
	_status = "Purchased %s." % quote.item.display_name if receipt.accepted() else "Purchase unavailable (coins, stock or item limit)."
	_shown_actions = ""
	return receipt.accepted()

func _can_interact() -> bool:
	return lifetime.active and not _stage_pending and director.state == DemoRunDirector.State.IN_STAGE and is_instance_valid(stage) and is_instance_valid(controller) and not controller.actor_resources.health.terminal and not get_tree().paused

func open_region_map() -> bool:
	if not connected_region or not _can_interact() or map_modal.opened or reward_modal.opened or exit_modal.opened: return false
	_pause_for_menu()
	map_modal.show_map(stage as PlainsRegionStage)
	return true

func close_region_map() -> void:
	if not is_instance_valid(map_modal) or not map_modal.opened: return
	map_modal.close()
	get_viewport().gui_release_focus()
	if is_instance_valid(controller): controller.router.clear("map_close")
	_resume_exit_input()
	if director.state==DemoRunDirector.State.IN_STAGE: get_tree().paused=false

func toggle_pause() -> void:
	if is_instance_valid(progression_modal) and progression_modal.opened: return
	if _forest_reader_open(): return
	if is_instance_valid(shop_modal) and shop_modal.opened: return
	if is_instance_valid(map_modal) and map_modal.opened: return
	if director.state != DemoRunDirector.State.IN_STAGE or (is_instance_valid(reward_modal) and reward_modal.opened) or (is_instance_valid(exit_modal) and exit_modal.opened):
		return
	if get_tree().paused:
		menu.close_panel()
	else:
		var items: Array[ItemDefinition]=[]
		if build!=null: items=build.owned_items()
		menu.show_pause(_build_description(),items)

func _pause_for_menu() -> void:
	_cancel_stage_shot_latches()
	if is_instance_valid(controller):
		controller.router.clear("menu")
		controller.air_focus_ability.stop()
	_queued_actions.clear()
	# Pause freezes encounter state and live enemy projectiles; only player intents are cancelled.
	get_tree().paused = true
	_clear_actions()
	_shown_actions = ""

func _resume_from_menu() -> void:
	if director.state != DemoRunDirector.State.IN_STAGE or not is_instance_valid(controller):
		return
	controller.router.clear("menu_resume")
	get_viewport().gui_release_focus()
	get_tree().paused = false
	_shown_actions = ""

func apply_input_settings(patch: Dictionary) -> bool:
	var profile := InputProfile.load_default()
	if not profile.configure(_session_input) or not profile.configure(patch):
		return false
	if is_instance_valid(controller) and not controller.router.reconfigure(profile.values):
		return false
	_session_input = profile.values.duplicate(true)
	if director.state == DemoRunDirector.State.IN_STAGE and lifetime.active:
		_input_revision += 1
		director.manifest.record_output(director.stage_index, StringName("input_settings_%s" % _input_revision), {"values": _session_input.duplicate(true), "game_clock": policy.clock if is_instance_valid(policy) else 0.0})
	menu.set_input_values(_session_input)
	if is_instance_valid(home_scene):
		home_scene.controller.router.reconfigure(_session_input)
	if is_instance_valid(overlay):
		overlay.update_layout()
	return true

func _build_description() -> String:
	if build == null or not is_instance_valid(controller):
		return "No items yet."
	var items := build.item_ids()
	var names: PackedStringArray=[]
	for item: ItemDefinition in build.owned_items(): names.append(item.display_name)
	return "Items: %s\nJumps: %s  •  Air shots: %s\nShot damage: %.1f  •  Recoil burst: %.0f" % [", ".join(names) if not items.is_empty() else "None", controller.motor.tuning.max_jumps, controller.motor.tuning.max_air_shots, controller.motor.tuning.projectile_damage, controller.motor.tuning.shot_burst_speed]

func _input(event: InputEvent) -> void:
	# Presentation entry only; reuse the existing pause/cancellation boundary.
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START and menu.visible_panel.is_empty():
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if _forest_reader_open():
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			(stage as ThornForestRegionStage).discoveries.close()
			get_viewport().set_input_as_handled()
		# The reader owns its buttons, scrolling and navigation until it closes.
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if is_instance_valid(shop_modal) and shop_modal.opened:
			if event.physical_keycode==KEY_ESCAPE: _close_region_shop()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(map_modal) and map_modal.opened:
			if event.physical_keycode in [KEY_M,KEY_ESCAPE]: close_region_map()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode==KEY_M and connected_region:
			open_region_map()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		debug_hud = not debug_hud
	if director.state == DemoRunDirector.State.IN_STAGE and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and menu.visible_panel.is_empty():
		toggle_pause()
		get_viewport().set_input_as_handled()

func _open_module_lab() -> void:
	if director.state != DemoRunDirector.State.HOME or is_instance_valid(_lab) or is_instance_valid(_preview) or is_instance_valid(_foundry) or is_instance_valid(_style_lab):
		return
	_remove_home_scene()
	menu.hide_home()
	_lab = MODULE_LAB.instantiate() as ModuleLab
	_lab.configure(_session_input)
	_lab.home_requested.connect(_close_module_lab)
	_lab.terrain_region_requested.connect(_open_terrain_study)
	add_child(_lab)

func _open_terrain_study()->void:
	if is_instance_valid(_lab):_lab.leave_lab()
	_terrain_study_requested=true
	if not start_plains("terrain-art-study"):_terrain_study_requested=false

func _close_module_lab() -> void:
	if not is_instance_valid(_lab):
		return
	_session_input = _lab.input_values.duplicate(true)
	menu.set_input_values(_session_input)
	_lab.queue_free()
	_lab = null
	get_tree().paused = false
	_show_home()

func _open_foundry() -> void:
	if director.state != DemoRunDirector.State.HOME or is_instance_valid(_lab) or is_instance_valid(_preview) or is_instance_valid(_foundry) or is_instance_valid(_style_lab):
		return
	_remove_home_scene()
	menu.hide_home()
	_foundry = FoundryLab.new()
	_foundry.configure(_session_input)
	_foundry.home_requested.connect(_close_foundry)
	add_child(_foundry)

func _close_foundry() -> void:
	if not is_instance_valid(_foundry): return
	_session_input = _foundry.input_values.duplicate(true)
	_foundry.queue_free()
	_foundry = null
	get_tree().paused = false
	_show_home()

func _open_random_preview(seed_text: String) -> void:
	if director.state != DemoRunDirector.State.HOME or is_instance_valid(_lab) or is_instance_valid(_preview) or is_instance_valid(_foundry) or is_instance_valid(_style_lab):
		return
	_remove_home_scene()
	menu.hide_home()
	_preview = RandomStagePreview.new()
	_preview.configure(_session_input, seed_text)
	_preview.home_requested.connect(_close_random_preview)
	add_child(_preview)
	queue_redraw()

func _close_random_preview() -> void:
	if not is_instance_valid(_preview):
		return
	_session_input = _preview.input_values.duplicate(true)
	menu.set_input_values(_session_input)
	_preview.queue_free()
	_preview = null
	queue_redraw()
	get_tree().paused = false
	_show_home()

func abandon_run() -> void:
	if director.state == DemoRunDirector.State.IN_STAGE:
		controller.router.clear("abandon")
		controller.air_focus_ability.stop()
		get_tree().paused = false
		director.end_failure(_next_id("abandon"))

func _run_ended(result: DemoRunResult) -> void:
	if is_instance_valid(progression_modal): progression_modal.close()
	_progression_token = null
	_terrain_study_requested=false
	if is_instance_valid(shop_modal): shop_modal.close()
	if is_instance_valid(item_toast): item_toast.clear()
	if is_instance_valid(map_modal): map_modal.close()
	GameAudio.cue(self, &"victory" if result.reason in [&"biome_complete", &"success"] else &"death")
	_cancel_enemy_attacks()
	_cancel_stage_shot_latches(true)
	var generation_failure := _status if _status.begins_with("GENERATION FAILED") else ""
	_cancel_exit_ui("run_end")
	_pending_exit = &""
	_reward_token = null
	if is_instance_valid(reward_modal):
		reward_modal.close()
	_queued_actions.clear()
	var summary := {"stage": director.stage_index, "items": build.item_ids(), "run_coins_discarded": wallet.balance, "seed": director.seed}
	var settlement_id := StringName("%s/run_%s_%s" % [_run_receipt_prefix, result.run_epoch, result.event_id])
	var settled := meta.settle_biome(settlement_id, summary) if result.reason == &"biome_complete" else meta.settle(settlement_id, result.reason == &"success", summary)
	_status = "BIOME COMPLETE / GOLD CLAIMED" if result.reason == &"biome_complete" else ("VICTORY / GOLD CLAIMED" if result.reason == &"success" else "RUN ENDED / RETURNED HOME")
	if connected_region and result.reason == &"biome_complete":
		_status = _region_name()+" COMPLETE / Next regions are in development. Run ended; run abilities cleared."
	if not generation_failure.is_empty():
		_status += " / " + generation_failure
	if not settled:
		_status += " / HOME SUMMARY SAVE FAILED (banked notes unchanged)"
	_ui_run_report = {"success": result.reason in [&"biome_complete", &"success"], "can_retry": true, "summary": "本次旅途 · %s\n金币 %s · 本局物品 %s 件\n永久音符 %s · 已返回家园\n再次出发将从风铃平原开始新的冒险。" % [_region_name(), wallet.balance, build.item_ids().size(), meta.snapshot().get("notes", 0)]}
	if not settled: _ui_run_report.summary += "\n保存摘要失败 · 已存入音符保持原值"
	controller.router.clear("run_end")
	controller.air_focus_ability.stop()
	controller.active = false
	call_deferred("_cleanup_run")

func _cleanup_run() -> void:
	get_tree().paused = false
	_resources_hud.unbind()
	_demo_hud.unbind()
	build.clear()
	wallet.balance = 0
	for object: Node in [stage, policy, player, _run_camera]:
		if is_instance_valid(object):
			if object.get_parent() == self:
				remove_child(object)
			object.queue_free()
	_run_camera = null
	stage = null
	player = null
	controller = null
	policy = null
	segment = null
	director.return_home()
	campaign = RunCampaignProgression.new()
	_show_home()
	if not _ui_run_report.is_empty():
		home_scene.set_input_blocked(true)
		menu.show_run_end(_ui_run_report)
		_ui_run_report = {}

func _hide_run_hud() -> void:
	_demo_hud.hide()
	_hud_frame.hide()
	_boss_status.hide()
	_resources_hud.hide()
	_pause_button.hide()
	_hud.text = ""
	_hint.text = ""
	_title.text = ""
	_status_label.text = ""
	_clear_actions()

func _refresh_home_meta() -> void:
	var snapshot := meta.snapshot()
	snapshot.upgrade_quote = meta.upgrade_quote()
	menu.set_meta_state(snapshot)
	if is_instance_valid(home_scene):
		home_scene.set_meta_state(snapshot)

func _show_home() -> void:
	if director.state != DemoRunDirector.State.HOME or is_instance_valid(_lab) or is_instance_valid(_preview) or is_instance_valid(_foundry) or is_instance_valid(_style_lab):
		return
	get_tree().paused = false
	_sync_region_presentation(true)
	_hide_run_hud()
	menu.hide_home()
	if not is_instance_valid(home_scene):
		home_scene = HomeScene.new()
		home_scene.avatar_selection_id = avatar_selection_id
		home_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(home_scene)
		home_scene.controller.router.reconfigure(_session_input)
		home_scene.controller.actor_resources.health_definition = meta.fresh_health_definition(home_scene.controller.actor_resources.health_definition)
		home_scene.controller.actor_resources.health.configure(home_scene.controller.actor_resources.health_definition)
		home_scene.requested_interaction.connect(_open_home_function)
		home_scene.requested_navigation.connect(_open_home_navigation)
	(get_meta("avatar_presentation") as Node).call("bind_player",home_scene.player)
	_refresh_home_meta()
	home_scene.set_input_blocked(false)
	queue_redraw()

func _remove_home_scene() -> void:
	if is_instance_valid(home_scene):
		home_scene.set_input_blocked(true)
		remove_child(home_scene)
		home_scene.queue_free()
		home_scene = null

func _open_home_function(id: StringName) -> void:
	if not is_instance_valid(home_scene) or director.state != DemoRunDirector.State.HOME:
		return
	home_scene.set_input_blocked(true)
	_refresh_home_meta()
	if id == &"character":
		var avatars := get_meta("avatar_presentation") as AvatarPresentation
		menu.set_avatar_options(avatars.selection_options(), avatars.selected_id)
	menu.show_home_panel(id)

func _open_home_navigation() -> void:
	if not is_instance_valid(home_scene) or director.state != DemoRunDirector.State.HOME:
		return
	home_scene.set_input_blocked(true)
	_refresh_home_meta()
	var snapshot := meta.snapshot()
	menu.show_home_navigation("%s\nBiomes cleared %s / Runs ended %s" % [_status, snapshot.completed_biomes, snapshot.failed_runs])

func _close_home_panel() -> void:
	if is_instance_valid(home_scene) and director.state == DemoRunDirector.State.HOME:
		get_tree().paused = false
		home_scene.set_input_blocked(false)

func _sync_music() -> void:
	if not is_instance_valid(_music): return
	var track: StringName = &"home"
	if director.state == DemoRunDirector.State.IN_STAGE and is_instance_valid(controller) and not controller.actor_resources.health.terminal:
		var forest := active_region_id == &"thorn_forest"
		track = &"forest" if forest else &"plains"
		if not _stage_pending and is_instance_valid(stage) and is_instance_valid(stage.boss):
			var encounter := stage.boss.get_node_or_null("Encounter") as BossEncounter
			if encounter != null and encounter.active and not encounter.health.terminal:
				track = &"forest_boss" if forest else &"plains_boss"
	_music.request_track(track)
	_music.set_menu_paused(get_tree().paused)

func _process(_delta: float) -> void:
	_sync_music()
	# UI-only visibility: the appearance selector belongs to playable consumers,
	# and must not float above full-screen menus or the title illustration.
	var avatar := get_meta("avatar_presentation", null) as Node
	if is_instance_valid(avatar):
		var selector := avatar.get_node_or_null("AvatarSelectorLayer") as CanvasLayer
		if selector != null: selector.visible = false # Selection belongs to the Home Timeweaver.
	_boss_status.hide()
	var shown_boss: WindkeeperEncounter = null
	if director.state == DemoRunDirector.State.IN_STAGE and is_instance_valid(stage) and is_instance_valid(stage.boss):
		shown_boss = stage.boss.get_node("Encounter") as WindkeeperEncounter
	_windkeeper_hud.bind(shown_boss)
	if is_instance_valid(_run_camera):
		_run_camera.route_focus = Vector2.INF
		_run_camera.region_focus = (stage as PlainsRegionStage).composition_focus() if connected_region and stage is PlainsRegionStage else Vector2.INF
		_run_camera.observation_focus = stage.call("observation_composition_focus") if connected_region and is_instance_valid(stage) and stage.has_method("observation_composition_focus") else Vector2.INF
		if shown_boss != null and shown_boss.active:
			if shown_boss.stage_phase == 3 and shown_boss.reward_stands.size() == 3:
				_run_camera.route_focus = shown_boss.reward_stands[mini(shown_boss.chase_segment+1,2)]
			else: _run_camera.route_focus = shown_boss.motor.global_position+shown_boss.core_offset()
	_status_label.text = _status if director.state == DemoRunDirector.State.IN_STAGE else ""
	if director.state != DemoRunDirector.State.IN_STAGE or not is_instance_valid(controller) or _stage_pending:
		return
	_title.text = "%s / CONNECTED REGION %s/2 / " % [_region_name(),director.region_map_index] + (stage as PlainsRegionStage).visited_area if connected_region else "DEVELOPMENT / ROOM %s OF %s / %s" % [director.stage_index, director.profile.stages_per_biome, String(director.stage_type_id).to_upper()]
	(player.get_node("PlayerFeedback") as PlayerFeedback).effects_enabled = not _reduced_effects
	_hud.text = "COINS %s | NOTES %s | JUMPS %s | AIR SHOTS %s" % [wallet.balance, meta.snapshot().get("notes", 0), controller.motor.tuning.max_jumps, controller.action_resources.shot_charges]
	if is_instance_valid(stage.boss):
		var boss_encounter = stage.boss.get_node("Encounter")
		if not boss_encounter is WindkeeperEncounter and boss_encounter.active and boss_encounter.has_method("objective") and not boss_encounter.health.terminal:
			var boss_title: String = boss_encounter.definition.display_name if boss_encounter is ThornForestEncounter else "THE WINDKEEPER"
			var seal_status := ""
			if stage is ThornForestRegionStage and is_instance_valid(stage.boss_seal) and not stage.boss_seal.world_status_text_enabled:
				if stage.boss_seal.closed:seal_status=" / ARENA SEALED"
				elif stage.boss_seal.armed:seal_status=" / GATES CLOSING"
			_boss_status.text = "%s  /  %.0f / %.0f%s\n%s" % [boss_title,boss_encounter.health.current, boss_encounter.health.capacity,seal_status,boss_encounter.call("objective")]
			_boss_status.show()
	_hint.text = _device_hint()
	if generated_plains:
		var random_stage := stage as GeneratedDemoStage
		var route_index := random_stage.assembler.module_index_at(player.global_position) + 1
		var flow := "LEFT" if random_stage.generated.manifest.nodes[0].mirrored else "RIGHT"
		_status_label.text += "\nROUTE %s / %s | WORLD X %.0f | CAMERA X %.0f | FLOW %s" % [route_index, random_stage.assembler.modules.size(), player.global_position.x, _run_camera.global_position.x, flow]
	_hint.visible = debug_hud
	_status_label.visible = debug_hud or "FAILED" in _status
	if connected_region and not debug_hud:
		_title.text = "%s  %s/2" % [_region_name(),director.region_map_index]
		_hud.show()
		_hud.text = "COINS %s   NOTES %s" % [wallet.balance, meta.snapshot().get("notes",0)]
		_hud.position = Vector2(22,29)
		_hud_frame.size = Vector2(320, 140)
		_debug_button.position=Vector2(250,8)
		_resources_hud.set_region_compact(true)
	else:
		_hud.show()
		_hud_frame.position=Vector2(12,8)
		_debug_button.position=Vector2(434,10)
		_title.position=Vector2(22,14)
		_hud.position=Vector2(22,42)
		_resources_hud.position=Vector2.ZERO
		_resources_hud.set_region_compact(false)
		_hud_frame.size.y = 252 if debug_hud else 172
	if not connected_region or debug_hud: _hud_frame.size.x=760 if connected_region else 500
	_hint.position.y=178
	_status_label.position.y = 208 if debug_hud else 178
	_actions.position.y = 268 if debug_hud else 178
	_pause_button.visible = not overlay.enabled
	_update_actions()
	# Retain legacy debug consumers; normal play uses the task-owned read-only HUD.
	_demo_hud.visible = not debug_hud
	_demo_hud.present_context("%s · %s/2 · %s" % [_region_name(), director.region_map_index, (stage as PlainsRegionStage).visited_area] if connected_region else "试玩 · 房间 %s/%s" % [director.stage_index, director.profile.stages_per_biome], wallet.balance, int(meta.snapshot().get("notes", 0)), _reduced_effects)
	if not debug_hud: _demo_hud.present_touch_menu(overlay)
	if not debug_hud: _demo_hud.present_navigation((stage as PlainsRegionStage).map_view if connected_region else null, _pause_button, overlay._pause_rect if overlay.enabled else Rect2())
	if connected_region and not debug_hud: _layout_region_hud()
	_hud_frame.visible = debug_hud
	_resources_hud.visible = debug_hud
	_title.visible = debug_hud
	_hud.visible = debug_hud

func _layout_region_hud() -> void:
	# Only two stable edge layouts. Read visible actors and projectiles, never
	# move gameplay bodies or read the test driver's desired route.
	var blockers: Array[Rect2] = []
	var transform := player.get_canvas_transform()
	blockers.append(transform * Rect2(player.global_position-Vector2(22,38),Vector2(44,65)))
	if stage is PlainsRegionStage:
		for enemy: EnemyMotor in stage.enemies:
			var actor := enemy.get_node("Actor") as EnemyActor
			if actor.health.terminal or enemy.global_position.distance_to(player.global_position)>450:continue
			blockers.append(transform * Rect2(enemy.global_position-actor.definition.collision_size*.5,actor.definition.collision_size).grow(12))
			if actor.attack_behavior!=null:
				var attack:=actor.attack_behavior
				if attack.state in [&"telegraph",&"attack"]:blockers.append(transform*Rect2(attack.attack_origin-Vector2(20,20),Vector2(40,40)))
				for projectile:EnemyAttackProjectile in attack._projectiles:
					if is_instance_valid(projectile) and not projectile.spent:blockers.append(transform*Rect2(projectile.global_position-Vector2.ONE*12,Vector2.ONE*24))
	var critical_count := blockers.size()
	var required_regions: Array[Rect2]=[]
	var viewport:=get_viewport_rect()
	if stage is PlainsRegionStage:
		for module: PlatformingModule in stage.assembler.modules:
			for anchor: Vector2 in module.definition.anchors:
				var point := module.global_position+anchor
				var projected:=transform*Rect2(point-Vector2(26,48),Vector2(52,65))
				if viewport.intersects(projected):blockers.append(projected)
			if module.definition.module_id==&"plains_windchime_well":
				var bank: Rect2=module.definition.platforms[1]
				var receiver:=transform*Rect2(module.global_position+bank.position-Vector2(0,36),Vector2(bank.size.x,36))
				if viewport.intersects(receiver):required_regions.append(receiver.intersection(viewport))
		for latch: ShotLatch in (stage as PlainsRegionStage).shot_latches:
			var point := latch.global_position+latch.bell_position
			var projected:=transform*Rect2(point-Vector2(20,30),Vector2(40,60))
			if viewport.intersects(projected):
				blockers.append(projected)
				if not latch.is_open:required_regions.append(projected.intersection(viewport))
	var touch_regions:=_region_touch_regions()
	touch_regions.append_array(required_regions)
	var hud_candidates: Array = [Vector2(12,8),Vector2(12,382),Vector2(12,220)] if overlay.enabled else [Vector2(12,8),Vector2(12,590)]
	var best:=Vector2(12,8)
	var score:=INF
	for candidate:Vector2 in hud_candidates:
		# Compact resource labels extend beyond the old fixed bottom slot.
		# Score the real in-viewport panel position, including its full height.
		candidate=candidate.clamp(viewport.position+Vector2(8,8),viewport.end-_hud_frame.size-Vector2(8,8))
		var bounds:=Rect2(candidate,_hud_frame.size).grow(5)
		if touch_regions.any(func(region: Rect2):return region.intersects(bounds)):continue
		var overlap:=0.0
		for index: int in blockers.size():
			var cut:=bounds.intersection(blockers[index])
			overlap+=cut.get_area()*(1000000.0 if index==0 else 1000.0 if index<critical_count else 1.0)
		if overlap<score:score=overlap;best=candidate
	_hud_frame.position=best
	var shift:=best-Vector2(12,8)
	_title.position=Vector2(22,8 if _explicit_plains_candidate() else 14)+shift
	_title.add_theme_font_size_override("font_size",14 if _explicit_plains_candidate() else 16)
	_hud.position=Vector2(22,30 if plains_environment_candidate_requested else 29)+shift
	_resources_hud.position=shift+Vector2(0,8 if plains_environment_candidate_requested else 0)
	if stage is PlainsRegionStage:
		var cards: Array[Control] = _demo_hud.region_layout_controls()
		var card_reservations: Array[Rect2] = []
		for card: Control in cards: card_reservations.append(card.get_global_rect())
		var navigation_reserved: Array[Rect2] = touch_regions.duplicate()
		navigation_reserved.append_array(card_reservations)
		var map := (stage as PlainsRegionStage).map_view
		if is_instance_valid(map):
			map.position = _clear_ui_edge(_region_ui_positions.get("map",map.position),map.size*map.scale,([Vector2(1098,78),Vector2(1098,142),Vector2(952,78)] if overlay.enabled else [Vector2(1098,14),Vector2(1098,674)]),blockers,critical_count,navigation_reserved)
			_region_ui_positions["map"]=map.position
			touch_regions.append(map.get_global_rect())
			navigation_reserved.append(map.get_global_rect())
		if _pause_button.is_visible_in_tree():
			_pause_button.position = _clear_ui_edge(_region_ui_positions.get("pause",_pause_button.position),_pause_button.size*_pause_button.scale,[Vector2(1150,75),Vector2(1150,620)],blockers,critical_count,navigation_reserved)
			_region_ui_positions["pause"]=_pause_button.position
			touch_regions.append(_pause_button.get_global_rect())
		for index: int in cards.size():
			var card: Control=cards[index]
			var extent:=card.size*card.scale
			var reserved: Array[Rect2]=touch_regions.duplicate()
			for other: Control in cards:
				if other!=card:reserved.append(other.get_global_rect())
			var key: String="card_"+str(index)
			card.position=_clear_ui_edge(_region_ui_positions.get(key,card.position),extent,[card.position,Vector2(24,18),Vector2(24,viewport.end.y-extent.y-24),Vector2(viewport.end.x-extent.x-24,18),Vector2(viewport.end.x-extent.x-24,viewport.end.y-extent.y-24),Vector2(24,(viewport.size.y-extent.y)*.5),Vector2(viewport.end.x-extent.x-24,(viewport.size.y-extent.y)*.5)],blockers,critical_count,reserved)
			_region_ui_positions[key]=card.position
		if is_instance_valid(item_toast._root):
			var toast_reserved: Array[Rect2]=touch_regions.duplicate()
			for card: Control in cards:toast_reserved.append(card.get_global_rect())
			item_toast._root.position = _clear_ui_edge(item_toast._root.position,item_toast._root.size,([Vector2(300,125),Vector2(300,392),Vector2(300,260),Vector2(350,24)] if overlay.enabled else [Vector2(300,615),Vector2(300,125),Vector2(350,24),Vector2(300,392),Vector2(300,260)]),blockers,critical_count,toast_reserved)

func _region_touch_regions() -> Array[Rect2]:
	var regions: Array[Rect2]=[]
	if not is_instance_valid(overlay) or not overlay.enabled:return regions
	# Actual current overlay geometry, including floating-stick displacement.
	# No control, input rule or capability is changed by the HUD.
	for center: Vector2 in [overlay.left_center,overlay.right_center]:
		regions.append(Rect2(center-Vector2.ONE*overlay.radius,Vector2.ONE*overlay.radius*2))
	regions.append(Rect2(overlay.jump_center-Vector2.ONE*overlay.jump_hit_radius,Vector2.ONE*overlay.jump_hit_radius*2))
	regions.append(overlay._pause_rect)
	if not overlay.hide_reset_button:regions.append(overlay._reset_rect)
	if overlay.router.grapple_available:regions.append(Rect2(overlay.hook_center-Vector2.ONE*overlay.hook_radius,Vector2.ONE*overlay.hook_radius*2))
	if overlay.router.weapon_context_available:regions.append(Rect2(overlay.context_center-Vector2.ONE*overlay.hook_radius*.8,Vector2.ONE*overlay.hook_radius*1.6))
	if overlay.router.weapon_skill_available:regions.append(Rect2(overlay.skill_center-Vector2.ONE*overlay.hook_radius*.8,Vector2.ONE*overlay.hook_radius*1.6))
	return regions

func _clear_ui_edge(current: Vector2, extent: Vector2, candidates: Array, blockers: Array[Rect2], critical_count: int=1, reserved: Array[Rect2]=[]) -> Vector2:
	var viewport:=get_viewport_rect()
	var best := current.clamp(viewport.position+Vector2(8,8),(viewport.end-extent-Vector2(8,8)).max(viewport.position+Vector2(8,8)))
	var cost := INF
	var choices: Array = [current]
	choices.append_array(candidates)
	for at: Vector2 in choices:
		at=at.clamp(viewport.position+Vector2(8,8),(viewport.end-extent-Vector2(8,8)).max(viewport.position+Vector2(8,8)))
		if reserved.any(func(region: Rect2):return region.intersects(Rect2(at,extent).grow(8))):continue
		var overlap := 0.0
		for index: int in blockers.size(): overlap += Rect2(at,extent).grow(8).intersection(blockers[index]).get_area()*(1000000.0 if index==0 else 1000.0 if index<critical_count else 1.0)
		if overlap < cost: cost = overlap; best = at
	return best

func _device_hint() -> String:
	if controller.router.current_device == &"touch":
		return "Left stick: move / hold up-down: look / up: interact | JUMP: tap or hold | Right stick: aim, RELEASE to fire"
	if controller.router.current_device == &"gamepad":
		return "Left stick: move / hold up-down: look | Jump button: tap / hold | Right stick: aim, return to center to fire"
	return "A/D: move | Space: tap / hold jump | Mouse: aim, RELEASE left button to fire | W: interact | ↑/↓ on ground: look | S: drop"

func _update_actions() -> void:
	var key := ""
	if get_tree().paused:
		return
	elif connected_region:
		var rs := stage as PlainsRegionStage
		var has_discovery := rs is ThornForestRegionStage and is_instance_valid((rs as ThornForestRegionStage).discoveries) and not (rs as ThornForestRegionStage).discoveries.nearby(player.global_position).is_empty()
		var has_cache := rs.nearby_chest(player.global_position) >= 0
		if has_discovery and has_cache: key = "forest_discovery_and_cache"
		elif has_discovery: key = "forest_discovery"
		elif has_cache: key = "region_chest"
		elif not rs.nearby_shortcut(player.global_position).is_empty(): key = "region_shortcut"
		elif player.global_position.distance_to(rs.merchant_position) < 90: key = "region_shop"
	elif not generated_plains and current_reward != null and not rewards.get_offer(current_reward.offer_id).claimed and player.global_position.distance_to(stage.reward_position) < 130:
		key = "reward:" + str(current_reward.offer_id)
	elif not generated_plains and simple_reward != null and not simple_reward.claimed and player.global_position.distance_to(stage.reward_position) < 130:
		key = "simple_reward"
	elif director.stage_type_id == &"shop" and player.global_position.distance_to(stage.reward_position) < 130:
		key = "shop"
	elif not generated_plains and not stage.supply_claimed and player.global_position.distance_to(stage.supply_position) < 80:
		key = "supply"
	elif not generated_plains and stage.nearby_exit(player.global_position) >= 0:
		key = "exit:" + str(stage.nearby_exit(player.global_position))
	if key == _shown_actions:
		return
	_shown_actions = key
	_clear_actions()
	if key == "forest_discovery_and_cache":
		_button(_actions, "OPEN CACHE / CHOOSE REWARD", interact)
		_button(_actions, "查看发现物", _request_forest_discovery)
	elif key == "forest_discovery":
		_button(_actions, "查看发现物", _request_forest_discovery)
	elif key == "region_chest":
		_button(_actions,"OPEN CACHE / CHOOSE REWARD",interact)
	elif key == "region_shortcut":
		_button(_actions,"OPEN RETURN SHORTCUT",interact)
	elif key == "region_shop":
		var quote := shop.quote(_region_shop_id())
		_button(_actions,"MERCHANT / STOCK %s" % quote.stock,_open_region_shop)
	elif key.begins_with("reward:"):
		for item: ItemDefinition in current_reward.candidates:
			var selected_id := item.stable_id
			_button(_actions, item.display_name, func() -> void: claim_item(selected_id))
	elif key == "simple_reward":
		_button(_actions, "CLAIM COINS" if director.stage_type_id == &"coin_reward" else "RESTORE HEALTH", claim_room_reward)
	elif key == "shop":
		var quote := shop.quote(_stage_id("shop_jump"))
		_button(_actions, "%s / %s coins / stock %s" % [quote.item.display_name, quote.price, quote.stock], purchase_item)
	elif key == "supply":
		_button(_actions, "USE SUPPLY / +2 HP", interact)
	elif key.begins_with("exit:"):
		var index := stage.nearby_exit(player.global_position)
		var exit_id: StringName = stage.exits[index].exit_id
		var button := _button(_actions, "ENTER " + stage.exits[index].label, func() -> void: choose_exit(exit_id))
		button.disabled = not stage.completed

func _make_ui() -> void:
	map_modal=PlainsRegionMapModal.new()
	add_child(map_modal)
	map_modal.closed.connect(close_region_map)
	exit_modal = EXIT_MODAL.new()
	add_child(exit_modal)
	exit_modal.entered.connect(_confirm_generated_exit)
	exit_modal.stayed.connect(_stay_generated_exit)
	reward_modal = StageRewardModal.new()
	add_child(reward_modal)
	reward_modal.item_selected.connect(_claim_modal_item)
	shop_modal=ItemShopModal.new();add_child(shop_modal)
	shop_modal.purchase_requested.connect(_confirm_region_purchase)
	shop_modal.closed.connect(_close_region_shop)
	item_toast=ItemAcquiredToast.new();add_child(item_toast)
	_canvas = CanvasLayer.new()
	_canvas.layer = 2
	add_child(_canvas)
	_hud_frame = Panel.new()
	_hud_frame.position = Vector2(12, 8)
	_hud_frame.size = Vector2(500, 112)
	_hud_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.045, 0.09, 0.13, 0.9)
	frame_style.border_color = Color(0.2, 0.45, 0.49, 0.65)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(8)
	_hud_frame.add_theme_stylebox_override("panel", frame_style)
	_canvas.add_child(_hud_frame)
	_title = _label(Vector2(22, 14), 16)
	_hud = _label(Vector2(22, 42), 14)
	_hint = _label(Vector2(22, 108), 14)
	_status_label = _label(Vector2(22, 134), 15)
	_windkeeper_hud = WindkeeperHud.new()
	_canvas.add_child(_windkeeper_hud)
	_boss_status = _label(Vector2(555, 18), 14)
	_boss_status.add_theme_color_override("font_color", Color("fff0c8"))
	_boss_status.add_theme_color_override("font_shadow_color", Color(0.08, 0.13, 0.10, 0.95))
	_boss_status.add_theme_constant_override("shadow_offset_x", 2)
	_boss_status.add_theme_constant_override("shadow_offset_y", 2)
	_resources_hud = ActorResourcesHud.new()
	_canvas.add_child(_resources_hud)
	_demo_hud = DemoGameHud.new()
	_canvas.add_child(_demo_hud)
	_demo_hud.debug_requested.connect(func() -> void: debug_hud = not debug_hud)
	_pause_button = Button.new()
	_pause_button.text = "MENU"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.position = Vector2(1150, 75)
	_pause_button.size = Vector2(108, 45)
	_pause_button.pressed.connect(toggle_pause)
	_canvas.add_child(_pause_button)
	var debug_button := Button.new()
	_debug_button = debug_button
	debug_button.text = "INFO"
	debug_button.position = Vector2(250, 8)
	debug_button.size = Vector2(56, 30)
	debug_button.theme = DemoMenu.create_theme()
	debug_button.add_theme_font_size_override("font_size", 12)
	debug_button.pressed.connect(func() -> void: debug_hud = not debug_hud)
	_hud_frame.add_child(debug_button)
	_actions = HBoxContainer.new()
	_actions.position = Vector2(360, 178)
	_actions.add_theme_constant_override("separation", 16)
	_canvas.add_child(_actions)
	menu = DemoMenu.new()
	add_child(menu)
	menu.set_input_values(_session_input)
	menu.requested_enter_home.connect(_show_home)
	menu.home_panel_closed.connect(_close_home_panel)
	menu.requested_start.connect(func(seed: String) -> void: start_demo(seed, false))
	menu.requested_plains.connect(start_plains)
	menu.requested_debug_region.connect(start_debug_region)
	menu.requested_forest_places.connect(func(map_index: int,seed: String) -> void:
		start_debug_region(&"thorn_forest",map_index,seed,ThornForestRegionGenerator.DEPTH_VERSION,ThornForestRegionGenerator.DEPTH_LAYOUT_PLACES))
	menu.requested_forest_varied.connect(func(map_index: int,seed: String) -> void:
		start_debug_region(&"thorn_forest",map_index,seed,ThornForestRegionGenerator.DEPTH_VERSION,ThornForestRegionGenerator.DEPTH_LAYOUT_VARIED))
	menu.requested_forest_exploration.connect(func(map_index: int,seed: String) -> void:
		start_debug_region(&"thorn_forest",map_index,seed,ThornForestRegionGenerator.DEPTH_VERSION,ThornForestRegionGenerator.DEPTH_LAYOUT_EXPLORATION))
	progression_modal = RegionProgressionModal.new()
	add_child(progression_modal)
	progression_modal.ability_selected.connect(_select_core_ability)
	progression_modal.region_selected.connect(_select_next_region)
	progression_modal.finish_requested.connect(_finish_campaign_boundary)
	menu.requested_upgrade.connect(_purchase_meta_upgrade)
	menu.requested_avatar.connect(func(id: String) -> void:
		if not is_instance_valid(home_scene) or director.state != DemoRunDirector.State.HOME: return
		var avatars := get_meta("avatar_presentation") as AvatarPresentation
		if avatars.select_avatar(id): menu.set_avatar_options(avatars.selection_options(), avatars.selected_id))
	menu.requested_lab.connect(_open_module_lab)
	menu.requested_actions.connect(_open_action_studio)
	menu.requested_player_presentation.connect(_open_player_presentation)
	menu.requested_foundation.connect(_open_foundation)
	menu.requested_windchime.connect(_open_windchime)
	menu.requested_pixel_plains.connect(_open_pixel_plains)
	menu.requested_style_lab.connect(_open_style_lab)
	menu.requested_foundry.connect(_open_foundry)
	menu.requested_random.connect(_open_random_preview)
	menu.requested_resume.connect(_resume_from_menu)
	menu.requested_home.connect(abandon_run)
	menu.requested_retry.connect(func() -> void: start_plains(menu._plains_seed()))
	menu.settings_changed.connect(apply_input_settings)
	menu.presentation_changed.connect(func(reduced: bool, muted: bool) -> void:
		_reduced_effects = reduced
		if stage is ThornForestRegionStage and is_instance_valid((stage as ThornForestRegionStage).ambience):
			(stage as ThornForestRegionStage).ambience.set_reduced_effects(reduced)
		if stage is ThornForestRegionStage and is_instance_valid((stage as ThornForestRegionStage).near_scenery):
			(stage as ThornForestRegionStage).near_scenery.set_reduced_effects(reduced)
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),muted))
	menu.menu_opened.connect(_pause_for_menu)
	UnderworldUI.style_canvas(_canvas)
	# Keep current system glyph coverage after applying the Underworld palette.
	var ui_font: Font = DemoMenu.create_theme().default_font
	for control: Node in _canvas.get_children():
		if control is Control and control.theme != null:
			control.theme.default_font = ui_font

func _label(location: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = location
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	_canvas.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 52)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _clear_actions() -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()

func _stage_id(prefix: String) -> StringName:
	return StringName("%s_stage_%s" % [prefix, director.stage_index])

func _next_id(prefix: String) -> StringName:
	_sequence += 1
	return StringName("%s_%s_%s" % [prefix, lifetime.epoch, _sequence])

func _draw() -> void:
	# The viewport backdrop is shared by Home, fixed rooms and module practice.
	# No world-sized opaque rectangle may cover it when the camera moves.
	pass

func _contact(parent: Node2D, id: StringName, kind: DamageRequest.Kind, size: Vector2) -> DemoContactEmitter:
	var emitter := DemoContactEmitter.new()
	emitter.policy = policy
	emitter.controller = controller
	emitter.source_id = id
	emitter.kind = kind
	emitter.half_size = size
	emitter.interval = 0.7
	parent.add_child(emitter)
	return emitter

# Physical damage resolves first. UI and interaction intents cannot win a race
# against a lethal contact/Boss projectile in the same physics frame.
func interact() -> void:
	_queue_action(_commit_interact)

func choose_exit(id: StringName) -> bool:
	return _queue_action(_commit_exit.bind(id))

func claim_item(option_id: StringName) -> bool:
	return _queue_action(_commit_claim.bind(option_id))

func purchase_item() -> bool:
	return _queue_action(_commit_purchase)

func _queue_action(action: Callable) -> bool:
	if not _can_interact():
		return false
	_queued_actions.append({"token": lifetime.token(), "action": action})
	return true

func _flush_actions() -> void:
	var pending := _queued_actions
	_queued_actions = []
	for entry: Dictionary in pending:
		if lifetime.accepts(entry.token) and _can_interact():
			entry.action.call()

func _record_reward() -> void:
	var ids: Array[String] = []
	for item: ItemDefinition in current_reward.candidates:
		ids.append(String(item.stable_id))
	director.manifest.record_output(director.stage_index, &"reward_candidates", {"offer": String(current_reward.offer_id), "gold": current_reward.gold, "items": ids})

func claim_room_reward() -> bool:
	return _queue_action(_commit_room_reward)

func _commit_room_reward() -> bool:
	if generated_plains or not _can_interact() or simple_reward == null or player.global_position.distance_to(stage.reward_position) > 130:
		return false
	var result := simple_reward.claim(lifetime.token(), _next_id("room_reward"))
	if not result.accepted():
		return false
	GameAudio.cue(self, &"heal" if director.stage_type_id == &"health_reward" else &"coin")
	stage.reward_available = false
	director.manifest.record_output(director.stage_index, &"simple_reward_claim", {"amount_applied": result.amount_applied, "coins": result.coins, "health": result.current_health, "max_health": result.maximum_health})
	_status = "Reward claimed. Choose your next exit."
	_shown_actions = ""
	return true

func _commit_pickup(index: int) -> bool:
	if not _can_interact() or not stage is GeneratedDemoStage:
		return false
	var random_stage := stage as GeneratedDemoStage
	if index < 0 or index >= random_stage.pickups.size():
		return false
	var pickup: Dictionary = random_stage.pickups[index]
	if pickup.claimed or random_stage.clock<float(pickup.get("ready_at",0)) or player.global_position.distance_to(pickup.position) >= 46:
		return false
	var receipt_id := StringName("%s/stage_%s/%s" % [_run_receipt_prefix, director.stage_index, pickup.id])
	if pickup.kind == "coin":
		if not wallet.grant(pickup.amount, receipt_id):
			return false
		random_stage.coins_collected += pickup.amount
	elif pickup.kind == "heart":
		if controller.actor_resources.health.current >= controller.actor_resources.health.capacity:
			return false
		var healed := SupplyHealEffect.apply(controller.actor_resources.health, float(pickup.amount), receipt_id)
		if not healed.accepted():
			return false
		if pickup.id == "supply_heart":
			random_stage.mark_supply_used()
	elif pickup.kind == "note":
		var receipt := meta.grant_notes(pickup.amount, receipt_id)
		if not receipt.accepted:
			_status = "NOTES SAVE FAILED / " + str(receipt.reason)
			return false
	else:
		return false
	pickup.claimed = true
	if connected_region: region_state.claimed[pickup.id] = true
	GameAudio.cue(self, &"coin" if pickup.kind == "coin" else &"heal" if pickup.kind == "heart" else &"note")
	var feedback := player.get_node_or_null("PlayerFeedback") as PlayerFeedback
	if feedback != null:
		feedback.reward_received(pickup.position, pickup.kind == "note")
	director.manifest.record_output(director.stage_index, StringName("pickup_claim_" + str(pickup.id)), {"id": pickup.id, "kind": pickup.kind, "amount": pickup.amount})
	return true

func _purchase_meta_upgrade() -> void:
	if director.state != DemoRunDirector.State.HOME:
		return
	_meta_purchase_sequence += 1
	var result := meta.purchase_upgrade("vitality", StringName("%s/upgrade_%s" % [meta.new_run_receipt_prefix(), _meta_purchase_sequence]))
	GameAudio.cue(self, &"confirm" if result.accepted else &"denied")
	_status = "Permanent vitality improved. Next run begins with more health." if result.accepted else "Upgrade unavailable: " + str(result.reason)
	if is_instance_valid(home_scene):
		_refresh_home_meta()
		menu.show_home_panel(&"upgrade")
	else:
		_show_home()

func _in_boss_core() -> bool:
	if not generated_plains or not is_instance_valid(stage) or not stage is GeneratedDemoStage or not is_instance_valid(player):return false
	var arena:Rect2=(stage as GeneratedDemoStage).boss_arena
	if connected_region and stage is PlainsRegionStage:
		var seal:BossArenaSeal=(stage as PlainsRegionStage).boss_seal
		# The real sealed walls define containment. A legal jump/recoil can pass
		# above the old trigger rectangle without leaving the combat arena.
		if is_instance_valid(seal) and seal.closed:
			return seal.containment.has_point(player.global_position)
	return arena.has_point(player.global_position)

func _record_boss_shot(_direction: Vector2, shot_id: int) -> void:
	if generated_plains and _boss_started and _in_boss_core() and lifetime.active:
		_boss_eligible_shots["%s:%s" % [controller.session_id, shot_id]] = lifetime.actor_epoch

func _restore_forest_duel(encounter: BossEncounter, data: Dictionary) -> bool:
	if not encounter.has_method("valid_duel_snapshot") or not encounter.call("valid_duel_snapshot",data): return false
	var saved_health: Variant = data.get("health")
	if typeof(saved_health) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(saved_health)) or float(saved_health) < 0 or float(saved_health) > encounter.health.capacity: return false
	var saved_position: Variant = data.get("position")
	if not saved_position is Array or saved_position.size() != 2: return false
	for coordinate: Variant in saved_position:
		if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)): return false
	var body_position: Variant = data.get("body_position")
	if not body_position is Array or body_position.size() != 2: return false
	for index: int in 2:
		if typeof(body_position[index]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(body_position[index])) or not is_equal_approx(float(body_position[index]),float(saved_position[index])): return false
	var restored := encounter.definition.health_definition.duplicate(true) as HealthDefinition
	restored.initial_current = float(saved_health)
	encounter.health.configure(restored)
	encounter.damageable.bind_health(encounter.health)
	encounter.call("restore_combat_state",data)
	return encounter.get("last_restore_accepted") == true and encounter.motor.position.is_equal_approx(Vector2(saved_position[0],saved_position[1]))

func _start_generated_boss() -> void:
	var encounter := stage.boss.get_node("Encounter") as BossEncounter
	var receiver := stage.boss.get_node("Damageable") as Damageable
	if not policy.bind_damageable(&"boss", receiver, encounter.health):
		return
	var sink := receiver.damage_sink
	receiver.damage_sink = func(context: Dictionary) -> bool:
		var key := "%s:%s" % [context.get("session_id", -1), context.get("shot_id", -1)]
		return _boss_started and _in_boss_core() and lifetime.active and _boss_eligible_shots.get(key, -1) == lifetime.actor_epoch and sink.call(context) == true
	if encounter is WindkeeperEncounter: encounter.intro_seen = _boss_intros_seen.has(encounter.definition.stable_id)
	_boss_started = encounter.activate()
	if connected_region and _boss_started:
		var data: Dictionary=(stage as PlainsRegionStage).restored_boss
		if data.get("active",false):
			if encounter.has_method("bind_duel"):
				if not _restore_forest_duel(encounter,data):
					push_error("Recorded active forest duel rejected")
					abandon_run()
					return
			elif encounter.has_method("restore_combat_state"): encounter.call("restore_combat_state",data)
		(stage as PlainsRegionStage).restored_boss.clear()
	if _boss_started and encounter is WindkeeperEncounter: _boss_intros_seen[encounter.definition.stable_id]=true
	if _boss_started:
		_status = ("BOSS ACTIVE / Branch seals close after full entry." if active_region_id == &"thorn_forest" else "BOSS ACTIVE / Wind gates close after full entry.") if connected_region else "BOSS ACTIVE / Core entered. Retreat into the entrance is safe; Boss health persists."


func _exit_location(id: StringName) -> Vector2:
	if id == &"boss_home":
		return stage.reward_position
	for index: int in stage.exits.size():
		if stage.exits[index].exit_id == id:
			return stage.exit_positions[index]
	return Vector2.INF

func _rearm_exit_prompts() -> void:
	for id: StringName in _dismissed_exits.keys():
		if player.global_position.distance_to(_exit_location(id)) > 145:
			_dismissed_exits.erase(id)

func _offer_generated_exit(id: StringName) -> bool:
	if not _can_interact() or not director.stage_complete or not _pending_exit.is_empty() or _dismissed_exits.has(id):
		return false
	if connected_region and stage.clock<stage.reward_ready_at:return false
	var next_label := "HOME / BIOME COMPLETE" if id == &"boss_home" else ""
	if connected_region and director.region_map_index==1 and id==&"boss_home": next_label=_region_name()+" / MAP 2 OF 2"
	for exit: ExitOffer in stage.exits:
		if exit.exit_id == id:
			next_label = exit.label
	if next_label.is_empty() or player.global_position.distance_to(_exit_location(id)) > 100:
		return false
	_cancel_stage_shot_latches()
	_offered_exit = id
	_exit_prompt_token = lifetime.token()
	controller.router.clear("exit_confirmation")
	controller.air_focus_ability.stop()
	_queued_actions.clear()
	_clear_actions()
	var summary := "Reward: exploration pickups already collected"
	if connected_region and director.region_map_index==1: summary="Mini Boss: +12 coins, +1 HP / keep your build / no major ability yet"
	if current_reward != null:
		summary = "Reward: guaranteed GOLD item" if current_reward.gold else "Reward: choose ONE of TWO items"
	elif simple_reward != null:
		summary = "Reward: +%s COINS" % COIN_REWARD.amount if director.stage_type_id == &"coin_reward" else "Reward: restore current health (+%s HP)" % HEAL_REWARD.amount
	elif stage.stage_type == &"combat":
		summary = "Reward: +10 COINS"
	_cancel_enemy_attacks()
	get_tree().paused = true
	exit_modal.show_exit(next_label, summary)
	return true

func _confirm_generated_exit() -> bool:
	if not exit_modal.opened:
		return false
	if not lifetime.accepts(_exit_prompt_token) or controller.actor_resources.health.terminal:
		_cancel_exit_ui("stale_exit")
		return false
	var chosen := _offered_exit
	exit_modal.close()
	_offered_exit = &""
	_exit_prompt_token = null
	controller.router.clear("exit_confirmed")
	get_tree().paused = false
	_resume_exit_input()
	return _enter_generated_exit(chosen)

func _resume_exit_input() -> void:
	get_viewport().gui_release_focus()
	if is_instance_valid(player):
		var keyboard := player.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter
		keyboard.observe_current_key_neutral()

func _stay_generated_exit() -> void:
	if not _offered_exit.is_empty():
		_dismissed_exits[_offered_exit] = true
	_cancel_exit_ui("exit_stay")

func _cancel_exit_ui(reason: String) -> void:
	_offered_exit = &""
	_exit_prompt_token = null
	_pending_exit = &""
	_reward_token = null
	if is_instance_valid(exit_modal):
		exit_modal.close()
	if is_instance_valid(reward_modal):
		reward_modal.close()
	if _forest_reader_open(): (stage as ThornForestRegionStage).discoveries.close()
	if is_instance_valid(controller):
		controller.router.clear(reason)
		controller.air_focus_ability.stop()
	get_tree().paused = false
	_resume_exit_input()

func _enter_generated_exit(id: StringName) -> bool:
	if not director.stage_complete or not _pending_exit.is_empty() or controller.actor_resources.health.terminal:
		return false
	_pending_exit = id
	_reward_token = lifetime.token()
	if connected_region and director.region_map_index==1 and id==&"boss_home": return _advance_region_map()
	# Non-choice rewards settle at the selected exit, never at a pre-exit marker.
	if simple_reward != null and not simple_reward.claimed:
		var result := simple_reward.claim(_reward_token, _next_id("exit_reward"))
		if not result.accepted():
			_pending_exit = &""
			return false
		GameAudio.cue(self, &"heal" if director.stage_type_id == &"health_reward" else &"coin")
		stage.reward_available = false
		director.manifest.record_output(director.stage_index, &"simple_reward_claim", {"amount_applied": result.amount_applied, "coins": result.coins, "health": result.current_health, "max_health": result.maximum_health})
	if stage.stage_type == &"combat":
		wallet.grant(10, _stage_id("combat_coins"))
	if current_reward != null and not rewards.get_offer(current_reward.offer_id).claimed:
		controller.router.clear("exit_reward")
		controller.air_focus_ability.stop()
		_queued_actions.clear()
		_clear_actions()
		_cancel_enemy_attacks()
		get_tree().paused = true
		var next_label := "Core ability choice" if current_reward.gold and connected_region else "Home" if current_reward.gold else "next room"
		for exit: ExitOffer in stage.exits:
			if exit.exit_id == id:
				next_label = "Core ability choice" if current_reward.gold and connected_region else "Home" if current_reward.gold else exit.label
		reward_modal.show_offer(current_reward, next_label)
		return true
	return _finish_generated_exit()

func _advance_region_map() -> bool:
	if not connected_region or director.region_map_index!=1 or not lifetime.accepts(_reward_token) or controller.actor_resources.health.terminal or not director.stage_complete: return false
	var encounter:=stage.boss.get_node("Encounter") as BossEncounter
	if not encounter.health.terminal: return false
	var id:=StringName(_region_prefix()+"mini_boss/reward")
	if not wallet.grant(12,id): return false
	if controller.actor_resources.health.current<controller.actor_resources.health.capacity:
		SupplyHealEffect.apply(controller.actor_resources.health,1.0,id)
	director.manifest.record_output(director.stage_index,&"mini_boss_reward",{"coins":12,"heal":1,"major_ability":false})
	(stage as PlainsRegionStage).capture_state()
	stage.reward_available=false
	return director.advance_region_map(_reward_token,StringName(_region_prefix()+"enter_map_2")).accepted()

func _claim_modal_item(option_id: StringName) -> bool:
	if connected_region and _region_chest >= 0:
		if _region_pending_claim or not reward_modal.opened or not lifetime.accepts(_region_offer_token): return false
		_region_pending_claim=true
		get_tree().paused=false
		if not _queue_action(_commit_region_choice.bind(option_id)):
			_region_pending_claim=false;get_tree().paused=true;return false
		return true
	if not generated_plains or not reward_modal.opened or not lifetime.accepts(_reward_token) or controller.actor_resources.health.terminal:
		return false
	var request := RewardClaimRequest.new()
	request.token = _reward_token
	request.offer_id = current_reward.offer_id
	request.option_id = option_id
	request.claim_id = _next_id("exit_claim")
	var receipt := rewards.claim(request)
	if not receipt.accepted():
		return false
	GameAudio.cue(self, &"confirm")
	director.manifest.record_output(director.stage_index, &"reward_claim", {"offer": String(current_reward.offer_id), "item": String(receipt.item_id), "at_exit": String(_pending_exit)})
	reward_modal.close()
	controller.router.clear("exit_reward_complete")
	get_tree().paused = false
	if current_reward.gold:
		_gold_claimed = true
		if connected_region:
			return _begin_core_reward()
		return director.finish_biome(_reward_token, _next_id("biome_complete"), true).accepted()
	return _finish_generated_exit()

func _finish_generated_exit() -> bool:
	if _pending_exit.is_empty() or not lifetime.accepts(_reward_token) or controller.actor_resources.health.terminal:
		return false
	var id := _pending_exit
	return director.select_exit(_reward_token, id, _next_id("exit")).accepted()

func _cancel_stage_shot_latches(permanent: bool = false) -> void:
	if is_instance_valid(stage) and stage is GeneratedDemoStage:
		(stage as GeneratedDemoStage).cancel_shot_latch_requests(permanent)

func _cancel_enemy_attacks() -> void:
	if not is_instance_valid(stage) or not stage is GeneratedDemoStage: return
	for enemy_motor: EnemyMotor in (stage as GeneratedDemoStage).enemies:
		if not is_instance_valid(enemy_motor): continue
		var actor := enemy_motor.get_node("Actor") as EnemyActor
		if actor.attack_behavior != null: actor.attack_behavior.cancel()
	if is_instance_valid(stage.boss):
		var encounter := stage.boss.get_node("Encounter")
		if encounter.has_method("cancel_pending_attacks"):
			encounter.call("cancel_pending_attacks")
			_boss_eligible_shots.clear()
			if is_instance_valid(controller): controller.shoot_ability.clear_projectiles()

func _record_attack_shortcut_opened(id: String, stage_epoch: int, run_epoch: int) -> void:
	if not lifetime.active or lifetime.stage_epoch != stage_epoch or lifetime.epoch != run_epoch or not connected_region:
		return
	director.manifest.record_output(director.stage_index,StringName("shortcut/"+id),{"opened":true,"trigger":"accepted_attack"})

func _region_interact() -> void:
	var rs := stage as PlainsRegionStage
	var index := rs.nearby_chest(player.global_position)
	if index >= 0:
		var chest: Dictionary = rs.chests[index]
		var items: Array[ItemDefinition] = []
		for id: String in chest.items:
			var item := load("res://resources/items/%s.tres" % id) as ItemDefinition
			if build.can_add(item): items.append(item)
		# Keep every eligible item; resources are real, tier-valued alternatives.
		var selected: Array[ItemDefinition]=[]
		if str(chest.reward_mode)!="resources" and not items.is_empty(): selected.append(items[0])
		var item_offer: RewardOffer=null
		if not selected.is_empty(): item_offer=rewards.create_cache_offer(StringName(chest.id),selected,StringName(chest.id+"/source"))
		if not selected.is_empty() and item_offer==null: return
		_region_offer=item_offer.copy() if item_offer!=null else RewardOffer.new()
		_region_offer.offer_id=StringName(chest.id)
		_region_offer.candidates.clear()
		_region_offer.candidates.assign(selected)
		for resource: Dictionary in chest.resources:
			if _region_offer.candidates.size()>=2: break
			if resource.kind=="heart" and controller.actor_resources.health.current>=controller.actor_resources.health.capacity: continue
			var tier: ItemDefinition.Rarity=ItemDefinition.Rarity.BLUE if chest.tier=="medium" else ItemDefinition.Rarity.PURPLE if chest.tier=="high" else ItemDefinition.Rarity.GOLD
			_region_offer.candidates.append(ResourceRewardChoice.make(StringName(chest.id+"/resource/"+resource.kind),str(resource.kind),int(resource.amount),tier))
		if _region_offer.candidates.size()<2 and items.size()>1: _region_offer.candidates.append(items[1])
		# A full-health resource-only cache still offers a valuable note alternative.
		if _region_offer.candidates.size()<2:
			_region_offer.candidates.append(ResourceRewardChoice.make(StringName(chest.id+"/resource/note"),"note",1 if chest.tier=="medium" else 2 if chest.tier=="high" else 4,ItemDefinition.Rarity.BLUE if chest.tier=="medium" else ItemDefinition.Rarity.PURPLE if chest.tier=="high" else ItemDefinition.Rarity.GOLD))
		_region_pending_claim=false
		_region_chest = index
		_region_offer_token = lifetime.token()
		controller.router.clear("region_cache")
		controller.air_focus_ability.stop()
		get_tree().paused = true
		reward_modal.show_offer(_region_offer,"Continue exploring / " + str(chest.tier))
		return
	if _open_forest_discovery(): return
	if player.global_position.distance_to(rs.merchant_position) < 90:
		_open_region_shop()

func _open_region_shop() -> void:
	if not _can_interact() or shop_modal.opened: return
	_shop_offer=shop.quote(_region_shop_id())
	if _shop_offer==null: return
	_shop_token=lifetime.token()
	_pause_for_menu()
	shop_modal.show_offer(_shop_offer,wallet.balance,build.can_add(_shop_offer.item))

func _close_region_shop() -> void:
	shop_modal.close()
	_shop_offer=null
	if is_instance_valid(controller): controller.router.clear("shop_close")
	if director.state==DemoRunDirector.State.IN_STAGE and lifetime.active: get_tree().paused=false

func _confirm_region_purchase() -> void:
	if not shop_modal.opened or not lifetime.accepts(_shop_token) or controller.actor_resources.health.terminal: return
	var current:=shop.quote(_region_shop_id())
	if current==null or current.quote_version!=_shop_offer.quote_version or current.offer_id!=_shop_offer.offer_id: return
	_close_region_shop()
	_region_purchase()

func _commit_region_choice(option_id: StringName) -> bool:
	var accepted:=_claim_region_chest(option_id)
	_region_pending_claim=false
	if not accepted and lifetime.active and reward_modal.opened:
		get_tree().paused=true
		reward_modal.show_error(_status if _status.begins_with("NOTES SAVE FAILED") else "CHOICE UNAVAILABLE")
	return accepted

func _claim_region_chest(option_id: StringName) -> bool:
	if not lifetime.accepts(_region_offer_token) or controller.actor_resources.health.terminal or not reward_modal.opened: return false
	var rs := stage as PlainsRegionStage
	var chest: Dictionary = rs.chests[_region_chest]
	if chest.claimed: return false
	var selected: ItemDefinition=null
	for item: ItemDefinition in _region_offer.candidates:
		if item.stable_id==option_id: selected=item
	if selected==null: return false
	var resource:=selected as ResourceRewardChoice
	if resource!=null:
		var id:=StringName(_run_receipt_prefix+"/"+chest.id+"/resource")
		if resource.resource_kind=="coin":
			if not wallet.grant(resource.amount,id): return false
		elif resource.resource_kind=="heart":
			if controller.actor_resources.health.current>=controller.actor_resources.health.capacity: return false
			if not SupplyHealEffect.apply(controller.actor_resources.health,float(resource.amount),id).accepted(): return false
		else:
			var saved:=meta.grant_notes(resource.amount,id)
			if not saved.accepted:
				_status="NOTES SAVE FAILED / Nothing granted. Retry this choice."
				return false
	else:
		var request:=RewardClaimRequest.new()
		request.token=_region_offer_token;request.offer_id=_region_offer.offer_id;request.option_id=option_id;request.claim_id=StringName(chest.id+"/claim")
		if not rewards.claim(request).accepted(): return false
		wallet.grant(int(chest.coins),StringName(chest.id+"/coins"))
	item_toast.show_item(selected)
	if connected_region: _layout_region_hud()
	_status="CACHE CLAIMED / "+selected.display_name.split(" / ")[-1]
	chest.claimed = true
	region_state.claimed[chest.id] = true
	if rs is ThornForestRegionStage:
		(rs.assembler as ThornForestRegionAssembler).resolve_reward_shortcuts()
	director.manifest.record_output(director.stage_index,StringName("cache/"+chest.id),{"choice": String(option_id),"resource":resource.resource_kind if resource!=null else "item","amount":resource.amount if resource!=null else int(chest.coins)})
	_region_chest = -1
	_region_offer = null
	reward_modal.close()
	controller.router.clear("region_cache_complete")
	get_tree().paused = false
	GameAudio.cue(self,&"confirm")
	return true

func _region_purchase() -> bool:
	if not _can_interact() or player.global_position.distance_to((stage as PlainsRegionStage).merchant_position) > 90: return false
	var quote := shop.quote(_region_shop_id())
	var request := ShopPurchaseRequest.new()
	request.token = lifetime.token()
	request.shop_id = quote.shop_id
	request.offer_id = quote.offer_id
	request.quote_version = quote.quote_version
	request.transaction_id = _next_id("region_purchase")
	var receipt := shop.purchase(request)
	GameAudio.cue(self,&"confirm" if receipt.accepted() else &"denied")
	if receipt.accepted():
		item_toast.show_item(quote.item)
		if connected_region: _layout_region_hud()
	return receipt.accepted()

func _region_shop_id() -> StringName:
	return StringName(_region_prefix()+"shop/"+str((stage as PlainsRegionStage).generated.manifest.merchant_id))

func _open_player_presentation() -> void:
	if director.state != DemoRunDirector.State.HOME: return
	# The author retained this body/weapon work as a development candidate.
	# Keep it reachable from the shipped menu without replacing formal actors.
	get_tree().paused = false
	if is_instance_valid(home_scene): home_scene.set_input_blocked(true)
	_open_player_presentation_scene.call_deferred()

func _open_player_presentation_scene() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/dev/player_presentation_01/weapon_feel_v2.tscn")
	if error != OK:
		push_error("Player presentation sample could not be opened: " + str(error))
		menu.show_home()
		if is_instance_valid(home_scene): home_scene.set_input_blocked(false)

func _open_action_studio() -> void:
	if director.state != DemoRunDirector.State.HOME or is_instance_valid(_action_studio): return
	_remove_home_scene()
	menu.hide_home()
	_action_studio = preload("res://scenes/demo/action_studio.tscn").instantiate()
	_action_studio.configure(_session_input)
	_action_studio.home_requested.connect(func() -> void:
		_action_studio.queue_free()
		_action_studio = null
		_show_home())
	add_child(_action_studio)

func _begin_core_reward() -> bool:
	if not lifetime.accepts(_reward_token) or controller.actor_resources.health.terminal: return false
	if not campaign.begin_reward(active_region_id,_reward_token): return false
	_progression_token = _reward_token.copy()
	controller.router.clear("core_ability_choice")
	controller.air_focus_ability.stop()
	get_tree().paused = true
	progression_modal.show_abilities(campaign.offers(),active_region_id == &"thorn_forest")
	return true

func _select_core_ability(id: StringName) -> void:
	if not lifetime.accepts(_progression_token) or controller.actor_resources.health.terminal: return
	if not campaign.claim(id,_progression_token,true): return
	if not controller.traversal.grant(id): return
	print("FOREST_UI_EVENT " + JSON.stringify({"event":"ability_selected","ability":String(id),"source_region":String(active_region_id),"token":_progression_token.key()}))
	director.manifest.enable_campaign()
	director.manifest.record_output(director.stage_index,&"core_ability_reward",{"ability":String(id),"source_region":String(active_region_id),"abilities":Array(campaign.abilities)})
	if campaign.phase == RunCampaignProgression.Phase.REGION_CHOICE: progression_modal.show_regions()
	else: progression_modal.show_boundary()

func _select_next_region(id: StringName) -> void:
	if not lifetime.accepts(_progression_token) or controller.actor_resources.health.terminal: return
	if not campaign.enter_region(id,_progression_token,true): return
	print("FOREST_UI_EVENT " + JSON.stringify({"event":"region_selected","region":String(id),"token":_progression_token.key()}))
	progression_modal.close()
	controller.router.clear("region_transition")
	active_region_id = id
	region_states.clear()
	region_state = PlainsRegionState.new()
	_region_loaded_map = 0
	catalog.configure(build,&"plains")
	get_tree().paused = false
	director.continue_region(_progression_token,id,_next_id("enter_thorn_forest"),campaign.abilities)
	_progression_token = null

func _finish_campaign_boundary() -> void:
	if campaign.phase != RunCampaignProgression.Phase.BOUNDARY or not lifetime.accepts(_progression_token) or controller.actor_resources.health.terminal: return
	progression_modal.close()
	get_tree().paused = false
	director.finish_biome(_progression_token,_next_id("forest_boundary"),true)

func _open_style_lab() -> void:
	if director.state != DemoRunDirector.State.HOME or is_instance_valid(_style_lab): return
	var scene := load("res://scenes/style_exploration/style_lab.tscn") as PackedScene
	if scene == null:
		push_error("Five Style Lab scene is unavailable")
		menu.show_title()
		return
	_remove_home_scene()
	menu.hide_home()
	_style_lab = scene.instantiate()
	_style_lab.set("input_values", _session_input.duplicate(true))
	_style_lab.connect("home_requested", func() -> void:
		_style_lab.queue_free()
		_style_lab = null
		_show_home())
	add_child(_style_lab)

func _open_pixel_plains() -> void:
	if director.state!=DemoRunDirector.State.HOME or is_instance_valid(_pixel_plains):return
	_remove_home_scene()
	menu.hide_home()
	_pixel_plains=preload("res://scenes/demo/pixel_plains_preview.tscn").instantiate()
	_pixel_plains.input_values=_session_input.duplicate(true)
	_pixel_plains.home_requested.connect(func() -> void:
		_pixel_plains.queue_free()
		_pixel_plains=null
		_show_home())
	add_child(_pixel_plains)

func _open_windchime() -> void:
	if director.state != DemoRunDirector.State.HOME or is_instance_valid(_windchime_lab): return
	_remove_home_scene()
	menu.hide_home()
	_windchime_lab = preload("res://scenes/demo/windchime_lab.tscn").instantiate()
	_windchime_lab.input_values = _session_input.duplicate(true)
	_windchime_lab.home_requested.connect(func() -> void:
		_windchime_lab.queue_free()
		_windchime_lab = null
		_show_home())
	add_child(_windchime_lab)

func _open_foundation() -> void:
	if director.state != DemoRunDirector.State.HOME or is_instance_valid(_foundation_lab): return
	_remove_home_scene()
	menu.hide_home()
	_foundation_lab = preload("res://scenes/demo/blob47_lab.tscn").instantiate()
	_foundation_lab.input_values = _session_input.duplicate(true)
	_foundation_lab.home_requested.connect(func() -> void:
		_foundation_lab.queue_free()
		_foundation_lab = null
		_show_home())
	add_child(_foundation_lab)


func _uses_pixel_plains_presentation() -> bool:
	return connected_region and active_region_id == &"plains" and stage is PlainsRegionStage and not stage is ThornForestRegionStage and not _explicit_plains_candidate() and not p1_random_plains_requested and not "--p1-random-plains" in OS.get_cmdline_user_args()

func _uses_shared_region_pixel_presentation() -> bool:
	return _uses_pixel_plains_presentation() or (stage is ThornForestRegionStage and ForestBiblePresentation.enabled(stage.generated.manifest))

func _sync_region_presentation(home := false) -> void:
	# Select presentation from the assembled consumer, including a reused player
	# crossing from Plains to Forest. This owns no movement or ability state.
	var plains := not home and _uses_pixel_plains_presentation()
	var pixel := not home and _uses_shared_region_pixel_presentation()
	var parallax := get_node("PixelPlainsParallax") as PixelPlainsParallax
	# Home owns its own configured instance; avoid drawing six duplicate planes.
	parallax.visible = plains
	(get_node("PlainsBackground") as PlainsBackground).visible = not pixel and not home
	if plains: parallax.origin = stage.spawn
	var avatar := get_meta("avatar_presentation",null) as Node
	if is_instance_valid(avatar):
		var selector_layer := avatar.get_node_or_null("AvatarSelectorLayer") as CanvasLayer
		if selector_layer != null: selector_layer.visible = false
	if home or not is_instance_valid(player): return
	var visual := player.get_node_or_null("PixelPlainsActor") as PixelPlainsActor
	if pixel and visual == null:
		visual = PlayerPresentationRuntime.make_body(player, controller, "PixelPlainsActor", avatar_selection_id)
		player.add_child(visual)
	elif not pixel and visual != null:
		PlayerPresentationRuntime._remove(player, "MotionFeel")
		PlayerPresentationRuntime._remove(player, "WeaponFeel")
		player.remove_child(visual)
		visual.queue_free()
	var courier := player.get_node("CourierVisual") as CanvasItem
	var feedback := player.get_node("PlayerFeedback") as CanvasItem
	player.get_node("PlayerVisualAdapter").process_mode = Node.PROCESS_MODE_DISABLED if pixel else Node.PROCESS_MODE_INHERIT
	courier.visible = not pixel
	feedback.visible = not pixel
	for child: Node in player.get_children():
		if child.has_meta("avatar_presentation_owned") and child is CanvasItem:
			(child as CanvasItem).visible = not pixel
			if not pixel: courier.hide()
	# The source-art selector is session-only; rebind after pixel disposal so a
	# deliberate alternate avatar can be restored on non-pixel consumers.
	if is_instance_valid(avatar): avatar.call("bind_player",player)

# Local discoveries use the shared post-damage action queue, just like caches.
func _forest_reader_open() -> bool:
	return stage is ThornForestRegionStage and is_instance_valid((stage as ThornForestRegionStage).discoveries) and (stage as ThornForestRegionStage).discoveries.is_open()

func _bind_forest_discoveries() -> bool:
	if not stage is ThornForestRegionStage: return true
	var forest := stage as ThornForestRegionStage
	if ForestBiblePresentation.enabled(forest.generated.manifest):
		ForestBibleActors.install(forest, forest.generated.manifest, forest.enemies, forest.enemy_manifest)
		forest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		forest.assembler.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		forest.ambience = ForestBibleAmbience.new()
		forest.add_child(forest.ambience)
		forest.ambience.configure(forest.generated.manifest, player, _reduced_effects)
		forest.near_scenery = ForestBibleNearScenery.new()
		forest.add_child(forest.near_scenery)
		forest.move_child(forest.near_scenery, forest.assembler.get_index()+1)
		if not forest.near_scenery.configure(forest.generated.manifest, player, _reduced_effects):
			return false
	var rows: Array = forest.generated.manifest.get("forest_discoveries", [])
	if rows.is_empty(): return true
	var reader := ForestBibleDiscoveries.new()
	forest.add_child(reader)
	if not reader.configure(rows, region_state, lifetime, controller.actor_resources.health, wallet, rewards):
		push_error("Recorded forest discoveries rejected")
		return false
	forest.discoveries = reader
	reader.opened.connect(func() -> void:
		if is_instance_valid(stage) and stage == forest and lifetime.active: _pause_for_menu())
	reader.closed.connect(func() -> void:
		if not is_instance_valid(stage) or stage != forest or not lifetime.active or _stage_pending: return
		if is_instance_valid(controller): controller.router.clear("forest_reader_close")
		_resume_exit_input()
		if director.state == DemoRunDirector.State.IN_STAGE: get_tree().paused = false)
	reader.confirm_requested.connect(func() -> void:
		if not is_instance_valid(stage) or stage != forest or not lifetime.active: return
		controller.router.clear("forest_reader_confirm")
		get_tree().paused = false
		if not _queue_action(_commit_forest_discovery.bind(reader)) and reader.is_open(): _pause_for_menu())
	reader.acquired.connect(func(receipt: Dictionary) -> void:
		if not is_instance_valid(stage) or stage != forest or not lifetime.active: return
		director.manifest.record_output(director.stage_index, StringName("forest_discovery/" + str(receipt.id)), receipt)
		(forest.assembler as ThornForestRegionAssembler).resolve_reward_shortcuts()
		GameAudio.cue(self, &"confirm")
		_shown_actions = ""
		forest.queue_redraw())
	return true

func _commit_forest_discovery(reader: ForestBibleDiscoveries) -> bool:
	if not is_instance_valid(reader) or not stage is ThornForestRegionStage or (stage as ThornForestRegionStage).discoveries != reader: return false
	return reader.commit_pending(player.global_position)

# An optional readable find must never monopolize a co-located cache action.
func _request_forest_discovery() -> void:
	_queue_action(_open_forest_discovery)

func _open_forest_discovery() -> bool:
	if not _can_interact() or not stage is ThornForestRegionStage: return false
	var reader := (stage as ThornForestRegionStage).discoveries
	return is_instance_valid(reader) and reader.interact(player.global_position, lifetime.token())
