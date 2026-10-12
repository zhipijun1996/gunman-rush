# D081 第三轮独立严格审查

审查者：`d081_strict_review3`，独立于前两轮。production 全程只读；自行编写 `/tmp` 探针，本报告为唯一仓库写入。审查使用官方 Godot `4.7.2.stable.official.ed1daf0bf`，命令前缀 `bash tools/godot.sh --headless --path . --fixed-fps 60`。审查期间根代理继续修复，以下区分修复前证据与复测。

结论：**本轮实际复测的技术门槛通过，未留下已证实的 P0/P1。** 第二轮固定左岸输出反例被真实条件阻止；实际跨台、攻击姿态快照、机关暂停/死亡/重载与四朝向附着几何获得具体证据。这个结论不代表完整 Boss 击杀、完整双图真人趣味、美术设备验收或所有种子的敌人压力均通过。

## 独立执行与结果

| 证据 | 实际结果与范围 |
| --- | --- |
| `/tmp/d081_review2_shore.gd`，重新运行输出 `/tmp/d081_review3_shore.log` | 原反例连续 **7 次**：左岸 x `260.15..266.05`，起跳并下射反冲至 y≈351，再下射暴露铃芯。**Boss HP12保持12，hits=0，玩家HP5保持5**。未上草台，没有在过程中改位置、血量、资源或 Boss 模式。 |
| `tests/plains_platform_boss_runner.gd`；`/tmp/d081_review3_boss.log` | **11/0**。第一阶段真实地面弹体命中；第二阶段地面侧射拒绝、真实跳上高台后上侧命中；第三阶段站立拒绝、实际踩台起跳下射接受。局部阶段入口 fixture，不冒称完整实战。 |
| `/tmp/d081_review3_snapshot.gd`；`/tmp/d081_review3_snapshot2.log` | **18/0**。先实际踩中台、起跳、接受真实射击，短暂停止该真实弹体的物理处理，真实 Motor 先落地，然后推进该弹体进行实际核心碰撞：Boss HP11→10，此时玩家已 grounded、当前 rune 已=-1，证明接受的是发射资格快照而非命中时姿态。延迟弹体为明确的时间隔离 fixture，不宣称普通游戏会自然产生这个延迟。后段以隔离容器 fixture 验证资格最多32条、restore/cancel 清空，不把手动设置容器前置状态当成实际踩台证明。 |
| `/tmp/d081_review3_piers.gd`；`/tmp/d081_review3_piers.log` | 自然第三阶段、真实地形/断桥/弹体/伤害，**中台→右台连续两处有效命中，Boss12→10，玩家5→3**。无过程中修改 Boss 状态、血量或玩家位置。首台初始瞄准策略未命中，返程控制策略未完成；因此只证明两处实际跨台攻击，**不证明无损、全部三台返程或全 Boss 击杀**。 |
| `tests/plains_interactive_platforms_runner.gd`；`/tmp/d081_review3_interactive2.log` | **107/0**。四种新模块、四初始相位、双向真实 Motor/身体扫掠；远门上下替代路线；真实射铃停车与恢复。 |
| `/tmp/d081_review3_ferry_fatal.gd`；`/tmp/d081_review3_ferry_fatal.log` | 真正射铃启动后冻结/恢复局部时钟，cancel 保持运行相位。第二发真实弹体碰撞形成 **非空 accepted pending**，随后同帧向实际 FrameDamagePolicy 提交致死请求，真实 Health terminal、lifetime end，再运行 deferred 铃提交：**open_count保持1、running保持true，不发生死后停车**。卸载后无旧 callback。原 review2 探针 pending={} 的检查未被当作本项证据。 |
| `/tmp/d081_review3_reload.gd`；`/tmp/d081_review3_reload4.log` | **8/0**。实际正式 App、seed `review3-actuator-reload`，真实弹体启动实际生成的渡台；暂停、capture、真正 unload/rebuild，LINK/计数/运行状态保持，旧待处理请求和旧射击资格均为空。clock差 **0**，位置差 **0.000061px**（0.001px浮点容差），恢复后从 .95 连续至 1.0667。初始玩家传送明确是事务 fixture；不把它当连续探索证明。 |
| `/tmp/d081_review3_hints.gd`；`/tmp/d081_review3_hints.log` | **15/0**：四朝向实际 host 派生危险矩形、镜像/双镜像12个断言，加阶段II/III拒绝提示三个实际函数分支。 |
| `/tmp/d081_review2_sweep.gd`，独立重跑 `/tmp/d081_review3_sweep.log` | 真实玩家弹体，友方 Area + 2px薄墙/目标：无墙HP3→2，有墙目标保持3，**failures=0**。不是移除物理半径或忽略挡墙。 |
| `tests/plains_exploration_pressure_runner.gd`；`/tmp/d081_review3_pressure.log` | **6/0**，正式 v3 seed `review-pressure/2`，实际全地图几何中的渡台局部敌人组合；425 ticks，fan9发真实弹体，双方敌人HP3保持，玩家HP5保持5，safe/continuous。仅激活该窗口敌人，非完整地图所有敌人运行证明。 |
| `/tmp/d081_review3_pressure_dodge.gd` 与 `/tmp/d081_review3_pressure_counterfactual.gd`；同名 `.log` | 独立操作反事实：读俯冲预警 `.3167s`，在真实甲板 `(542.4,-.0244)` 请求普通起跳，玩家5→5。只移除这一次读预警起跳，其余路线/时间/敌人/资源一致，425ticks，玩家 **5→4**；无损断言按原规则失败、其余条件通过。证明敌人压力确实改变走位操作，而非仅增加数量；不证明该起跳是唯一无损解。 |

