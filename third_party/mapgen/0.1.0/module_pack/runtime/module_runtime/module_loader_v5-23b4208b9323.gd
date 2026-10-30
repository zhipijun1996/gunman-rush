extends "module_loader_v3-1d72f57d63dd.gd"
## Native consumer binding only. Actor/profile initialization belongs to host.
const NATIVE_PICKUPS=preload("original_pickups_v4-fba91db74f2c.gd")
const EXACT_PROFILE=preload("native_profile_v5-eeef5b9dc854.gd")
const REGION_CHESTS=preload("original_region_chests_v5-3f409ecd7991.gd")
var original_region_chests
var original_pickups

func bind_player(player: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, wallet: RunWallet, existing_scope=null, instance_id: String="", native_meta: MetaProgression=null, native_region_state: PlainsRegionState=null) -> Dictionary:
	for pickup: Dictionary in content.get("original_pickups",[]):
		if pickup.get("kind","")=="note" and native_meta==null:return {"ok":false,"reason":"explicit_meta_required_for_notes"}
	if not content.get("original_region_chests",[]).is_empty() and (native_meta==null or native_region_state==null or instance_id.is_empty()):return {"ok":false,"reason":"explicit_shared_region_wallet_meta_and_instance_required"}
	var profile: Variant=content.get("original_tuning_profile")
	var fixture: Variant=content.get("original_fixture_profile")
	if fixture is Dictionary:
		var verified: Dictionary=EXACT_PROFILE.new().verify_existing(player,profile,fixture)
		if not verified.ok:return verified
	elif profile is Dictionary:
		var required: PlayerTuning=FoundryCatalog.tuning_for(str(profile.id))
		if required==null:return {"ok":false,"reason":"unknown_original_profile"}
		if player==null or player.motor.tuning.max_jumps!=required.max_jumps or player.motor.tuning.max_air_shots!=required.max_air_shots:return {"ok":false,"reason":"existing_actor_native_profile_mismatch"}
	# The original consumer owns every radius/health/lifetime check and grant.
	# Neither this method nor its parent applies profile/grants/refills resources.
	var result: Dictionary=super.bind_player(player,policy,lifetime,wallet,existing_scope,instance_id)
	if not result.get("ok",false):return result
	original_pickups=NATIVE_PICKUPS.new();add_child(original_pickups)
	var installed: Dictionary=original_pickups.setup(content.get("original_pickups",[]),self,player,scope,wallet,native_meta,instance_key)
	if not installed.ok:bound=false;return installed
	if not content.get("original_region_chests",[]).is_empty():
		original_region_chests=REGION_CHESTS.new();add_child(original_region_chests)
		var region_result: Dictionary=original_region_chests.setup(content.original_region_chests,self,player,scope,wallet,native_meta,native_region_state,instance_id)
		if not region_result.ok:bound=false;return region_result
		result.original_region_consumer="DemoApp._region_interact/_claim_region_chest"
	result.original_pickup_consumer="DemoApp._commit_pickup";result.profile_applied_at_seam=false
	return result

func request_native_pickup_interaction() -> void:
	if bound and original_pickups!=null:original_pickups.request_interaction()

func request_native_region_interaction() -> void:
	if bound and original_region_chests!=null:original_region_chests.request_interaction()

func request_native_region_choice(kind: String) -> void:
	if bound and original_region_chests!=null:original_region_chests.request_choice(kind)

func capture() -> void:
	super.capture()
	if bound and original_pickups!=null:original_pickups.capture()
	if bound and original_region_chests!=null:original_region_chests.capture()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if bound and _owned_scope and original_pickups!=null:original_pickups.capture()
	if bound and _owned_scope and original_region_chests!=null:original_region_chests.capture()

func snapshot() -> Dictionary:
	var value:=super.snapshot()
	if bound and original_pickups!=null:value.original_pickups=original_pickups.snapshot()
	if bound and original_region_chests!=null:value.original_region_chests=original_region_chests.snapshot()
	return value
