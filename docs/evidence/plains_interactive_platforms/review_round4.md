# D081 第四轮独立严格审查

审查者 `d081_strict_review4`。读取 AGENTS、D080 交接及前三轮报告；生产代码只读，独立探针保留在 `/tmp`，本报告为唯一主动仓库写入。官方 Godot `4.7.2.stable.official.ed1daf0bf`；命令前缀 `bash tools/godot.sh --headless --path . --fixed-fps 60 --script`。审查期间根代理继续修复，以下标明初始失败、修复后证据和范围。

**结论：当前复测范围技术 ACCEPT，没有留下已证实的 P0/P1。** 不是“14 个模块就有趣”：实际支持安全落脚范围、墙面起跳余量、机关启停、上下旁路的资源选择，以及 Boss 踩台/起跳/下射等不同操作。已读取根代理 `/tmp/d081-regions6.log` 的完整12套通过及 `/tmp/d081-core4.log` 的5942/0；其后仅端口动作说明/原生快照补断言等收尾变更仍由根代理完成最终针对性检查。公开部署验收由根代理最终记录，不替代真人趣味或设备验收。

## 独立执行证据

| 探针 / 日志 | 实际结果和边界 |
| --- | --- |
| `/tmp/d081_review4_corpus.gd`、`/tmp/d081_review4_corpus.log` | **568/0**。100 个原 `operation-corpus/0..99` 种子正常生成、原完整 validator 均通过；14 种动作全部进入正式图，`thorn_gap` 65 次，max_retry=0、fallbacks=0。实读原五格承载面320px、左两格危险128px；仅最右草岸由200缩到160，总模块宽680。复合680+260后余60px，join有两个真实支持端口。三张实际完整装配地图中该复合连接均正反向真实连续遍历，每向354–361ticks、safe=true。初始站位是明确的局部连接 fixture，之后仅普通 router 输入，无途中传送/补资源；不宣称从出生走完所有100图。 |
| `tests/plains_interactive_platforms_runner.gd`、`/tmp/d081_review4_interactive.log` | **107/0**。四种新模块、四初始相位、双向身体扫掠，受控平台真实射铃停车/继续，远门关闭时真实高处旁路，旁路零开枪/零开门。未删除旧断言。 |
| `/tmp/d081_review2_shore.gd`、`/tmp/d081_review4_shore.log` | 重放第二轮左岸反冲反例 **7 次**，x仅260.15..266.05，Boss保持12HP、hits=0、玩家5HP。没有上草台，真实下射方向与暴露窗口均存在，但没有真实踩台资格而不能伤害。 |
| `/tmp/d081_review4_piers4.gd`、`/tmp/d081_review4_piers4.log` | 自然阶段三、实际断桥/敌弹/伤害，**左→中→右三处真实命中，Boss12→9、玩家5→4**。初始左台x310；之后沿本台移到实际起跳边，再跨中台和右台。没有途中改角色位置、血量、资源或 Boss 模式。首次返程输入策略未完成，不宣称无损、全返程或完整击杀。 |
| `/tmp/d081_review3_snapshot.gd`、`/tmp/d081_review4_snapshot.log` | **18/0**。真实空中射击捕获资格后，显式暂停此弹体、实际 Motor 落地，再推进该弹体，真实命中仍有效；接受的是开火姿态快照。隔离容器检查资格最多32条，restore/cancel清除旧资格。该时间隔离 fixture 不冒称普通自然延迟实战。 |
| `/tmp/d081_review3_hints.gd`、`/tmp/d081_review4_hints.log` | **15/0**。四朝向真实平台面派生危险、镜像/双镜像；阶段II拒绝提示仅上侧背铃，阶段III分别提示踩亮台与已充能起跳。 |
| `/tmp/d081_review3_ferry_fatal.gd`、`/tmp/d081_review4_fatal.log` | 真实射铃启动，暂停冻结全部对应时钟/平台位置，恢复连续，段取消不重置。第二发实际碰撞产生非空 pending，再向真实 FrameDamagePolicy 提交致死批次；health terminal、lifetime失效后 deferred铃提交不停车，open_count保持1/running保持true，卸载无旧回调。 |
| `tests/plains_interactive_lifecycle_runner.gd`、`/tmp/d081_review4_lifecycle.log` | **21/0**。实际正式 App 正常生成带渡台地图，真实启动后暂停 capture→unload/rebuild，局部相位/位置/稳定LINK保持，旧 pending/eligible 不恢复；恢复继续运行。同帧死亡使用实际伤害批次，非简单假终止。 |
| `/tmp/d081_review2_sweep.gd`、`/tmp/d081_review4_sweep.log` | 无墙目标3→2，友方Area后2px薄墙挡住实际玩家弹体，目标保持3，failures=0。未放宽弹体半径、碰撞层或墙阻挡。 |
| `tests/plains_exploration_pressure_runner.gd`、`/tmp/d081_review4_pressure.log` | **6/0**；最终生成器选择 `review-pressure/0` 的真实渡台局部窗口，425ticks，fan9发、双方敌人HP3保持，玩家5→5、safe/continuous。读预警后普通起跳消费的是实际动作。第三轮此前 `review-pressure/2` 的425ticks同输入反事实（只去掉预警起跳5→4）仍保留为当时版本证据，不能把不同地图版本当成同一反事实。 |
| `/tmp/d081_review4_items2.gd`、`/tmp/d081_review4_items2.log` | **29/0**。实际 BuildState 逐个加入六新蓝道具，再加入两种反冲和两种伤害道具；每一步组合的真实派生 tuning 均可 roundtrip。任意 recoil+.13、gravity+1、未知道具、`../`资源路径、超过稳射2层、非Array items、非Dictionary capability均被拒。明确为构筑序列化 fixture，不宣称实际探索赚到了这些道具。 |

