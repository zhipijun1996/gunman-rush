# ENEMY-FEEDBACK-01：可审查样板与音效试听

运行源 `82940b7f057d74bfadf5855b1d489c38619c4a00`，基线main `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`；草稿[PR104](https://github.com/zhipijun1996/gunman-rush/pull/104)。两个已有对象：plains_charger / plains_diver。未合main，未部署试玩站；本轮只改可观察反馈，没有新增操作机制。

## 实际媒体

- [候选短片 after.mp4](after.mp4)：20.233秒，四连续案例分别为旧链冲锋/俯冲、正式安装器冲锋/俯冲；真实Router→射击→弹体→批处理HP，12次提交、4次死亡。带真实音轨，正式音效未替换。
- [基线短片 before.mp4](before.mp4)与[前后完整对照 comparison.mp4](comparison.mp4)：同Seed标签、驱动、初始摆位、AI、输入、镜头、1280×720/60fps，1200个gameplay轨迹帧严格一致。不是自然通关路线；初始定位是显式fixture，之后不改AI/HP/碰撞/伤害/资源。
- 基线工程只增加相同三个采集驱动文件（untracked，hash记录），原玩法/表现字节为main；候选使用clean提交。before/after原回执分别保存，不能把基线说成无附加驱动的原包。驱动SHA相同 `d85bda44348a4efebe1fe596ea299147978b1edbd7f37db912536f697a0a2629`。
- 视频实际帧含场景切换开销，与driver frame有偏移；独审报告使用解码video n，未伪造tick↔媒体对齐。离线软件GPU/MovieMaker不是实体设备性能证明。没有完整播放/听音验收，独审实际看过范围见[review-v2](review-v2.md)。

## 声音返工试听（离线候选，未接正式游戏）

[25秒声音A/B](audio-comparison-25s.wav)：0–5秒当前激光枪声；5–10秒[A紧凑机械](shot-a-compact-mechanical.wav)；10–15秒[B厚实机械](shot-b-weighted-mechanical.wav)；15–20秒当前命中三声组合；20–25秒精简实体命中假设。每段重复三次。首120ms RMS统一−26dBFS，不等于感知响度相同；没有简单加大音量签力度。

来源为已有Kenney CC0实体冲击样本，原激光只作基准，机械候选不把激光降调冒充实体枪。保留两份许可、[完整配方/源SHA](audio-candidates-manifest.json)，生成器为tools/enemy_feedback_01_audio_candidates.py。最终公开样本为audition-v3；v1/v2的测量问题和原件保留在build，未选作公平对比。以上是离线音频编辑，不是正式输入驱动的修复音轨，不冒充游戏内替换。

真实正式App音频probe为43断言0失败：非致死命中tick13/63同时启动impact/hurt/confirm，三者voice增益均−10.098dB，shot−13.098dB；素材本身能量不同，不能直接推出感知响度。fixed-fps快于墙钟混音时曾满12voice，后续cue缺失不能外推真人性能。详见[audio-audit](audio-audit.md)及原始audio-probe-v1.json。用户明确嫌电子提示感，候选尚待用户试听；正式共享音频、PlayerFeedback和GameAudio均未改。

## 已执行与边界

| 检查 | 结果 | 可声明范围 |
| --- | --- | --- |
| 新反馈专项 | 154/0，独立重跑同结果 | 两对象×两继承链，真实弹体、拒绝/重播/旧epoch、暂停/慢时、恢复死体、安装器与信号释放 |
| 默认DemoApp | 44/0，独立重跑同结果 | 实际生成对象各3发、2hurt/1death；charger coin1pickup、diver合法none0pickup；真实同图重载保账本、死体静默 |
| 原Harness专项 | actor-actions2872/0、Underworld两图96/0、森林Bible集成54/0、underworld-damage-feedback通过 | 原消费者回归，source stable；不是146项完整Integration |
| 独审 | 技术样板有限ACCEPT | review-v1原发现保留；v2独立执行及抽邻帧；不签完整播放/听音、玩家或真机 |
| 原docs | 首轮在structure失败、第二轮源冻结失败；最终冻结后前7项通过，在quality因中央task索引/卡状态不一致拒绝 | 原失败未改签；既有.gdignore原字节已恢复。其余docs项因fail-fast未执行，不签完整docs通过 |

`runtime-v1.log`为测试WeakRef类型解析失败；`runtime-v2.log`为旧巡逻/俯冲组合历史定位，154/0不移签；最终组合结果在runtime-v3-charger.log与runtime.json。原生成功同时核对退出与ERROR/泄漏终态，没有忽略内部错误。

## 总控接续与剩余门槛

1. 原远端同ID分支ce84d01是另一代表选择；本线已更名，未覆盖。两个实现须先择一/收敛，禁止双系统并入main。
2. docs/tasks仍planned、本卡review，总控持有中央索引；check_quality.py因此拒绝。不得假填planned或修改校验器绕过。
3. 原planner对新组件/测试/驱动保守full（146项）。完整受影响Integration、森林所选charger的实际反馈、其他正式消费者与发布守门仍需总控执行。专项绿不取消该要求。
4. 用户声音返工已记录，A/B未获认可；请求总控分配最小音频写集后做实际场景听音比较。用户视觉/手感、完整听音、真实设备均未验，内容不标done。

复现：`bash tools/godot.sh --headless --path . --fixed-fps 60 --script res://tests/enemy_feedback_01_tests.gd`；正式消费者将脚本换为enemy_feedback_01_formal.gd。每轮保新目录/日志，不覆盖失败。源与授权输入完整SHA见authority-inputs.json；质量卡、范围及恢复点见docs/enemy_feedback_01.md。
