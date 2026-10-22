# PLAINS-GOLDEN-01 · M0 / M1 切片合同

阶段：M0 实际审计完成，候选尚未制作；内容仍 in_progress。基线 main merge `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`，工作线起点 `0ee0e79197f40e898283440d4af2d956f91f1c64`。本文件不是整平原完成、美术认可或趣味通过。

## 正式消费者与能力

真实入口为 `DemoApp.start_plains`（scripts/demo/demo_app.gd:203）→ `start_demo`（239）→ `_load_stage`（331）→ `PlainsRegionGenerator.generate`（406）→ `PlainsRegionStage._ready`（scripts/demo/plains_region_stage.gd:15）→ `PlainsRegionAssembler.build`。普通正式版本实跑为 `plains-region-v12-root-bell-spaces`。

平原开局 campaign abilities=[]，只有实际 PlayerMotor 一跳、定向射击及既有两发未命中空中预算；`start_demo` 仅对森林授予 grapple（demo_app.gd:258、276），平原没有 H/W/D 授予。地图一 Boss 不授大能力（1968），最终奖励选择才调用 traversal.grant（2184–2190）。不把练习装备、Foundry 或规划 Envelope 当授予。使用原 `scenes/player/player.tscn`、`config/player_tuning.json`、`config/input_profile.json`、ActorResources / ShootAbility / FrameDamagePolicy，不复制参数或资源默认值。

地形真实链为 PlainsRegionStage → PlainsTerrainStudy → UnderworldTerrain，16 source px /32 wu，Blob47 core + exact boundary；角色是 UnderworldPlayer，怪物正式安装器是 UnderworldActors。远景 UnderworldParallax；场景根基和装饰 UnderworldScenery。所有共享源只读。完整来源 SHA 在 [source-ledger.json](../evidence/plains_golden_01/m0/source-ledger.json)。

## 原检查与真实像素

原 Harness `underworld-formal` 本线 fresh：96 checks /0 failures /2 maps /exit0 /3.394s，原报告和日志保存在 [m0](../evidence/plains_golden_01/m0/)。map1 Manifest `ac5a6654b8aab5ceb53451a767b9efaa665b3d0ec3a45e661ce976cbdb967d5f`，map2 `fe31fdf3a71087e20f689e389e7d5ae23b2fe0150e95d9d3e7f4aebadbfaa269`。该检查证明实际资源消费、暂停及卸载，不证明全路线 Motor 或商业品质。另一线已运行同检查的消息到达时本线已完成，不再重复。

M0 另用真实 Godot 4.7.2 / llvmpipe /1280×720 /fixed60 /Dummy audio 采三帧。root Seed `underworld-formal-integrated`；地图1；正式 zoom1.6；镜头使用原 StageCameraRig，单帧观察时显式 snap。输入无 Router 请求；定位为 staged fixture，有实际敌人/机关；不注入资源。位置、镜头和原生终态见 [receipt](../evidence/plains_golden_01/m0/pixels/receipt.json)。不宣称三点之间曾实际走通。第一次图形启动在引擎前因缺可选锁环境变量失败；原失败单列，随后使用现有共享锁 fallback 成功，未改引擎或预算。

## 三处可见缺口（作者观察，待独审）

| 原件 | 实际观察 | 对应 Bible / 下一步 |
| --- | --- | --- |
| [spawn](../evidence/plains_golden_01/m0/pixels/spawn.png) | 主角在 x≈540,y≈485；两个大直角草石断面占底部，断口至右岸约190屏幕像素。大面积深蓝天空与金色水平线形成强横带；可见悬铃架，但没有下层恢复路线的同屏线索。 | Bible3.1、3.3要求宽接收台与可恢复中层；先使断口、上层收益和低层退路在决策窗口共同可读。深蓝黄昏观感与Bible2.1清透晨光有冲突，M1不擅换共享背景，保留为美术未解项。 |
| [junction](../evidence/plains_golden_01/m0/pixels/junction.png) | 高路是数条薄草边，最近两层位于 y≈200与360；角色层为细水平桥。屏幕内有飞行敌人和右侧铃，但上层缺连续承载体量，空间身份主要依文字“OPTIONAL TRIAL”。 | Bible断桥/上下层应由岩体、残桥与负空间辨认。候选比较“横向断桥”与“岩体两侧折返”，避免只增加平台数。 |
| [bell approach](../evidence/plains_golden_01/m0/pixels/bell_approach.png) | 铃位于主角右上约175×100屏幕像素；大钟环摆件在更右侧，构图上比小功能铃更醒目。左上飞行敌人、功能铃、金色云带共享相近明度；静态帧无法确认预告/弹道在移动中是否被淹没。 | Bible4要求射击机关后立即移动与落点判断；两候选均把实用射击目标和其落点关系作为第一焦点。战斗动态读图是待验证假设，不从截图推导失败或通过。 |

