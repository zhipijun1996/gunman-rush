@static_unload
class_name ItemPresentation
extends RefCounted
const EXTRA_KEYS:=[&"stabilizer",&"braid",&"hammer",&"brakes",&"cooling",&"bandage"]
const KEYS:=[&"barrel",&"heart",&"magazine",&"coil",&"boots",&"echo",&"grip",&"map",&"energy"]
const NAMES:={&"focus_rearm_stamina":"慢时再启能量 / Rearm energy",&"focus_stamina_drain":"慢时耗能 / Time drain",&"focus_stamina_recovery":"接地回能 / Time recovery",&"max_jumps":"跳跃次数 / Jumps",&"max_air_shots":"空中弹药 / Air rounds",&"projectile_damage":"射击伤害 / Damage",&"shot_burst_speed":"反冲速度 / Recoil",&"recoil_impulse":"反冲 / Recoil",&"max_health":"生命上限 / Max HP",&"shot_energy_cost":"每发精力 / Shot cost",&"hit_energy_recovery":"命中回能 / Hit energy",&"ground_recoil_multiplier":"地面反冲 / Ground recoil",&"ground_deceleration":"地面减速 / Braking",&"shot_cooldown":"开枪间隔 / Shot interval",&"ground_energy_recovery":"落地回能 / Ground energy",&"shot_energy_delay":"回能等待 / Recovery delay"}
static func icon(key: StringName) -> Texture2D:
	return UnderworldUI.icon(key)

static func reason(value: Variant, fallback := "条件尚未满足，暂不可操作。") -> String:
	var text := String(value)
	var messages := {"maximum_level":"此道具已达最高等级。","ownership_limit":"已达持有数量上限。","duplicate_owned":"已持有此道具。","insufficient_coins":"金币不足。","sold_out":"已售罄。","not_in_shop":"请在商店交互时修复。","not_at_shop":"请在商店交互时修复。","not_broken":"道具尚未损坏，无需修复。","not_owned":"本局未持有该道具。","stale":"操作已过期，请重新打开界面。","stale_quote":"报价已变化，请重新查看。","stale_revision":"构筑已变化，请重新选择。","stale_session":"操作已过期，请重新打开界面。","stale_actor":"当前无法操作。","weapon_required":"当前武器不符合前置条件。","capability_required":"尚未解锁所需核心能力。","prerequisite":"缺少所需的已装备道具。","capacity_exceeded":"齿轮负荷不足，请先卸下其他道具。","exclusive":"与现有装备互斥。","locked_until_run_end":"本局已锁定，结束本局后解除。","active_required":"请先装备所需主动道具。"}
	if messages.has(text): return messages[text]
	for index: int in text.length():
		if text.unicode_at(index) > 127: return text
	return fallback

static func effects(item: ItemDefinition, level: int = 1, effect_state: Dictionary = {}) -> String:
	if item is ResourceRewardChoice:
		return (item as ResourceRewardChoice).effect_text()
	if item.catalog_version >= 5: return _catalog_effects(item,level,effect_state)
	var lines: PackedStringArray=[]
	for m: BuildModifier in item.stat_modifiers():
		var amount: String
		if m.operation==BuildModifier.Operation.MULTIPLY: amount="%+.0f%%" % ((m.value-1.0)*100)
		elif m.operation==BuildModifier.Operation.OVERRIDE: amount="= %s" % str(snappedf(m.value,.01))
		else: amount="+%s" % str(snappedf(m.value,.01))
		lines.append(str(NAMES.get(m.stat_id,"效果 / Effect"))+" "+amount)
	return "\n".join(lines)

