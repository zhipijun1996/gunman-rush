# 第三轮独立严格审查

结论：**REJECT（当前开发快照）**。模块操作、资源与敌人已有实质进展，但当前全图运动日志有失败，精力专项日志仍有资源解析错误；正式消费者还存在预警目标、回程铃绕过和资源选项的问题。此结论不代表拒绝继续迭代，也不把主代理正在实施的修正算作已验证。

审查者：独立代理 `strict_review_round3`，仅读代码、日志与资源。唯一写入文件为本报告。没有修改游戏代码，没有提交、导出、部署，也没有将未进行的 GUI / 设备试玩记为通过。

## 审查证据

- 分支 `feature/plains-exploration-expansion`，在 D079 后存在未提交开发改动。
- `/tmp/d080-modules5.log`：新模块 40 个方向/相位输入案例，96 assertions、0 failures；退出时存在 ObjectDB / resources in use 信息。
- `/tmp/d080-region9.log`：3886 assertions、8 failures；包括 deep drop 缺 `path` 的脚本错误，以及升降台到上方路口失败。不能用局部模块通过代替该全图失败。
- `/tmp/d080-expansion2.log`：2266 assertions、19 failures，部分生成地图达不到六种动作链。
- `/tmp/d080-expansion3.log`：2482 assertions、0 failures，但开头仍有 `windkeeper.tscn` 引用 `windkeeper_damageable.gd` 的 Parse Error。零断言失败不能覆盖加载错误。
- 本审查实际执行 `python3 tools/check_plains_item_art.py`，退出 0：15 个 AI 图标区块、20 个实际道具资源检查通过。主观风格、图标缩小后的辨识与 GUI 排版仍待画面证据。

## 必须关闭的事项

### P0：正式地图的真实运动与资源加载证据尚未闭环

位置：`tests/plains_region_trace.gd:55`、`:201`、`:225`，`tests/plains_exploration_expansion_runner.gd:115`。

当前完整 tour 日志的升降台回程与出口仍失败，专项又出现资源加载 Parse Error。主代理已经开始修正 deep drop 的 tour 路由过滤和 preload 循环；这里只确认源码改动存在，不确认修复成功。过滤旧 deep reward drop 只有在其挑战、落差撤离与普通路口再交汇另有连续真实轨迹覆盖时才成立，不能直接删除失败边的验收。

验收：最新编辑器导入、全部地区 suites 与旧回归须退出 0，并且无 Parse Error / SCRIPT ERROR。每个 open 双向边分别通过真实 Motor；两个自然单向下降有实际下降与独立回程；两条困难奖励路线有连续入口、领取位置、撤离、重返探索区域的记录。失败日志保留为迭代历史。

### P1：生成跳甲虫与测试跳甲虫不是同一消费者

位置：`scripts/generation/plains_region_generator.gd:224`–`:227`；`scripts/demo/generated_demo_stage.gd:173`–`:175`；`tests/plains_exploration_expansion_runner.gd:141`。

首次审查时正式 generator 为 hopper 分配 `patrol_radius=0`，加载器覆盖资源的 100px 半径，导致正式实例原地跳，而专项测试直接使用原资源验证横向落点。主代理已改正式值为 35px；仍需补生成实例的运动证据，不能只证明资源自身。

验收：从真实正式地图选出 hopper，确认实例半径、预警落点、横向起跳与落地、回收窗口及玩家可跳避。其压力不能仅等同地面 charger 的同一避让动作。检查多个种子的狭窄路口与回退后状态。

### P1：跳甲虫预警目标与实际落点不一致；阻塞态可能成为隐形伤害体

位置：`scripts/enemies/enemy_attack_behavior.gd:50`、`:66`、`:84`–`:87`；`scripts/enemies/enemy_presentation.gd:34`–`:38`、`:82`–`:96`。

