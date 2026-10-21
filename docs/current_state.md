# 当前状态

2026-10-21。分支 `feature/region-bible-v2-forest`；HEAD基线 `7be8c340372d1e20db6685cbd6a559191821eb0e`，本轮区域实现正建立本地WIP检查点，仍非最终准入。目标：先完整荆棘森林（含美术），再优化风铃平原；SFX/背景动画可做，BGM由用户后续引入。当前仍开发中，旧main通过不代签新区域。

## 当前权威

[用户原话及附件](creative_direction/bibles/user-request.json)、[注册表](creative_direction/bibles/registry.json)、[森林Bible](creative_direction/bibles/2-thorn_forest_region_bible_v2.md)、[平原Bible](creative_direction/bibles/1-windchime_plains_region_bible_v2.md)原文完整保留。最新两条用户纠正和[16个实际共享参考](creative_direction/bibles/style-continuity-20261021-v2.json)约束所有后续区域：继承正式平原Underworld像素家族，再发展地区材料、结构、生态和色域。不能把旧提案不再绑定误解为丢弃正式共享风格；用户选方向不代签实际像素、手感或设备。

原动作、PlayerMotor唯一移动、合法能力、资源、伤害、RNG和保存合同保留。森林当前显式新版 `forest-bible-world-v15`，普通默认仍v14。旧v13/v14算法与保存重建保留。任务见[任务表](tasks.md)及[质量记录](quality/records)；被压缩前状态原文见[历史档案](archive/status_history/region_bible_v2_start/README.md)。

## 本轮进度与证据范围

`REGION-BIBLE-WORKFLOW-01`：Bible-first、creative-v6、16区注册、完整输入与恢复/缓存防漂移、6个Skill入口已实现；缺Bible只做文档提案。补充v2绑定实际玩家animation metadata与两个sprite PNG，原遗漏反例保留。独审77窄测试/31依赖反例/68风格反例/14旧绕过/36缓存案例通过，48源稳定。随后原harness全fresh112/112与31/31通过74.217秒（报告 `build/verification/harness/20261021T013022.684703Z/report.json`；原180/60预算、targeted/release=false）。此后profiles仅追加检查，不重签最终完整发布。

`FOREST-BIBLE-V2-01`：新连接、F05背枝、F06交替网、六发现物/真实奖励、领奖捷径、练习动铃、风叶与3个SFX已接；未加入BGM。已恢复同平原16px/32wu、47核心/精确边界adapter及UnderworldPlayer；原独立高res方向退出运行范围，原图和失败保留。两Boss和全部生态主体已有同族native候选，charger复用完整正式UnderworldEnemy。

以下均为各自冻结来源的限定事实，不能自动覆盖后续源码：

- F06局部126/0、发现物101/0、App恢复54/0、实际App双按钮/两领奖顺序/同帧致命伤害90/0、练习铃持久化69/0、环境73/0已实际通过。fixture/UI staging不代表正式探索、H实练或设备。
- G原正式出生inner35/35、F05背枝43/43、outer30/30，逐帧HP5、无player committed_damage、Motor一次，三次3414源完全一致并获限定独审。此前掉血/顶头/重复射击失败全部保留。后来F08已LOCAL14/14及正式31/31（3551帧、74.105秒）无伤通过，真实Reader木芯0→1、弹伤1→2.5并返营；不证明H-only排他性。
- CI适配实际修复中心瞄准与真实枪口差异、重复交互合法打开Reader导致旧driver挂起。显式原16代表已16/16通过221.430秒、源稳定；其中7条旧auto路线受伤，不能称全无伤。原80/600、90import/240native、双worker与原断言保留。完整80尚未通过，最终留冻结后正式入口。两轮80失败/超时和未执行清单均保留。
- 独立56版本补充已原生通过24.008秒，含2个真实无pin App与4个旧v13/v14重建及10个合成reader拒绝；原327/schema6/24未改。薄测试selector向App保留真实空pin。当前483/0布局回放合同也已执行；后继源码需按适用范围重验。
- 最新生态18张实际合屏22.908秒、3511源前后稳定，8种实际宿主可见；独审限定接受静态主体、甲虫左朝视觉足台、共享charger。`EnemyMotor.is_on_floor`不作为敌人落地证明。花荚上根15–17px缝隙已做真实host枝梗补丁，等待实际复验；正常AV/主动预告/来回镜像仍未验。

