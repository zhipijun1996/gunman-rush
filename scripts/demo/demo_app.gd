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
var _actions: HBoxContainer
var _pause_button: Button
var _boss_status: Label
var _windkeeper_hud: WindkeeperHud
var _shown_actions := ""
var exit_modal: EXIT_MODAL
var _offered_exit: StringName = &""
var _exit_prompt_token: DemoToken
var _dismissed_exits: Dictionary = {}
var reward_modal: StageRewardModal
var _pending_exit: StringName = &""
var _reward_token: DemoToken

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(GameAudio.new())
	process_physics_priority = 900
	lifetime.end() # TITLE/Home do not own an active Run token.
	var backdrop := PixelPlainsParallax.new()
	backdrop.name = "PixelPlainsParallax"
	add_child(backdrop)
	director.stage_entered.connect(_stage_entered)
	director.run_ended.connect(_run_ended)
	if meta_persistence_enabled:
		meta.configure_persistence("user://plains_meta.json")
	_make_ui()
	_refresh_home_meta()
	_hide_run_hud()
	menu.show_title()
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

func start_plains(seed_value: String = "plains-run") -> bool:
	_debug_region = &""
	return start_demo(seed_value, true)


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
