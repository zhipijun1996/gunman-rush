class_name CacheRewardPolicy
extends RefCounted
## Pure display alternatives; item offer registration and claims stay with their owners.

static func note_amount(tier: Variant) -> int:
	return 1 if tier=="medium" else 2 if tier=="high" else 4

static func complete_choices(selected_items: Array[ItemDefinition],eligible_items: Array[ItemDefinition],cache_id: Variant,tier: Variant,resources: Array,full_health: bool) -> Array[ItemDefinition]:
	var candidates: Array[ItemDefinition]=[]
	candidates.assign(selected_items)
	for resource: Dictionary in resources:
		if candidates.size()>=2: break
		if resource.kind=="heart" and full_health: continue
		var rarity: ItemDefinition.Rarity=ItemDefinition.Rarity.BLUE if tier=="medium" else ItemDefinition.Rarity.PURPLE if tier=="high" else ItemDefinition.Rarity.GOLD
		candidates.append(ResourceRewardChoice.make(StringName(cache_id+"/resource/"+resource.kind),str(resource.kind),int(resource.amount),rarity))
	# Preserve the existing second-item precedence, including resource-only offers.
	if candidates.size()<2 and eligible_items.size()>1: candidates.append(eligible_items[1])
	# This is a single fallback, not a fill/deduplicate operation.
	if candidates.size()<2:
		candidates.append(ResourceRewardChoice.make(StringName(cache_id+"/resource/note"),"note",note_amount(tier),ItemDefinition.Rarity.BLUE if tier=="medium" else ItemDefinition.Rarity.PURPLE if tier=="high" else ItemDefinition.Rarity.GOLD))
	return candidates
