extends SceneTree
## Isolated native profile/policy/ledger fixtures. No actual user's save is used.
## App reward acquisition, menu input and real Home movement are separate suites.
const PROFILE_A := "user://home_codex_backend_a.json"
const PROFILE_B := "user://home_codex_backend_b.json"
const MIGRATION := "user://home_codex_backend_migration.json"
const POLICY := "user://home_codex_backend_policy.json"
var assertions := 0
var failures := 0

class RejectSave:
	extends MetaSaveService
	func commit(_payload: Dictionary, _revision: int) -> bool:
		status = "fixture_storage_rejected"
		return false

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func clean(path: String) -> void:
	for suffix: String in ["", ".backup", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)

func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		check(false,"fixture file can be opened: " + path)
		return
	file.store_string(text)
	file.close()

func policy(discovered_required: bool = true) -> Dictionary:
	return {"schema_version":1,"version":1,"requires_discovered":discovered_required,"default_note_prices":{"BLUE":5,"PURPLE":12,"GOLD":25},"items":{},"home_enabled_blacklist":[]}

func write_policy(value: Dictionary) -> void:
	write_text(POLICY,JSON.stringify(value))

func funded(amount: int = 100) -> MetaProgression:
	var meta := MetaProgression.new(POLICY)
	check(meta.grant_notes(amount,&"fixture/notes").accepted,"explicit isolated permanent-note fixture funds the profile")
	return meta

func state(meta: MetaProgression) -> String:
	return MetaSaveService.canonical_json(meta._payload())

func acquisitions_and_unlocks() -> void:
	write_policy(policy())
	var meta := funded()
	var quote := meta.home_item_quote(&"B11")
	check(not quote.discovered and not quote.unlocked and not quote.available and quote.reason == "requires_discovered","unknown item is not eligible for discovered-first unlock")
	check(quote.price == 5 and meta.home_item_quote(&"P24").price == 12 and meta.home_item_quote(&"G05").price == 25,"rarity trial prices are actually read from policy data")
	var initial := state(meta)
	check(not meta.unlock_home_item(&"B11",&"before_discovery").accepted and state(meta) == initial,"unlock before discovery cannot debit or mutate the profile")
	check(meta.discover_item(&"B11",&"actual_committed_reward").accepted,"explicit committed-reward caller records first discovery")
	check(meta.snapshot().discovered_items == ["B11"] and meta.snapshot().unlocked_home_items.is_empty(),"discovery changes a set and does not grant permanent unlock")
	var revision: int = int(meta.snapshot().profile_revision)
	var receipt_count: int = meta._payload().receipts.size()
	for index: int in 12:
		check(meta.discover_item(&"B11",StringName("known_source_%s" % index)).accepted,"already discovered ID remains an idempotent set operation")
	check(meta._payload().receipts.size() == receipt_count and meta.snapshot().profile_revision == revision,"later acquisitions do not create an unbounded discovery receipt log")
	check(meta.discover_item(&"B11",&"actual_committed_reward").replayed,"exact first-discovery receipt replays")
	initial = state(meta)
	check(not meta.discover_item(&"B03",&"actual_committed_reward").accepted and state(meta) == initial,"same committed receipt cannot discover another item")
	check(not meta.discover_item(&"missing",&"unknown_discovery").accepted and state(meta) == initial,"new unknown definition is not accepted as discovery")
	quote = meta.home_item_quote(&"B11")
	var price: int = int(quote.price)
	check(quote.can_unlock and quote.available and not quote.can_select,"discovered item exposes a usable permanent unlock quote")
	check(meta.unlock_home_item(&"B11",&"unlock_one",int(quote.profile_revision),String(quote.quote_fingerprint)).accepted,"real notes debit and unlock commit together")
	check(meta.snapshot().notes == 100-price and meta.snapshot().unlocked_home_items == ["B11"],"unlock commits exact policy price and only the requested stable ID")
	check(meta.snapshot().selected_home_item == "","unlock does not automatically select or grant an item")
	check(meta.unlock_home_item(&"B11",&"unlock_one",int(quote.profile_revision),String(quote.quote_fingerprint)).replayed and meta.snapshot().notes == 100-price,"same purchase receipt replays read-only despite a later profile revision")
	initial = state(meta)
	check(not meta.unlock_home_item(&"B03",&"unlock_one",int(quote.profile_revision),String(quote.quote_fingerprint)).accepted and state(meta) == initial,"same purchase receipt with a different item conflicts without debit")
	check(meta.unlock_home_item(&"B11",&"second_purchase").accepted and state(meta) == initial,"already unlocked item never consumes notes or writes another purchase")
	check(meta.select_home_item(&"B11",&"select_one").accepted and meta.snapshot().selected_home_item == "B11","one unlocked ID can be selected without a grant or notes cost")
	check(meta.select_home_item(&"B11",&"select_one").replayed and meta.snapshot().notes == 100-price,"same selection receipt replays without extra permanent consumption")
	initial = state(meta)
	check(not meta.select_home_item(&"B03",&"select_locked").accepted and state(meta) == initial,"unlocked status is authoritative for carry selection")
	var rows := meta.home_item_rows()
	check(rows.size() == ItemCatalogV5.all_items().size(),"list snapshot enumerates the current definition database, without a second hardcoded item count")
	var selected_rows := 0
	for row: Dictionary in rows:
		if row.selected: selected_rows += 1
		if row.id == "B11": check(row.discovered and row.unlocked and row.available and row.item is ItemDefinition,"row API carries actual detached definition and profile flags")
	check(selected_rows == 1,"only one row is selected")
	var detached := meta.snapshot()
	detached.discovered_items.clear()
	detached.unlocked_home_items.clear()
	check(meta.snapshot().discovered_items == ["B11"] and meta.snapshot().unlocked_home_items == ["B11"],"caller snapshots cannot mutate permanent sets")
	check(meta.select_home_item(&"",&"select_none").accepted and meta.snapshot().selected_home_item == "" and meta.snapshot().notes == 100-price,"explicit empty selection clears only the preference")

