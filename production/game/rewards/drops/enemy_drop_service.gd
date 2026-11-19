class_name EnemyDropService
extends RefCounted
## Demo weights are tentative. Per-enemy streams make kill order irrelevant.
const CONFIG_PATH := "res://config/enemy_drops.json"
const CONTENT_VERSION := "plains-enemy-drops-v1"
const GUARANTEED_CONTENT_VERSION := "plains-enemy-drops-v2"
const RNG_VERSION := "plains-enemy-drops-v1"
var configuration: Dictionary = {}
var root_seed := ""
var stage_id := ""
var _settled: Dictionary = {}

func configure(seed_value: String, stable_stage: String, config: Dictionary = {}) -> bool:
	configuration = config.duplicate(true) if not config.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	root_seed = seed_value
	stage_id = stable_stage
	_settled.clear()
	return valid_configuration(configuration) and not root_seed.is_empty() and not stage_id.is_empty()

static func valid_configuration(config: Dictionary) -> bool:
	if config.get("version", 0) != 1 or not config.get("weights") is Dictionary or not config.get("amounts") is Dictionary:
		return false
	var sum := 0
	for kind: String in ["coin", "note", "heart", "none"]:
		var weight: Variant = config.weights.get(kind, -1)
		if not (weight is int or weight is float) or not is_finite(float(weight)) or weight != int(weight) or weight < 0 or weight > 100000:
			return false
		sum += int(weight)
		if kind != "none":
			var amount: Variant = config.amounts.get(kind, 0)
			if not (amount is int or amount is float) or not is_finite(float(amount)) or amount != int(amount) or amount <= 0 or amount > 100000:
				return false
	if config.has("guaranteed_coins") and not config.guaranteed_coins is bool: return false
	if config.has("coin_totals"):
		if not config.coin_totals is Dictionary: return false
		for behavior: Variant in config.coin_totals:
			var value: Variant = config.coin_totals[behavior]
			if not behavior is String or str(behavior).is_empty() or not (value is int or value is float) or not is_finite(float(value)) or value!=int(value) or value<=0 or value>100000: return false
	return sum > 0

func settle(enemy_id: StringName, behavior: StringName = &"") -> Dictionary:
	if enemy_id.is_empty() or _settled.has(enemy_id) or not valid_configuration(configuration):
		return {}
	var stream := RunRandomStream.new(root_seed, "enemy_drops", "%s/%s" % [stage_id, enemy_id], RNG_VERSION)
	var total := 0
	for kind: String in ["coin", "note", "heart", "none"]:
		total += int(configuration.weights[kind])
	var roll := stream.next_int(total)
	var selected := "none"
	var cumulative := 0
	for kind: String in ["coin", "note", "heart", "none"]:
		cumulative += int(configuration.weights[kind])
		if roll < cumulative:
			selected = kind
			break
	var output := {"enemy_id": String(enemy_id), "kind": selected, "amount": 0 if selected == "none" else int(configuration.amounts[selected]), "roll": roll, "stream_namespace": "enemy_drops", "stream_position": stream.position(), "content_version": RNG_VERSION, "config_version": configuration.version}
	# Keep the original per-enemy draw and note/heart intervals. A configured
	# plains species now always pays coins, with that original draw as its bonus.
	# Consumers without an explicit species retain the legacy single reward.
	if configuration.get("guaranteed_coins", false) and configuration.get("coin_totals", {}).has(String(behavior)):
		var coins: int = int(configuration.coin_totals[String(behavior)])
		var rewards: Array[Dictionary] = [{"kind":"coin", "amount":coins}]
		if selected in ["note", "heart"]: rewards.append({"kind":selected,"amount":int(configuration.amounts[selected])})
		output.merge({"kind":"coin", "amount":coins, "rewards":rewards, "coin_total":coins, "configured_coin_total":coins, "behavior":String(behavior), "bonus_roll_kind":selected, "drop_revision":2,"content_version":GUARANTEED_CONTENT_VERSION}, true)
	_settled[enemy_id] = output.duplicate(true)
	return output

static func rewards_of(output: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if output.has("rewards"):
		for reward: Dictionary in output.rewards:
			if int(reward.get("amount",0)) > 0: result.append(reward.duplicate(true))
	elif output.get("kind","none") != "none" and int(output.get("amount",0)) > 0:
		result.append({"kind":str(output.kind),"amount":int(output.amount)})
	return result
