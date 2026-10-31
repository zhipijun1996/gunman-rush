class_name RunSession
extends RefCounted
## Owns one App's run services and the existing flow authority. Reused across
## departures so Lifetime epochs remain monotonic and old tokens stay stale.
## Scene nodes retain their original parents; this object owns their references.
var flow := DemoRunDirector.new()
var lifetime: DemoLifetime:
	get: return flow.lifetime
var receipt_prefix := ""
var player: PlayerMotor
var controller: PlayerController
var build: BuildState
var wallet: RunWallet
var rewards: RewardService
var shop: ShopService
var item_runtime: ItemRuntime
var item_pool: ItemV5Pool
var catalog := DemoRewardCatalog.new()
var campaign := RunCampaignProgression.new()
var region_state: PlainsRegionState
var region_states: Dictionary = {}
var loaded_map := 0

func reset_campaign(debug_entry := false, grant_forest_access := false) -> void:
	campaign = RunCampaignProgression.new()
	campaign.debug_entry = debug_entry
	if grant_forest_access: campaign.abilities.append(&"grapple")

func reset_maps(connected: bool) -> void:
	region_state = PlainsRegionState.new() if connected else null
	region_states.clear()
	loaded_map = 0

func select_map_state(stage_index: int) -> void:
	loaded_map = stage_index
	region_state = region_states.get(loaded_map, PlainsRegionState.new())
	region_states[loaded_map] = region_state

func create_run_services(catalog_biome: StringName, connected: bool) -> void:
	build = BuildState.new()
	build.configure(controller, lifetime, StringName(receipt_prefix))
	catalog.configure(build, catalog_biome, connected)
	wallet = RunWallet.new()
	rewards = RewardService.new()
	rewards.configure(lifetime, build)
	shop = ShopService.new()
	shop.configure(lifetime, build, wallet)

# Called after the existing reward/shop signal bindings, preserving startup order.
func create_item_services(enabled: bool) -> void:
	if enabled:
		item_runtime = ItemRuntime.new()
		item_runtime.configure(controller, build, lifetime, wallet)
		item_pool = ItemV5Pool.new()
		item_pool.configure(build)
	else:
		item_runtime = null
		item_pool = null

func end_summary() -> Dictionary:
	return {"stage": flow.stage_index, "items": build.inventory.item_ids(), "equipped_items": build.item_ids(), "run_coins_discarded": wallet.balance, "seed": flow.seed}

func clear_run_services() -> void:
	# Keep the cleared objects observable after Home, as existing App consumers
	# require. A later departure replaces them with fresh run-owned services.
	build.clear()
	wallet.balance = 0

func release_player_references() -> void:
	player = null
	controller = null