func policy_stale_and_atomic_failures() -> void:
	write_policy(policy())
	var meta := funded(4)
	check(meta.discover_item(&"B11",&"seen").accepted,"insufficient balance fixture has a genuine discovered ID")
	var before := state(meta)
	check(not meta.unlock_home_item(&"B11",&"too_poor").accepted and state(meta) == before,"insufficient notes leaves both flags and balance intact")
	check(meta.grant_notes(20,&"fund_more").accepted,"separate note transaction changes profile revision")
	var quote := meta.home_item_quote(&"B11")
	check(meta.grant_notes(1,&"advance_revision").accepted,"quote staleness uses a real accepted profile mutation")
	before = state(meta)
	check(not meta.unlock_home_item(&"B11",&"old_revision",int(quote.profile_revision),String(quote.quote_fingerprint)).accepted and state(meta) == before,"old profile-revision purchase refuses atomically")
	quote = meta.home_item_quote(&"B11")
	var changed := policy()
	changed.version = 2
	changed.items = {"B11":{"unlock_notes":7}}
	write_policy(changed)
	before = state(meta)
	check(meta.home_item_quote(&"B11").price == 7,"per-ID price data overrides the rarity experiment value")
	check(not meta.unlock_home_item(&"B11",&"old_price",int(quote.profile_revision),String(quote.quote_fingerprint)).accepted and state(meta) == before,"old price fingerprint refuses even without a profile mutation")
	var save: MetaSaveService = meta._save
	meta._save = RejectSave.new()
	quote = meta.home_item_quote(&"B11")
	check(not meta.unlock_home_item(&"B11",&"disk_failure",int(quote.profile_revision),String(quote.quote_fingerprint)).accepted and state(meta) == before,"storage rejection rolls back notes, unlock, receipt and revision")
	meta._save = save
	check(meta.unlock_home_item(&"B11",&"disk_failure",int(quote.profile_revision),String(quote.quote_fingerprint)).accepted and meta.snapshot().notes == 18,"same intent can retry after a failed non-commit at the exact current price")
	check(meta.select_home_item(&"B11",&"selected").accepted,"unlocked item can be chosen before a later data disable")
	before = state(meta)
	changed.home_enabled_blacklist = ["B11"]
	write_policy(changed)
	var disabled := meta.home_item_quote(&"B11")
	check(disabled.discovered and disabled.unlocked and disabled.selected and not disabled.available and disabled.reason == "home_item_disabled","disabled policy retains known/unlocked/selected history while suspending new carry")
	check(not meta.select_home_item(&"B11",&"disabled_select").accepted and state(meta) == before,"disabled item cannot be newly submitted as a carry choice")
	check(not meta.unlock_home_item(&"B11",&"disabled_unlock").accepted and state(meta) == before,"disabled item cannot consume another unlock payment")
	check(meta.select_home_item(&"",&"clear_disabled").accepted,"unavailable old choice can be cleared explicitly")
	write_text(POLICY,"{invalid")
	check(not meta.home_item_quote(&"B11").available and meta.home_item_rows().is_empty(),"invalid replacement policy never reuses a stale valid success cache")
	write_policy(policy())
	check(meta.home_item_quote(&"B11").can_select,"restored current policy keeps its original permanent unlock")
	before = state(meta)
	check(not meta._transaction(&"unknown_kind",{"kind":"future_mutation"}).accepted and state(meta) == before,"unknown transaction kind is explicit rejection, never an upgrade fallback")
	check(not meta.select_home_item(&"B11",&"stale_select",int(meta.snapshot().profile_revision)-1).accepted and state(meta) == before,"selection obeys current profile revision")
	meta._save = RejectSave.new()
	check(not meta.select_home_item(&"B11",&"select_disk_failure").accepted and state(meta) == before,"failed selection persistence cannot partially change the preferred item")
	check(not meta.discover_item(&"B03",&"discovery_disk_failure").accepted and state(meta) == before,"failed discovery persistence reports failure without a false saved flag")
	meta._save = null
	check(meta.discover_item(&"B03",&"discovery_disk_failure").accepted,"discovery retry uses the original receipt after storage returns")

