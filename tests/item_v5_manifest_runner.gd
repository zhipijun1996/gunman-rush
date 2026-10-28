extends SceneTree
## Real Player/BuildState and actual region-generator/RunManifest transactions.
## Known catalog grants, explicit break/repair and isolated actor placement are
## setup fixtures; this verifies content reconstruction, not a resume/save engine.
const EQUIP := preload("res://tests/gear_inventory_support.gd")
const SOURCE_FIELDS := ["item_sources_version","item_sources","gear_capacity","gear_level"]
var checks := 0
var failures := 0
var fixture: RefCounted
var actor: PlayerController
var build: BuildState
var lifetime: DemoLifetime

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+label)

func own(id: StringName, source: StringName) -> bool:
	return build.add_item(source,ItemCatalogV5.get_item(id))

func equip(ids: Array[StringName]) -> bool:
	var instances: Array[StringName] = []
	for id: StringName in ids:
		var owned := build.inventory.instance_for_definition(id)
		if owned == null: return false
		instances.append(owned.instance_id)
	return EQUIP.equip_ids(build,instances)

func source_output() -> Dictionary:
	var tuning: Dictionary = {}
	var keys: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
	for key: String in keys: tuning[key] = actor.motor.tuning.get(key)
	return {"stage_tuning":tuning,"capability_snapshot":{"max_jumps":actor.motor.tuning.max_jumps,"max_air_shots":actor.motor.tuning.max_air_shots,"items":build.item_ids(),"abilities":[],"item_sources_version":1,"item_sources":build.manifest_item_sources(),"gear_capacity":build.equipment.capacity(),"gear_level":build.equipment.snapshot().level}}

func full_snapshot(output: Dictionary) -> Dictionary:
	var seed := "item-v5-current-manifest"
	var map_seed := PlainsRegionCampaign.seed_for(seed,1)
	var generator := PlainsRegionGenerator.new()
	generator.root_bell_mode = "v3"
	var generated := generator.generate(map_seed,actor.motor.tuning,false,"","intro")
	check(bool(generated.get("ok",false)),"actual current V3 region generation accepts the live equipped tuning")
	if not bool(generated.get("ok",false)): return {}
	var m: Dictionary = generated.manifest
	var manifest := RunManifest.new(seed,RunProfile.formal())
	manifest.enable_plains_region(PlainsRootBellEncounterV3.CONTENT_VERSION)
	var exits: Array[ExitOffer] = []
	manifest.append_stage(1,&"boss",&"plains",exits)
	var data := output.duplicate(true)
	data["generated_layout"] = m
	data["stage_generator"] = {"version":m.version}
	data["region_map"] = {"version":PlainsRegionCampaign.VERSION,"map_index":1,"seed":map_seed,"instance_prefix":PlainsRegionCampaign.prefix(1),"boss_role":PlainsRegionCampaign.role(1)}
	data["enemy_layout"] = {"version":m.version,"enemies":m.enemies}
	data["shot_latch_layout"] = m.shot_latch_plan
	var boss: BossDefinition = load("res://resources/bosses/bellstrider.tres")
	data["boss_layout"] = {"id":String(boss.stable_id),"version":boss.definition_version,"health":boss.health_definition.max_health}
	for key: String in data: manifest.record_output(1,StringName(key),data[key])
	return manifest.snapshot()

func rejected(output: Dictionary, label: String) -> void:
	check(RunManifest._region_tuning(output) == null,label)

