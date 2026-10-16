# Experimental kill_from_bank_v2：局部静岸搜索的真实改善与开放失败

这是父V3直接工程包，不是额外原Harness宿主调用。旧v1和原80例71/9结论保持原件，不升级。新策略必须显式选择 `--encounter-policy kill_from_bank_v2`；默认仍 blind_legacy，原v1候选顺序与行为保持。唯一算法变化是在原有限 ±16/32/48/64 候选全部之后追加 ±80/96，并仅对v2记录实际候选检查；全部全身/路径/动态危险/敌人体积净空、原40步移动、900tick/6shot/资源/真实InputRouter约束保留。没有修改任何游戏运行规则、物理、敌人、地图或资源。

## 四次正式原生事实

| Case | 实际ticks/终态 | HP |
| --- | --- | --- |
| 旧源码 v1，seed03 map2 deep | 931，unsafe recoil bank | 5 |
| 旧源码 v1，baseline map2 fast | 3063，测试目标到达 | 5 |
| 新源码 v2，seed03 map2 deep | 6544，测试目标到达 | 最低1，后由合法奖励恢复5 |
| 新源码 v1，baseline map2 fast | 3063，测试目标到达 | 5 |

四次实际producer收据accepted、退出0且各自source_before/after完全一致，完整command/source fingerprint/日志/Manifest/连续帧/事件/资源原件都在ZIP与索引中。测试目标到达不等于Boss/整图无损/玩家公平性通过。

## 改善与停止边界

v1 在 x=-130 的 deep_high 静岸因真实Pulse反冲支持不足停止。v2 的第一个新 +80 候选通过原支持/净空检查，以真实输入走到 x≈-50；931–1026 整段HP恒5，三次射击实际击杀 ferry_air_intercept。没有刷新输入timestamp、注资源、传送、禁敌或增加重试预算。

随后原连续路线在1180/1284/1391/1489真实受到 ferry_fan_crossfire 四次伤害，HP跌至1；对应damage_committed源与事件ID、之后原奖励的真实回血/选择全部保留在analysis.json。没有回退。该新暴露段落仍FAILED/REVIEW，不能把最终6544到目标写成无损或完整内容准入，也不能靠回血掩盖失败。父任务明确允许仅将局部bank改善保留为opt-in experimental；不设默认、不为了后续交叉火力改游戏规则、不继续调参数。

v1前后两个真实baseline fast的frames/events/edges/观察/资源/初末状态/Manifest及终态全部原始字段完全相同。与原80同case，仅172处真实进程player owner_id及其event_id/source别名不同；严格仅映射该唯一owner后所有上述字段相同。原始172条差异和有限映射规则均保留，不声称原raw相同或旧80覆盖v2。

## 未验证

v2只有phase0单seed/map2/deep，不是多相位/多地图/手机/正常影片或人类可读性验收。原19helper/运行核心未改；旧v1对照不是全部算法语义的普遍证明。父任务后续完整专项和不同作者只读审查另存结果。本目录不代签独审/用户/设备或商业品质。

最小实际CLI构造正例接受v2、未知v99拒绝（没有引擎）也有原脚本和日志。没有新增tracked测试或更改原断言。完整原始证据均未重写为新结果。

## Effective source：原Git base与真实dirty overlay

原四份capture/receipt的source_commit都是 `9eef7a88003deaf924f895d585cb7e5de0cb48b0`，这是启动时真实HEAD，但不能冒称clean Git构建。当时尚有真实未提交的Foundry replay/basis资料与失败资产family JSON；后两份另有本轮三脚本变化。原字段和原收据不改写。

每份原producer source_files清单有806项：前两份742项来自原Git blob、64项为dirty；后两份739项来自原Git blob、67项为dirty。原dirty实际包含56个Foundry项（54 replay JSON 与 batch/export_basis 两份 JSON）及8个 supported_overhang 失败资产JSON，不假设它们都已在base。所有67个唯一dirty源原字节共4,994,157B已经逐SHA保存在 `effective_sources/dirty_blobs/`，每份完整路径→SHA→Gitblob/dirtyblob绑定和投影SHA均在其manifest。

这份清单只对应原producer观察的source_files范围，不声称覆盖未纳入清单的所有PNG/GPU产物。`verify_effective_sources.py` 实际验证ZIP中34原文件、四份共3224条源绑定与原source_before/after全等，退出0；命令 `python3 docs/evidence/region_production_v3/kill_bank_v2/verify_effective_sources.py` 可复核，需要仓库保留原base Git对象。它是本地一致性证明，不是重跑native、远程认证或新clean commit声明。父任务如将同字节overlay提交，可另提供新commit逐blob证明，不改写这里的原native source_commit。
