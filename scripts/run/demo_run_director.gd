class_name DemoRunDirector
extends RefCounted

signal stage_entered(result: DemoRunResult)
signal run_ended(result: DemoRunResult)

enum State { HOME, IN_STAGE, ENDING_FAILURE, ENDING_SUCCESS, ENDING_BIOME }
var lifetime: DemoLifetime
var state: State = State.HOME
var profile: RunProfile
var seed := ""
var stage_index := 0
var stage_type_id: StringName
var biome_id: StringName = &"demo_ruins"
var manifest: RunManifest
var stage_complete := false
var _offers: Array[ExitOffer] = []
var _receipts: Dictionary = {}
var _planner := RoutePlanner.new()

var offers: Array[ExitOffer]:
	get:
		var detached: Array[ExitOffer] = []
		for offer: ExitOffer in _offers:
			detached.append(offer.copy())
		return detached

func _init(injected_lifetime: DemoLifetime = null) -> void:
	lifetime = injected_lifetime if injected_lifetime != null else DemoLifetime.new()

func start(root_seed: String, selected_profile: RunProfile = null) -> DemoRunResult:
	if state != State.HOME or root_seed.is_empty():
		return _result(DemoRunResult.Status.INVALID)
	profile = selected_profile if selected_profile != null else RunProfile.development()
	if not profile.is_valid():
		return _result(DemoRunResult.Status.INVALID)
	profile = profile.duplicate(true)
	seed = root_seed
	lifetime.epoch += 1
	lifetime.stage_epoch += 1
	lifetime.actor_epoch += 1
	lifetime.active = true
	_receipts.clear()
	manifest = RunManifest.new(seed, profile)
	state = State.IN_STAGE
	_enter_stage(1, &"combat")
	var result := _result(DemoRunResult.Status.APPLIED)
	stage_entered.emit(result.copy())
	return result

func complete_stage(token: DemoToken) -> bool:
	if state != State.IN_STAGE or not lifetime.accepts(token):
		return false
	stage_complete = true
	return true

func select_exit(token: DemoToken, exit_id: StringName, selection_id: StringName) -> DemoRunResult:
	var payload := {"exit_id": exit_id, "run_epoch": token.run_epoch if token != null else -1, "stage_epoch": token.stage_epoch if token != null else -1, "actor_epoch": token.actor_epoch if token != null else -1}
	if selection_id.is_empty():
		return _result(DemoRunResult.Status.INVALID)
	if _receipts.has(selection_id):
		var receipt: Dictionary = _receipts[selection_id]
		if receipt.payload != payload:
			return _result(DemoRunResult.Status.CONFLICT)
		var replay: DemoRunResult = receipt.result.copy()
		replay.status = DemoRunResult.Status.REPLAY
		return replay
	if state != State.IN_STAGE or not lifetime.accepts(token):
		return _result(DemoRunResult.Status.STALE)
	if not stage_complete:
		return _result(DemoRunResult.Status.NOT_READY)
	var selected: ExitOffer
	for offer: ExitOffer in _offers:
		if offer.exit_id == exit_id:
			selected = offer
	if selected == null or selected.next_stage_index != stage_index + 1:
		return _result(DemoRunResult.Status.INVALID)
	manifest.select(selected, selection_id)
	lifetime.stage_epoch += 1
	lifetime.actor_epoch += 1
	_enter_stage(selected.next_stage_index, selected.next_stage_type_id)
	var result := _result(DemoRunResult.Status.APPLIED, selection_id)
	_receipts[selection_id] = {"payload": payload, "result": result.copy()}
	stage_entered.emit(result.copy())
	return result

func end_failure(end_id: StringName) -> DemoRunResult:
	return _end(end_id, &"failure", false)

func finish_success(token: DemoToken, end_id: StringName, gold_receipt: bool) -> DemoRunResult:
	if state == State.ENDING_SUCCESS:
		return _end(end_id, &"success", true)
	if state != State.IN_STAGE or not lifetime.accepts(token):
		return _result(DemoRunResult.Status.STALE)
	if not profile.development_only or stage_index != profile.boss_stage or stage_type_id != &"boss" or not stage_complete or not gold_receipt:
		return _result(DemoRunResult.Status.NOT_READY)
	return _end(end_id, &"success", true)

func finish_biome(token: DemoToken, end_id: StringName, gold_receipt: bool) -> DemoRunResult:
	# The fixed eight-stage trial ends at a biome boundary. Q001 deliberately
	# leaves the number of biomes and whole-run victory undefined.
	if state == State.ENDING_BIOME:
		return _end(end_id, &"biome_complete", false, State.ENDING_BIOME)
	if state != State.IN_STAGE or not lifetime.accepts(token):
		return _result(DemoRunResult.Status.STALE)
	if profile.development_only or profile.stages_per_biome != 8 or profile.boss_stage != 8 or stage_index != 8 or stage_type_id != &"boss" or not stage_complete or not gold_receipt:
		return _result(DemoRunResult.Status.NOT_READY)
	return _end(end_id, &"biome_complete", false, State.ENDING_BIOME)

func return_home() -> bool:
	if state not in [State.ENDING_FAILURE, State.ENDING_SUCCESS, State.ENDING_BIOME]:
		return false
	state = State.HOME
	stage_complete = false
	_offers.clear()
	return true

func _end(end_id: StringName, reason: StringName, success: bool, ending_state: State = State.HOME) -> DemoRunResult:
	if end_id.is_empty():
		return _result(DemoRunResult.Status.INVALID)
	if _receipts.has(end_id):
		var receipt: Dictionary = _receipts[end_id]
		if receipt.payload != {"end_reason": reason}:
			return _result(DemoRunResult.Status.CONFLICT)
		var replay: DemoRunResult = receipt.result.copy()
		replay.status = DemoRunResult.Status.REPLAY
		return replay
	if state != State.IN_STAGE:
		return _result(DemoRunResult.Status.TERMINAL)
	state = ending_state if ending_state != State.HOME else (State.ENDING_SUCCESS if success else State.ENDING_FAILURE)
	manifest.end(reason, end_id)
	lifetime.end()
	var result := _result(DemoRunResult.Status.APPLIED, end_id)
	result.reason = reason
	_receipts[end_id] = {"payload": {"end_reason": reason}, "result": result.copy()}
	run_ended.emit(result.copy())
	return result

func _enter_stage(index: int, type_id: StringName) -> void:
	stage_index = index
	stage_type_id = type_id
	stage_complete = false
	_offers = _planner.offers(profile, index, seed, StringName("stage_%s" % index))
	manifest.append_stage(index, type_id, biome_id, _offers)

func _result(status: DemoRunResult.Status, event_id: StringName = &"") -> DemoRunResult:
	var result := DemoRunResult.new()
	result.status = status
	result.event_id = event_id
	result.stage_index = stage_index
	result.stage_type_id = stage_type_id
	result.run_epoch = lifetime.epoch
	result.stage_epoch = lifetime.stage_epoch
	return result
