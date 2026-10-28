extends SceneTree
## Run from an isolated cwd against the actual exported PCK, never res://source.
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var expected := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--home-policy-sha="): expected = argument.trim_prefix("--home-policy-sha=")
	check(not expected.is_empty() and FileAccess.get_sha256(HomeItemCatalog.CONFIG_PATH) == expected,"Actual PCK contains the exact source Home policy bytes")
	var definitions := ItemCatalogV5.all_items()
	check(not definitions.is_empty(),"Actual exported Definition database loads without checkout fallback")
	for item: ItemDefinition in definitions:
		var texture := ItemPresentation.icon(item.icon_key)
		check(texture != null and texture.get_width() > 0,"Exported catalog icon is loadable: " + String(item.stable_id))
	var meta := MetaProgression.new()
	check(meta.home_item_rows().size() == definitions.size(),"Exported Home rows enumerate the shared database")
	check(meta.grant_notes(100,&"packed_notes_fixture").accepted and meta.discover_item(&"B11",&"packed_discovery_fixture").accepted,"Isolated pack fixture commits permanent progress in memory")
	var quote := meta.home_item_quote(&"B11")
	check(quote.can_unlock and int(quote.price) > 0,"Packed Home policy provides the actual configured quote")
	check(meta.unlock_home_item(&"B11",&"packed_unlock_fixture",int(quote.profile_revision),str(quote.quote_fingerprint)).accepted,"Actual packed backend unlocks with the bound quote")
	check(meta.select_home_item(&"B11",&"packed_selection_fixture").accepted and meta.snapshot().selected_home_item == "B11","Actual packed backend exposes one carry selection")
	definitions.clear()
	ItemArtLibrary.clear_cache()
	await process_frame
	print("HOME CODEX PACK: %s assertions, %s failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