F05接地v2新增100wu实柱已被真实LOCAL反例否决：3/30段、2077帧后卡在x1777.9908，未到奖励；无伤不等于可达。现明确v3撤回该柱，碰撞与v1相同；原v1/v2源、原轨迹与独审REJECT保留。未完成返回，不能用raw 0耗时比较长短。两轮新C/Y背景树母块均REWORK停止；当前正式共享完整alpha树固定构图复用与花荚补缝已实际18张复拍（22.834秒、源稳定），等待独审；不能以调低透明度追认失败。森林有机材料/大形与连续表现仍未完成，不签整区艺术通过。

新代码/断言独审20reader+11原scheduler、41谓词、71源稳定，限定接受流程完整性；不签新F05路线、完整80或艺术。旧高res失败画面/原料可追溯，但最初两presentation helper逐字备份未找到，不能宣称完整可重放。普通Git精选见[共享风格阶段证据](evidence/region_bible_v2/style_continuity_20261021/README.md)。

`PLAINS-BIBLE-V2-01`：只读差距盘点完成，尚未启动新实现。正式App现用v12 root-bell/Underworld，已有真实两图、两Boss、回环和机关。森林完成后优先断桥下层发现→奖励→异路返回、晨光与风，再四生态；不重写已成立Boss，不引入跨循环世界例外。

## 已完成main基线与存储

PR96、99、100已普通合main。运行P `66e8b912854d6d4cccadb45b9c348a618689f5a1`正式CI核心/艺术120、Web41、Docs26、旧森林80、GPU/audio/Windows、实际CI ZIP原三浏览器和公网同源证据已完成；档案R已推main且R freshDocs26通过。main已修短跳镜头突变、接有根果实、移除旧八房间专属30文件。106远端head当时88包含、18旧art/UI/部署未盲合。公开仍P，不能当本轮新Bible预览；[完整旧main证据与限制](evidence/main_pr96_repair01/main-P66e8/README.md)。

存储已精确重复去重，另142份旧终态capture无损ZIP+逐项SHA/实际恢复反例后压缩留存，外receipt/日志原位不改，净回收1,382,440,960B，约2.3GiB可用。旧capture需各旧根restore脚本按需还原，执行索引 `build/region_bible_v2/storage-archive-review/completed.json`。不删唯一AVI/实际CI ZIP或另一个ci-H工作树的用户改动。下一执行及未验见[交接](handoff.md)。

## 2026-10-21 03:11 检查点增量

F05 v3四例已完成且G明确释放引擎租约：正式图1连接24/24、背枝32/32，LOCAL图2长返30/30、短返22/22，四次3513源相同，全部HP5/Motor1/无player damage。长返1374vs短返1155物理帧；短返另5个modal process帧，receiver有1tick/1.5focus差，不签严格因果或FUN。精选原件已入普通Git。最新18图独审限定接受实际枝梗闭缝与一处固定共享TREE背景用途，整区艺术仍待验。

用户新要求[自然缠绕的带荆棘平台](creative_direction/bibles/thorn-covered-platforms-20261021.json)及原图已绑定creative-v7（仅森林，原Bible/共享风格不改）。发现唯一790×18旧prototype刺带与宿主相隔210wu，将在v15显式淘汰，旧v13/v14保留；其余上/下/侧危险表面改为依真实宿主覆生藤刺，禁止跨空假根。尚未修改该物理delta或采新图。木皮13母材v3已接入候选，源级独审允许一次实际样本；新两个PNG与shader/47原接口完整来源已登记，实际GPU尚未采。下一步完成荆棘语义与像素覆生renderer、一次材质+危险面合屏、原路线/断言窄适配和连续AV。
