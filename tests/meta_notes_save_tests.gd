extends SceneTree
var failures := 0
var assertions := 0
const PATH := "user://meta_notes_test.json"
func _initialize() -> void:
	_run.call_deferred()
func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
func clear_files() -> void:
	for suffix: String in ["", ".backup", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
func overwrite(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
func _run() -> void:
	check(MetaSaveService.bridge_boolean(true) and MetaSaveService.bridge_boolean(1), "Web bridge accepts actual bool true and numeric int one")
	for value: Variant in [false, 0, 2, -1, "true", "1", null, 1.0]:
		check(not MetaSaveService.bridge_boolean(value), "Web bridge rejects wrong-type or unsuccessful result")
	clear_files()
	var meta := MetaProgression.new()
	check(meta.configure_persistence(PATH, false).accepted, "absent profile initializes cleanly")
	check(meta.grant_notes(12, &"pickup_a").accepted, "notes grant commits")
	check(meta.grant_notes(12, &"pickup_a").accepted and meta.snapshot().notes == 12, "duplicate grant only once")
	check(not meta.grant_notes(13, &"pickup_a").accepted, "conflicting pickup rejected")
	check(not meta.grant_notes(-1, &"negative").accepted, "negative grant rejected")
	check(meta.purchase_upgrade(&"vitality", &"buy_a").accepted and meta.snapshot().notes == 7, "upgrade deducts notes atomically")
	check(meta.purchase_upgrade(&"vitality", &"buy_a").accepted and meta.snapshot().notes == 7, "purchase replay does not buy second level")
	check(not meta.purchase_upgrade(&"vitality", &"poor").accepted, "insufficient balance preserves profile")
	var loaded := MetaProgression.new()
	check(loaded.configure_persistence(PATH, false).accepted and loaded.snapshot().notes == 7 and loaded.snapshot().upgrades.vitality == 1, "new process instance loads persisted notes and upgrade")
	check(loaded.grant_notes(12, &"pickup_a").accepted and loaded.snapshot().notes == 7, "receipt persists through restart")
	var health := HealthDefinition.new()
	health.resource_id = &"test_health"
	health.max_health = 5
	health.initial_current = 5
	var upgraded := loaded.fresh_health_definition(health)
	check(upgraded.max_health == 6 and upgraded.initial_current == 6 and health.max_health == 5, "permanent bonus clones base health and leaves shared definition unchanged")
	check(loaded.settle(&"death", false, {"run_coins": 999}) and loaded.snapshot().notes == 7, "death keeps earned notes and never converts run coins")
	check(loaded.new_run_receipt_prefix() != loaded.new_run_receipt_prefix(), "new run receipt identity does not reset with epochs")
	# Previous valid profile is a real backup, truncated primary recovers it.
	overwrite(PATH, "{truncated")
	var recovered := MetaProgression.new()
	check(recovered.configure_persistence(PATH, false).accepted and recovered.snapshot().save_status == "recovered_backup", "truncated primary restores previous valid backup")
	check(recovered.grant_notes(1, &"after_recovery").accepted and FileAccess.get_file_as_string(PATH + ".corrupt") == "{truncated", "next commit preserves corrupted original")
	overwrite(PATH, "")
	var empty_recovered := MetaProgression.new()
	check(empty_recovered.configure_persistence(PATH, false).accepted and empty_recovered.grant_notes(1, &"empty_recovered").accepted and FileAccess.file_exists(PATH + ".corrupt") and FileAccess.get_file_as_string(PATH + ".corrupt").is_empty(), "empty primary recovers valid backup and preserves empty original")
	overwrite(PATH, "bad")
	overwrite(PATH + ".backup", "bad")
	var broken := MetaProgression.new()
	check(not broken.configure_persistence(PATH, false).accepted and not broken.grant_notes(5, &"bad").accepted and FileAccess.get_file_as_string(PATH) == "bad", "two invalid profiles block writes and retain original")
	clear_files()
	var failed := MetaProgression.new()
	check(failed.configure_persistence("user://missing_meta_directory/profile.json", false).accepted, "missing profile can initialize")
	check(not failed.grant_notes(5, &"write_fail").accepted and failed.snapshot().notes == 0, "write denial cannot grant phantom notes")
	var old := {"notes": 3, "receipts": {}, "settled": {}, "completed_runs": 0, "failed_runs": 0, "completed_biomes": 0, "last_summary": {}}
	var envelope := {"schema_version": 1, "profile_revision": 1, "payload": old, "checksum": JSON.stringify(old).sha256_text()}
	overwrite(PATH, JSON.stringify(envelope))
	var migrated := MetaProgression.new()
	check(migrated.configure_persistence(PATH, false).accepted and migrated.snapshot().notes == 3 and migrated.snapshot().upgrades.is_empty(), "v1 profile migrates to explicit upgrade map")
	check(migrated.grant_notes(1, &"migrated").accepted and JSON.parse_string(FileAccess.get_file_as_string(PATH)).schema_version == 2, "migration next commit writes v2 and backs up original")
	var future := {"schema_version": 999, "profile_revision": 1, "payload": old, "checksum": JSON.stringify(old).sha256_text()}
	overwrite(PATH, JSON.stringify(future))
	var incompatible := MetaProgression.new()
	check(not incompatible.configure_persistence(PATH, false).accepted and not incompatible.grant_notes(1, &"future").accepted and JSON.parse_string(FileAccess.get_file_as_string(PATH)).schema_version == 999, "future schema is not silently replaced by older backup")
	# Existing empty files are corruption, never a clean new profile.
	clear_files()
	overwrite(PATH, "")
	overwrite(PATH + ".backup", "")
	var empty_profile := MetaProgression.new()
	check(not empty_profile.configure_persistence(PATH, false).accepted and not empty_profile.grant_notes(2, &"empty").accepted, "zero-byte primary and backup block overwrite")
	clear_files()
	var header_meta := MetaProgression.new()
	check(header_meta.configure_persistence(PATH, false).accepted and header_meta.grant_notes(40, &"rich").accepted, "header test profile committed")
	var unsigned: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	unsigned.profile_revision = 2.5
	overwrite(PATH, JSON.stringify(unsigned))
	var tampered := MetaProgression.new()
	check(not tampered.configure_persistence(PATH, false).accepted, "fractional header revision rejected")
	clear_files()
	var capped := MetaProgression.new()
	check(capped.grant_notes(40, &"capfunds").accepted, "memory fixture supports same notes contracts")
	for index: int in 3:
		check(capped.purchase_upgrade(&"vitality", StringName("cap_%d" % index)).accepted, "configurable upgrade next level")
	check(not capped.purchase_upgrade(&"vitality", &"over_cap").accepted and capped.snapshot().notes == 10, "upgrade cap leaves balance untouched")
	if "--verify-failure-exit" in OS.get_cmdline_user_args():
		check(false, "intentional failure exit probe")
	clear_files()
	print("META NOTES SAVE: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
