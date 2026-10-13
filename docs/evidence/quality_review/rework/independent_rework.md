# 局部返工独立审查

审查者 `/root/independent_gameplay_audit`，未参与实现，未修改生产代码、权威文档或仓库测试。此次只审暂停语义迁移、Boss RA4、普通敌人RA1；不审当前tile gallery，不认可平台画面，也不作整体品质或玩家认可PASS。

源版本：HEAD=`89ca510cad97b8940389d25423ab7869313734eb` **dirty工作区**，不是冻结修复提交。执行期间主代理另有地形工坊开发。本次结论绑定下列实际读取的文件SHA256；后续变化需重新核对：

| 文件 | SHA256 |
| --- | --- |
| scripts/demo/demo_app.gd | 5be7eb342005b9c59c1b529783b31c46e843f82f73134e4edfb028910268942f |
| tests/plains_enemy_attacks_runner.gd | a06a73333ef0c4dbbe503d1112c6adde566b3a94ab5a1b0540b0554dd64b50c1 |
| scripts/enemies/enemy_attack_behavior.gd | 2631c540f3d62b4ea313b60cdf935bf2feacbc998bb6a023afcbf4c98c1afe9d |
| scripts/enemies/enemy_attack_projectile.gd | dabc0f3e1e8b7aceaaed4a085c18b82fe19dfca483d772bb0dd9dcc6b0deaa06 |
| scripts/bosses/boss_arrival_presentation.gd | 4397061558672f90f6c475a4b0a698df61407b4d00dbc46bf744b75a2e80d81b |
| scripts/bosses/windkeeper_encounter.gd | 94a1bf744194ba1336286dbfde232c5f2c94d52aefa0767beeb6a66dc62902e3 |
| scripts/enemies/enemy_presentation.gd | 3d2bc0e2a6fb88cb2b2ae5d8c050bd525eadf43055d57b47a45a60728cc2cc70 |
| assets/plains_v3/enemies/meadow_actions/manifest.json | 3259288c624b08a05ad687ecafb1e6bf943c8f120c291cbfc32abc47abc4a6cd |

## 1. 暂停测试迁移：限定范围 ACCEPT

这次修改是纠正旧测试保护的exploit，不是删除生命周期保护以让失败消失。

旧 `app_pause()` 明确要求暂停将telegraph改成recovery并删除敌弹；初审IQA-01已经证明这是无代价打断攻击。新期待对应“暂停只冻结世界，不改变战斗状态；离开/死亡才取消”的合同。生产路径中 `_pause_for_menu()` 保留清玩家意图和停止慢时，随后暂停SceneTree；EnemyActor和EnemyAttackProjectile均PAUSABLE。菜单、地图和商店共用这个入口。`abandon_run()`→director.end_failure→`_run_ended()`仍调用 `_cancel_enemy_attacks()`；死亡、场景重载与明确失效路径也仍调用取消。

逐条核对新测试 `tests/plains_enemy_attacks_runner.gd:142`–159：

- 记录真实生成敌人的phase、state_time、cooldown、serial和实际生成弹体位置；不是只看暂停布尔值。
- 暂停后等待3帧，再验原telegraph/时钟/恢复债不变、弹体实例仍存活且未移动、生命不重置。
- 恢复3帧后验同一弹体推进、serial不增加，排除把旧攻击重新发射作为恢复。
- abandon后验原弹体无效或spent。
- 原套件中owner death立即取消、stage失效取消、actor_epoch取消、墙体挡弹与重复伤害无敌保护的断言未被删除或放宽。

**独立实际执行**：通过现有 `tools.run_tests.run_engine` 直接运行 `--headless --fixed-fps 60 --path . --script tests/plains_enemy_attacks_runner.gd`，没有再启动editor import。结果 **42 assertions, 0 failures；wrapper exit0**。原日志：`build/verification/independent-rework-enemy-test.log`。

边界：此测试仍是旧生成回归消费者（`start_plains_regression`），且显式设置telegraph、直接 `_fire()`创建状态夹具，不是自然遭遇完整试玩。它有效检查DemoApp公共暂停/清理路径；新正式两图消费者此前另有phase冻结测试，但本次没有再次跑GUI地图按钮。ACCEPT仅覆盖测试语义迁移和所运行路径，不能延伸成所有菜单、设备和完整战斗通过。

退出日志还包含 **18 ObjectDB实例/8 resources未释放**。它们未在本次归因，不隐瞒，也不凭此声称暂停修复新增泄漏；本次是断言通过，不能写“零错误清洁退出”或性能/生命周期全面通过。

## 2. BossArrivalPresentation / intro_duration：RA4限定范围 ACCEPT

源码修复与原反例对应：

- `WindkeeperEncounter.activate()`固定本次intro_duration，snapshot/restore保存该值；不再以重建时剩余clock当完整时长。
- `pose_offset(0)`和`pose_offset(1)`均为原休眠/战斗位置ZERO，关闭了原第一帧±130/y-100瞬移路径。
- 首次观察已到64%之后的intro时，初始化 `_impact_played=true`，避免重建后再次播放已越过的冲击。
- skip改为有限速度回位，避免直接强置ZERO。

