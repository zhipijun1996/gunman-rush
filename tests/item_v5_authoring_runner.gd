extends SceneTree
## Authoring uses production composition and real paused equipment transactions.
## Original baseline was captured by Godot from d9445c0 before this refactor.
const EQUIP := preload("res://tests/gear_inventory_support.gd")
var checks := 0
var failures := 0
var base: Dictionary
var policy: Dictionary
var fixture: RefCounted
var actor: PlayerController
var build: BuildState

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ITEM V5 AUTHORING FAILURE: "+label)

func get_definition(items: Array[ItemDefinition], id: StringName) -> ItemDefinition:
	for item: ItemDefinition in items:
		if item.stable_id == id: return item
	return null

func reject(authoring: Dictionary, label: String) -> void:
	check(ItemCatalogV5.compose_catalog(base,authoring).is_empty() and ItemCatalogV5.from_payload(base,authoring).is_empty(),label)

func same_baseline() -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/item_v5_authoring_baseline.json"))
	var items := ItemCatalogV5.all_items()
	check(items.size() == 72 and original.items.size() == 72,"default production catalog retains the complete original workbook set")
	for item: ItemDefinition in items:
		var previous: Dictionary = original.items[String(item.stable_id)]
		check(item.fingerprint() == previous.fingerprint,"original full runtime fingerprint unchanged: "+String(item.stable_id))
		check(String(item.icon_key) == previous.icon_key,"original icon identity unchanged: "+String(item.stable_id))
	check(ItemCatalogV5.from_payload(base,policy).size() == 72,"fixtures use the same production composition admission")

func invalid_edits() -> void:
	for value: Variant in ["1",true,0,2,1.5]:
		var p := policy.duplicate(true)
		p.schema_version = value
		reject(p,"authoring schema version has strict numeric whole-one type: "+str(value))
	var p := policy.duplicate(true)
	p.extra_root_field = true
	reject(p,"unknown root fields do not silently disappear")
	p = policy.duplicate(true)
	p.metadata.erase("B11")
	reject(p,"missing source metadata is rejected rather than defaulting category")
	p = policy.duplicate(true)
	p.metadata.unknown = p.metadata.B11.duplicate(true)
	reject(p,"unknown metadata IDs cannot register unimplemented definitions")
	for id: String in ["B25","missing"]:
		p = policy.duplicate(true)
		p.overrides[id] = {"shop_price":30}
		reject(p,"unknown or deleted override is rejected: "+id)
	for patch: Dictionary in [{"stable_id":"CHANGED"},{"parameter_contract":{}},{"typo_price":5},{},{"effect_parameters":{"misspelled_hp":2}},{"runtime_metadata":{"callback":"code"}}]:
		p = policy.duplicate(true)
		p.overrides["B11"] = patch
		reject(p,"unknown/empty/structural override is rejected: "+str(patch))
	for value: Variant in [0,-1,1.5,"30",true,NAN,INF]:
		p = policy.duplicate(true)
		p.overrides["B11"] = {"shop_price":value}
		reject(p,"invalid price cannot be partially committed: "+str(value))
	for patch: Dictionary in [{"gear_cost":6},{"gear_cost":1.5},{"max_level":2},{"display_name":""},{"rarity":"SILVER"},{"definition_version":0},{"definition_version":true},{"effect_parameters":{"max_hp_add_by_level":[1,2]}},{"effect_parameters":{"max_hp_add_by_level":[1,NAN,3]}}]:
		p = policy.duplicate(true)
		p.overrides["B11"] = patch
		reject(p,"runtime definition validation remains mandatory: "+str(patch))
	for metadata: Dictionary in [{"appearance_weight":-1},{"appearance_weight":NAN},{"channel":"UNKNOWN"},{"tags":["item_v5","item_v5"]},{"tags":["item_v5",false]},{"required_tags":["bad-tag"]},{"required_weapon_id":7}]:
		p = policy.duplicate(true)
		p.overrides["B11"] = {"runtime_metadata":metadata}
		reject(p,"category metadata validates before any definitions escape: "+str(metadata))
	for entry: Dictionary in [{"id":"B04","metadata":{"tags":["item_v5","active"]}},{"id":"P24","metadata":{"tags":["item_v5"]}},{"id":"B04","metadata":{"channel":"ACTIVE"}}]:
		p = policy.duplicate(true)
		p.overrides[entry.id] = {"runtime_metadata":entry.metadata}
		reject(p,"designer patches cannot forge or remove implemented component roles: "+str(entry))
	for disabled: Array in [["missing"],["B25"],["B11","B11"],[true]]:
		p = policy.duplicate(true)
		p.disabled_ids = disabled
		reject(p,"disabled list refuses unknown, deleted, duplicate or nonstring IDs: "+str(disabled))