## 本轮发现并复测的修改

1. **阶段II拒绝提示 P1。** 原 `_armour_hit` 三目优先判断 `rune_platform != chase_segment`，阶段II默认 -1/0 也提示“先踏亮当前草台”，但该符印仅第三阶段存在。已反馈；根代理将符印文案严格置于 `stage_phase == 3` 分支。独立函数测试确认阶段II只提示上台向下瞄准，第三阶段分别提示未充能踩台与已充能起跳。
2. **暂停重建位置 P2。** 原真正暂停重载后，motion clock正确为 .95，但新 `AnimatableBody2D.position` 停留在 `(0,0)`，旧位置 `(355.2,312)`，直至恢复物理帧；这是暂停重建时的显示/碰撞初始定位问题，不是已证实的普通流程软锁。根代理在 `_ready` 初始化及 `restore_motion` 定位时临时禁用 `sync_to_physics`，再开启，并让正式 stage 调用恢复方法。独立正式 App 重载复测通过。修复后直接浮点向量相等的初始诊断仍因0.000061px差失败；保留失败日志 `reload3.log`，改用0.001px明确容差，不掩盖原位置归零问题。
3. **原容器诊断前置条件错误。** 延迟射击后真实玩家落到地面，rune已重置为-1，后续直接插入50个资格自然均被拒绝；首个 `/tmp/d081_review3_snapshot.log` 的“上限32”失败属于诊断前置条件错误。实际快照命中已通过。后续只为隔离容器检查设置合法容器前置条件，18/0，不放宽生产接受条件。

## 静态与视觉源复核

- 附着荆棘由真实平台索引、TOP/LEFT/RIGHT/BOTTOM、start/length/depth 派生。五格承载平台长320，左两格危险128，其余192为可落脚部分；墙面刺用实际墙体面。反射调整top/bottom起始范围，互换left/right。渲染同一attachment，根床向host伸入8px；RIGHT采用竖墙源图的水平翻转，BOTTOM采用顶刺源图的竖翻转。未见第二轮把RIGHT错误压成横图的分支。
- 已实际查看新 AI atlas：三个羊Boss造型、石草五格/墙刺、配对标记和下射图形。RGBA边界alpha=0；查看器背景不应误认成运行贴图的有色方块。实际小屏尖端辨识、边缘透明品质、四朝向合屏效果仍由公开网页/设备视觉验收承担。
- 风铃与远门/移动平台通过同一个AI图形及唯一LINK编号匹配，不只依赖颜色；不同配对复用三图形时编号区分。远门存在实际闭门上下路线选择，不应宣传成所有玩家都必须射铃才能通行。移动平台使用独立motion clock，其他机关时钟继续；cancel只取消旧请求，不重新抽图或重置相位。
- 第三阶段资格按真实 on_floor 与完整脚底范围检测，发射事件记录 session/shotID，再要求 fired_airborne 和 `.85` 下射锥。资格快照不进入combat snapshot；restore与cancel清空。造型、过场、粒子、震动仅表现，不决定伤害。核心半径18px、基础Motor/PlayerTuning/InputProfile未改。

## 保留边界与后续严格建议

- 本轮技术 ACCEPT 不等于“已经足够有趣”。跨中/右台实战需要掉血，返程尚未由本探针跑完；应继续做可观察的全三阶段普通输入Boss击杀与完整两图探索，记录失败，而非只看方向predicate通过。
- 需要公开网页真正看到阶段II/III转换条幅、当前符印/下射图、实际开场震动/叶片与形态尺寸平滑；不能把原图数目当过场动画验收。
- 受控渡台“在岸上启停”已通过，不应未验证就宣传甲板中途停车必然更安全；后续值得加入稳定泊点、远端起降选择、平台与敌人预警的反事实路线，以操作和风险差异验收玩法。
- Headless交互/部分诊断仍输出 ObjectDB/resource/RID 退出清理警告，日志保留；本轮结果未出现 Parse/SCRIPT ERROR。没有把退出码0当作所有清理问题都解决。
- 未执行公开部署、手机/手柄、完整双图真人体验或美术风格用户确认。上述门槛必须分别记录，不能以107局部断言替代。
