class_name RunCampaignProgression
extends RefCounted
## A run-local capability ledger. UI never grants abilities directly.
enum Phase { PLAYING, ABILITY_CHOICE, REGION_CHOICE, BOUNDARY }
var phase := Phase.PLAYING
var abilities: Array[StringName] = []
var completed_regions: Array[StringName] = []
var debug_entry := false
var _token_key := ""
var _claims: Dictionary = {}

func begin_reward(region: StringName, token: DemoToken) -> bool:
	if phase != Phase.PLAYING or token == null or completed_regions.has(region): return false
	completed_regions.append(region)
	_token_key = token.key()
	phase = Phase.ABILITY_CHOICE
	return true

func offers() -> Array[Dictionary]:
	if phase != Phase.ABILITY_CHOICE: return []
	if completed_regions.back() == &"plains":
		return [{"id":"grapple","label":"H / GRAPPLE — hook between forest branches","available":true}, {"id":"wall_climb","label":"W / WALL CLIMB — locked: Canyon is not built","available":false}, {"id":"weapon_evolution_1","label":"U1 / WEAPON EVOLUTION — locked: Swamp and branch selection are not built","available":false}]
	var result: Array[Dictionary] = []
	for id: StringName in [&"wall_climb", &"double_jump"]:
		if not abilities.has(id): result.append({"id":String(id),"label":"W / WALL CLIMB" if id == &"wall_climb" else "D / DOUBLE JUMP","available":true})
	return result

func claim(id: StringName, token: DemoToken, alive: bool) -> bool:
	if token == null or not alive or token.key() != _token_key: return false
	if _claims.has(_token_key): return _claims[_token_key] == id
	if phase != Phase.ABILITY_CHOICE or abilities.has(id): return false
	var legal := false
	for offer: Dictionary in offers():
		if StringName(offer.id) == id and offer.available: legal = true
	if not legal: return false
	abilities.append(id)
	_claims[_token_key] = id
	phase = Phase.REGION_CHOICE if completed_regions.back() == &"plains" else Phase.BOUNDARY
	return true

func enter_region(id: StringName, token: DemoToken, alive: bool) -> bool:
	if phase != Phase.REGION_CHOICE or token == null or token.key() != _token_key or not alive: return false
	if id != &"thorn_forest" or not abilities.has(&"grapple") or completed_regions.has(id): return false
	phase = Phase.PLAYING
	_token_key = ""
	return true

func snapshot() -> Dictionary:
	return {"abilities":Array(abilities),"completed_regions":Array(completed_regions),"phase":phase,"debug_entry":debug_entry}
