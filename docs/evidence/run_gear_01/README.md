# RUN-GEAR-01：本局背包、齿轮与装备

已实现当前正式道具的领取入包、暂停装备／卸下／原子替换、实际效果重算和局内扩容。运行源 [`91ea885`](https://github.com/zhipijun1996/gunman-rush/tree/91ea8850f308cc3c955bcece2c35cd66f75e7bda)，基线最新main `26e7f2a`；分支`feature/run-gear-inventory`，不自动合并。之后的提交仅收录证据、文档和质量状态。

[完整操作录屏 · MP4下载](gear-flow.mp4) · [媒体SHA／格式](media.json) · [独立审查](independent-review.md) · [机器审查](review.json) · [权威规则](../../rewards_and_builds.md)

录屏20.47秒、1280×720／60fps，H264与原Godot音轨48k双声道。真实脚本键鼠输入完成：3发物理弹体击杀取得10金币→自然越过缺口→奖励入包0/8→装备跳跃1→2→卸下恢复1→花10金币扩容8→10。20断言/0失败，engine退出0，源前后一致；无传送、注资、改血或直接结算。画面明确标注固定开发三房间，不能称为正式区域自然全路线；正式平原／森林另由下列实际App专项验证。没有before对照片，也不以软件GPU／离线录制签实体设备性能或听感。

## 实际测试

同一运行源的独立原Harness使用`--release --jobs 1`，15项fresh全部通过，445.748秒：[完整报告](reviewer/harness/report.json)、[命令](reviewer/harness/command.json)、[收据](reviewer/harness/receipt.json)。这是选定scope，未宣称full profile／PR CI通过。

| 验证 | 实际结果 |
| --- | --- |
| 原核心套件 | 5685断言／0失败 |
| 新装备与交易专项 | 107断言／0失败 |
| 正式构筑UI headless／实际软件GL | 64／67检查，均0失败 |
| 原Underworld UI／原菜单触控回归 | 268／44检查，均0失败 |
| 正式平原→森林及最终结束 | 67断言／0失败；含实例、装备、10容量、金币与交易收据 |
| 森林发现模型／真实App领取按钮 | 103／92断言，均0失败；保死亡优先及first-W |
| 当前平原地区／Root Bell当前回放 | 15 suites／40图通过；27条旧独立路线明确未跑 |
| 当前时间能量／Planner | 140检查／21个Python测试通过 |
| 最终连续录屏 | 20断言／0失败，源码稳定、严格退出clean |

用户10项验收分别由gear107的8/9边界、蓝5/金1、满负荷领取购买、可撤销／重复／互斥／前置、HP钳制与无免费回血、无免费空中次数／弹药／移动改动、交易扩容与回滚，以及core／formal UI／campaign的环境回退／跨图／跨区／死亡与多端输入覆盖。[实际消费者清单](consumer-inventory.json)说明各fixture边界。所有通过均保留原ERROR、泄漏、非零退出、超时和断言守门。

实际正式图：[背包](reviewer/gui/desktop-backpack.png)、[装备后生命5.0/6.5](reviewer/gui/desktop-equipped.png)、[960×540触屏布局](reviewer/gui/touch-equipped.png)。

## 架构及剩余边界

`RunInventory`持有稳定实例；`EquipmentService`拥有负荷、装备ID和会话；`BuildState`仅计算已装备来源。背包不耗槽，8→10→12→14及10／18／28金币来自唯一[配置](../../../config/gear_capacity.json)。同局跨地图／地区保留，环境伤害回退不清构筑，真正结束清理。武器／核心能力／永久音符独立。

本轮只实现现有属性Modifier，主动／武器行为／钩索复杂效果仅预留来源接口；未做跨进程局内存档恢复。扩容价格为试验值。实体安卓／实体手柄、低端设备及数百卡片性能、玩家手感／趣味／听感未验证。触屏底部提示可能仍显示键鼠文案，实际触控操作已过；开发ModuleLab提供只读构筑预览。PR完整CI与技术G5验收单列，不把本地选定通过称为已合main。

## 真实失败保留

[独审F1–F14链](independent-review.md)和[历史原报告／日志](reviewer/README.md)保留原core override失败、root-bell动态测试类型错误／超时、森林按钮等待fixture失败、菜单重复信号与脚本类型引用清理失败。首次录片虽功能20/0，仍因Godot ERROR及采录中源码漂移被拒绝，保留失败身份；不追签为最终通过。最终片及当前GUI另以精确源重采。
