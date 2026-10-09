# ENEMY-01报告

2026-10-09 UTC。基于最新远端feature/actor-resources-framework的524c97433573402bfc2a3f34b03b9d6238efc23b创建feature/enemy01-patrol；最新fetch main仍64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226。开始工作区干净，PR #16未合并，本轮PR叠加其分支，不自动合并/强推。

## 实现范围

首个敌人为固定高度悬浮巡逻fixture（D038工程候选，不锁定正式敌人/平衡）。配置放resources/enemies，独立场景scenes/enemies/patrol_drone.tscn可复用。EnemyActor组合HealthState、PatrolAI、Intent、独立Motor、Damageable兼容适配与原创几何占位Presentation；AI不引用玩家控制/输入，表现不改伤害。

巡逻速度90、半径100、3HP、碰撞28×32只来自Definition/tres。Motor一次move_and_collide实现扫掠阻挡，遇墙通知AI反向；PlayerMotor仍唯一move_and_slide入口。死亡只发一次defeated，停止AI/速度/碰撞，不发奖励或决定Run结果。

现有弹体附target_actor_id/target_epoch，绑定新Health的Damageable校验目标/epoch/友伤/自身/非法量/重复事件后提交ActorResourceRequest。新敌人HP只有HealthState一份，旧靶保留旧计数兼容；未来DamagePolicy迁移成统一类型化批次，不扩张为全局字典总线。灰盒Practice新增一个巡逻敌人，旧整关Retry会恢复其状态；正式段回退不得调用该reset，SEGMENT任务后续处理。

## 实际验证

Godot4.7.2.stable.official.ed1daf0bf Standard，python3 tools/run_tests.py实际416断言/0失败、退出0（含import；旧374保留+新42）。新测试覆盖两个实例独立、实际巡逻运动/边界/禁用/配置变更、真实大步墙碰撞与恢复、现有有体积高速弹体命中、重复/错目标/旧epoch/非法/友伤/自身拒绝、死亡停止和唯一败亡、重启token失效、真实暂停和全场慢时速度比。构建与干净检出结果在handoff补证。

A20仅最小独立AI/受击/死亡部分有证据，第二种AI/主动攻击待后续。玩家接触伤害/怪物无敌/击退、环境回退、零血Home、Boss/奖励均未实现；A33仍待DAMAGE-01。不提交二进制/截图，本轮不发新APK/Pages；Android/iPhone真机触控/手感/性能和Windows实机未验证。

下一任务DAMAGE-01：统一类型化伤害请求、确定性批次、怪物受击无敌与环境保护边界，按D028暂定策略验证；不直接回退/做完整Boss。

本轮python3 tools/build.py web与windows分别实际退出0；Web构建 **617857acf493**。Chromium151触屏模拟实际加载该PCK，Practice按钮重新初始化后两张渲染截图的敌人中心x693.5→758.0，证实真实Web可见且运动。HP/精力条/按钮分离，慢时黄边/透明中心/淡出回归通过；无脚本/Shader/页面错误。首次两端采样跨越巡逻转向造成位移阈值失败；通过实际Practice按钮固定起始相位再测，同一移动阈值不变，未更改游戏速度/范围来过测。

两个导出日志均无res://build/验证产物入包；Windows PCK在同版本Linux Godot中--headless --main-pack ... --quit-after 5启动退出0，无脚本错误，仅说明数据包加载，Windows EXE实机仍未验证。故意失败测试实际退出1。文档检查27文档/33任务依赖与链接/契约、diff-check退出0。实际截图/构建报告保存于忽略的build，不提交二进制。

[PR #17](https://github.com/zhipijun1996/gunman-rush/pull/17)，base feature/actor-resources-framework；实现1bf2f05、Motor定位入口补强a41c170。独立无缓存检出1bf2f05实际416/0、退出0，a41c170最终无缓存检出同样416断言/0失败、退出0（含首次import），CI core/Windows与Web通过，证据见handoff；重启定位也只经EnemyMotor.reset_at。

最终Motor入口补强后的Web构建e5415f5135bb、Windows分别重导出0，Chromium再验敌人可见且中心x696.5→764.0，HUD/慢时通过、无脚本/Shader/页面错误；最终PCK同版本Linux再次启动0，仍不代表Windows实机。实现提交a41c170的Documentation与Godot CI均实际success，Android/Pages按条件skip。