func roundtrips_and_growth() -> Dictionary:
	var empty := source_output()
	check(RunManifest._region_tuning(empty) != null,"explicit V1 empty equipment reconstructs without an inventory owner in Manifest")
	var snapshot := full_snapshot(empty)
	check(not snapshot.is_empty() and RunManifest.from_snapshot(snapshot) != null,"current empty-loadout Manifest completes its actual generator/content roundtrip")
	var historical := empty.duplicate(true)
	for field: String in SOURCE_FIELDS: historical.capability_snapshot.erase(field)
	check(RunManifest._region_tuning(historical) != null,"fully absent new metadata preserves historical empty-resource reconstruction")
	var unconfigured := BuildState.new()
	var legacy: ItemDefinition = load("res://resources/items/damage_blue.tres")
	unconfigured._base[&"projectile_damage"] = actor.motor.tuning.projectile_damage
	check(unconfigured.inventory == null and unconfigured._modifiers_for(&"legacy",legacy).size() == legacy.stat_modifiers().size(),"original unconfigured BuildState legacy modifier call is null-inventory safe")
	check(is_equal_approx(unconfigured._resolve({&"legacy":legacy})[&"projectile_damage"],actor.motor.tuning.projectile_damage+.2),"null-inventory legacy resolver keeps original real-resource arithmetic")
	check(own(&"B04",&"level/one") and own(&"B11",&"backpack/health"),"canonical known item fixtures enter actual owned inventory")
	check(equip([&"B04"]),"level-one focus source equips through original session validation")
	var identity := build.inventory.instance_for_definition(&"B04").instance_id
	for level: int in range(1,4):
		if level > 1: check(own(&"B04",StringName("level/%s" % level)),"new real provenance upgrades equipped focus item to Lv%s" % level)
		var output := source_output()
		check(output.capability_snapshot.item_sources.size() == 1 and output.capability_snapshot.item_sources[0].instance_id == String(identity) and output.capability_snapshot.item_sources[0].level == level,"source metadata contains only equipped stable instance at Lv%s" % level)
		check(RunManifest._region_tuning(output) != null,"shared resolver reconstructs actual Lv%s focus drain rather than assuming Lv1" % level)
		snapshot = full_snapshot(output)
		check(not snapshot.is_empty() and RunManifest.from_snapshot(JSON.parse_string(JSON.stringify(snapshot))) != null,"current complete content Manifest JSON roundtrips real equipped Lv%s" % level)
	var final := source_output()
	var copy := build.manifest_item_sources()
	copy[0].level = 99
	check(build.inventory.get_instance(identity).level == 3 and build.manifest_item_sources()[0].level == 3,"source metadata is detached from authoritative owned growth")
	var downgrade := final.duplicate(true)
	downgrade.capability_snapshot.item_sources[0].level = 2
	rejected(downgrade,"a valid-range forged level with unchanged Lv3 stage tuning is rejected")
	return final

func tamper_guards(original: Dictionary) -> void:
	for value: Variant in [0,4,1.5,"3",true]:
		var output := original.duplicate(true)
		output.capability_snapshot.item_sources[0].level = value
		rejected(output,"malformed/out-of-range equipped level is rejected: %s" % str(value))
	for value: Variant in [0,2,1.5,"1",true]:
		var output := original.duplicate(true)
		output.capability_snapshot.item_sources_version = value
		rejected(output,"unknown/noninteger source metadata version is rejected: %s" % str(value))
	for field: String in SOURCE_FIELDS:
		var output := original.duplicate(true)
		output.capability_snapshot.erase(field)
		rejected(output,"partial versioned metadata cannot fall back to legacy: missing "+field)
	for entry: Dictionary in [{"key":"broken","value":"false"},{"key":"broken","value":0},{"key":"gear_cost","value":2},{"key":"definition_version","value":6},{"key":"catalog_version","value":4},{"key":"fingerprint","value":"forged"}]:
		var output := original.duplicate(true)
		output.capability_snapshot.item_sources[0][entry.key] = entry.value
		rejected(output,"canonical source identity/state rejects forged "+str(entry.key)+"="+str(entry.value))
	var missing := original.duplicate(true)
	missing.capability_snapshot.item_sources.clear()
	rejected(missing,"missing source for a declared equipped item is rejected")
	var extra := original.duplicate(true)
	extra.capability_snapshot.items.clear()
	rejected(extra,"extra source not declared in equipped item list is rejected")
	var repeated := original.duplicate(true)
	repeated.capability_snapshot.item_sources.append(repeated.capability_snapshot.item_sources[0].duplicate(true))
	repeated.capability_snapshot.items.append(&"B04")
	rejected(repeated,"duplicate stable instance ID is rejected")
	var duplicate := repeated.duplicate(true)
	duplicate.capability_snapshot.item_sources[1].instance_id += "/other"
	duplicate.capability_snapshot.item_sources[1].source_id += "/other"
	rejected(duplicate,"different instances cannot equip duplicate growable definition beyond canonical limit")
	for id: String in ["B99","B25","../damage_blue"]:
		var output := original.duplicate(true)
		output.capability_snapshot.item_sources[0].definition_id = id
		output.capability_snapshot.items[0] = id
		rejected(output,"unknown/deleted/path-traversal definition is rejected: "+id)
	for entry: Dictionary in [{"key":"gear_capacity","value":14},{"key":"gear_level","value":1.5},{"key":"gear_level","value":4},{"key":"max_jumps","value":99}]:
		var output := original.duplicate(true)
		output.capability_snapshot[entry.key] = entry.value
		rejected(output,"versioned capacity/capability state is checked against real policy: "+str(entry.key))
	var forged := original.duplicate(true)
	forged.stage_tuning.focus_stamina_drain += 1
	rejected(forged,"arbitrary edited stage tuning remains forbidden with valid item metadata")
	var legacy_v5 := original.duplicate(true)
	for field: String in SOURCE_FIELDS: legacy_v5.capability_snapshot.erase(field)
	rejected(legacy_v5,"missing V5 source metadata never invents a legacy resource or default V5 level")

