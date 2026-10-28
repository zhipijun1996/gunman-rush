# Audio Event Catalog（基线审计）

任务 AUDIO-DIRECTOR-01；固定源码 `26e7f2a4459623f35613a857da8a75e89daa3e62`。完整事件/路径/全部调用行见 [event_catalog.json](event_catalog.json)。

以下为代码映射验证，不是听感或实际试玩覆盖声明。自动扫描包括条件表达式及动态中间接口；原始callsites全部保留。候选接入和新事件规范另见当前Audio Director文档，不能回写基线。

## 事件映射

| 事件ID | 实际语义 | 代码位置（基线） |
| --- | --- | --- |
| `cue.focus_start` | 慢瞄开始／二跳／钩索释放／旧武器阶段共享 | `scripts/art/player_feedback.gd:34`、`scripts/art/player_feedback.gd:58`、`scripts/art/player_feedback.gd:67`、`scripts/combat/weapon_action_runtime.gd:55`、`scripts/combat/weapon_action_runtime.gd:122`、`scripts/combat/weapon_action_runtime.gd:242`、`scripts/dev/player_presentation_01/motion_feel.gd:44` |
| `cue.focus_end` | 慢瞄结束 | `scripts/art/player_feedback.gd:58` |
| `cue.enemy_defeat` | 敌人接受死亡（可被DeathAudio替换） | `scripts/enemies/enemy_actor.gd:75` |
| `cue.door` | 已接受关卡／区域门转换 | `scripts/demo/demo_app.gd:340`、`scripts/generation/plains_region_assembler.gd:80`、`scripts/generation/thorn_forest_region_assembler.gd:141`、`scripts/generation/thorn_forest_region_assembler.gd:164` |
| `cue.warning` | 敌人／Boss攻击预告或封门 | `scripts/bosses/bellstrider_presentation.gd:39`、`scripts/bosses/boss_arena_seal.gd:28`、`scripts/bosses/rootbell_guardian_v2.gd:206`、`scripts/bosses/thorn_forest_encounter.gd:115`、`scripts/bosses/windkeeper_presentation.gd:71`、`scripts/enemies/enemy_attack_behavior.gd:134` |
| `cue.boss_impact` | Boss动作冲击及DefeatBurst | `scripts/art/defeat_burst.gd:7`、`scripts/bosses/bellstrider_presentation.gd:40`、`scripts/bosses/boss_arena_seal.gd:48`、`scripts/bosses/boss_arrival_presentation.gd:30`、`scripts/bosses/windkeeper_presentation.gd:72` |
| `cue.click` | 全部BaseButton pressed自动点击 | `scripts/audio/game_audio.gd:71` |
| `cue.confirm` | 接受交易、资源恢复和部分动作成功共享 | `scripts/art/player_feedback.gd:51`、`scripts/art/visual_language_sample.gd:320`、`scripts/combat/weapon_action_runtime.gd:122`、`scripts/combat/weapon_action_runtime.gd:360`、`scripts/combat/weapon_action_runtime.gd:365`、`scripts/demo/demo_app.gd:1017`、`scripts/demo/demo_app.gd:1044`、`scripts/demo/demo_app.gd:1901`、`scripts/demo/demo_app.gd:2118`、`scripts/demo/demo_app.gd:2267`、`scripts/demo/demo_app.gd:2280`、`scripts/demo/demo_app.gd:2497` |
| `cue.coin` | 金币及普通奖励 | `scripts/demo/demo_app.gd:1851`、`scripts/demo/demo_app.gd:1889`、`scripts/demo/demo_app.gd:2067` |
| `cue.note` | 音符／其他拾取 | `scripts/demo/demo_app.gd:1889` |
| `cue.victory` | 运行成功／区域完成 | `scripts/demo/demo_app.gd:1235` |
| `cue.jump` | 经典主角起跳／蹬墙／钩索踢出及旧动作 | `scripts/art/player_feedback.gd:34`、`scripts/art/player_feedback.gd:66`、`scripts/combat/weapon_action_runtime.gd:122` |
| `cue.land` | 经典主角落地 | `scripts/art/player_feedback.gd:71` |
| `cue.step` | 主角累计移动距离脚步 | `scripts/art/player_feedback.gd:109` |
| `cue.hurt` | 敌人普通受击和主角受伤共享 | `scripts/art/player_feedback.gd:195`、`scripts/enemies/enemy_actor.gd:122` |
| `cue.shot` | 旧版主角射击（新正式WeaponFeel委派关闭） | `scripts/art/player_feedback.gd:78` |
| `cue.impact` | 旧弹体接触／钩索接触踢出／武器后备 | `scripts/art/player_feedback.gd:37`、`scripts/art/player_feedback.gd:88`、`scripts/combat/weapon_action_runtime.gd:353` |
| `cue.armour` | 护甲／无效伤害反馈 | `scripts/bosses/bellstrider_presentation.gd:28`、`scripts/bosses/thorn_damageable.gd:9`、`scripts/bosses/windkeeper_presentation.gd:43`、`scripts/enemies/prototype_enemy_damageable.gd:10`、`scripts/enemies/root_bell_behavior.gd:105` |
| `cue.core` | Boss铃芯有效受击 | `scripts/bosses/bellstrider_presentation.gd:27`、`scripts/bosses/windkeeper_presentation.gd:47` |
| `cue.enemy_shot` | 敌方攻击发射 | `scripts/bosses/thorn_forest_encounter.gd:107`、`scripts/enemies/enemy_attack_behavior.gd:113`、`scripts/enemies/forest_seed_sentry_behavior.gd:39` |
| `cue.heal` | 接受生命拾取／生命奖励 | `scripts/demo/demo_app.gd:1851`、`scripts/demo/demo_app.gd:1889`、`scripts/demo/demo_app.gd:2067` |
| `cue.death` | 主角死亡和运行失败共享 | `scripts/art/player_feedback.gd:55`、`scripts/demo/demo_app.gd:1235` |
| `cue.bell` | 机关射铃／钩索连接／部分种子接触共享 | `scripts/art/player_feedback.gd:35`、`scripts/bosses/thorn_seed_projectile.gd:39`、`scripts/enemies/forest_seed_projectile.gd:29`、`scripts/enemies/root_bell_behavior.gd:43`、`scripts/world/forest_practice_bell.gd:58`、`scripts/world/shot_latch.gd:336` |
| `cue.denied` | UI拒绝／射击拒绝／钩索失败共享 | `scripts/art/player_feedback.gd:42`、`scripts/art/player_feedback.gd:59`、`scripts/combat/weapon_action_runtime.gd:363`、`scripts/demo/demo_app.gd:1044`、`scripts/demo/demo_app.gd:1901`、`scripts/demo/demo_app.gd:2280` |
| `cue.roar` | 牧风者阶段咆哮 | `scripts/bosses/windkeeper_presentation.gd:69` |
| `cue.forest_wind` | 森林每9秒风声（首次3秒） | `scripts/presentation/forest_bible_ambience.gd:79` |
| `cue.forest_fruit` | 800wu内接受果枝钩索 | `scripts/presentation/forest_bible_ambience.gd:62` |
| `cue.forest_web` | 800wu内真实蛛网生长状态进入 | `scripts/presentation/forest_bible_ambience.gd:72` |
| `motion.jump` | 新版主角接受起跳 | `scripts/dev/player_presentation_01/motion_feel.gd:43`、`scripts/dev/player_presentation_01/motion_feel.gd:21` |
| `motion.land` | 新版主角轻落地 | `scripts/dev/player_presentation_01/motion_feel.gd:55`、`scripts/dev/player_presentation_01/motion_feel.gd:22` |
| `motion.heavy` | 新版主角重落地 | `scripts/dev/player_presentation_01/motion_feel.gd:55`、`scripts/dev/player_presentation_01/motion_feel.gd:22` |
| `weapon.pulse` | 接受普通枪及默认弹体射击／反冲同帧反馈 | `scripts/dev/player_presentation_01/weapon_feel.gd:122`、`scripts/dev/player_presentation_01/weapon_feel.gd:78` |
| `weapon.machine` | 接受机枪弹次 | `scripts/dev/player_presentation_01/weapon_feel.gd:78` |
| `weapon.blade` | 手里剑／扇刃／实体掷出 | `scripts/dev/player_presentation_01/weapon_feel.gd:158`、`scripts/dev/player_presentation_01/weapon_feel.gd:78` |
| `weapon.hit` | 确认敌方HP伤害提交；不是固体接触 | `scripts/dev/player_presentation_01/weapon_feel_v2.gd:68` |
| `weapon.wall` | 真实地形接触或地雷附着 | `scripts/dev/player_presentation_01/weapon_feel_v2.gd:58`、`scripts/dev/player_presentation_01/weapon_feel_v2.gd:107` |
| `weapon.blast` | 接受爆炸 | `scripts/dev/player_presentation_01/weapon_feel.gd:128`、`scripts/dev/player_presentation_01/weapon_feel_v2.gd:99`、`scripts/dev/player_presentation_01/weapon_feel_v2.gd:73`、`scripts/dev/player_presentation_01/weapon_feel_v2.gd:100` |
| `weapon.ion_start` | 光束开始／蓄力／炮释放 | `scripts/dev/player_presentation_01/weapon_feel_v2.gd:80`、`scripts/dev/player_presentation_01/weapon_feel_v2.gd:86`、`scripts/dev/player_presentation_01/weapon_feel_v2.gd:93` |
| `weapon.ion_loop` | 光束持续阶段 | `scripts/dev/player_presentation_01/weapon_feel_v2.gd:31`、`scripts/dev/player_presentation_01/weapon_feel_v2.gd:81` |
| `weapon.ion_tail` | 光束结束 | `scripts/dev/player_presentation_01/weapon_feel_v2.gd:88` |
| `weapon.blackhole_start` | 奇点启动 | `scripts/dev/player_presentation_01/weapon_feel_v2.gd:83` |
| `weapon.blackhole_loop` | 奇点持续阶段 | `scripts/dev/player_presentation_01/weapon_feel_v2.gd:32`、`scripts/dev/player_presentation_01/weapon_feel_v2.gd:84` |
| `weapon.blackhole_burst` | 奇点爆发 | `scripts/dev/player_presentation_01/weapon_feel_v2.gd:99`、`scripts/dev/player_presentation_01/weapon_feel_v2.gd:73`、`scripts/dev/player_presentation_01/weapon_feel_v2.gd:100` |
| `weapon.mine_beep` | 真实地雷age/fuse节奏提示 | `scripts/dev/player_presentation_01/weapon_feel_v2.gd:125` |
| `weapon.boomerang_return` | 回旋镖返回／自动接住 | `scripts/dev/player_presentation_01/weapon_feel_v2.gd:105`、`scripts/dev/player_presentation_01/weapon_feel_v2.gd:109` |
| `music.home` | 用户原BGM；由DemoApp真实状态选择 | `scripts/audio/game_music.gd:5`、`scripts/demo/demo_app.gd:116`、`scripts/demo/demo_app.gd:1368` |
| `music.plains` | 用户原BGM；由DemoApp真实状态选择 | `scripts/audio/game_music.gd:6`、`scripts/demo/demo_app.gd:1371` |
| `music.plains_boss` | 用户原BGM；由DemoApp真实状态选择 | `scripts/audio/game_music.gd:7`、`scripts/demo/demo_app.gd:1375` |
| `music.forest` | 用户原BGM；由DemoApp真实状态选择 | `scripts/audio/game_music.gd:8`、`scripts/demo/demo_app.gd:1371` |
| `music.forest_boss` | 用户原BGM；由DemoApp真实状态选择 | `scripts/audio/game_music.gd:9`、`scripts/demo/demo_app.gd:1375` |

