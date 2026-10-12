class_name ItemPresentation
extends RefCounted
const ATLAS:=preload("res://assets/plains_v4/items/icons.png")
const EXPANSION:=preload("res://assets/plains_v4/items/expansion.png")
const EXTRA_KEYS:=[&"stabilizer",&"braid",&"hammer",&"brakes",&"cooling",&"bandage"]
const KEYS:=[&"barrel",&"heart",&"magazine",&"coil",&"boots",&"echo",&"grip",&"map",&"energy"]
const NAMES:={&"max_jumps":"跳跃次数 / Jumps",&"max_air_shots":"空中弹药 / Air rounds",&"projectile_damage":"射击伤害 / Damage",&"shot_burst_speed":"反冲速度 / Recoil",&"recoil_impulse":"反冲 / Recoil",&"max_health":"生命上限 / Max HP",&"shot_energy_cost":"每发精力 / Shot cost",&"hit_energy_recovery":"命中回能 / Hit energy",&"ground_recoil_multiplier":"地面反冲 / Ground recoil",&"ground_deceleration":"地面减速 / Braking",&"shot_cooldown":"开枪间隔 / Shot interval",&"ground_energy_recovery":"落地回能 / Ground energy",&"shot_energy_delay":"回能等待 / Recovery delay"}
static func icon(key: StringName) -> Texture2D:
	if key in [&"run_coin",&"healing",&"meta_note"]: return PlainsV3Assets.texture("objects.json",str(key))
	var extra:=EXTRA_KEYS.find(key)
	if extra>=0:
		var tile:=AtlasTexture.new();tile.atlas=EXPANSION;tile.region=Rect2((extra%3)*512,(extra/3)*512,512,512);tile.filter_clip=true;return tile
	var i:=KEYS.find(key)
	if i<0: return null
	var texture:=AtlasTexture.new()
	texture.atlas=ATLAS
	texture.region=Rect2((i%3)*512,(i/3)*341,512,342 if i>=6 else 341)
	texture.filter_clip=true
	return texture
static func effects(item: ItemDefinition) -> String:
	if item is ResourceRewardChoice:
		return (item as ResourceRewardChoice).effect_text()
	var lines: PackedStringArray=[]
	for m: BuildModifier in item.modifiers:
		var amount: String
		if m.operation==BuildModifier.Operation.MULTIPLY: amount="%+.0f%%" % ((m.value-1.0)*100)
		elif m.operation==BuildModifier.Operation.OVERRIDE: amount="= %s" % str(snappedf(m.value,.01))
		else: amount="+%s" % str(snappedf(m.value,.01))
		lines.append(str(NAMES.get(m.stat_id,"效果 / Effect"))+" "+amount)
	return "\n".join(lines)
