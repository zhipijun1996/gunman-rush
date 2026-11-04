# 敌人与Boss

## 定义、实例与工厂

`EnemyBehaviorRegistry`和`EnemyFactory`将Definition、行为与物种表现装配成独立实例。`BossFactory`从现有Boss场景与Definition创建各自Encounter。定义描述配置，生命、招式相位、弱点和奖励收据属于实例。

代码位于`game/enemies/`及`game/bosses/`；Boss场景仍在`scenes/bosses/`，部分Definition类和资源仍在`scripts/`、`resources/`。改动从 [模块导航](module_map.md) 定位。

## 战斗合同

预警、攻击、命中与恢复使用明确时钟和碰撞语义；玩家可通过站位、跳跃、瞄准、反冲及已授予能力反制。敌人改变地形中的决策，不依靠单纯提高生命或数量制造新机制。

伤害提交统一FrameDamagePolicy；真实命中、受伤、死亡和奖励以接受结果触发表现。弹体／回调受Run、Stage和Actor生命周期限制。怪物生成许可、攻击距离、视线与安全区分别核对。

## Boss流程

平原两图分别接小Boss与牧风者；森林由实际生成版本选择对应Boss。Encounter拥有各自阶段、招式组、共用姿态与恢复协议，地图拥有封场及地图级账本。

Boss终态停止伤害并按实际动画／失效时序提交胜利；保证金道具与核心能力独立。玩家同帧死亡优先，奖励只结算一次。存活回退保留已声明的Boss状态与机关相位。

## 制作与验证

普通怪完整度按 [E01–E12标准](quality/enemy_completion_standard.md)，制作顺序见enemy-creator开发手册。Boss按自身设计卡和真实招式消费者验证。

验证覆盖活体／死亡／离开、无目标、中断、最差相位、完整出返程、连续恢复、同帧死亡及取消。正常速度音画、正式遭遇、技术检查、玩家与设备分别给证据。当前具体任务从 [任务索引](tasks.md) 进入。