telegraph 锁定 `home.y+dive_depth`（默认地板下 50px），但进入 attack 才改 hopper 的目标为 `home.y`。表现会在地板下画落点，攻击实际落到另一处。新增 `blocked` 状态没有 atlas 帧，地面表现遍历找不到帧便不绘制主体，而碰撞/接触消费者仍存在。

验收：telegraph 起就锁定最终合法落点，攻击不改变该目标；目标与真实身体最终落点在允许容差内。人为构造回程障碍，bounded recovery 进入阻塞后仍有可辨识实体与明确停滞表现，不能出现只剩 HP 点的隐形碰撞。

### P1：回程铃会绕过正式井铃的核心操作

位置：`scripts/world/generated_shot_latch_encounter.gd:23`–`:27`；`scripts/world/shot_latch.gd:254`；`scripts/generation/plains_route_recipes.gd:15`。

为保证回程添加的出口铃位于地板上方，当前从入口一侧也可射中。因此 `bell_pit` 宣称的跳起、向下瞄准、反冲开门可以被站在左边直接瞄对面回程铃替代。新输入驱动主动执行复杂动作，不证明真实玩家需要面对该操作决策。主代理正在加入出口侧开火快照限制，本报告尚未见该限制的验证。

验收：入口侧实际弹体对回程铃被拒绝且不打开；出口侧真实弹体能打开并顺利回程。可读标记说明“回程侧开铃”，不是静默拒绝。使用开火时的来源位置，避免弹飞途中换边改变资格；死亡/回退旧请求仍失效。

### P1：高级资源选项曾被固定金币选项遮蔽

位置：`scripts/generation/plains_region_generator.gd:230`–`:242`；`scripts/demo/demo_app.gd:1445`–`:1463`。

初始 `item_resource` 永远先放道具、再放资源数组第一项金币，两个位置立即填满，已记录的高级生命/音符从未展示。主代理现已使用独立 items 随机流调整资源顺序，这是正确修正方向，但当前专项只手工覆盖 medium 宝箱为 resources，不验证正式 high / region_top 的 UI 选项分布。

验收：从真实生成的 high / region_top 宝箱采样，实际 modal 出现金币、回血、音符与正确 tier 数值；最高挑战不能仅给最低价值。满血与道具满叠层情况仍给两个有效选择；选择失败不消耗宝箱、成功仅消费一次。再次进入和恢复实例保留同一确定性选项。

### P1：资源存档失败、同批致死与高档预算未被新专项覆盖

位置：`tests/plains_exploration_expansion_runner.gd:75`–`:114`；`scripts/demo/demo_app.gd:1496`–`:1538`。

现有测试明确用位置写入作为服务 fixture，可以用来验事务，但不能当真实行程。永久音符测试关闭持久化，未注入写盘失败；死亡测试直接 `health.apply_damage` 再手工 `_flush_actions`，未覆盖“选择已经入队、FrameDamagePolicy 同批致死”这一正式优先级。更新后的 HP 资源为 medium2 / high3 / top4，可领取总量为 `2+2+3+4=11`，而 `m.budget.cache_heart_limit` 仍为 9，已形成明确预算冲突；需重新分配数值或明确同步新的总预算。

验收：实际保存失败时钱包与 region_state.claimed 不变，modal 保留可重试选择且反馈可见；故障解除后仅提交一次。通过 FrameDamagePolicy 真实同批致死验证没有奖励和永久币提交。对所有可能选项计算金币/回血/音符分别可领取总上限，不能只检查每箱的 amount 大于 16。

### P1：两种敌人曾放在同一摆渡窗口；避让证据缺少正式组合

位置：`scripts/generation/plains_region_generator.gd:179`–`:213`。

首轮读取时 `ferry_air_intercept` 和 `ferry_fan_crossfire` 在同一渡船中点上方生成两只敌人，后者只是更换 behavior，没有独立空间位置。局部敌人测试验证三枚弹体和空中位移，不验证渡船移动、无人机俯冲、三向火力、落点与补能的实际组合是否公平可读。

