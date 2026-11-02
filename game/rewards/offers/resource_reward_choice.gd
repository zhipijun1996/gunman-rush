class_name ResourceRewardChoice
extends ItemDefinition
## Presentation-only choice. Never enters BuildState or RewardService.
@export var resource_kind := "coin"
@export var amount := 0
func is_valid() -> bool:
	return not stable_id.is_empty() and resource_kind in ["coin","heart","note"] and amount>0
func effect_text() -> String:
	return str({"coin":"局内金币 / Coins","heart":"当前生命 / Heal","note":"永久音符 / Notes"}[resource_kind])+" +%s" % amount
static func make(id: StringName,kind: String,value: int,tier: Rarity) -> ResourceRewardChoice:
	var choice:=ResourceRewardChoice.new()
	choice.stable_id=id;choice.resource_kind=kind;choice.amount=value;choice.rarity=tier
	choice.icon_key=StringName({"coin":"run_coin","heart":"healing","note":"meta_note"}[kind])
	choice.display_name={"coin":"金币袋 / Coin Pouch","heart":"应急补给 / Healing Supply","note":"风铃音符 / Chime Notes"}[kind]
	choice.description={"coin":"用于本次探索的商店；离开本局不会兑换音符。","heart":"恢复当前生命，最高恢复到已有生命上限。","note":"写入永久音符钱包；可在家园用于已实现的成长。"}[kind]
	return choice