func added_row() -> Dictionary:
	var parameters := {"max_hp_add":2}
	return {"stable_id":"CUSTOM_HEART","display_name":"配置心匣","rarity":"BLUE","gear_cost":1,"shop_price":12,"max_level":1,"description":"测试配置：最大生命+2，不补当前生命。","definition_version":1,"effect_parameters":parameters,"parameter_contract":{"required_keys":["max_hp_add"],"positive_keys":["max_hp_add"],"integer_keys":["max_hp_add"],"zero_allowed_keys":[],"text_modes":{},"reject_unknown_keys":true,"schema_source_sha256":"fixture static authoring schema v1".sha256_text()},"runtime_metadata":policy.metadata.B11.duplicate(true)}

func addition_guards() -> void:
	var p := policy.duplicate(true)
	p.additions = [added_row()]
	check(ItemCatalogV5.from_payload(base,p).size() == 73,"one new generic stat definition registers through data only")
	for id: String in ["B11","B25","bad-id","../bad"]:
		var row := added_row()
		row.stable_id = id
		p = policy.duplicate(true)
		p.additions = [row]
		reject(p,"new content cannot collide, resurrect tombstones or escape IDs: "+id)
	p = policy.duplicate(true)
	p.additions = [added_row(),added_row()]
	reject(p,"duplicate custom stable ID is rejected atomically")
	var row := added_row()
	row.effect_parameters = {"primary_damage_multiplier":1.2}
	p = policy.duplicate(true)
	p.additions = [row]
	reject(p,"new complex runtime mechanism cannot silently register without a component")
	for metadata: Dictionary in [{"channel":"ACTIVE"},{"tags":["item_v5","active"]},{"tags":["item_v5","companion"]}]:
		row = added_row()
		row.runtime_metadata.merge(metadata,true)
		p = policy.duplicate(true)
		p.additions = [row]
		reject(p,"new static definition cannot advertise a nonexistent complex behavior: "+str(metadata))
	row = added_row()
	row.effect_parameters.max_hp_add = "foo"
	row.parameter_contract.positive_keys = []
	row.parameter_contract.integer_keys = []
	row.parameter_contract.text_modes = {"max_hp_add":["foo"]}
	p = policy.duplicate(true)
	p.additions = [row]
	reject(p,"a numeric static parameter cannot disguise itself as an allowed text mode")
	for malformed: Dictionary in [{"stable_id":"BAD"},{"stable_id":"BAD","runtime_metadata":4}]:
		p = policy.duplicate(true)
		p.additions = [malformed]
		p.overrides["BAD"] = {"shop_price":30}
		reject(p,"incomplete additions with overrides reject without a script error: "+str(malformed))
	row = added_row()
	row.effect_script = "res://unregistered.gd"
	p = policy.duplicate(true)
	p.additions = [row]
	reject(p,"authoring never loads executable script paths")

