class_name RoutePlanner
extends RefCounted

const VERSION := 1
var definitions := StageTypeDefinition.registry()

func offers(profile: RunProfile, stage_index: int, seed: String, stage_id: StringName) -> Array[ExitOffer]:
	var result: Array[ExitOffer] = []
	if profile == null or not profile.is_valid() or stage_index < 1 or stage_index >= profile.boss_stage:
		return result
	var types: Array[StringName] = [&"shop", &"item_reward"]
	# The first demo choice always exposes the two implemented interactive rooms.
	if stage_index == profile.boss_stage - 1:
		types = [&"boss", &"boss"]
	elif not profile.development_only:
		var stream := RunRandomStream.new(seed, "route", String(stage_id), "demo_content_v1")
		var pool: Array[StringName] = [&"combat", &"shop", &"coin_reward", &"health_reward", &"item_reward"]
		var first := stream.next_int(pool.size())
		types = [pool[first], pool[(first + 1 + stream.next_int(pool.size() - 1)) % pool.size()]]
	for index: int in 2:
		var definition: StageTypeDefinition = definitions.get(types[index])
		if definition == null or not definition.is_valid():
			return []
		var offer := ExitOffer.new()
		offer.exit_id = StringName("%s/exit_%s" % [stage_id, index])
		offer.source_stage_id = stage_id
		offer.next_stage_index = stage_index + 1
		offer.next_stage_type_id = definition.type_id
		offer.icon_id = definition.icon_id
		offer.label = definition.display_name
		result.append(offer)
	return result
