# 森林敌人

森林敌人通过地形、可借用目标、方向、时间和持续危险改变路线判断，遵守 [森林圣经](../../bible/regions/thorn_forest.md)。是否出现取决于真实地图版本和放置，存在资源不等于默认地图都使用。

| 敌人 | 可感知行为与应对 | 唯一数值配置 |
| --- | --- | --- |
| 铃囊萤 | 有限停驻、转向预告和自主迁移；可保留为移动 H 目标，也可先清除，不发射攻击 | [forest_lantern](../../../resources/enemies/forest_lantern.tres) |
| 棘籽哨 | 预告后向锁定的真实支持区域投种子，落区持续威胁；玩家可离开、借遮挡或先清 | [forest_seed_sentry](../../../resources/enemies/forest_seed_sentry.tres) |
| 树皮甲虫 | 沿根盘巡行，有明确面向与甲壳方向；玩家在其面前时预告并沿已承诺方向冲出，越过它后不会瞬间转向追人，收势后休息 | [forest_bark_beetle](../../../resources/enemies/forest_bark_beetle.tres) |
| 吊荚摆锚 | 围绕真实悬根沿宽弧往返，转向和速度连续，可作移动借点；受树干阻挡时停下，不穿透或传送 | [forest_swing_pod](../../../resources/enemies/forest_swing_pod.tres) |
| 织棘蛛 | 预告后展线、持线、收线再恢复；线段与身体分别构成危险，玩家可抢行、等收线、换高度或清除 | [forest_thread_spider](../../../resources/enemies/forest_thread_spider.tres) |
| 跨枝移动体 | 在真实两岸间停驻、预告、起跳和落定，提供可选借用与回程；撞地形安全收束，不从障碍中穿过 | [forest_crossbranch](../../../resources/enemies/forest_crossbranch.tres) |
| 圣经织者 | 与实际宿主枝条、织场和可互动空间共同构成压力，需按选定场所核完整预告、动作与反制；完整物种表现仍待实际审查 | [forest_bible_weaver](../../../resources/enemies/forest_bible_weaver.tres) |

复用平原冲锋怪的行为只见 [冲锋怪](plains_charger.md)，森林提供放置与明确覆写，不重复抄尺寸和时序。

身体、预告、受伤与死亡保持同一形体，植物和蛛网有真实宿主。玩家能辨认威胁、落点、可借用对象与装饰；主路不因可选互动而暗需未来能力。具体物种的动作、音画和正式遭遇仍需随实际功能完善，当前缺口归任务，代码和检查见 [模块导航](../../project/module_map.md)。
