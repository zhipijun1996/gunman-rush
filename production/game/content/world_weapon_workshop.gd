class_name WorldWeaponWorkshop
extends RefCounted
## References identify combat resources only. Eligibility, workshop location,
## costs, rank damage and grants come from the pinned world's growth section.
const FAMILY := {"gun":"gun","shuriken":"weapon_shuriken","bomb":"B"}
const ADVANCED := {
	"triple_machine_gun":preload("res://resources/weapons/machine_storm.tres"),
	"sustained_laser":preload("res://resources/weapons/laser_cannon.tres"),
	"fan_shuriken":preload("res://resources/weapons/blade_bloom.tres"),
	"remote_boomerang":preload("res://resources/weapons/moon_boomerang.tres"),
	"magnetic_mine":preload("res://resources/weapons/magnetic_storm.tres"),
	"collapse_singularity":preload("res://resources/weapons/star_collapse.tres")
}
const PRIMARY := {
	"triple_machine_gun":preload("res://resources/weapons/triple_machine_gun.tres"),
	"sustained_laser":preload("res://resources/weapons/sustained_laser.tres"),
	"fan_shuriken":preload("res://resources/weapons/fan_shuriken.tres"),
	"remote_boomerang":preload("res://resources/weapons/remote_boomerang.tres"),
	"magnetic_mine":preload("res://resources/weapons/magnetic_mine.tres"),
	"collapse_singularity":preload("res://resources/weapons/collapse_singularity.tres")
}

static func loadouts(state: FixedWorldState, growth: Dictionary, base: Dictionary) -> Dictionary:
	var available: Dictionary={}
	for id: String in base:
		if state.has(id): available[id]=base[id]
	for recipe: Dictionary in growth.branch_upgrades:
		if state.has(recipe.grant_flag) and state.has(FAMILY[recipe.requires_weapon]):
			available[recipe.branch]=ADVANCED[recipe.branch] if state.has("skill_tier_2") else PRIMARY[recipe.branch]
	return available

static func rank(state: FixedWorldState, kind: String) -> int:
	return int(state.value.inventory.get("attack_rank",0)) if kind=="attack" else 2 if state.has("skill_tier_2") else 1 if state.has("skill_tier_1") else 0

static func quotes(state: FixedWorldState, growth: Dictionary, room: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if room not in growth.workshop_rooms: return result
	for kind: String in ["attack","skill"]:
		var current:=rank(state,kind)
		var track: Dictionary=growth["shared_"+kind]
		if current+1>=track.levels.size(): continue
		var next: Dictionary=track.levels[current+1]
		result.append({"id":"install_"+kind+"_"+str(int(next.level)),"kind":kind,"level":int(next.level),
			"item":"attack_alloy" if kind=="attack" else "skill_core","cost":int(next.cost_to_reach),"fee":int(track.gold_fee),
			"label":"共享攻击 %d · 单发 %d" % [next.level,next.damage] if kind=="attack" else "安装第 %d 枚共用技能芯"%next.level})
	if room in growth.branch_workshop_rooms:
		for row: Dictionary in growth.branch_upgrades:
			if state.has(row.grant_flag): continue
			result.append({"id":row.id,"kind":"branch","branch":row.branch,"flag":row.grant_flag,"family":FAMILY[row.requires_weapon],
				"item":row.material,"cost":int(row.cost),"fee":int(row.gold_fee),"label":PRIMARY[row.branch].display_name})
	return result

static func payable(state: FixedWorldState, quote: Dictionary) -> bool:
	return (not quote.has("family") or state.has(quote.family)) and int(state.value.inventory.get(quote.item,0))>=quote.cost and state.value.services.gold>=quote.fee

static func install(sites: WorldContentSites, npc: String, id: String, revision: int) -> bool:
	var s:=sites.session
	if not sites.workshop_here(npc) or s.state.revision!=revision or not s.state.has("smith"): return false
	for quote: Dictionary in quotes(s.state,s.weapon_growth,s.room.room_id):
		if quote.id!=id or not payable(s.state,quote) or s.state.value.receipts.has(id): continue
		var next:=s.state.candidate()
		next.inventory[quote.item]-=quote.cost
		next.services.gold-=quote.fee
		match quote.kind:
			"attack": next.inventory["attack_rank"]=quote.level
			"skill": next.flags.append("skill_tier_"+str(quote.level))
			"branch": next.flags.append(quote.flag)
		sites.record(next,quote)
		return s.state.commit(next,revision)
	return false