新增的独立临时探针只写在忽略目录：`build/verification/independent-rework-probe.gd`；对应日志 `independent-rework-probe.log`。实际引擎以当前生产类运行，显式实例化状态夹具，不冒充正式Boss自然入场。

探针覆盖轮式/非轮式两种演出：休眠→intro初始位为ZERO；25%、50%、70%、90%经真实combat_snapshot→restore_combat_state重建后，进度与位置相同；重建不增加GameAudio.played中的boss_impact次数；skip后6个1/60步骤回位。与Enemy布局计算合计 **32 assertions, 0 failures；wrapper exit0**。

边界：未实际观看当前包完整正常速度Boss登场、没有听声音。probe检查的是接受的声音事件计数，不是音色/响度/同步主观判断。旧snapshot没有intro_duration时使用definition.intro_seconds的兼容fallback；本次没有跨版本局内存档迁移声明。上述ACCEPT只关闭RA4的确定源码/状态反例，不是动画美术G5通过。

该临时probe退出也有ObjectDB/resources及DummyTexture RID清理诊断；不能拿此探针声称无泄漏，日志保留。探针没有改正式资源或生命周期代码。

## 3. EnemyPresentation action_layout：几何子项修复成立，表现替代方案 REJECT

原RA1“idle顶部整条约15单位空白可命中带”已关闭：新布局把当前帧alpha128外框映到28×32（死亡姿态下半框），独立引擎验证全部12帧边界；实测原图映射后beetle idle局部(0,-10)/(0,-15)像素alpha分别252/245，确实不再是整片空白。

但 `scripts/enemies/enemy_presentation.gd:101`–109 通过**每帧独立、非等比缩放**把所有不同形状硬塞进同一个矩形，造成新的比例与动作表现问题。它没有识别主躯干/装饰区域，也没有保持同一角色的图像比例。

独立探针实际输出的x/y倍率比：

| 对象/姿态 | x/y scale比 |
| --- | ---: |
| beetle idle_a | 0.68056 |
| beetle attack | 0.56377 |
| beetle recovery | 0.72108 |
| sentry idle_a | 1.11441 |
| sentry idle_b | 0.98665 |
| sentry attack | 0.61701 |

这不是统一缩小：beetle attack横向相对纵向被压缩约44%；sentry从idle到attack的额外比例因子明显变化。idle_a/idle_b也使用不同横纵比例，而当前动画以7Hz切换且没有插值。原本攻击伸展/呼吸膨胀的 authored pose 被重新归一化，角色的头壳/躯干比例随状态切换改变。现有“外框恰好28×32”断言全部通过正是因为它只证明算式的目标矩形，没有证明动作自然或身体轮廓一致。

已实际查看原beetle/sentry动作图集；这项REJECT针对本次将非等比逐帧硬塞框作为表现修复方案，**不是声称已经有玩家不喜欢这两张图**。最终动画观感仍待正常速度合屏评审。头饰、叶片、腿和枪嘴应作为明确装饰/附属部分处理，不能用整个alpha外框代替主躯干核心；也不要求每个透明角落都能完全吻合矩形碰撞。

建议返工：定义稳定主躯干核心与脚底/中心锚点，保持统一比例，必要时重新适配姿态资产；通过可见主身体内外成对弹道及短正常速度动作片段审查。不要回到前版“全帧极值一缩了之”，也不要更改既有正式碰撞去适配图像。能明确关闭原RA1反例不等于新的所有表现处理都通过。

## 本次交付判定

- 暂停测试语义迁移与所验DemoApp路径：**ACCEPT（局部）**。
- Boss RA4位置/重建/重复冲击事件反例：**ACCEPT（局部）**。
- Enemy action_layout作为最终表现修复：**REJECT**；原大空白带几何子项已修，逐帧非等比拉伸需返工/审查。
- 平台、tile候选、正式画风、完整玩法、设备及玩家认可：**不在本次通过范围**。没有任何整体内容或用户验收PASS。

## 处置更新：撤回错误修复，不是原缺陷解决

主代理在收到本审查后明确决定将EnemyPresentation撤回5fd9原表现，不保留action_layout的逐帧非等比变形。上文action_layout的哈希、测量与REJECT作为失败证据保留；不得据此把原缺陷标修复。

**RA1/IQA-02保持未解决、REJECT**：回到原表现也会回到最初“可见实心头壳超出hurtbox”的问题，需要后续统一母版动作、主躯干/装饰标注及伤害可读性设计。暂停和Boss的局部ACCEPT不受此处置影响。新tile gallery的实施者报告不在本轮独立实测范围，未正式接入和用户未认可的边界保持。

已实际核对撤回结果：`git diff 5fd9c272d74616ae477809fa4285f609e6b697c6 -- scripts/enemies/enemy_presentation.gd` 输出为空、退出0；恢复后该文件SHA256为 `c131672321f0715aad60c6080f34855f3981cbdb4a6499faf1a29082d41d2703`。这是原版复位证据，不是原缺陷通过证据。
