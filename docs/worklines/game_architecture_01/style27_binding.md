# style27 / creative30：有限所有权收口的技术源码绑定

这是同一未提交style27/creative30的R2技术候选。六叶初版的原四项通过记录只属于初版；R2原四项绑定检查与完整验收仍待验证。唯一当前选择仍由 Bible registry 的 shared_style_authority 和两区 creative direction 指向，没有新增运行版本选择器。原 style26/creative29、所有更早 SHA、艺术/声音接受记录及失败原件保留。

来源已绑定实际 P9 提交 `4e91a0dd1d6c02e6a7466368e91665d2a6a7a71a`：该提交的七个生产文件和四个测试文件 Git blob 逐项等于原2e1c基点上的冻结候选SHA，六个style变化叶也保持相同字节。style27 的 revision_impact.frozen_candidate 保留原冻结向量。这只是来源身份确认，不新增运行、艺术或用户接受；原2e1c候选外部原件保留。

| 独立范围 | 实际变化 | 保留行为 |
| --- | --- | --- |
| AUDIO-LAB-MATERIAL-01，ed95 | GameAudio 显式 enemy_hurt 试听尊重已有 ABC 候选 | 普通游戏/original 仍用当前材质音效；这是独立原缺陷修复，不冒称 Lab 音效逐字不变 |
| P9 Latch | Stage capture/setup 委托原 ShotLatch，复用平台 restore_motion | 原七字段、缺省值、写入与恢复顺序、开门覆盖及实际运动位置 |
| P9 Flow | terminal reentry 完成标记写入收回 DemoRunDirector | 同一触发和时点，不新增准入、重置其他状态或改变奖励 |
| P9 Arena | App 两处恢复委托 Encounter/Arena | 普通 phase3 与 Pressure bridge_break_ready 各自政策及 deferred 破桥时序 |

新绑定保留原206个角色、路径和顺序，新增角色为零。App、PlainsStage、ShotLatch、WindkeeperEncounter、WindkeeperPressureEncounter、GameAudio 原六个既有源码叶保持初版SHA；R2另推进 world_presentation 对应 UnderworldPresentation 一个叶，共七叶。全部媒体、许可和正式资源选择保持原字节。DemoRunDirector 与 WindkeeperArena 是真实生产依赖，但原206未单独逐叶绑定它们；其实际改动仍需原CI/原生回归，不能用“可达”冒充独立摘要覆盖。

[有限历史清单](../../creative_direction/archive/ownership-closeout-before-style27/manifest.json)从 `6f743953d6c70c63d4d366a3e84cbe2a571b29d7` 逐字保留七个旧源码叶及旧registry、两个creative29、两份原测试和原profiles。该提交全部206引用逐项匹配style26原SHA。无媒体复制、无全仓快照；使用原 archived_source 的路径/清单/叶摘要校验。已索引历史叶缺失或篡改必须失败，当前27直接检查当前源，不以历史字节遮蔽红灯。

旧26/29测试改为有限原源重放，新增27/30当前守门。原方法和循环保留；七处必要迁移有完整old/new AST身份及有限差分，不仅比较assert字面量。原25整method校验和return、if False、空loop反例保留，26重放边界追加同类守门。目录迁移layout_path继续读取原26迁移表，不误用27的SHA差异表。

四个原check命令和预算保持：Bible contract30秒、Bible tests30秒、creative direction30秒、creative tests60秒。原314/653项显式输入含重复与顺序全部作为前缀，仅末尾追加新style/archive等必要项。creative两check保持默认输入选择；原598映射前缀及三个重复项的收据不改。新style和归档叶变化必须进入既有input_digest；不另建检查注册表。

准备时P9只有限定静态独审接受，原生重载回归待root；音频154两lane结果仅属于独立音频卡。style26旧官方formal191/0但57 ObjectDB/25resources严格退出失败的原文保持，后续引擎结果另按实际来源记录。此版本不签新美术、听音、玩法、用户、设备、full182、最终PCK或工具链整体激活。

未生成图像/音效，未修改运行源码。回退本绑定需整体恢复旧registry和两份creative29；生产源码已变化时，旧26应重新报源漂移，不能将元数据回退冒称兼容通过。P9整体回退按原计划ed95及独立提交执行，保留所有失败和接受证据。

R2独立生命周期来源：`UNDERWORLD-DEFERRED-LIFETIME-01` 是 `59537400af06a26046037840e28989f75933a265` 基点上的三文件冻结候选，现已以完全相同Git字节提交为 `49a298b40890ccf4d9d2326d051f12a0ffe63c27`，实际SHA记于 `revision_impact.lifecycle_followup`；不声称该修复已在4e91。P9的11文件冻结向量与4e91身份原样保留。独立[技术质量记录](../../quality/records/UNDERWORLD-DEFERRED-LIFETIME-01.json)负责原生生命周期证据；R2不继承初版四项通过或新增视觉认可。当前实际world_presentation必须匹配新SHA，旧style26通过同一有限manifest重放其原6fa84字节。初版完整候选及通过日志保留在原外部目录，最终来源绑定只确认上述同字节，不新增验收。

R2新增生命周期来源测试实际读取三份冻结源码，Bible tests的原656项输入完整保留，仅尾部追加 `tests/underworld_plains/test_underworld_formal.gd` 与 `tests/quality_review_runner.gd` 两项；原条目重数、其他check参数和full182不变。原null/未提交R2候选及验证原件保存在独立外部历史目录。


实际主树最终R2原四项均fresh通过，Bible67在原30秒内完成（Harness29.445秒），creative tests原60秒内完成。原R1结果只属于其历史六叶候选，不追签R2；[原件及独审](../../evidence/game_architecture_02/style27-final-binding-01/index.json)分别保留来源。当前源绑定49a三Gitblob、P9原4e91十一叶不变；完整182及实际导出另验。
