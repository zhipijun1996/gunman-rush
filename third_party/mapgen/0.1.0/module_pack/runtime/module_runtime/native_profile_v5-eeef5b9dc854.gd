extends RefCounted
## Exact, source-bound original fixture initialization; never call at a seam.
const TOKEN="pcg_original_fixture_profile_v5"
func validate_definition(profile: Dictionary, fixture: Dictionary) -> Dictionary:
	if fixture.get("provider")!="original_fixture/v1" or profile.get("id")!=fixture.get("id"):return {"ok":false,"reason":"exact_fixture_identity_required"}
	var jumps:=int(fixture.get("max_jumps",-1));var shots:=int(fixture.get("max_air_shots",-1))
	var registry: Variant=JSON.parse_string(FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join("../player-profiles.json")))
	if not registry is Dictionary or registry.get(str(fixture.get("id","")))!=fixture:return {"ok":false,"reason":"undeclared_exact_player_profile"}
	if str(profile.id)!="original-fixture-%dj%ds"%[jumps,shots] or jumps not in [1,2] or shots!=2:return {"ok":false,"reason":"unsupported_exact_fixture_capacity"}
	if int(profile.get("overrides",{}).get("max_jumps",-1))!=jumps or int(profile.get("overrides",{}).get("max_air_shots",-1))!=shots or int(profile.get("effectiveTuning",{}).get("max_jumps",-1))!=jumps or int(profile.get("effectiveTuning",{}).get("max_air_shots",-1))!=shots:return {"ok":false,"reason":"exact_fixture_capacity_mismatch"}
	var expected:="ChallengeRecoilTests._fixture" if jumps==1 else "BranchLibraryRunner.fixture"
	var suffix:="source-resource-v9/challenge_recoil_tests.gd" if jumps==1 else "source-resource-v9/branch_library_runner.gd"
	if fixture.get("initializer")!=expected or not str(fixture.source.path).ends_with(suffix):return {"ok":false,"reason":"exact_fixture_initializer_mismatch"}
	return {"ok":true}
func initialize_once(player: PlayerController, profile: Dictionary, fixture: Dictionary) -> Dictionary:
	var checked:=validate_definition(profile,fixture)
	if not checked.ok:return checked
	if player==null or player.motor==null:return {"ok":false,"reason":"existing_actor_required"}
	if player.has_meta(TOKEN) or player._tick!=0:return {"ok":false,"reason":"profile_initialization_only_once_before_frame0"}
	# Identical original fixture mutation. Existing original abilities share this
	# tuning Resource; no replacement physics or different Foundry profile.
	player.motor.tuning.max_jumps=int(fixture.max_jumps)
	player.motor.tuning.max_air_shots=int(fixture.max_air_shots)
	if fixture.initializer=="ChallengeRecoilTests._fixture":player.action_resources.reset()
	player.set_meta(TOKEN,fixture.duplicate(true))
	return {"ok":true,"profile":profile.duplicate(true),"fixture":fixture.duplicate(true),"initialized_before_frame0":true,"seam":false,"shots":player.action_resources.shot_charges}
func verify_existing(player: PlayerController, profile: Dictionary, fixture: Dictionary) -> Dictionary:
	var checked:=validate_definition(profile,fixture)
	if not checked.ok:return checked
	if player==null or not player.has_meta(TOKEN) or player.get_meta(TOKEN)!=fixture:return {"ok":false,"reason":"existing_actor_exact_profile_identity_mismatch"}
	if player.motor.tuning.max_jumps!=int(fixture.max_jumps) or player.motor.tuning.max_air_shots!=int(fixture.max_air_shots):return {"ok":false,"reason":"existing_actor_exact_profile_capacity_mismatch"}
	return {"ok":true,"profile_applied_at_seam":false,"resources_reset":false,"shots":player.action_resources.shot_charges}
