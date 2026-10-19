extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3: quit(2); return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not manifest is Array: quit(2); return
	var packer := PCKPacker.new()
	if packer.pck_start(args[1]) != OK: quit(2); return
	for row: Dictionary in manifest:
		if packer.add_file("res://" + str(row.path), str(row.source)) != OK:
			push_error("Candidate pack source refused: " + str(row.path)); quit(2); return
	if packer.flush() != OK: quit(2); return
	var license_file := FileAccess.open(args[2], FileAccess.WRITE)
	if license_file == null: quit(2); return
	license_file.store_string(Engine.get_license_text())
	license_file.close()
	print("ENVIRONMENT SOURCE PACK COMPLETE: ", manifest.size(), " current frozen inputs")
	quit(0)