func broken_and_exclusive() -> void:
	check(own(&"B30",&"fragile/one") and equip([&"B04",&"B30"]),"fragile HP item is actually owned and equipped alongside focus")
	check(actor.actor_resources.health.capacity == 8,"actual equipped fragile source adds three maximum HP")
	var owned := build.inventory.instance_for_definition(&"B30")
	check(build.inventory.patch_effect_state(owned.instance_id,{"broken":true,"damage_hits":3},&"fixture_break") and build.refresh_equipped(),"explicit owned broken fixture refreshes real equipped static effects")
	check(actor.actor_resources.health.capacity == 5 and build.equipment.snapshot().used == 5,"broken source retracts real HP modifier but still consumes its four gear slots")
	var output := source_output()
	var reconstructed: Dictionary = RunManifest._manifest_source_modifiers(output.capability_snapshot,output.capability_snapshot.items)
	check(reconstructed.has(owned.instance_id) and (reconstructed[owned.instance_id] as Array).is_empty(),"Manifest shared resolver retains broken source identity while retracting all of its modifiers")
	check(RunManifest._region_tuning(output) != null and RunManifest.from_snapshot(full_snapshot(output)) != null,"broken equipped item survives actual current content roundtrip with its effects removed")
	check(own(&"G11",&"immortal/one") and equip([&"G11"]),"independent canonical exclusive source can be captured from a legal real loadout")
	var immortal := build.manifest_item_sources()[0]
	var conflicting := output.duplicate(true)
	conflicting.capability_snapshot.item_sources.append(immortal)
	var rows: Array = conflicting.capability_snapshot.item_sources
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	conflicting.capability_snapshot.items.clear()
	for row: Dictionary in rows: conflicting.capability_snapshot.items.append(row.definition_id)
	rejected(conflicting,"mutually exclusive canonical items remain forbidden even when one source is broken")
	check(equip([&"B04",&"B30"]) and build.inventory.patch_effect_state(owned.instance_id,{"broken":false,"damage_hits":0},&"fixture_repair") and build.refresh_equipped(),"explicit repair fixture uses owned state and rebuilds original equipped modifiers")
	check(actor.actor_resources.health.capacity == 8 and actor.actor_resources.health.current == 5 and RunManifest._region_tuning(source_output()) != null,"repair reconstructs HP capacity without granting current healing")

func legacy_and_capacity() -> void:
	var legacy: ItemDefinition = load("res://resources/items/damage_blue.tres")
	check(build.add_item(&"legacy/a",legacy) and build.add_item(&"legacy/z",legacy),"legal repeated legacy definition creates two distinct real owned instances")
	var rows: Array[Dictionary] = []
	for source: StringName in [&"legacy/a",&"legacy/z"]:
		check(EQUIP.equip_sources(build,[source]),"one legacy five-slot instance can equip independently")
		rows.append(build.manifest_item_sources()[0])
	var output := source_output()
	check(RunManifest._region_tuning(output) != null,"versioned canonical legacy modifiers reconstruct without losing definition version")
	var old := output.duplicate(true)
	for field: String in SOURCE_FIELDS: old.capability_snapshot.erase(field)
	check(RunManifest._region_tuning(old) != null,"old canonical legacy path preserves its original modifier and stack checks")
	var cap: Dictionary = output.capability_snapshot.duplicate(true)
	cap.item_sources = rows
	cap.items = [legacy.stable_id,legacy.stable_id]
	check(RunManifest._manifest_source_modifiers(cap,cap.items) == null,"two legal five-slot legacy sources are refused at eight capacity independently of tuning")
	cap.gear_level = 1
	cap.gear_capacity = 10
	check(RunManifest._manifest_source_modifiers(cap,cap.items) is Dictionary,"same ten-slot sources fit exactly the real configured first expansion")
	cap.item_sources[0].gear_cost = 1
	check(RunManifest._manifest_source_modifiers(cap,cap.items) == null,"declared cheap gear cost cannot override the canonical five-slot definition")

func run() -> void:
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.set("tree",self)
	await fixture.call("fixture",Vector2(80,20))
	actor = fixture.get("controller") as PlayerController
	# The shared combat helper deliberately installs a historical two-air-shot
	# fixture. Content reconstruction binds today's actual production base.
	var defaults := PlayerTuning.load_default()
	var tuning_keys: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
	for key: String in tuning_keys: actor.motor.tuning.set(key,defaults.get(key))
	actor.action_resources.reset()
	lifetime = DemoLifetime.new()
	build = BuildState.new()
	build.configure(actor,lifetime,&"manifest_fixture")
	var level_three := roundtrips_and_growth()
	tamper_guards(level_three)
	broken_and_exclusive()
	legacy_and_capacity()
	build.clear()
	(fixture.get("world") as Node).free()
	actor = null
	build = null
	fixture = null
	lifetime = null
	await process_frame
	print("ITEM V5 MANIFEST: %s checks, %s failures" % [checks,failures])
	quit(1 if failures else 0)
