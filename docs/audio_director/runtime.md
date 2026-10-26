# Godot Audio Director 运行规范 v1

本轮为 `AUDIO-DIRECTOR-01` 候选评审接入。正式默认保持 `original`。只有 Sound Lab 显式选择 A/B 才切换首批事件；自动验证不代表音效审美已验收。

## 入口与消费者

沿用 `GameAudio → PlayerMotionAudio → PlayerWeaponFeelAudio → PlayerWeaponFeelAudioV2` 原继承链和原 **12 个 AudioStreamPlayer**，不新增第二个 SFX 池。`GameMusic` 保留原两播放器交叉淡变和五首原始 MP3。

```gdscript
# 每个App实例独立选择；刷新或新建正式App仍默认original。
audio.set_audio_profile("A") # original / A / B；非法值false
# 独立试听支持完整候选ID；空candidate取该服务当前profile。
audio.play_director_event(&"jump", "jump_b", origin)
# 停止此来源的相位层；不截断其他来源或短促连接尾音。
audio.stop_director_cues(origin, true)
```

`GameAudio.cue(origin, old_id)` 对已映射事件在 A/B 中选择候选，其余事件继续现有声音。`GameAudio.cue_event(origin, semantic_id, legacy_id)` 用于原来复用同一 cue 的不同语义；original 调回原接口，因此不变更原事件时机。`EnemyActor._accepted_hit` 仅将已有 hurt 调用分义为 `enemy_hurt`，没有修改受伤、碰撞或运动处理。

| 正式表现入口 | A/B事件 | 原版行为 |
| --- | --- | --- |
| `weapon_cue(pulse)` | shot（含回弹层） | 现有 weapon pulse 三变体 |
| `weapon_cue(hit)` | enemy_hit | 已接受敌伤后的现有 hit 三变体 |
| `motion_cue(jump/land/heavy)` | jump/land | 现有 motion 银行；heavy按真实重落地映射land |
| `EnemyActor._accepted_hit` | enemy_hurt | Kenney hurt |
| `cue(enemy_defeat)` | enemy_death | 正式默认 Kenney enemy_defeat |
| `PlayerFeedback` 已提交主角HP损失 | hurt | Kenney hurt |
| `cue(coin/heal/note)` | coin/heal/reward | 原对应资源 |
| 显式 `cue(confirm/denied)` | confirm/denied | 原对应资源 |
| traversal action `hook_cast` | hook_release | focus_start |
| traversal action `hook_pull` | hook_connect + hook_pull | bell一次；没有持续牵引层 |

基础枪 shot 候选包含反冲回弹材质，实际开枪只发一声；`recoil` 候选可单独试听，不额外叠加到同次射击。非致命命中原来已有 weapon hit 和敌人 hurt 两条语义，本轮保留攻击接触与目标反应两层；致命伤沿现有分支产生 hit 与 death。审美是否叠加过多必须在实际战斗+BGM试听决定。

旧每来源 `audio_cue_stream_overrides` API 在 original 中保留，测试验证兼容；`death_burst.wav` 并非当前正式默认。A/B 选中时有意只播放候选，不再叠加旧死亡覆写。一般 BaseButton 的自动 click 在 original 中保持；A/B 中由显式已接受 confirm/denied 发声，避免拒绝交易同时被泛按钮音宣告成功。未覆盖的导航点击可后续增加独立 click 候选。

## 混音、优先级与重复控制

`ensure_buses()` 只在缺失时创建 `SFX / UI / Ambience / Music → Master`，均为 unity（0dB），不改变现有总音量。集中 cue、motion/weapon 及 GameMusic 已路由；独立 `AudioStreamPlayer2D`、更早的开发消费者仍保原路由，审计清单逐项记录，不能宣称所有声音均已迁移。

候选规则唯一来源为 [runtime.json](../../config/audio_director/runtime.json)。每事件包括 bus、priority、interval、max_voices、attenuation_db；优先级90用于主角受伤、敌人死亡、拒绝和钩索连接，70用于射击/反冲/命中/敌伤，50普通反馈，30牵引相位。全池满时只抢占严格更低优先级，绝不加第13声；同事件达到上限时丢弃。`director_dropped / director_preemptions / director_events` 可观察选择与压力，记录有界为256条。

候选 cooldown 使用真实时间（从引擎delta除以time_scale），暂停只允许UI。变体使用服务独立 `RandomNumberGenerator`，不触碰全局或地图/奖励随机流；同一候选多输入时禁止连续重复。v1每方向有两个真实输入变体，不添加连续随机音高以掩盖同一素材。原版节流和三变体次序仍保留。A/B 中尚未替换的 death / warning / boss_impact 也按90优先级抢占低声部，继续播放原资源；original 保持旧满池丢弃行为。

GameMusic 的 `MUSIC_GAIN=0.16`、session volume、0.9s crossfade、pause gain=0.5 保持原值。候选不是按全局同一响度强推，保留事件强弱；实际全混音峰值、遮蔽、刺耳度与手机扬声器表现仍须试听。没有新增自动ducking或主限幅器，不把单文件−4dBFS峰值误称混音总线不会削波。

## 空间与生命周期

本轮候选继续原 `AudioStreamPlayer` 近身/界面反馈，**没有伪称实现空间衰减**。现有铃机关的 `AudioStreamPlayer2D` 等空间消费者保留其原距离设置。后续区域环境/远处敌声应在来源规范中确定2D距离和衰减后迁移，不能让同一事件无条件全图等响。

- A/B切换清空旧池尾音及节流，确保比较不混入上一个方向；不会移动角色、换武器、改资源或重置场景。
- 每个带origin的候选保存弱引用，origin离树后停止；不通过音频回调写任何玩法状态。
- motion/weapon候选携带家族与owner，沿原 `stop_motion/stop_weapon` 清理，移动清理不会吞掉同owner枪声。
- 钩索连接只来自原 accepted `hook_pull` action。牵引层为0.52秒有淡变的可取消片段，不强行循环；离开pull、死亡、返段时取消。原版没有持续牵引声。
- 暂停拒绝新世界声，世界播放器仍pausable，UI可继续；停止地区同时停止候选，App unload沿原 `shutdown()` 观察真实backend弱引用释放。五首音乐继续由GameMusic单独drain。
- actor/weapon epoch仍由现有实际表现消费者过滤；本轮未在音效层另造会决定伤害的新epoch规则。

## 验证与边界

```sh
python3 tools/run_audio_director_tests.py --output build/audio_director/runtime-FRESH
python3 tools/run_audio_lifecycle_tests.py --script res://tests/audio_lifecycle_runner.gd --marker '^AUDIO LIFECYCLE: [1-9][0-9]* assertions, 0 failures$' --timeout 90 --output build/audio_director/original-lifecycle-FRESH
```

实际 `runtime-first` 40断言/0失败，补充null legacy反例的 `runtime-final` 41断言/0失败，独审后追加原关键cue满池反例的 `runtime-critical-review` 60断言/0失败；原 `original-lifecycle-first` 37断言/0失败，均由既有严格runner核退出码、完成标志及资源/解析/泄漏日志。第一次Lab消费者虽19断言/0失败，缺元数据读取产生ERROR，被严格runner真实拒绝；修复后 `lab-smoke-third` 25断言/0失败，另存新证据，不改写旧失败。实际Home/Router动作由独立Lab测试验证，当前完整自然战斗、森林完整路线、连续音画听感、用户选择及实体设备仍未验。最终准确源码、复验和公开Web身份以本轮交付收据为准。
