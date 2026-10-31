# 架构迁移执行记录

内容底座：`2ce4ffa64ef65dd5fba892776eea019c9e2841d4`（PR122/124/125/107，排除PR123）。主工作树 `/workspace/gunman-rush-refactor`，分支 `refactor/game-architecture-02`。用户要求持续完成且再次明确可用subagent并行；采用6个隔离实现/审查代理，root统一引擎验证。

## 已整合的实际调用关系

- `DemoApp → RunSession / RunComposition`：真实创建/清理迁移，一个Flow/Lifetime/Wallet/Build；Session不暴露给地图、敌人、道具。
- `DemoApp → LevelRequest → 两区Provider → LevelPlan → LevelRuntime → 现有Assembler/模块/EnemyFactory/BossFactory`：原算法与旧Manifest回退仍在旧Provider；裸Plan不需旧Manifest即可装配。旧Stage的表现/记录仍有Manifest适配层，不宣称整个旧入口已无此依赖。
- 三个Stage快照/一个App恢复点 → Actor/Behavior的共同状态协议；保平原11字段、森林8字段+专属depth及原String/StringName键类型。候选身份只由现有Registry定义。
- Shop修复 → Build → Inventory受限提交/回滚；Shop扣款/退款/Session清空 → Wallet；收益效果 → Runtime收益命令；两个主动族 → 同一ItemActiveCast。Time仅接窄能力上下文。
- 四Study + tests shim → 唯一生产WorldAudioLifecycle。音频nearest owner/Cloud重复服务/按钮重复响是独立旧缺陷修复，不混称等价。
- 绘制 → 一次姿态预处理 + UV权重 → 唯一顶点计算；旧deform入口仅委托同核。

## 实际验证与失败保留

P2原core/generated-consumers/forest-campaign通过；P4九项原道具family通过；集成P2/P4会话49/0。新地图146/0、实体61/0、共享施放13/0、四Study完整切换65/0。原森林80/80路线473.659秒，在原600秒内通过（源6b3df3f7，仅性能批+内容底座，不代签后来整合）。顶点367640逐字节等价5796/0，原motion481/0。

原/新音频释放16case对照80/0：同帧play→stop均保留待启动引用，物理启动后停止均释放；旧限制单列。先前失败包装marker、WeakRef推断、错误测试同帧假设、快照键类型差异、裸Plan空数组类型错误日志全部保留；修复后数据不覆盖失败原件。

现有Harness完整检查由172增到181，原172及预算保持。原自动跨job计划重复78次移除，实际Web仍在full生产并由消费者核同源完整指纹。architecture guard复用原structure，另有12项反例；动态加载仅披露，不冒称已静态解决。

## 第二轮原回归（源 d8144d39）

原14项计划实际执行13项：12通过；item-v5-formal的191断言全部通过，但严格清理检查发现57个ObjectDB实例和25个资源泄漏，整项失败，gear-inventory因fail-fast未执行。原基线同formal191/0且清理通过，作为本轮集成回归定位，不降低检查或清缓存掩盖。原日志见[完整运行报告](../../evidence/game_architecture_02/original-regressions-02/report.json)。

历史v11定义漂移另已由原内容基线重现280/2，独立修复afca59ec把原定义版本从生成器传至实际实体，不修改当前/v15资源。源端静态独审限定接受；原生和实际PCK验证仍待执行。Shop两个购买命令也已迁移到现有receipt重放函数（7be23e5a），原验证/扣款/信号顺序不变。

## 尚未完成

- 整合后的原core/生成消费者/森林保存与实体/道具/Boss/音频回归正在排队，完整181/GUI/实际导出待最终源冻结。
- P8.1已冻结旧style25/creative28有限原源（精确4bb7aa96）；当前live绑定仍失配，必须在全部调用者迁移后一次升技术style26/creative29，不重签旧SHA、不换图声。
- P8.2按功能路径迁移、动态与协议路径审核、35入口逐项盘点、全文件用途清单与最终依赖图仍待完成，不能以目前新目录或新增接口冒称全仓重构完成。
- 原能量初始化失败无回滚、Inventory patch失败后效果拒绝的原事务局限、同帧音频停止限制单独保留，不混改玩法。

每批回退父提交由Git历史真实记录；重构整体回退底座为2ce4ffa6。原dirty `/workspace/gunman-rush` 从未套用/覆盖。
