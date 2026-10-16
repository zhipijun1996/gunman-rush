extends "res://tests/plains_autonomy_slice_runner.gd"
## Preserve the frozen v9 assertions, evidence writer and expected failure exit.
func finish() -> void:
	if is_instance_valid(app):
		for child: Node in app.get_children():
			if child is GameAudio and not await preload("res://tools/observed_audio_teardown.gd").drain_service(child):
				failures += 1
				push_error("completed autonomy observation audio release timeout")
	super.finish()