func actual_equipment() -> void:
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.set("tree",self)
	await fixture.call("fixture",Vector2(80,20))
	actor = fixture.get("controller") as PlayerController
	build = BuildState.new()
	build.configure(actor,DemoLifetime.new(),&"authoring_fixture")
	var p := policy.duplicate(true)
	p.overrides["B11"] = {"effect_parameters":{"max_hp_add_by_level":[2,3,4]},"shop_price":31,"definition_version":6}
	var source_before := JSON.stringify(base)
	var policy_before := JSON.stringify(p)
	var items := ItemCatalogV5.from_payload(base,p)
	var edited := get_definition(items,&"B11")
	check(edited != null and edited.parameters_for_level(1).max_hp_add == 2 and edited.shop_price == 31 and edited.definition_version == 6,"partial edits produce the intended real definition and explicit version")
	if edited == null:
		await finish_fixture()
		return
	check(JSON.stringify(base) == source_before and JSON.stringify(p) == policy_before,"composition never mutates workbook source or author input")
	check(ItemPresentation.effects(edited,1).contains("最大生命 +2"),"known item description uses the edited actual level value")
	check(ItemPresentation.effects(ItemCatalogV5.get_item(&"B03"),1) == "主武器直接伤害 ×1.12；技能及派生伤害不重复加成。","existing item-specific presentation remains unchanged")
	check(build.add_item(&"edited",edited) and actor.actor_resources.health.capacity == 5,"edited rewards remain owned without automatic effects")
	var sources: Array[StringName] = [&"edited"]
	check(EQUIP.equip_sources(build,sources) and actor.actor_resources.health.capacity == 7 and actor.actor_resources.health.current == 5,"edited parameter actually changes equipped HP without healing")
	var none: Array[StringName] = []
	check(EQUIP.equip_sources(build,none) and actor.actor_resources.health.capacity == 5,"unload retracts edited effects from real state")
	check(EQUIP.equip_sources(build,sources) and actor.actor_resources.health.capacity == 7 and actor.actor_resources.health.current == 5,"reequip rebuilds edited stat without stacking or healing")
	edited.effect_parameters.max_hp_add_by_level[0] = 90
	check(build.inventory.instance_for_source(&"edited").item.parameters_for_level(1).max_hp_add == 2,"returned authoring resources cannot mutate owned definitions")
	check(ItemCatalogV5.get_item(&"B11").parameters_for_level(1).max_hp_add == 1,"isolated edits cannot mutate production canonical parameters")
	build.clear()
	p = policy.duplicate(true)
	p.additions = [added_row()]
	var custom := get_definition(ItemCatalogV5.from_payload(base,p),&"CUSTOM_HEART")
	check(custom != null,"generic static fixture resolves a real definition")
	if custom == null:
		await finish_fixture()
		return
	custom.description = "故意过期的作者文字：最大生命+999"
	check(ItemPresentation.effects(custom,1).contains("最大生命 +2") and not ItemPresentation.effects(custom,1).contains("999"),"new static item description renders real parameters rather than stale prose")
	var growth := added_row()
	growth.max_level = 3
	growth.effect_parameters = {"max_hp_add_by_level":[1,2,3]}
	growth.parameter_contract.required_keys = ["max_hp_add_by_level"]
	growth.parameter_contract.positive_keys = ["max_hp_add_by_level"]
	growth.parameter_contract.integer_keys = ["max_hp_add_by_level"]
	p.additions = [growth]
	var grown := get_definition(ItemCatalogV5.from_payload(base,p),&"CUSTOM_HEART")
	check(grown != null and ItemPresentation.effects(grown,3).contains("最大生命 +3") and not ItemPresentation.effects(grown,3).contains("+1"),"new growing static definition displays the actual selected level without an ID-specific UI branch")
	check(build.add_item(&"custom",custom),"new static item enters real inventory without equipment core edits")
	sources = [&"custom"]
	check(EQUIP.equip_sources(build,sources) and actor.actor_resources.health.capacity == 7 and actor.actor_resources.health.current == 5,"new data-only item actually applies generic HP mapping")
	check(EQUIP.equip_sources(build,none) and actor.actor_resources.health.capacity == 5,"new data-only item's effect fully retracts")
	build.clear()
	p = policy.duplicate(true)
	p.disabled_ids = ["B11"]
	var disabled := get_definition(ItemCatalogV5.from_payload(base,p),&"B11")
	check(disabled != null and disabled.is_valid() and disabled.appearance_weight == 0,"disabled definition stays canonical and addressable with zero drop weight")
	# Use the real pool with a local factory, never edit global source files.
	var pool := ItemV5Pool.new()
	p.additions = [added_row()]
	p.disabled_ids = p.metadata.keys()
	var provider := ItemCatalogV5.from_payload.bind(base,p)
	pool.configure(build,provider)
	var eligible := pool.eligible_items()
	check(eligible.size() == 1 and eligible[0].stable_id == &"CUSTOM_HEART","actual reward/shop eligibility omits disabled base definitions while admitting the new item")
	var offer := pool.generate("authoring-fixture",&"authoring/offer",1)
	check(bool(offer.accepted) and offer.items.size() == 1 and offer.items[0].stable_id == &"CUSTOM_HEART","real seeded pool successfully offers the new data-only definition")
	check(bool(offer.accepted) and offer.manifest.selected[0].definition_version == 1 and offer.manifest.selected[0].appearance_weight == 1,"actual pool manifest records authored version and weight")
	pool.configure(build,provider)
	check(not pool.manifest_for(&"authoring/offer").is_empty(),"same build and same factory keep the original immutable offer")
	p.additions[0].effect_parameters.max_hp_add = 3
	var replay := pool.generate("authoring-fixture",&"authoring/offer",1)
	check(bool(replay.accepted) and replay.items[0].parameters_for_level(1).max_hp_add == 2,"reopening an existing offer cannot reroll after authoring factory data changes")
	var later := pool.generate("authoring-fixture",&"authoring/later",1)
	check(bool(later.accepted) and later.items[0].parameters_for_level(1).max_hp_add == 3,"a new offer takes a fresh authored definition snapshot")
	pool.configure(build,ItemCatalogV5.from_payload.bind(base,policy))
	check(pool.manifest_for(&"authoring/offer").is_empty(),"explicitly changing the catalog factory invalidates its old offer authority")
	pool.configure(build,Callable(self,"_missing_factory"))
	check(pool.eligible_items().is_empty(),"an expired or invalid configured factory fails closed instead of falling back to another catalog")
	pool = null
	check(build.add_item(&"disabled_owned",disabled),"disabling availability is independent of owned-instance validity")
	cli_proposal()
	await finish_fixture()

