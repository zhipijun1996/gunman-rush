# v7 独立技术审查

结论：**本轮两个样板、两条表现链的死亡音色接口技术有限 ACCEPT；真人听感、设备和整体体验 UNVERIFIED。** 不签完整 Integration 或可合 main。审查遵循 gameplay-reviewer/review_method、animation-vfx 与 game-quality-gate；未改生产或 tracked tests。

## 源与边界

独立 worktree `/workspace/enemy-feedback-01-v4-after` 位于 `0e37e04528b4f71af75e74c5370d656e1e122588`。导入退出0；执行前后1890个 tracked scripts/tests/tools/任务音频文件 SHA 相同，结束 git status 为空。审计及完整独立输出在该树 `build/enemy-feedback-01/v7-review/`，不是对根工作区文档冻结的宣称。

静态核对确认：唯一发声入口仍是原 `EnemyActor._on_death → GameAudio.cue(enemy_defeat)`；任务 helper 只配置流、不调用 play、不新增死亡信号。两 host 分别安装 helper，选中范围仍只有 charger/diver。共享接口只让该 cue 读取合法 AudioStream 覆盖；默认素材、55ms节流、12声池、音量、暂停、弱引用释放保持原逻辑。Actor/Definition/父类计时与可见性/伤害/奖励/碰撞及 v6 VFX 未改。

弱 owner token 与 external fallback 已检查两 helper 的两种清理顺序；测试证明旧 owner 不清除新配置，最终恢复外部原值、保留其他 metadata，卸载不保留 Actor。此结论限实际安装器与被测两 owner 顺序，不宣称任意深度配置栈。

## 独立新运行

| 检查 | 结果 |
|---|---:|
| 原 native 实弹专项 | 370/0 |
| 新死亡音频，正常时钟 `--max-fps 60`、无 fixed-fps | 247/0 |
| 实际 DemoApp/formal | 62/0 |
| 原 audio_lifecycle，实际混音器释放 | 37/0 |
| GPU pixels | 162/0 |
| 独立接口 UNIT | 31/0 |

以上均完整退出0，专项无 SCRIPT ERROR、运行错误或 ObjectDB leak；GPU 仅既有 VSync 不支持警告。`execution.json`、`extra-execution.json`、`source-audit.json` 绑定命令、退出状态、耗时与源；`death_audio_runtime.json` 保留四个真实场景的收据。UNIT driver SHA256 `7527e17af290b8f0f04cef3d01b5ebf2a3a93b771f3e49091d64e1a6c0c5e053`；它直接测试接口，不冒充正式命中。

四个真实场景为两物种×原 Atlas/Underworld 两链，各三发 Router 弹体、三次 HP 提交、一次既有 enemy_defeat，实际 pooled voice 的 stream 均为任务 WAV。普通命中、拒绝、重复/旧 epoch、恢复死档及安装替换不补播；暂停时实际 voice 为 pausable、stream_paused=true。卸载后 Actor weakref 释放。接口 UNIT 另验证缺失/null/非字典/非法流默认回退、树外/null origin、非死亡 cue 不接受 metadata 覆盖、未知 id、静音、原冷却与声池满拒绝。

原四项 Harness 全 fresh/reused=false、退出0：actor-actions 2872/0，underworld-damage-feedback 317/0，underworld-formal 96/0（2 maps），forest-bible integration 54/0。报告：`build/verification/harness/20261023T002601.233775Z/report.json`。完整内层日志中的13条森林 ERROR 与测试显式 EXPECTED REFUSAL 的畸形存档负例对应，保留原件；没有把它们隐去宣称所有日志零 ERROR。

## 历史失败、媒体与未验

保留作者首轮126/41及依赖编译/退出泄漏失败；第二轮 fixed-fps 239/16 也保持失败。后者离线模拟快于独立音频混音墙钟，原12声池未释放导致死亡 cue 拒绝。独立最终247/0使用正常时钟，不修改生产声池、节流或断言；不追认固定帧率测试通过。同帧多死仍可能受原共享节流/声池拒绝，不能承诺每个死亡都独立起声。

已读真实新片报告：源0e37、source_stable=true，1560 gameplay 帧与 v6 的实际 inputs/events 投影一致；原片 SHA256 `229c5b53231b4c85702f4c2d08758538740d7d365eaa33ddd32126546aefa28a`，含48kHz双声道 AAC。独立读取任务 WAV 为48kHz/mono/PCM16/0.36秒，SHA与 provenance一致，import 不循环。作者对完整实际混音的解码测量为峰值−5.225dBFS、满幅样本0；此为客观音轨收据，不是独立试听结论。

本轮未完整正常速度观看/听取原片，未做声纹相关性证明，不签音色是否自然、与枪声混音的主观平衡、延迟、Hollow Knight 手感或真机。v6视觉几何未变，未重复视觉度量。此前 v3 移动平台持久尸体存档失败由 v5 用户改为爆裂消失而 superseded，未修复其存档接口；旧视觉 REJECT 继续保留。完整146项 Integration、完整新运动图帧及用户听感仍未验。

本报告完成后停止写入；引擎/CPU/render 租约已归还总控。