func migration_and_profile_isolation() -> void:
	write_policy(policy())
	for path: String in [PROFILE_A,PROFILE_B,MIGRATION]: clean(path)
	var meta := MetaProgression.new(POLICY)
	check(meta.configure_persistence(PROFILE_A,false,"slot_a").accepted,"first native slot opens without a profile")
	check(meta.grant_notes(30,&"slot_a_notes").accepted and meta.discover_item(&"B11",&"slot_a_seen").accepted and meta.unlock_home_item(&"B11",&"slot_a_unlock").accepted and meta.select_home_item(&"B11",&"slot_a_selection").accepted,"slot A actually persists notes/discovery/unlock/selection")
	var again := MetaProgression.new(POLICY)
	check(again.configure_persistence(PROFILE_A,false,"slot_a").accepted and again.snapshot().notes == 25 and again.snapshot().selected_home_item == "B11","new owner loads actual slot A state")
	check(again.snapshot().discovered_items == ["B11"] and again.snapshot().unlocked_home_items == ["B11"],"discovery and unlock survive process-owner replacement")
	check(meta.configure_persistence(PROFILE_B,false,"slot_b").accepted and meta.snapshot().notes == 0 and meta.snapshot().discovered_items.is_empty() and meta.snapshot().unlocked_home_items.is_empty() and meta.snapshot().selected_home_item == "","switching the same Meta owner to a new slot does not leak prior state")
	var wrong := MetaProgression.new(POLICY)
	check(not wrong.configure_persistence(PROFILE_A,false,"slot_b").accepted and not wrong.grant_notes(1,&"wrong_slot").accepted,"a different declared profile identity cannot consume another slot's file")
	var local := MetaSaveService.new()
	local.configure(PROFILE_A,false)
	var separate := MetaSaveService.new()
	separate.configure(PROFILE_B,false,"slot_b")
	check(local.web_storage_key() == "gunman_rush.plains_meta.v2" and local.web_storage_key() != separate.web_storage_key(),"local Web storage location remains stable while explicit slots get separate keys; this is not a browser storage execution")
	var old := {"notes":40,"upgrades":{"vitality":1},"receipts":{"old_notes":{"kind":"notes","amount":40}},"settled":{"old_run":{"success":false,"summary":{"items":["B11","B11","not_a_definition"]}}},"completed_runs":0,"failed_runs":1,"completed_biomes":0,"last_summary":{"items":["B03"]}}
	var envelope := {"schema_version":2,"content_version":"plains_meta_1","profile_id":"local","profile_revision":7,"payload":old}
	envelope.checksum = MetaSaveService.canonical_json(envelope).sha256_text()
	write_text(MIGRATION,JSON.stringify(envelope))
	var original_text := FileAccess.get_file_as_string(MIGRATION)
	var migrated := MetaProgression.new(POLICY)
	check(migrated.configure_persistence(MIGRATION,false).accepted,"actual current schema2 profile migrates into the new owner")
	check(migrated.snapshot().notes == 40 and migrated.snapshot().upgrades.vitality == 1 and migrated.snapshot().failed_runs == 1 and migrated.snapshot().profile_revision == 7,"migration preserves notes, permanent vitality, history counters and revision")
	check(migrated.snapshot().discovered_items == ["B03","B11"] and migrated.snapshot().unlocked_home_items.is_empty() and migrated.snapshot().selected_home_item == "","only evidenced valid current IDs recover discovery; no inferred free permanent unlock")
	check(FileAccess.get_file_as_string(MIGRATION) == original_text,"load/migration does not overwrite the old envelope before a real commit")
	check(migrated.unlock_home_item(&"B11",&"migration_unlock").accepted,"migrated current notes can be spent through the normal unlock transaction")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MIGRATION))
	check(saved.schema_version == 3 and saved.content_version == "plains_meta_2" and saved.profile_id == "local" and saved.payload.notes == 35,"next commit writes schema3 to the same actual save location")
	check(FileAccess.get_file_as_string(MIGRATION+".backup") == original_text,"the exact old schema2 primary survives as a valid backup")
	check(migrated.grant_notes(1,&"old_notes").reason == "receipt_conflict" and migrated.snapshot().notes == 35,"old monetary receipt identity remains authoritative after migration")
	var future := saved.duplicate(true)
	future.schema_version = 999
	write_text(MIGRATION,JSON.stringify(future))
	var unsupported := MetaProgression.new(POLICY)
	check(not unsupported.configure_persistence(MIGRATION,false).accepted and not unsupported.grant_notes(1,&"future_write").accepted,"future schema refuses without falling back to an older successful backup")
	var future_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MIGRATION))
	check(future_file.schema_version == 999,"future primary is never silently replaced")
	for path: String in [PROFILE_A,PROFILE_B,MIGRATION]: clean(path)

