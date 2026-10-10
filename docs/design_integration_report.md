# 动作肉鸽设计整合报告

2026-10-09。新分支docs/roguelike-run-contracts基于最新远端feature/snappy-shot-burst，基线77b10ec92e97aa89eddd92d83c409154f5d732b5；再次fetch后main仍64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226。开始时工作区干净，#12/#13/#14仍open，架构#11已合并；本设计PR以#14分支为base，不把未合并原型假装放进main。

## 旧规则冲突处理

| 旧规则/误解 | 当前正式规则与修改位置 |
| --- | --- |
| 精确跑酷为全产品、战斗/商店循环以后再定 | game_design/roadmap/tasks明确动作肉鸽、六阶段有界实现 |
| 环境碰撞直接死亡回检查点 | damage_and_respawn/player_mechanics/enemies明确扣血存活段回退、零血run结束回Home |
| 检查点/段点/家园/存储点混用 | level_design/world_components/architecture分别建模四种概念 |
| WorldContext.respawn全对象reset、补给每生命刷新 | world/combat/奖励契约明确选择性回退、世界/账本保留；旧代码待P2显式隔离，不称已迁移 |
| 只追加肉鸽文档但旧MVP仍禁止商店/玩家扣血 | game_design/mvp/combat/enemies/roadmap原章节直接重写，不留正式冲突 |
| 精力条等同射击次数或默认动作成本 | Health/Stamina/ActionResources分离；当前AirFocus标原型实验，正式用途Q002待定 |
| 随机先于完整战斗/路线闭环 | GEN依赖RUN-TEN/LEVEL-02，P4固定3关仅开发，不覆盖正式10关 |
| 回调先后决定零血/Boss/奖励 | Damage批次、RunEnd优先、暂定双方死玩家失败无奖励，事务幂等 |

新权威run_and_routes/rewards_and_builds/damage_and_respawn/home_and_save、AGENTS来源已互链。docs/design_contract.json为设计检查输入，不是游戏运行配置；用它验证正式10/Boss10、3关开发隔离、六类/稀有度/奖励/独立资源/随机流、暂定/待定状态与A32–A49的存在。

## 本轮完成与限制

DOC-02设计整合与BASE-01技术回归完成；新增Health、玩家伤害/敌人、段回退/真正死亡、奖励商店、RunDirector/Boss/Home、Meta/Save/随机生成均未实现。新A32–A49全部planned，旧326断言只证明现有运动/射击/输入/世界与慢时原型。

实际Godot4.7.2.stable.official.ed1daf0bf Standard。python3 tools/run_tests.py退出0，ALL TESTS:326 assertions,0 failures；含headless import成功。--verify-failure-exit故意失败实际退出1。python3 tools/check_docs.py退出0，26required/32dependencies/链接与参数通过；py_compile与git diff --check退出0。未更换引擎/配置、未改运行scripts/scenes/shaders/测试断言，未构建新APK/重发Pages。平台与真机历史证据保留，不重新声称本轮构建/试玩。

文档检查器临时副本负向自检：正式3关、暂定冒充确认、缺A39、循环依赖四例均实际退出1，正常副本退出0；真实仓库未受失败注入影响。本轮PR/CI在handoff更新。历史交接移到archive/handoff_before_roguelike.md，保留原始当时事实并修复相对链接。原型网页仍是旧运动/慢时测试，不能当作新正式游戏。下一小范围实现HEALTH-01（Health/Stamina独立接口/配置与固定图HUD），不一口气做伤害/Boss/家园/随机/永久系统。
