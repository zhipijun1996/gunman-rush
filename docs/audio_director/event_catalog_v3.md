# Audio Event Catalog · V3试听增量

本表是基于[固定main原审计](event_catalog.md)的增量，原审计代码行保持其26e7f2a身份，不冒称已经全游戏采用。14新ID只在显式V3 bank/开发录屏中选择，正式默认original。所有候选/源/trace见[manifest](../../assets/audio/director_v3/manifest.json)。

| 事件/录屏 | 接受时点及真实代码消费者 | 原版/新方案边界 |
| --- | --- | --- |
| coin / heal | [真实Area接触](../../scripts/dev/audio_director_lab_pickup.gd#L27)→[钱包或SupplyHealEffect接受](../../scripts/dev/audio_director_lab_v2.gd#L304)→GameAudio | 原版旧cue；V3 bank显式选择清脆收集/液体主体 |
| chest_open | [靠近后的Router交互、RewardService接受及可见开盖](../../scripts/dev/audio_director_reels.gd#L141) | 原版沿旧confirm通用音；新ID独立，不代表所有正式区域宝箱已改 |
| item_get | [Area接触及RewardService.claim成功](../../scripts/dev/audio_director_reels.gd#L117)→[真实ItemAcquiredToast](../../scripts/dev/audio_director_reels.gd#L127) | 原版旧note通用音；新获得乐句独立，重复领取不发 |
| click / confirm / denied | [实际选择按钮及ShopService购买回执](../../scripts/dev/audio_director_lab_v2.gd#L237) | generic点击不等于成功交易，profile控制钮不额外叠点击 |
| enemy_hit | 原[武器伤害提交信号](../../scripts/dev/player_presentation_01/weapon_feel_v2.gd#L60)→[weapon_cue](../../scripts/dev/player_presentation_01/weapon_audio.gd#L11) | 只在accepted enemy HP伤害后；墙接触独立。录屏与enemy_hurt分焦点 |
| enemy_hurt | [真实敌人/FrameDamagePolicy损伤接受](../../scripts/dev/audio_director_lab_v2.gd#L326) | 身体反应层；同次损伤的武器层在本片暂隔离，原版与候选条件一致 |
| hurt | [原敌弹发射](../../scripts/dev/audio_director_lab_v2.gd#L358)→[真实HealthState APPLIED damage](../../scripts/dev/audio_director_lab_v2.gd#L384) | 无直接改HP伪装受伤；拾取初始缺血静默，不夹杂准备伤音 |
| shot_pulse / shot_shuriken | 原ShootAbility.shot_fired→[真实当前weapon.id传给音频](../../scripts/dev/player_presentation_01/weapon_feel.gd#L63)→[按精确武器ID路由](../../scripts/dev/player_presentation_01/weapon_audio.gd#L69) | 仅pulse_gun/shadow_shuriken；其他blade/pulse类不误用这两个ID |
| shot_bomb | [新Lab只订阅原accepted shot_fired](../../scripts/dev/audio_director_reels.gd#L289) | 正式原版launch无专用音；仅V3 Lab新profile加发射声，原版保安静 |
| bomb_explode | 原WeaponActionRuntime.blast_fired→[原Feel爆炸消费者](../../scripts/dev/player_presentation_01/weapon_feel_v2.gd#L96)→同服务路由 | 与发射是独立接受信号，Lv1可同帧；实际爆破后才发，其他blast模式不误用bomb |
| mix | [原Home BGM＋真实拾取/弹体/HP序列](../../scripts/dev/audio_director_reels.gd#L198) | 每profile同曲起点，Godot现场混音录出，页面不再叠BGM |

`weapon_cue`末尾新增可选weapon_id，旧调用兼容。新weapon声音沿原12voice、owner family清理，缺V3 bank或original不改旧音色。未增加伤害、反冲、弹药、输入TTL、命中范围、物理或存档规则；固定开发初始条件与摄影机仅在reels fixture。

后续事件（未生产/未采用）：钩索完整五阶段、其他武器等级/技能/装填、机关锁定/开启、各材质敌人/死亡、Boss预告/破防、UI地图/对话/存档及地区环境。需要先查对应正式消费者，依本轮功能风格选材、录实际动作，不把placeholder或仅有文件当事件已接入。