func retained_history_and_fresh_run_items() -> void:
	write_policy(policy())
	var meta := funded()
	var historical: Dictionary = meta._payload()
	historical.discovered_items = ["RETIRED_Z99"]
	historical.unlocked_home_items = ["RETIRED_Z99"]
	historical.selected_home_item = "RETIRED_Z99"
	check(meta._commit(historical),"well-formed historical ID sets survive missing current definitions")
	check(meta.snapshot().unlocked_home_items == ["RETIRED_Z99"] and not meta.home_item_quote(&"RETIRED_Z99").available,"missing definition cannot be carried but is not erased from permanent history")
	check(meta.select_home_item(&"",&"clear_retired").accepted,"orphan historical preference can be cleared without destroying its unlock record")
	check(meta.discover_item(&"B21",&"grapple_item_seen").accepted and meta.unlock_home_item(&"B21",&"grapple_item_unlock").accepted and meta.select_home_item(&"B21",&"grapple_item_choice").accepted,"carry selection does not require an actor's current grapple equipment capability")
	check(meta.discover_item(&"B26",&"five_gear_seen").accepted and meta.unlock_home_item(&"B26",&"five_gear_unlock").accepted and meta.select_home_item(&"B26",&"five_gear_choice").accepted,"a legal five-gear definition can be carried without checking current equipped load")
	check(meta.discover_item(&"B11",&"health_seen").accepted and meta.unlock_home_item(&"B11",&"health_unlock").accepted and meta.select_home_item(&"B11",&"health_choice").accepted,"fresh-run item fixture chooses the actual growth-capable health definition")
	var definition := HomeItemCatalog.item(&"B11")
	check(definition != null and definition.max_level == 3,"database lookup retains growth rules rather than copying a past owned level")
	if definition != null:
		var first := RunInventory.new(&"new_run_one")
		check(first.add_item(&"new_run_one/home_starter/slot_0",definition,&"home_carry_once"),"isolated ownership ledger receives the chosen Definition")
		var owned := first.instance_for_source(&"new_run_one/home_starter/slot_0")
		check(owned != null and owned.level == 1,"new instance starts at Lv1 even though its Definition supports Lv3")
		check(first.add_item(&"new_run_one/home_starter/slot_0",definition,&"home_carry_once") and first.instances().size() == 1 and first.instance_for_source(&"new_run_one/home_starter/slot_0").level == 1,"same run source cannot duplicate or grow the starting grant")
		first.clear()
		check(first.instances().is_empty() and "B11" in meta.snapshot().unlocked_home_items,"true run ownership clear leaves permanent unlock untouched")
		var next := RunInventory.new(&"new_run_two")
		check(next.add_item(&"new_run_two/home_starter/slot_0",definition,&"home_carry_once") and next.instance_for_source(&"new_run_two/home_starter/slot_0").level == 1,"next distinct run receives one fresh Lv1 item; actual App once-per-run wiring is tested separately")
	var unseen_policy := policy(false)
	write_policy(unseen_policy)
	var optional := funded()
	check(optional.unlock_home_item(&"B11",&"policy_without_discovery").accepted and not optional.home_item_quote(&"B11").discovered,"configurable undiscovered-unlock candidate does not silently mark an item obtained")
	check(optional.select_home_item(&"B11",&"unseen_selected").accepted,"already unlocked reuse remains free under the alternative policy fixture")
	write_policy(policy())

func _run() -> void:
	for path: String in [PROFILE_A,PROFILE_B,MIGRATION,POLICY]: clean(path)
	acquisitions_and_unlocks()
	policy_stale_and_atomic_failures()
	migration_and_profile_isolation()
	retained_history_and_fresh_run_items()
	for path: String in [PROFILE_A,PROFILE_B,MIGRATION,POLICY]: clean(path)
	await process_frame
	print("HOME ITEM CODEX: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