追加最终针对性复测：`/tmp/d081_review4_campaign_final.gd`、`/tmp/d081_review4_campaign_final.log` **3714/0**，包含原生StringName快照、非法物理值/未知来源及畸形capability拒绝；临时副本只将产物路径改到/tmp，断言与最新版正式runner一致。`/tmp/d081_review4_ports.gd`、`/tmp/d081_review4_ports.log` **189/0**，30张正常随机图的JSON replay仍通过，受控船的真实区域端口记录shoot_mechanism=true，远门端口记录optional_remote_shot=true且不误称必需射击；所有实际area.ports消费的描述与对应连接一致。此端口说明修正不改变物理或随机抽取顺序。

以上 headless 部分日志仍有 ObjectDB/resources/RID 退出清理警告；保留原文，不把退出码0称为所有诊断消失。

## 本轮发现、修复与断言审查

1. **复合连接的20px残段确实存在错误，而非签名不足。** 旧720+260组合留下20px，端口缺少真实支撑站位；缩短独立尾草岸40px，使join变60px是实际几何修复。没有改变核心五格平台/两格荆棘、Motor或碰撞；原有完整validator与双向输入扫掠均仍满足。`safe_cell_hop>land>observe_gear>second_hop` 与实际两段动作相符；签名本身不被当作独占操作要求。
2. **新增 ground hopper 使旧“所有其他pattern均aerial diver”断言失败。** 保留 `/tmp/d081-regions5.log`。最新测试对唯一新增 `safe_cell_ambush` 明确验证地面hopper、radius35和真实行为Definition，其余原fan/diver断言未改。属扩展新增合法类型，不能只删除旧约束。局部新hopper全种子公平性尚未由本探针证明。
3. **真正的两图 manifest roundtrip 漏洞。** 初始独立原campaign **3710/1**，`/tmp/d081_review4_campaign.log`；独立instrument `/tmp/d081_review4_manifest_checker.gd`、`/tmp/d081_review4_campaign_diag.gd` 定位旧 RunManifest.compatible 的基线 tuning 比较，原source line123。旧实现只允许projectile_damage变化；正常商店抽稳射支架使第二图 ground_recoil_multiplier合法变化，却被拒。根代理新增 `_region_tuning` 从已记录合法ItemDefinition/stack limit重建 BuildState modifiers，再逐键比较实际 stage_tuning。29/0独立组合/篡改验证通过；根代理 `/tmp/d081-campaign3.log` **3712/0** 也已读取。不是允许任意新物理值的白名单，核心参数篡改仍拒；非地区旧分支未改。
4. **旧固定reload种子不再必含渡台。** 独立重跑旧 `/tmp/d081_review3_reload.gd` 在最终配方下正常生成合法图，但没有controller，`/tmp/d081_review4_reload.log` 的失败为fixture前提失效。最新runner在8次有界正常种子中找实际含controller的图，没有覆盖生成内容/状态，再执行真实卸载恢复，21/0。不能将换seed当作规避不可达：原无渡台图仍由原生成validator通过，测试选择的是存在目标消费者的前提。
5. **探针失败不隐瞒。** 自然Boss初试x300完整脚底越出左台，Rune=-1且射击被拒；x310后真实踩台/命中成立。随后加实际本台起跳边得到左中右三命中。一次 `/tmp/d081_review4_piers3.gd` 缩进错误仅属于探针ParseError，生产文件未动；修正脚本为piers4。另一自适应返程策略piers5失败跌落，fixture未完整接入正式App环境回退，不据此报正式软锁，也不把它写成返程通过。