## 正式动作同步与生命周期

- 新主角跳跃/落地：真实motor/controller事件→candidate visual的motion_jump/motion_land→PlayerMotionFeel；旧jump/land回调显式断开，退出时恢复。命中音只订阅接受后的weapon_damage_committed，物理接触只画火花，地形另走wall。
- 同时齐射只发一枪声；机枪逐轮。持续ion/blackhole声随真实Runtime phase进入/退出，stop_weapon(owner,true)清理；地雷85ms录音依真实entity age/fuse排节奏，不用音轨驱动玩法。
- 角色伤害/死亡/segment return清理Motion/Weapon表现，武器epoch/session变更清理旧声；GameAudio/音乐服务在App卸载时有shutdown。一般短cue由App池持有，不能据此宣称每个短voice都按actor epoch取消。
- 默认敌人死亡仍使用Kenney enemy_defeat。EnemyFeedback01DeathAudio保留同cue的origin meta替换能力，但当前默认host没有配置该helper；现有legacy资产登记亦明确fixture_only。恢复已死亡实例不重放；基础override仅对enemy_defeat生效，不能假设所有事件已支持参数化override。

## 缺失或折叠的语义

- `hook.release / hook.connect / hook.pull / hook.miss`：existing shared cues, no dedicated family or sustained pull loop。
- `player.hurt vs enemy.hurt`：same cue.hurt; independent scopes collide with global cooldown。
- `recoil`：accepted shot supplies feedback; no standalone recoil audio layer observed。
- `plains wind / gears / pendulum / material-specific footsteps / enemy species vocal identity`：no dedicated runtime event mapping found in audited source; not proof every future design requires one。

## 冲突与待试听判断

- Nonlethal enemy HP hit may trigger shared hurt plus weapon.hit; this is observed static layering, not a claim of audible clipping
- All BaseButton pressed emits click; explicit confirm/denied can layer on the same interaction
- Shared global cue cooldown can suppress unrelated origins (e.g. player.hurt after enemy.hurt)
- motion and weapon serials cycle deterministically; no shuffle bag or per-family no-repeat policy
- Most SFX have no spatial attenuation; forest has binary 800wu gate and standalone bell has 2D attenuation
- Parent V1 bank and V2 timer files stay loaded although formal V2 replaces their playback mapping

上述冲突是静态行为与设计风险；响度是否不适、哪个层应去除、素材是否悦耳均保持subjective_pending，须在单声和同场景BGM中试听。不能用hash不同或有3个变体宣称避免疲劳。

## 音频节点和事件边界

全项目非历史代码的AudioStreamPlayer/AudioServer/bus引用及全部生成/加工代码入口已存入inventory.json；测试、工具调用保留scope标记。没有静态引用只说明本次未发现，不将资源直接判可删除。
