extends SceneTree
var failures := 0
var checks := 0
class VisualFixture extends Node2D:
	var pickups: Array[Dictionary] = [{"kind": "coin", "position": Vector2(100, 100), "claimed": false}, {"kind": "note", "position": Vector2(140, 90), "claimed": false}]
	var exit_positions: Array[Vector2] = [Vector2(200, 120), Vector2(450, 40)]
	var completed := false
	var stage_type := &"boss"
	var reward_position := Vector2(600, 100)
	var reward_available := false
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _run() -> void:
	for key: StringName in PlainsRefreshAssets.REGIONS:
		var texture := PlainsRefreshAssets.object_texture(key)
		check(texture.region.position.x >= 0 and texture.region.end.x <= texture.atlas.get_width() and texture.region.position.y >= 0 and texture.region.end.y <= texture.atlas.get_height(), "named generated object crop stays in original atlas: " + str(key))
		check(PlainsRefreshAssets.object_texture(key) == texture, "generated object regions reused without per-frame allocation")
	var fixture := VisualFixture.new()
	root.add_child(fixture)
	var visual := PlainsStageVisual.new()
	visual.configure(fixture)
	fixture.add_child(visual)
	await process_frame
	check(visual._pickups.size() == 2 and visual._doors.size() == 2, "one visual per real pickup and route exit")
	check(visual._doors[0].position == fixture.exit_positions[0] + Vector2(0, -22), "door art is anchored independently of trigger geometry")
	visual._process(0.37)
	check(visual._pickups[0].position != fixture.pickups[0].position and visual._pickups[1].rotation != 0, "coin and note have actual cosmetic animation")
	check(not fixture.pickups[0].claimed and not fixture.pickups[1].claimed, "animation cannot grant or mutate rewards")
	fixture.pickups[0].claimed = true
	visual._process(0.1)
	check(not visual._pickups[0].visible and visual._pickups[1].visible, "claimed pickup hides only its own icon")
	check(not visual._boss_door.visible, "unearned Boss reward has no visible portal")
	fixture.reward_available = true
	fixture.completed = true
	visual._process(0.1)
	check(visual._boss_door.visible and visual._doors[0].modulate == Color.WHITE, "actual stage availability controls portal presentation")
	fixture.free()
	await process_frame
	if "--prove-failure" in OS.get_cmdline_user_args():
		check(false, "intentional failure proves non-zero exit")
	print("PLAINS REFRESH ART: %d assertions, %d failures; actual GPU/device visual review pending" % [checks, failures])
	quit(1 if failures else 0)