## 美术、提示与契约复核

- 静态确认AI原图四朝向绘制正确：RIGHT使用竖墙源图水平翻转，BOTTOM用顶面源图竖翻转；根床伸入真实host8px，绘制读取同一危险attachment。查看根代理早期普通网页截图，顶部/墙面红刺与草石承载面连成一体，未看到浮刺盒；这三张旧本地截图不是最终公开合屏验收。
- 早期Lab远门标牌受顶部菜单遮挡，根代理新四模块仅练习显示向下移200px；其记录offset、玩家world_entry、危险及实际机关同步移动，正式地图定义与碰撞尺寸未改。新配对AI图形+LINK编号真实消费；不是只有颜色或虚假画通道。最终网页可读性待最终GUI。
- Boss三AI形态、过场条幅、叶片与相机offset impulse是表现消费者；阶段III形态scale通过form_blend插值，避免骤变。符印来自真实完整脚底与对应台索引，再在射出时以session/shot ID记录；不是只检查命中时人在空中。允许等待一个台下次巡回慢打，不宣称必须访问全部三个台。
- 对 PlayerMotor、基础player_tuning和input_profile读取SHA及git diff，保持D079/D080字节：`d5287d731fd4155250541415a529f70bb2b3818c516c72959c164862b3abe6f6`、`e5161bb8ef1855b9eda515ab0613a4a738b47abc43b0f2dc118d2e45f71b2058`、`4b32d1d2a2ae930d649ed4a02c19833a725b9e8669ec33a9c5393229433ad64e`。PlayerProjectile的零motion静态初重叠和真实cast修复保留薄墙阻挡，不是偷改玩家物理。

## 主动玩法建议：已实现与候选分开

- **已实现：操作与资源的旁路取舍。** 远门可射铃走地面，也可零射击做上层攀跳再drop_through，实际双向输入已过。其价值是玩家比较瞄准/精力与平台操作，而不是强制所有人按同一按钮；下一步可将较危险高路的可见金币线索做得更明确。
- **已实现：落点足迹之后切换齿轮节奏。** 五格中两格危险需要选绿格落地，紧接独立齿轮段再读相位起跳。100图和实际双向组合已过，不能把第二段仍称普通gap。新hopper把落点观察扩展到跃扑预警，但多种子无损公平性需后续反事实。
- **已实现：相对运动的可控相位。** 射铃启停渡台、保留相位、双岸返回消费者与重载通过。此后值得用“停在一个可跳出的中间支岸”做真实操作对照；本轮验证岸边停车/恢复，不宣称中途刹车一定更安全。
- **候选：背风窗与射击救场。** 实心挡风墙后的短安全窗，玩家观察风段、离墙跳出并用反冲修正落点；需要真实风遮挡与普通跳/反冲反事实，不能先靠贴图命名宣布接入。
- **候选：先开撤离桥的高价值箱。** 看见困难箱之前能从另一侧打开下层回程，让“投入前准备退路”成为探索决策。要保留不同进入顺序与两向验证，不使用必须清怪/固定钥匙数强迫探索。

已读取根代理本地普通GUI报告 `build/verification/plains-interactive-browser/report.json`，failed=0，build_id=209e39911793，六个真实菜单入口、远铃OPEN/渡台MOVING与II/III名牌/形态通过；独立查看最新remote-shot与phase2/phase3-form截图，配对编号不再被顶栏遮住，两种形态与阶段III踩亮提示清楚。此为本地普通GUI输出复核，不称独立浏览器操作或最终线上演出验收。公开build-info/PCK一致、最终普通网页更新、完整双图真人探索与完整Boss击杀、小屏/触屏/手柄/Windows实机仍分别验收。技术ACCEPT不取代这些边界，也不自动合并PR。
