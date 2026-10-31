extends "res://tests/bellstrider_rework_01/contact_edges.gd"
## Short actual-App proof, explicitly controlled; not a natural whole fight.
var trace: Array[Dictionary] = []
var caption: Label
var case_label := "FALL ON INSTALLED MAIN BELL"

func relocate(point: Vector2, label: String) -> void:
	super.relocate(point, label)
	if is_instance_valid(app._run_camera):
		app._run_camera.snap_to_target()
		app._run_camera.force_update_scroll()

func observe() -> void:
	if is_instance_valid(app) and is_instance_valid(app.player) and encounter != null:
		var hp: float = app.controller.actor_resources.health.current
		caption.text = "CONTROLLED APP / %s / PLAYER HP %.0f / BOSS HP %.0f" % [case_label, hp, encounter.health.current]
		trace.append({"movie_frame": Engine.get_process_frames(), "player": app.player.global_position,
			"bell": encounter._core.global_position, "player_HP": hp,
			"boss_HP": encounter.health.current, "hurt_motion": app.player.damage_remaining,
			"contacts": contacts.duplicate(true)})

func run() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(14, 650)
	caption.add_theme_font_size_override("font_size", 17)
	layer.add_child(caption)
	var note := Label.new()
	note.position = Vector2(14, 681)
	note.text = "Disclosed initial position + stationary Boss pose. Real gravity, health, hurt sound and frame damage."
	layer.add_child(note)
	process_frame.connect(observe)
	await mounted_bell(1, &"roll")
	await ticks(60)
	case_label = "THROWN COPPER BELL ON ACTUAL SHELF"
	await copper_lob()
	await ticks(45)
	process_frame.disconnect(observe)
	DirAccess.make_dir_recursive_absolute("res://build/bellstrider_review_03")
	var file := FileAccess.open("res://build/bellstrider_review_03/contact-movie-trace.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "controlled actual App fall on installed main bell; normal clock, real health and original sound; not natural fight", "frames": trace, "assertions": assertions, "failures": failures}, "\t"))
	file.close()
	await cleanup()
	print("BELLSTRIDER BELL CONTACT REVIEW: ", assertions, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
