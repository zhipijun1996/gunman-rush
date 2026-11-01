# App 与地图内部接线收口

本批生产改动以 `c8d39551` 为基点；其后独立保存的验证读取优化为 `254b6003`。六个游戏源码沿三份补丁依次迁移，未改图声、物理、伤害、资源、奖励、随机、存档或入口。

| 原 App 内部操作 | 当前实际所有者 | 保留的行为 |
| --- | --- | --- |
| 遍历敌人／Boss取消攻击 | `GeneratedDemoStage.cancel_enemy_attacks`、`EnemyActor.cancel_attacks` | 敌人先Boss；只有原Boss方法存在且调用完成，App才清自己的shots及玩家弹体。Actor死亡／技能冲击共用同一实现，reset不变 |
| 地图anchor／伤害／机关／静态危险物装配 | `GeneratedDemoStage.bind_damage_context` | 原先后顺序、latch失败退出、shortcut epoch绑定和Manifest记录中点不变 |
| 创建接触伤害节点 | `DemoContactEmitter.attach` | App真实旧测试桥与Stage共用一个构造，字段／0.7间隔／parent时点保持，不复制一套 |
| Boss场地／存档恢复／Windkeeper几何／封印和重生点 | Generated／Plains Stage与Thorn小override | 原六阶段、两错误处理、终态恢复、坐标、Bell／Pressure差异保留；基类不反依赖Forest子类 |

App保留用户流程、原错误输出／结束运行、投射物／接触策略及奖励UI协调。Stage不接收App、Director或Session容器。阶段中点记录用窄同步回调，避免为了拆函数而移动副作用顺序。

## 真实验证

原9项相关Harness全部fresh通过：core5686、run-session61、完整R3 Boss、Forest App、Forest integration、Forest restore、world-objects、enemy-state、architecture。完整R3检查117.999秒／原360；核心34.872秒／原720。六源码在验证前后完全同字节，原生退出守门保留。具体各检查时间与来源见[收据](../../evidence/app_world_composition_01/final-receipt.json)。

style29／creative32只技术重绑六个实际漂移源码；旧28原件、206角色／路径／顺序和86非GD引用保持。历史适配仍是原有限reader，源／元数据来自精确254基点；不继承艺术、设备或玩家接受。当前46、creative26、历史32分别14.204／7.333／11.794秒，全0失败且保持原30／60／30预算。原74 Bible和25 creative方法保留，新增当前29与旧28回放控制。注册219、full171、legacy31不变。

旧C8完整CI仍记失败：串行79通过，并行70通过后Bible30.045秒超时，21项未执行。原API摘要验证的报告已[保存](../../evidence/bible_validation_cost_01/c8-ci-result.json)。独立性能提交254只在每次公开验证内共享读取上下文；所有SHA与每次祖先lstat仍执行，跨调用重新读取。旧超时未追签，本地更快不代替远端完整验收。

## 剩余工作及顺序

1. 固定本批最终源码，完成一次新的完整171集成；真实失败只定位对应消费者，不重生成素材或修改玩法换绿。
2. 地图替换最后接口验证：App仍有两处只读assembler查询（debug路线进度、camera构图），以及旧Stage内部Manifest适配。新Provider／模块库须通过统一Plan和既有工厂／恢复／结算接入；后续新算法独立开发。
3. 完成同源平台导出、PCK／浏览器／连续运行交付，再评价整轮架构是否收口。用户／设备／艺术认可独立记录，不由工程检查代签。

本批回退基点254b6003；生产六文件、后继绑定与测试适配应共同撤销，不能只回退一半。未合main或更新公开游戏。逐文件／依赖索引目前仍明确为旧冻结源，最终生产源码稳定后再刷新一次，不冒称已覆盖本批。