static func _catalog_effects(item: ItemDefinition, level: int, effect_state: Dictionary = {}) -> String:
	var parameters := item.parameters_for_level(level)
	if parameters.is_empty(): return "当前等级不可用。"
	var formats: Dictionary = {
		&"B03":"主武器直接伤害 ×{primary_damage_multiplier}；技能及派生伤害不重复加成。",
		&"B05":"主攻冷却 ×{primary_cooldown_multiplier}；总冷却倍率最低0.65，仍需合法松手发射。",
		&"B22":"炸弹家族爆炸半径 ×{bomb_explosion_radius_multiplier}；不改变伤害、安放与位移。",
		&"B29":"普通枪弹射程 ×{projectile_range_multiplier}；不能穿墙，不增加反冲。",
		&"B31":"可硬直普通敌人的受击硬直 ×{enemy_stagger_multiplier}；不突破Boss护甲与窗口。",
		&"P03":"武器三级主动技能直接伤害 ×{lv3_skill_damage_multiplier}；资源和位移不变。",
		&"P06":"满血空中瞄准时，世界时间流速为0；玩家仍可移动。仍消耗时间能量，单次腾空慢时累计最多{airtime_focus_budget_s}秒。",
		&"P08":"主弹额外贯穿{max_extra_pierce}名敌人，贯穿伤害为{pierced_damage_ratio_D}D；不能穿墙或护甲。",
		&"P23":"奇点吸引时间 +{singularity_pull_duration_add_s}秒，爆炸伤害 ×{singularity_explosion_damage_multiplier}；不能远程安放或解除锁定。",
		&"P31":"空中实际反冲后的主攻命中额外造成{air_recoil_hit_extra_damage_ratio_D}D；每攻击包一次，冷却{cooldown_s}秒。",
		&"P33":"激光有效命中宽度 ×{laser_hit_width_multiplier}；中心射线和伤害结算频率不变。",
		&"P34":"三连枪第三发真实命中产生{third_hit_bonus_damage_ratio_D}D冲击波，半径{blast_radius_px}；三发共用一个攻击包。",
		&"B07":"地面反冲倍率 ×{ground_recoil_multiplier}；空中反冲不变。",
		&"B08":"离台土狼跳时间 +{coyote_time_add_s}秒；不增加跳跃次数或奔跑惯性。",
		&"B23":"反冲终点留下半径{radius_px}的齿环，持续{effect_duration_s}秒，接触造成{damage_ratio_D}D；冷却{cooldown_s}秒，不额外位移。",
		&"B28":"普通地面跑速 ×{run_speed_multiplier}；不增加空中、反冲或钩索速度。",
		&"P12":"实际反冲路径接触造成{path_contact_damage_ratio_D}D，宽度{contact_width_px}；每敌每次反冲一次，并受每敌2秒冷却限制。",
		&"G01":"空中主攻施加{mark_duration_s}秒印记，下个不同攻击包命中引爆{detonation_damage_ratio_D}D；同目标冷却{target_cooldown_s}秒。",
		&"B19":"钩索有效命中敌人额外获得{extra_combat_energy_on_hook_hit}点战斗共鸣；仍受每攻击包12点上限约束。",
		&"B21":"钩索有效距离 ×{hook_range_multiplier}；不授予钩索核心能力。",
		&"P13":"钩索接触施加{mark_duration_s}秒追索标记，对该目标主攻直接伤害 ×{marked_primary_damage_multiplier}。",
		&"P29":"合法主动攻击命中后，向半径{chain_radius_px}内最多{chain_targets}名额外敌人传导{chain_damage_ratio_D}D电击；冷却{cooldown_s}秒，不穿墙、不回能。",
		&"B04":"空中枪械与钩索瞄准的时间能量消耗 ×{focus_stamina_drain_multiplier}；射击本身不扣时间能量。",
		&"P04":"空中主攻命中后{buff_window_s}秒内，下一次主攻直接伤害 ×{next_primary_multiplier}；单次生成与消费。",
		&"B06":"空中主攻命中返还{air_hit_refund}时间能量，每次腾空最多返还{airtime_refund_cap}；每攻击包一次，不延长2秒慢时上限。",
		&"B09":"接地自然恢复时间能量的速度 ×{focus_stamina_recovery_multiplier}；空中不自然恢复。",
		&"B18":"主攻击包每个有效目标额外获得{extra_combat_energy_per_target}共鸣；整包总收益最多{energy_packet_total_cap}点。",
		&"B26":"战斗共鸣上限 +{max_resonance_add}；装备或升级不免费补充当前共鸣。",
		&"P02":"技能共鸣消耗 ×{skill_combat_energy_cost_multiplier}；每次至少15点，不影响时间能量。",
		&"B33":"主动消耗{combat_energy_cost}共鸣，产生半径{radius_px}、{damage_ratio_D}D的爆炸；冷却{cooldown_s}秒。炸弹家族不再抽取此道具。",
		&"P17":"有真实蓄力前摇的武器三级技能，蓄力时可按基础地速 ×{charge_move_speed_multiplier}移动；不解除奇点等锁定。",
		&"B11":"最大生命 +{max_hp_add}；装备或升级不自动回血，卸下只钳制当前生命。",
		&"B13":"已装备时首次进入新地图获得{map_start_barrier}点临时护盾；中途换装不补，共享护盾上限3。",
		&"B14":"实际损失生命后获得{combat_energy_gain_on_damage}点战斗共鸣；同次伤害一次，致死后不触发。",
		&"B15":"损失生命后，在半径{radius_px}内反击{damage_ratio_D}D；冷却{cooldown_s}秒，派生伤害不回能。",
		&"B27":"已有受伤无敌时间 +{invulnerable_add_s}秒；保持原伤害与死亡优先规则。",
		&"B30":"最大生命 +{max_hp_add}；累计{break_on_hits}次真实生命伤害后损坏。商店修复需{repair_price}金币，修复不回血。",
		&"B32":"已装备时首次进入新地图获得{map_start_barrier}点临时护盾；回退和换装不重复生成，共享上限3。",
		&"P18":"最大生命 ×{max_hp_multiplier}；首次装备按原生命比例转换一次。本局锁定不可卸下，此后常规治疗无效。",
		&"P20":"真实反冲开始的位置留下水晶，持续{crystal_lifetime_s}秒，敌人接触造成{contact_damage_ratio_D}D；不授予传送。",
		&"P26":"主动消耗{combat_energy_cost}共鸣，抵御合规伤害{invulnerable_duration_real_active_s}秒；冷却{cooldown_s}秒。暂停不计时，不抵挡坠落与强制失败。",
		&"P27":"主动消耗{combat_energy_cost}共鸣，恢复{heal_hp}生命；每图最多{max_uses_per_map}次。满血或禁疗时不能使用。",
		&"G02":"每累计{hits_for_one_barrier}次真实生命受伤获得{shield_per_trigger}点护盾；跨图保留计数，护盾吸收不计，共享上限{shared_barrier_cap}。",
		&"G03":"已装备时首次进入每张新地图恢复{heal_hp_on_new_map}生命；返回旧图与换装不重触发，受禁疗约束。",
		&"G04":"即将因敌方伤害死亡时，消耗{combat_energy_cost}共鸣保留{set_remaining_hp}生命；每图最多{uses_per_map}次。不挡强制失败。",
		&"G11":"最大生命 +{max_hp_add}；不会破损，与易裂心匣互斥，装备不回血。",
		&"P05":"生命比例不高于{hp_ratio_threshold}时，主攻直接伤害 ×{primary_damage_multiplier}；随当前生命实时启停。",
		&"B24":"主攻附加{dot_duration_s}秒余火，总伤害{total_dot_damage_ratio_D}D；同目标只刷新不叠加，派生不回能。",
		&"P09":"主攻命中引发半径{radius_px}、{explosion_damage_ratio_D}D的爆震；冷却{cooldown_s}秒，每攻击包最多一次，不递归。",
		&"P10":"主动技能后{primed_window_s}秒内首次主攻命中生成半径{cloud_radius_px}的腐蚀云，持续{cloud_duration_s}秒，每秒{dot_damage_per_second_ratio_D}D；不回能。",
		&"P14":"装备时跟随{small_drone_count}台巡钟无人机，每台每{attack_interval_s}秒攻击{attack_damage_ratio_D}D；卸下消失，不产生共鸣。",
		&"P15":"每实际消耗{combat_energy_spent_threshold}共鸣产生临时巡钟机，持续{temp_drone_lifetime_s}秒，每击{temp_drone_damage_ratio_D}D，同场最多{max_temp_drones}台。",
		&"P16":"环绕梦盾拦截{projectile_blocks_per_cooldown}颗敌方可拦截飞弹，冷却{cooldown_s}秒；不防身体碰撞、荆棘或不可拦截Boss招式。",
		&"G05":"主动消耗{combat_energy_cost}共鸣，召唤最多{max_large_drones}台大型钟卫，持续{lifetime_s}秒，每{attack_interval_s}秒造成{attack_damage_ratio_D}D；冷却{skill_cooldown_s}秒。",
		&"G06":"主攻命中向半径{chain_radius_px}内最多{chain_targets}个额外目标连锁，每个{chain_damage_ratio_D}D；冷却{cooldown_s}秒，不回能或再连锁。",
		&"B01":"吸取半径{pickup_radius_px}内无遮挡的金币、永久音符与生命／能量资源；不自动领取道具、宝箱或商店货物。",
		&"B16":"每图前{max_bonus_kills_per_map}次合法击杀各额外获得{bonus_coin_per_kill}金币；累计{break_on_hits}次生命受伤后损坏，商店修复{repair_price}金币。",
		&"B20":"首次钩中不同敌人获得{coin_per_enemy}金币，每图最多{map_coin_cap}金币；Boss与重复目标不给金币。",
		&"P39":"合法击杀所得金币 ×{kill_coin_multiplier}，小数结余累计；受伤不扣钱，不影响宝箱或退款。",
		&"G10":"每图前{max_bonus_kills_per_map}次合法击杀各额外获得{bonus_coin_per_kill}金币；与裂纹钱袋互斥。",
		&"G12":"每图{free_rerolls_per_map}次商店刷新免费；蓝色概率减少{blue_penalty_pp}百分点，紫色增加{purple_bonus_pp}、金色增加{gold_bonus_pp}百分点。",
		&"G07":"脱战{idle_delay_s}秒后，每秒恢复{resonance_per_s}共鸣；每图最多恢复{max_recovery_per_map}点，换装不能重置。",
		&"G08":"伴机优先攻击追索标记目标，首次副伤 ×{marked_companion_first_hit_multiplier}；需要同时具备伴机与标记。",
		&"B17":"主武器直接伤害 ×{primary_damage_multiplier}；累计{break_on_hits}次生命受伤后损坏，仍占原负荷。商店修复{repair_price}金币。",
		&"P24":"主动消耗{combat_energy_cost}共鸣，抛出往返飞轮，总伤害预算{total_damage_ratio_D}D，射程{range_px}；冷却{cooldown_s}秒。",
		&"P25":"主动消耗{combat_energy_cost}共鸣，在脚下可靠地面放置针雷，持续{trap_lifetime_s}秒，半径{radius_px}、伤害{trap_damage_ratio_D}D，最多{max_active_traps}枚；冷却{cooldown_s}秒。无可靠地面不扣能。",
		&"G14":"主动消耗{combat_energy_cost}共鸣，向瞄准方向投掷雷樽，主伤{throw_damage_ratio_D}D，再连锁最多{chain_targets}名敌人各{chain_damage_ratio_D}D；冷却{cooldown_s}秒。只有投掷模式。",
		&"G15":"投射型道具主动技能分为{projectile_count_multiplier}发，合计伤害预算 ×{total_damage_budget_multiplier}；共享一次扣能与冷却。",
		&"G16":"主动消耗{combat_energy_cost}共鸣，释放{pulse_count}段钟波，每段{damage_ratio_D_each}D，距离{range_px}；冷却{cooldown_s}秒，不添加位移。",
		&"G19":"跟随1台成长型侍钟机，基础伤害{base_damage_ratio_D}D，每{attack_interval_s}秒攻击；击败精英可成长{evolution_levels}次，每级相对基础增伤{damage_bonus_per_level_pct}%。卸装保留成长。",
		&"N01":"空中瞄准时世界时间流速 ×{world_slow_scale}；正常消耗时间能量，每次腾空慢时上限{airtime_budget_s}秒。满血时由满月枪歌优先停时。",
		&"N02":"主动消耗{combat_energy_cost}共鸣，获得最多{barrier_grant}点临时护盾；每图最多{max_uses_per_map}次，共享护盾上限{shared_barrier_cap}。"}
	var values: Dictionary = {}
	for key: Variant in parameters:
		var value: Variant = parameters[key]
		if value is float:
			values[key] = _display_number(float(value))
		else:
			values[key] = str(value)
	var result: String
	if formats.has(item.stable_id):
		result = str(formats[item.stable_id]).format(values)
	else:
		result = _static_parameter_text(parameters)
		if result.is_empty(): result = item.description.format(values)
	if item.stable_id == &"G19" and effect_state.has("evolution"):
		var maximum := int(parameters.evolution_levels)
		var evolution := clampi(int(effect_state.evolution),0,maximum)
		var damage := float(parameters.base_damage_ratio_D)*(1.0+evolution*float(parameters.damage_bonus_per_level_pct)/100.0)
		result = "成长%s/%s · 当前每%s秒攻击%sD。\n%s" % [evolution,maximum,values.attack_interval_s,_display_number(damage),result]
	# New data without a presentation template remains explicit instead of
	# leaking internal keys or raw JSON into the player's inventory.
	if result.contains("{"): return "当前效果说明尚未同步，请查看道具描述。"
	return result

static func _static_parameter_text(parameters: Dictionary) -> String:
	# New data-only passive items use the same resolved level values as BuildState.
	# Their numerical description must not require another item-ID UI branch.
	var formats := {
		"max_hp_add":"最大生命 +%s；装备不回血。",
		"max_hp_multiplier":"最大生命 ×%s；普通装备不回血。",
		"ground_recoil_multiplier":"地面反冲倍率 ×%s。",
		"coyote_time_add_s":"离台跳跃宽限 +%s秒。",
		"focus_stamina_drain_multiplier":"慢时耗能 ×%s。",
		"focus_stamina_recovery_multiplier":"接地时间能量恢复 ×%s。"}
	var lines := PackedStringArray()
	for key: String in formats:
		if parameters.has(key): lines.append(formats[key] % _display_number(float(parameters[key])))
	return "\n".join(lines)

static func _display_number(value: float) -> String:
	var number := snappedf(value,.001)
	return str(int(number)) if is_equal_approx(number,roundf(number)) else str(number)
