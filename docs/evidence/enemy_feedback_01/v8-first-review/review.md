# v8 独立审查：REJECT

**整体 REJECT。** 正式保存/重载后的两具尸体不可见；实际受伤帧与原活体的回接仍有材质、比例跳变。局部真实画帧与当前房间保留尸体已经可评审，不等于完整艺术、用户或设备通过。依据 gameplay-reviewer/review_method、animation-vfx、game-quality-gate；未修改生产或 tracked tests。

## 冻结源与实际执行

独立树 `/workspace/enemy-feedback-01-v4-after` 安全 detach 到 `5ffd6e97a439d6397e4751b39206eebb622465dd`。`build/enemy_feedback_01/v8-independent/source-before.json` / `source-after.json` 的1905个 tracked scripts/tests/tools/任务资产 SHA 全等，结束 git status 为空；不是对根树文档冻结的宣称。独立原始日志、退出收据、runtime JSON 和观察图均在该 `v8-independent/`。

| 独立检查 | 终态 | exit |
|---|---:|---:|
| import | 完成 | 0 |
| native 实弹专项 | 458/0 | 0 |
| formal/default DemoApp | **66/2** | **1** |
| support/void/恢复顺序 | 199/0 | 0 |
| 原死亡音频，正常时钟 max-fps60 | 278/0 | 0 |
| GPU pixels | 258/0 | 0 |

完整日志除 formal 两条 FAIL 外，无专项 SCRIPT ERROR、运行错误或退出泄漏；GPU 有既有 VSync 警告。formal 两条均为 `official restored corpse stays visible despite hidden saved EnemyMotor`。当前房间实弹杀死、单次死亡、coin/none 掉落与重结算防重通过；重建后恢复末帧状态及零重播通过，**可见尸体保留失败**。Motor 存档未包含真实尸体落点或 support-local pose；严格 contact-band 不把远处地面猜作保存落点。该问题现也影响地面对象，不再只称旧渡船一个失败。需要总控分配保存/恢复接口；不能恢复 v5 消失合同的62/0冒充此需求通过。

环境重启中断第一次 Harness，日志仅到首项启动，无终态；原件保留 `interrupted-harness/`，不计通过。仅重跑四项后全 fresh/reused=false、exit0：actor-actions2872/0，underworld-damage-feedback317/0，underworld-formal96/0（2 maps），forest-bible integration54/0。正式报告 `build/verification/harness/20261023T012016.428056Z/report.json`。内层森林13条 ERROR 对应明确 EXPECTED REFUSAL 畸形存档负例，保留日志，不隐去。

## 两链与真实媒体观察

源码确认：两 host 分别接 `EnemyFeedback01Frames`；非致死 hurt 消费既有 APPLIED 样本，致死事件匹配 epoch/event_id/serial 后只启动一次 Remains。stage sibling 不写 Actor/Motor/AI/碰撞/奖励，不依赖父类死亡后可见性；父类计时/可见性保持只读。死档直接 D4、首 physics 静态校准，无新动作/闪光/粒子；支持丢失只继续有界视觉跌落，卸载释放 owned sibling/listener。两 host 已移除 v7 音色 helper，实际声池验证恢复原默认 enemy_defeat；既有唯一死亡 cue 没有被全局静音或另播一声。

已实际看四张源 PNG：头、足、翅、腹部具有相对姿态变化，D1–D4 有收拢/倒下/低姿尸体，**不是把一张原图整体翻转**。manifest 统一物种尺度与逐帧 anchor，GPU 实测覆盖两链新帧。单中心支撑 ray 与 alpha 最低 foot 只支持本次已测几何；斜坡/旋转支撑、非单位世界缩放仍未验（死亡 leaf 将 global scale 设为ONE），不能签通用地形/变换等价。

对 root 最终 `build/enemy_feedback_01/v8/{movie,movie-legacy}/after.mp4`，实际查看**每链240个解码帧**：MP4零基54–114、178–229、834–894、962–1025逐个连续邻帧，另看775/1555完整1280×720尾帧；八张邻帧图、四张全图与 movie SHA 在 `media/inspection-manifest.json`。两片报告均5ffd、source_stable=true；Underworld1560 gameplay/input/event 投影与前版相等，trace每物种各210尾帧可见/settled/静止。尾段稳定性据trace，未假称完整观看尾段或全片正常播放/听音。

本样本确认 D1–D4、空中落地、末帧长期可见；尾帧接地未见旧版明显浮尸。**局部连续性 REWORK：** Underworld charger93→94由较暗金色厚甲突回亮绿原皮，diver876→877由暗铜新翼突回亮青旧翼；legacy 相同回接点亦可见身体比例变化，飞行体从较圆宽姿突回瘦长原体。白闪遮住部分首帧，后续真实姿态可见，但不能由“8张不同图”推定丝滑。完整新运动图帧、艺术一致性和用户认可均未完成。

## 溯源与保留项

独立逐 PNG chunk 核实四图都有 caBX（21881/23654字节）；此前 PIL.info为空不能推出无metadata，已纠正。`png-chunks-independent.json` 保留实测；未验 C2PA签名，不推断模型许可或恢复缺失的 Underworld verbatim prompt，溯源缺口仍在。早期测试/媒体失败继续保留；独立解码首命令有一次 filter 逗号转义错误，观察命令修正并保留记录，不涉及生产变更。

完整146项 Integration、自然路线、正常速度完整体验、声音听感与真机仍 UNVERIFIED。引擎租约已归还；本报告完成后停止写入。