环境动态的源事实：UnderworldScenery._process/_draw（185–200）只移动12个低亮尘点，明确不摇动根部。它不是Bible2.2中的成片草浪/风旗/风车系统；尚未听音或看连续录像，audio与环境生命力保持未验。当前正式库有远程铃、移动承载和双层恢复桥，缺口不等于“没有实现平原”。

## 两个同能力候选（proposed，不重新选择地区方向）

共用问题：跳起后，向落点相反方向射击会延伸位移；射击目标、反冲方向与安全接收面是否形成值得判断的同一瞬间。均使用原角色、真实 Router/Motor/弹体/资源和现有敌人；没有传送通过、静图动画、赠送第三发、H/W/D锁或BGM替换。

**A：断桥回针 / 横向开窗。** 一次可见宽沟连接主岸与高接收岸，中层实心救援台从断面内露出，低路沿岩体回接原岸；高奖在右上回望台。现有铜翼敌人占可预测空中窗口，目标铃安排在跨越方向的反侧，使一次有效射击同时影响敌/机关和自身落点。目的打法：观察→跳→反向瞄准射击→高岸稳定→可选高奖→低路回流。最便宜打法：先站安全岸清敌，再普通跨越或下低路；允许主路安全绕行，但高路须仍有明确收益/更短回流。若不射击即可同成本获得同奖励，或最佳策略是无脑同方向连点，两候选中的A淘汰/返工。

**B：钟桥折返 / 中央岩体两侧。** 相同总跨度与资源，中央连续石灰岩体围出一条可见下路；上路绕其肩部折返，远铃在岩体异侧，需改变射击角度后回接门/落点。目的打法：先读上下关系→从侧面跳出→瞄向异侧目标→接受反冲返回已知岸→走上层捷径/取奖。最便宜打法：在入口站桩射中所有目标，或完全下路绕过；主路可以保底，但若站在一处即可无观察解决全部关系，B淘汰/返工。若需要看不见的目标、无授予能力或原参数下无法回岸，立即拒绝，不以镜头或资源作弊补救。

**比较判据。** 三个观看窗都应能回答：哪一面可站、下一落点在哪、射击将把自己推向哪里、失误如何恢复；正常速度观察功能铃/预告/角色/弹道是否各自可辨。记录目的打法和最便宜打法实际输入、接受事件、资源和落点；比较去掉关键射击目标/只选低路时失去的真实决策。不用跳数、Hash或作者自评分判“好玩”。只读独审给继续、REWORK或DISCARD后才考虑第二空间；用户/真机保持未验。

## M1 冻结与可恢复入口

冻结 root Seed `plains-golden-01/review-01`，1280×720，fixed60采证，原 input_profile，基础未强化构筑，campaign abilities=[]，同一镜头策略 zoom1.6、正常跟随（仅初始一次定位），同一敌人定义/资源与恢复策略。A/B只改变任务局部几何、视线、目标与回流组织，不改变共享核心。两候选从同源首次创建各自的新世界，输入按实际目标语义记录，明确差异，不把不同路线冒充逐tick严格纯美术对照。

下一实现只写 `scenes/dev/plains_golden_01.tscn`、`scripts/dev/plains_golden_01.gd`及自身UID、专属driver/tests与本任务文档记录。候选A/B在同一可玩场景中明确选择/重开；现有 generic-scene Preview 命令为：

```sh
source /workspace/worklines/plains-golden-01-env.sh
bash tools/godot.sh --path . res://scenes/dev/plains_golden_01.tscn
# M1完成并实际导出后，由总控安排：
python3 tools/cloud_delivery.py stage-preview --bundle build/web --host-root <总控批准的独立托管目录> --task PLAINS-GOLDEN-01 --seed plains-golden-01/review-01 --entry scene --scene res://scenes/dev/plains_golden_01.tscn
```

当前dev场景尚不存在，命令是明确的M1 nextcmd，不是已发布URL；M0没有可操作新玩法交付。总控负责独审/昂贵验证/托管，不修改 DemoApp 菜单、正式生成器/模块池/共享资产、Harness/config、中央 tasks/current_state/handoff。M0 checkpoint 先 commit+push；之后实现两候选与正常速度短片，按实际输入/源码变更只做必要检查。
