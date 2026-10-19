# V13 接收岸占位修复独审

结论：**SCOPED_ACCEPT**，仅接受 root02/map1/growth 的蜘蛛占位修复；不签完整80案例或 FUN。

生产源 SHA：`6c7fd60c1cf5419528e117c52ec2445001ae6a5cecb1bcd3dcf83352f09e31a3`。原 capture `9223d22955113d139cb6bc852b6a1d709446a50dc78357f9908b8b144eb63d4b` 保留：tick1144 玩家身体右缘390.94撞旧蜘蛛左缘387，属于真实落点占位缺陷，原 native 完成不能替代体验验收。

修后原严格 wrapper receipt 为 passed/source_stable=true，capture `45cdafaf85f4f2c63187b5b8bcb0faf1fb9e58bed817aefa66a8fd01bfc76585` 与 receipt 声明相符。实际逐帧读取 leg13 共151帧，HP始终5，尾部1150–1161连续12帧全脚承托于 inner_root [290,820,500,40]，脚底误差<1px。leg13/14没有玩家受伤事件；后续其它腿伤害不被本结论覆盖。

x500相较旧位置仅改变命名蜘蛛 position/line_start/line_end/authored_body_sweep 四字段，实际敌数15不变，其余敌人、资源掉落、RNG流/游标、选择及玩家合同一致。两 receipt 源清单仅 producer 和对应 contract test 两文件改变；敌人属性、伤害实现及 reader 未改。

落点400至线程实际碰撞边界450有50px余裕；线程至种子哨之间允许完整玩家中心在(540,593)范围内观察，宽53px（若蜘蛛x540则仅13px）。线到受保护落点70px，大于8+45=53px，未静默取消攻击；y802线不穿root实木。上方奖励枝台保留绕行。

原 contract 报告实际242检查/20案例通过；当前只对单敌四字段精确投影，保留完整数组相等和其它参数相等，并新增20个逐案例敌数断言，预期262。**当前262尚未执行，不能继承242通过。**这不是放宽碰撞、连续或路线读者断言。
