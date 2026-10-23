# 枪声／命中声：只读诊断与总控接口请求

用户反馈原话：“现在射枪的音效，击中怪物的音效都有点奇怪”；后续明确选择“太电子／像提示音，缺少实体感”。该反馈是现有音频未获认可的明确证据，不能用既有音轨或技术断言追签音色通过。

当前生产音频由总控持有。本报告不修改 GameAudio、PlayerFeedback、EnemyActor、音频文件或来源账本；只提供可运行的真实消费者观测工具与候选方向。

## 目前可以确认的事实

| 层 | 当前事实 | 证据与边界 |
| --- | --- | --- |
| 枪声素材 | `shot.ogg` 来源名为 Kenney Digital Audio 的 `laser2.ogg`，CC0 | `assets/audio/kenney/sources.json`。来源命名说明选材类别，不能替代实际试听；未宣称听到了某种具体频率或失真。 |
| 接触素材 | `impact.ogg` 来源为 `impactWood_light_000.ogg` | 同一来源账本。PlayerFeedback._impact 在 projectile_impacted 接触事件播放，包含碰墙以及非Boss一般接触；它不等价于已提交HP伤害。 |
| 受伤素材 | `hurt.ogg` 来源为 `impactPunch_medium_000.ogg` | EnemyActor._accepted_hit 在已接受非致死伤害时播放；非致死 HP 提交与接触可能带来不同cue的并行播放。 |
| 恢复提示 | 正式 ShotEnergyPolicy.on_hit 会发 recovered；PlayerController 转为 energy_recovered；PlayerFeedback 同时播放 `confirm` | 正式 DemoApp 安装此policy；旧独立玩家arena没有这个配置，因此arena音轨不能代替正式App音色组合。 |
| 层级与调度 | GameAudio 对shot额外衰减10dB，对impact/hurt/confirm衰减7dB；使用12voice上限、每cue0.055s或特定cue0.16s去重 | 这是源码读出的增益/调度事实，不能直接推导感知响度：不同素材的真实能量及频谱不同，需测量并试听。不同cue不会互相去重。 |

推断：激光类起音、轻木接触、拳击受伤和资源确认提示属于不同语义。它们在一次动作附近叠加，是“音色不统一／像多种提示挤在一起”的可检验候选原因；目前不是已试听确认的根因。另有可能只是某一素材本身不合方向，不能仅凭叠层就删事件。

## 新增观测工具

`tools/enemy_feedback_01_audio_probe.gd` 继承已通过的真实App消费者测试，复用同一seed、实际生成对象、Router→真实弹体→HP／掉落／重建链。覆写run只为写独立输出，绝不调用会覆盖旧formal_runtime.json的父run；覆写ticks按一帧调用原实现再观察音频。

记录每帧 GameAudio.played 计数增量、实际活跃voice的cue、音量、playback position及stream路径，并与原shots、accepted_events使用同一个物理tick。不会替换服务、重放cue、改变stream、调音量或修改任何玩法结果。

```sh
bash tools/godot.sh --headless --path . --fixed-fps 60 \
  --script res://tools/enemy_feedback_01_audio_probe.gd -- \
  --output=res://build/enemy_feedback_01/audio-probe-FRESH.json
```

现有输出会拒绝覆盖。`played`计数证明服务接受播放请求；不证明感知音量、同步延迟或音色好坏。AudioServer以墙钟混音，fixed-FPS活跃voice同时数也不能直接替代设备并发／听感。

实际运行：`build/enemy_feedback_01/audio-probe-v1.log` / `audio-probe-v1.json`，Godot4.7.2 Standard、headless fixed60，exit0，43断言0失败；两个正式生成目标各3发、3次HP提交，原formal_runtime.json未覆盖。

实证：物理tick13及63各有一次非致死HP提交，同时 `new_played` 增加 impact、hurt、confirm 各1；三个voice的实际volume_db均约-10.098dB，枪声voice约-13.098dB。这证明正式消费者一次已接受命中确实可能叠加三种音效，而非仅仅猜测素材名。

重要限度：离线fixed-FPS比墙钟快，AudioServer真实播放未及时结束，voice池曾达12；后续cue未启动不能据此指认真人播放一定丢音。probe计数不是感知响度、延迟、削波或完整听音证据。当前未做主观音频认可。

## 已制作的可试听候选（build内，不接生产）

`tools/enemy_feedback_01_audio_candidates.py` 以来源账本SHA核验的现有Kenney CC0木、拳击、金属接触作层，使用ffmpeg裁短／滤波／包络／轻变速，生成两种机械发射候选。激光原声只用于对照，不以降调激光伪装实体枪声；没有添加合成提示音。A为紧凑机械瞬态，B为主体更重、尾声仍短的机械声。原始shot解码长约1.091s，两个候选长0.18/0.23s；长度是测量，不代表较短就更好。

```sh
python3 tools/enemy_feedback_01_audio_candidates.py \
  --output build/enemy_feedback_01_audio/audition-FRESH
```

输出两份shot WAV及一份25秒声音对比；所有样本、衍生配方、ffmpeg命令、SHA和时间表在manifest.json。对比按首120ms RMS统一至-26dBFS、峰值上限-2dBFS，避免候选仅靠变响讨好；这仍不等于主观等响或设备测量。

| 对比时间 | 内容 |
| --- | --- |
| 0–5s | 当前laser2枪声 |
| 5–10s | A紧凑机械枪声候选 |
| 10–15s | B较厚实机械枪声候选 |
| 15–20s | 当前impact＋hurt＋confirm同起音组合 |
| 20–25s | 离线假设：短促受击主体＋较轻接触纹理，省去confirm |

每段在+0.5／2／3.5秒各重复一次。最后一段只是供用户听取方向的离线混音假设，未改变游戏资源恢复逻辑或正式播放事件，不能冒充实际游戏已修好。旧候选保留、实际推荐试听产物目录以root交付收据为准。

## 请求总控分配的最小改动

1. 素材与混音试听：为默认枪声准备“短促机械瞬态＋紧凑低频主体＋短尾声”的方向，与当前激光音作同响度A/B；命中分开比较当前混合与单一清晰主体。保留许可和真实来源，不以单纯升音量替代力度，也不预先承诺适合整个武器库。
2. 事件层：审计普通接触impact、已接受HP hurt、资源恢复confirm的真实同tick关系；考虑将资源恢复反馈缩为低优先级辅音或UI-only视觉，保证HP确认仍可辨。改变PlayerFeedback或GameAudio必须由总控分配，不能由本线私改。
3. 材质层：如果未来支持材质音色，复用正式accepted伤害和现有impact_style；先让两代表对象验证后再推广。当前共享普通cue没有足够材质语义，不能把一个硬编码金属声强加给全部怪物。

最小审查矩阵：空枪／打墙／非致死／致死各一次，连续开火／多敌人／暂停恢复／重载各一次；同源同输入录制当前与候选音轨。由实际试听确认“枪的起音是否明确、命中是否一声可辨、是否抢过敌人预警、连续发射是否疲劳”。主观听感保持未验，用户反馈不得由AI代签。
