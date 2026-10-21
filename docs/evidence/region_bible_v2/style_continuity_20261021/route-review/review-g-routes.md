# G route/control 独立只读审查

结论：**路线事实 ACCEPT_SCOPED；安全返路 REWORK**。未修改生产、测试或工具，未运行引擎。审查者未实现 G 几何/驱动；本人 E 蛛、练习铃及整体 FUN、视觉、设备认可不在此签署。

两份原始正式 App debug-entry 记录为 map2 / forest-depth-hollow-00。inner 35/35、3349帧；backbranch 43/43、4050帧。两次完整3414源前后相等，每条记录 tick 连续、每帧 Motor 恰好1次、actor/stage epoch 均3，无死亡重生。实际出生[-2200,1882]至营地[200.015,449.925]，只具 H，未启用二段跳/蹬墙。源码链无搬位置、赋HP、赋精力/弹数或直接开门。这里的正式出生来自真实地图 debug entry，不能代替自然地图进程。

F05 真正走出边沿再下降，tick3018在[2079.994,1080.147]、向下速度693.333，随后0.91675秒真实瞄准hold，tick3050 contact命中 side_fruit；0.35154秒枪hold后实际右下开枪。东窗[1790,1000,80,80]重叠11帧，24×36身体顶部≥1000.07477、底部≤1050.54346；末3帧已经接触 crown，因此只签真实穿窗，不能称全程悬空至平台中心。奖台真实交互/Viewport选项经生产 accepted claim 开西门，原native日志明确 source=accepted_reward_claim，ledger和opened均置位；西门15帧身体完整清空。重复交互检查继续保留。原trace没导出pointer/modal逐帧及交易output，精确奖励金额、停帧时长不签。

**G-SAFETY-RETURN-01：原满血PASS不能签安全返路。** inner实际两次身体接触，HP5→4(tick2830)→3(2879)；backbranch三次，HP5→4(3471)→3(3531)→2(3580)。首个backbranch伤在outer_to_inner/hollow_lower_land，其余在inner_recovery/hollow_inner_walk，来源是旧seed sentry与inner spider活体，非F05。两次最终各被营地既有camp_heart加1，实际采集距离41.17<46；不是注入补血，但它发生于损伤之后，不能为低血量返程兜底。走相同输入时，inner以≤2HP、backbranch以≤3HP进入这些连续接触会死亡；这是条件反例，不是已执行低血量测试。地图并未证明强制不可避伤：敌人可杀，需合法清怪/等窗/避让后另留新证据。

定位到原pilot：精确旧body SHA `b6239735cf9e4ad76d0b7fc58a08bea7aa93a831965b3640cd2b5614806ace46` 已恢复到 ignored old-full01-grove-pilot.gd 并匹配两receipt；继承_ground白名单不认hollow_lower/recovery，旧hollow driver盲走穿活体。当前新pilot已有后续修正，不在两份旧PASS签署内。原伤害与旧失败不覆盖。

资源与输入仅限事实：精力80..100、弹数1..2；真实命中回能有owner/session/弹体记录，停地恢复和focus rest为实际系统运行。瞄准目标受自动辅助，鼠标/SPACE送实际adapter、轴走router，不能称玩家手动/设备实测。hook_cast的target沿用旧hook_target，F05 cast行误显示旧ring；以真实contact/tip确认目标。

旧Motor/tuning/traversal、旧trace/helpers、harness/quality/level contracts字节仍同HEAD；新run保90秒import/240秒native、18000总tick/1800边tick和400相位限额。旧403/0静态世界合同含20种生产与重算hash后的五类破坏拒绝；workflow差异原132 checks无删改。原局部fixture compile/runtime FAIL、局部PASS均保留，不转写为完整路线证明。未重跑旧引擎/全snapshot，也不扩大旧合同报告范围。

完整源SHA、原trace/receipt/outerlog SHA、逐帧汇总与限制见 `review-g-routes.json`。
