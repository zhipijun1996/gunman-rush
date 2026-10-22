# ENEMY-FEEDBACK-01 · feedback-sample-v2

用户本轮要求：音效暂不处理；Underworld真实接受命中应有清晰身体变色，像素粒子更明显且保持画风；当前怪物美术颜色沉、特点弱，需要建议，并要求实际运动动画帧。原话见[user-feedback.json](user-feedback.json)。

本轮只修两代表普通怪物charger/diver的反馈，不改AI、伤害、碰撞、奖励、Boss、音频或共享父类/素材。生产源 `5de1eca1f3150289c2dc3bc72b206ac2efc326d9`；新源继承v1的全部受击/死亡/掉落与epoch合同。完整Integration和中央planned/review同步仍归总控；不合main。

## 修订与失败保留

- v1暗像素的乘法染色不够亮；Underworld缺少受击碎片消费。本轮新身体叶节点用私有shader在接受命中后短闪奶油色，保留alpha；血条/预告不染色。14/18片小块像素碎片共享同一组件、接真实context接触点。
- `cfce9b3`是第一次候选，`native-v1.log`240/0、`formal-v1.log`50/0、`pixels/`38/0都来自这个早期版本，不能移签最新源。
- `1c1238d`修正身体仍在原actor世界层，避免降低到地形层；`5de1eca`修正独审发现的暂停restore缓存风险，使用现有initialize信号立即清掉自有短时显示。最终专项和录制另存final目录，不覆盖首轮。
- 第一次docs检查在本README创建前发现悬空链接并退出1，创建入口后重新检查。此前v1原docs失败与质量卡保留，不把旧通过追签新源。

## 证据范围

最终执行和影片以本目录final报告/原件为准；早期v2原件保留用于返工轨迹。所有命中来自Router真实弹体→原伤害提交，无直接反馈方法调用。GPU专项读取真实viewport的身体像素，并在第二发真实命中后暂停、通过正式restore API恢复死体检查清屏。

影片使用显式战斗fixture、原Courier玩家和简化地面，保留真实AI/弹体与现有音轨，不是正式Underworld人物＋地形的美术黄金，也不签设备性能。主对照只剪取原始连续影片中Underworld的两个case；保留完整四case源片、未剪trace及转码配方。剪辑不添加/插值动画帧。

[独立审查](review.md)只签已见源码/像素/原生结果的有限修订，不代签整体美术、玩家手感或设备。

## 当前美术与动画仍返工

[完整建议与逐状态动作卡](../../../enemy_feedback_01_art_direction.md)：扩大苔草/旧铜/石灰腹甲的中亮材质面，暗色集中在轮廓/关节；地面保留低重心、前刺和支撑腿，空中突出双铜翼、悬铃腹和镜片；不全图提曝光换风格。每种实际关键运动需要独立身体帧和稳定锚点。当前每物种仅一张身体PNG，整图缩放/旋转/闪色不是新帧；新配色/轮廓/图集尚未生产。质量卡visual/animation保持failed，不能用本次VFX通过代签用户美术认可。

音频由用户明确暂缓，原有负评未被撤回；本轮不制作/替换正式声音，也不要求用户在旧离线音频候选中选型。

## 最终专项与真实短片

- [约20秒Underworld前后对照](final-movies/underworld-comparison.mp4)：前10.1秒旧版，后10.1秒新版，都是原影片的连续Underworld两case；转码命令/时间区间见[recipe](final-movies/comparison-recipe.json)。
- 完整四case：[before](final-movies/before.mp4) / [after](final-movies/after.mp4)，各20.233秒，真实既有音轨未改；[after报告](final-movies/after-report.json)记source_stable=true、same_gameplay_frames=true，1200个实际玩法帧严格相等，12次真实HP提交、4次死亡。
- 独立重跑：[native240/0](final-tests/native.log)、[正式App50/0](final-tests/formal.log)、[GPU50/0](final-tests/pixels.log)。[GPU实图与测量](final-tests/pixels/report.json)包含每种原色、受击、恢复、暂停恢复死体，受击奶油身体覆盖约97.6%/98.8%，暂停恢复后为0。
- 具体实际命令、环境、来源SHA与源文件hash见[独审](review.md)；正式App只有初始玩家安全位置是fixture，敌人/AI/伤害/掉落均原合同。不能把原生正式App测试当自然整局体验。

v1 PR自动检查实际失败原因为新增feedback.gd.uid未列入质量卡写集，原CI日志保存在ci-v1-failure.log；本轮质量卡完整列出任务生产文件及UID，不修改/绕过检查器。中央tasks索引仍planned、卡仍review的独立错误不能由本线越权同步；完整Integration未签通过。


原Harness本轮新鲜定向回归全部通过：[actor-actions / underworld-damage-feedback / underworld-formal / forest-bible-integration-tests](final-affected/report.json)。完整docs profile实际前7项通过，quality在[中央任务索引planned与卡review不一致](final-docs/quality.log)处失败，后继未执行；[原报告](final-docs/report.json)保留，不改为局部通过。单卡格式一致、[diff守门通过](quality-diff-final.log)，内容判定仍REJECT，因为整体美术和新帧未完成；不把格式检查代签作品完成。
