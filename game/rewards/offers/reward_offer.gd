class_name RewardOffer
extends RefCounted
var offer_id: StringName
var source_id: StringName
var run_epoch := 0
var stage_epoch := 0
var candidates: Array[ItemDefinition] = []
var claimed := false
var gold := false

func copy() -> RewardOffer:
	var result := RewardOffer.new()
	result.offer_id = offer_id
	result.source_id = source_id
	result.run_epoch = run_epoch
	result.stage_epoch = stage_epoch
	result.claimed = claimed
	result.gold = gold
	for item: ItemDefinition in candidates:
		result.candidates.append(item.duplicate(true))
	return result
