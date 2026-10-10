extends SceneTree
## Settlement fixture injects player position, not a traversal/playability proof.
var assertions := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for _index: int in count:
		await physics_frame
func _run() -> void:
	var app := preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(2)
	check(app.start_plains("branch-risk-receipts"), "Generated formal run starts")
	await frames(4)
	var stage := app.stage as GeneratedDemoStage
	var profiles: Array = stage.generated.manifest.get("branch_profiles", [])
	check(profiles.size() == 2, "Two committed branch profiles")
	if profiles.size() != 2:
		app.free()
		quit(1)
		return
	var signpost := stage.route_signpost
	check(signpost != null and signpost.routes.size() == 2, "World signpost shows both routes")
	for index: int in profiles.size():
		check(signpost.routes[index].label == stage.exits[index].label and signpost.routes[index].type_id == stage.exits[index].next_stage_type_id, "Risk subtitle preserves actual next-room offer")
		check(signpost.routes[index].risk_label == ("CHALLENGE + LOOT" if profiles[index].risk == "challenge" else "STEADY PATH"), "Signpost displays committed branch risk")
	var bonus_indices: Array[int] = []
	for index: int in stage.pickups.size():
		var pickup: Dictionary = stage.pickups[index]
		if not pickup.has("branch_index"):
			continue
		bonus_indices.append(index)
		var profile: Dictionary = profiles[pickup.branch_index]
		check(profile.risk == "challenge", "Only challenging route receives optional bonus")
		check(pickup.amount == profile["bonus_coins" if pickup.kind == "coin" else "bonus_notes"], "Pickup amount matches committed budget")
	check(bonus_indices.size() == 2, "One coin and one note bonus on challenge branch")
	var snapshot := stage.manifest_pickups()
	var manifest: Dictionary = stage.generated.manifest.duplicate(true)
	stage._install_branch_bonuses()
	check(stage.manifest_pickups() == snapshot, "Bonus installer is idempotent")
	for index: int in bonus_indices:
		var pickup: Dictionary = stage.pickups[index]
		var coin_before: int = app.wallet.balance
		var note_before: int = app.meta.snapshot().notes
		app.player.reset_at(pickup.position)
		check(app._commit_pickup(index), "Real app settles bonus at contact position")
		check(not app._commit_pickup(index), "Same pickup cannot settle twice")
		check(app.wallet.balance == coin_before + (pickup.amount if pickup.kind == "coin" else 0), "Coins affect only RunCoin wallet")
		check(app.meta.snapshot().notes == note_before + (pickup.amount if pickup.kind == "note" else 0), "Notes affect only permanent wallet")
		app._environment_return()
		check(pickup.claimed and stage.generated.manifest == manifest, "Segment return retains pickup claim and manifest")
		app.player.reset_at(pickup.position)
		check(not app._commit_pickup(index), "Revisiting after segment return cannot farm bonus")
	check(stage.manifest_pickups() == snapshot, "Claiming cannot change reproducible initial pickup descriptors")
	app.free()
	var tuning := PlayerTuning.load_default()
	var data := PlainsStageGenerator.new().generate("branch-risk-receipts", 1, &"combat", tuning)
	var replica := GeneratedDemoStage.new()
	replica.configure(1, &"combat", [])
	replica.configure_generated(data, tuning)
	root.add_child(replica)
	await frames(2)
	check(replica.manifest_pickups() == snapshot, "Same seed and version reproduces complete pickups including branch bonuses")
	replica.free()
	print("BRANCH RISK REWARDS: %s assertions, %s failures" % [assertions, failures])
	quit(1 if failures else 0)
