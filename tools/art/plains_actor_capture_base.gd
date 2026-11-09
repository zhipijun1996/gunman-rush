extends SceneTree
## Shared lifecycle for current formal-world combat captures and regressions.
var app: FixedWorldApp
var note: Label

func _initialize() -> void:
	run.call_deferred()

func ticks(count: int) -> void:
	for i: int in count:
		await physics_frame

func settle() -> void:
	for i: int in 240:
		await physics_frame
		if not app.busy: return
	assert(false, "room load did not settle")

func run() -> void:
	push_error("Use a concrete combat capture or test script.")
	quit(1)

func load_fixture(rid: String, entry := "") -> void:
	preload("res://tests/world/authored_room_fixture.gd").install(app, rid)
	app.load_room(rid, entry)