验收：正式布局避免重叠身体/预警；记录不同 approach / landing / retreat 窗口。至少真实通过一次渡船与风扇火力组合、一次齿轮落点俯冲组合，不依靠先清所有敌人或损血穿越。明确等待与撤退落脚点，并验证首次地图的同时攻击限制。

## 操作与探索设计建议

### P2：低顶短跳需要“不同控制会产生不同结果”的反例

位置：`resources/generation/modules/plains_low_arch.tres`；`tests/plains_exploration_motion.gd:33`–`:42`。

现在证明 7 帧松跳可安全通过；未证明长按碰顶以后不能同样跨轮。若满按也稳定通过，它仍是低顶走廊加普通跳，而“松键控制高度”只是驱动的选择。先做短按与满按真实输入对照，再决定保持为容错教学，或通过真实头顶结构、落脚节奏、下一危险使高度控制成为可判断的操作收益。不要通过改 PlayerMotor、加资源或删除扫掠测试制造区别。

### P2：骨架现在有真实差异，第三种还需明确空间组织依据

位置：`scripts/generation/plains_exploration_topology.gd:6`–`:35`；`scripts/generation/plains_region_generator.gd:62`–`:106`、`:320`–`:323`。

原固定三行已改成缺口、不连续廊道和四/五层 footprint；linked_rings 的单向下降与独立回程是实质变化。后续修正又让三类骨架有不同竖井权重，这改变局部操作，但 crossroads 与 woven 仍主要共享矩形相邻图和删边算法。建议用实际连接不变量定义“庭院交织 / 竖井环路 / 中枢多入口”：例如跨层回路位置、共享交汇中心、从不同方向两次回到同一地标。不要只统计 family 名称和 hash。

验收建议：三家族记录角色完整行程的转向、下降/爬升、重复交汇与捷径缩短步数，不只 geometry 图。高级挑战当前固定 col0/2、row0，可在下一轮扩展入口深度和归返位置，避免每次“顶部两个固定大奖”。

### P2：中级宝箱与地标还缺少玩法归属

位置：`scripts/generation/plains_region_generator.gd:119`–`:121`、`:161`–`:165`、`:302`。

普通地标每个节点独立随机，缺少连续溪谷/维修区/钟台的空间归属；中级箱随机放路口并附固定 risk，未由通往它的一次可选挑战导出。深层所有 variant 的 platforming/timing/resource risk 也固定写 3/3/2，未体现渡船、双反冲、顺序风铃不同压力。

建议：让相邻若干节点共享区域意象和真实机制，路口保留稳定地标；奖励风险由已放入的模块、动作投入、敌人窗口和回程条件计算并记录。中级资源可以是路口的成长补给，但不能把这种箱与“完成一段完整可选挑战的中级奖励”混为一种证明。

## 已确认的有效进展

- 新原始 AI 六图标 atlas 与原九图标共存；源图不改，实际 20 个道具资源通过检查。稳定性、地面恢复、恢复延迟、开火冷却、刹车有真实 Modifier 消费者，不是空描述。
- 新水平摆渡、低顶、双水平齿轮、跨坑再到终点计时门有局部真实双向/相位驱动，不只是名称扩充。
- mini 使用独立场地；八方向真实弹体专项的断言目前通过，开场使用自己的 Definition 名称。仍需正常入口 GUI 的登场可见性及上方平台实际跳入后射击证据，人工摆源点不能证明所有上方落脚点都能打中。
- 固定三路硬结构已移除，真实单向竖井与强连通返回检查已加入；随机商店与资源宝箱进入正式消费者。
- 新专项进入 `tools/run_plains_region_tests.py`，没有将旧回归整体移除。

## 下一轮放行条件

完成上述实错修正后，交给新一轮独立审查者，提供最新无运行错误的真实轨迹、正式资源/敌人消费者、正常 GUI 与更新网页的证据。技术通过、画面可读与玩家趣味评价须分别报告。当前报告的 REJECT 不应被重新描述为已通过。
