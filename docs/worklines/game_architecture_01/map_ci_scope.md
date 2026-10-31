# 旧地图内部验证退出默认 CI

用户明确后续更换地图库／生成算法，授权先去掉地图内部关卡验证。本批只调整默认检查范围，不改地图、删除入口、修改检查预算或追签旧失败。

默认 `full` 从 C59 的185项变为 **171＝92 parallel＋79 serial**。14项原命令、输入、断言、成功标记和预算保持，追加到已有 `legacy-compat` 手动集合；全部218项注册保留，没有增加另一套 runner。

退出项是：`forest-interwoven-contract`、`level-design-golden`、`plains-redesign-golden`、`plains-redesign-spatial`、`plains-experience-golden`、`forest-h-slice`、`forest-depth-region`、`forest-vertical-shortcut`、`forest-bible-world-contract`、`forest-bible-world-connection`、`forest-bible-world-backbranch`、后两项的 `-map1`、`forest-bible-world-spiral`。六个默认 profile 同步投影，自动影响选择不会把它们加回；现 production domains 对这14项没有引用，不改无关配置。

地图接口／装配、物理、战斗、奖励、拾取、存档、敌人恢复和生命周期保留。`region`、`root-bell-spaces` 等混合检查暂保，因为其中还有真实事务、历史读取和恢复反例。纯旧布局部分以后再按原消费者拆出，不按 forest/map 名称整项删除。

原路线矩阵中通用的宝箱义务已迁入现有 `tests/chest_art_runner.gd`：五个暂停帧的实际支撑／位置／motion_steps冻结，真实 Control 鼠标按下／释放，经原 App 队列结算，关闭后首个 W 与重复领取幂等。复用已打开的第二个箱子；原两区／重载／键盘流程完整保留。原 world-objects 检查实际87/0、chest225/0，原240秒外层／150秒native预算不变。该输入证明限 headless Viewport 到真实 Control，不代签浏览器或实体触屏，也不称旧80路线已通过。

原 planner37与Harness91通过；当前主树planner37通过。精确投影保护C59有序集合、原legacy16前缀、通道互斥与所有原历史断言。见[清单与原件](../../evidence/game_architecture_02/map-ci-retirement-01/plan-plan.json)及[真实交互收据](../../evidence/game_architecture_02/map-ci-retirement-01/cache-ui-receipt.json)。回退使用本批实际父提交，撤销profile／测试两部分须一起进行。

C59远端运行41216348163仍是失败：serial17项通过后旧80矩阵600秒超时；parallel73项通过后资源历史检查30秒超时。Windows成功，Web／Android／发布跳过。它们与新171范围不同，不转换为通过；后继精确源码仍须新的集成验收。