func finish_fixture() -> void:
	if build != null: build.clear()
	if fixture != null:
		var world := fixture.get("world") as Node
		if is_instance_valid(world): world.free()
	actor = null
	build = null
	fixture = null
	await process_frame

func cli_proposal() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--authoring-addition-proposal=") or argument.begins_with("--authoring-disable-proposal="):
			cli_addition_proposal(argument)
			continue
		if not argument.begins_with("--authoring-proposal="): continue
		var path := argument.trim_prefix("--authoring-proposal=")
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(value is Dictionary,"explicit real CLI proposal is readable JSON")
		if not value is Dictionary: return
		var edited := get_definition(ItemCatalogV5.from_payload(base,value),&"B11")
		check(edited != null and edited.parameters_for_level(1).max_hp_add == 2,"actual CLI output reaches the production definition factory")
		build.clear()
		check(build.add_item(&"cli/edited",edited),"actual CLI definition reaches authoritative owned inventory")
		var sources: Array[StringName] = [&"cli/edited"]
		check(EQUIP.equip_sources(build,sources) and actor.actor_resources.health.capacity == 7 and actor.actor_resources.health.current == 5,"actual CLI parameter edits change real equipped HP")
		var none: Array[StringName] = []
		check(EQUIP.equip_sources(build,none) and actor.actor_resources.health.capacity == 5,"CLI-produced effect retracts on real unload")

func cli_addition_proposal(argument: String) -> void:
	var disabling := argument.begins_with("--authoring-disable-proposal=")
	var path := argument.trim_prefix("--authoring-disable-proposal=") if disabling else argument.trim_prefix("--authoring-addition-proposal=")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(value is Dictionary,"actual CLI addition/disable proposal is readable JSON")
	if not value is Dictionary: return
	var definitions := ItemCatalogV5.from_payload(base,value)
	var custom := get_definition(definitions,&"EXTRA_HEART")
	check(custom != null and custom.parameters_for_level(1).max_hp_add == 2,"actual CLI addition registers the new static definition in the production loader")
	check(custom != null and ItemPresentation.effects(custom).contains("最大生命 +2"),"actual CLI addition displays its resolved stat without another UI branch")
	if custom == null: return
	build.clear()
	check(build.add_item(&"cli/extra",custom),"actual CLI-added item enters authoritative inventory")
	var sources: Array[StringName] = [&"cli/extra"]
	check(EQUIP.equip_sources(build,sources) and actor.actor_resources.health.capacity == 7 and actor.actor_resources.health.current == 5,"actual CLI-added item changes real equipped HP without healing")
	var none: Array[StringName] = []
	check(EQUIP.equip_sources(build,none) and actor.actor_resources.health.capacity == 5,"actual CLI-added item fully retracts through original equipment transaction")
	if disabling:
		var disabled := get_definition(definitions,&"B11")
		check(disabled != null and disabled.appearance_weight == 0,"actual CLI disable retains canonical owned definition with zero offer weight")
		build.clear()
		var pool := ItemV5Pool.new()
		pool.configure(build,ItemCatalogV5.from_payload.bind(base,value))
		check(get_definition(pool.eligible_items(),&"B11") == null,"actual CLI-disabled item is excluded by the real offer pool")
		check(get_definition(pool.eligible_items(),&"EXTRA_HEART") != null,"actual CLI disable leaves unrelated new content eligible")
		pool = null

func run() -> void:
	base = JSON.parse_string(FileAccess.get_file_as_string(ItemCatalogV5.CONFIG_PATH))
	policy = JSON.parse_string(FileAccess.get_file_as_string(ItemCatalogV5.AUTHORING_PATH))
	same_baseline()
	invalid_edits()
	addition_guards()
	await actual_equipment()
	print("ITEM V5 AUTHORING: %s checks, %s failures" % [checks,failures])
	quit(1 if failures else 0)
