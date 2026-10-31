# RUN-GEAR-UI-02：正式暂停背包

本轮根据用户[原图与补充](user-reference.json)重做暂停入口与背包布局，更新[PR110](https://github.com/zhipijun1996/gunman-rush/pull/110)，不自动合main。运行源`bb4bf464a639af6c20828b84a5ac1df3785f393b`；之后只追加文档和证据。

系统已接入正式DemoApp平原／森林，而此前公开试玩站未含新分支，前片又采用固定开发三房间，因此不能用旧网站／旧片评价本轮入口。新片明确从标题、可操作家园和正式出发进入平原，随后真实点击暂停直达背包。宝箱领取段使用一次屏幕明确标注的位置fixture，原W交互、奖励领取与装备交易不绕过；不是自然平台挑战通关。

## 界面变化

- 暂停一次直接背包，顶部背包／旅途／设置／帮助四页；点左右箭头、Q/E或手柄LB/RB切页，方向键继续选择道具。
- 左上已装备、齿轮形状负荷槽；左下独立滚动图标网格。右侧选中实例的名称／图标／稀有度／负荷／实际效果，装备／卸下／替换及扩容。
- 齿轮采用原生8齿轮廓与中心孔，青色实心表示已用，暗色空心表示剩余；8／10／14槽均核对实际状态与小屏边界。
- 点击／焦点选择只改详情；切页关闭原装备会话，返回新建；选择变化使旧详情按钮失效。关闭取消旧游戏输入。

[桌面实际装备](desktop-equipped.png) · [桌面实际背包](desktop-backpack.png) · [960×540背包滚动](touch-equipped.png) · [14槽小屏](touch-max-capacity.png)。后两图的48件相同图标来自明确的滚动stress fixture，未向正式内容池加入假道具。

## 实际验证

独立原生软件GL运行原`tools/run_gear_ui_tests.py --capture`，**159检查／0失败、exit0、源码前后一致**：[收据](ui-receipt.json)、[逐项报告](ui-report.json)、[原生日志](ui-native.log)。实际输入覆盖默认直达、选择不装备、图标重复点击高亮、装卸／HP、左右页和旧会话、同帧旧详情装备／购买按钮、失焦、拖动取消点击、gamepad确认、三次真实扩容至14、跨图保留及死亡清理。

同源原Harness选定**10项fresh全部通过**：[报告](harness/report.json)／[原命令](harness/command.json)。core5686、gear107、正式UI155（GL159）、Underworld UI291、Home185、BGM89、canopy50、时间能量140、campaign67，以及原平原8路线与10反例均通过。仅代表选定scope，不代表full144或PR CI通过。

另原UI contract149／0；R2补跑208／0，分别保[contract原日志](ui-contract-native.log)、[R2收据](r2-receipt.json)及[逐项观察](r2-assertions.json)。R2的标题旧假设与布局等待fixture修复源为`11a4216`，只改此测试；运行脚本／场景／资源／采录工具与`bb4bf46`字节一致，未把旧影片或Harness追签新测试源。独立复核见[界面审查](independent-review.md)与[R2入口专项](r2-entry-review.md)。

[正式主游戏27秒连续录屏下载](formal-game.mp4)：标题→Home真实步行→原生出发→正式平原→暂停直达背包／切页→明示宝箱位置fixture→原生领取→选图标→装备／卸下。冻结源`bb4bf46`，34断言／0失败、引擎exit0、源码稳定，1280×720／60fps、原Godot48k双声道音轨。无before对照，非实体性能或听感签字。见[媒体身份](media.json)、[采录收据](movie-receipt.json)、[逐帧轨迹](movie-trace.json)。

## 失败与剩余边界

初轮实际GL126／9失败，原面板移出视口、金币竖排及缺箭头字形已保[旧截图](history/failed-desktop-equipped.png)与[旧日志](history/failed-ui-gl-second.log)。最终根因是事务重建短暂撑大Margin，最小尺寸恢复后实际尺寸仍残留；仅在最终真实minimum能放入viewport时恢复FullRect，不遮蔽实际overflow。独立滚动和旧API跳过disabled容器分别处理。

前轮CI保[原身份及可读annotations](history/previous-ci-summary.json)。本地实际重现plains的动态`equip_sources`调用Array类型错误：[原生日志](history/failed-plains-native.log)；已给动态边界显式`Array[StringName]`。canopy原GOLD自动加HP假设迁移为只入包，原+2／不回血断言保留为明确装备fixture，真实核心能力弹窗仍开着，未伪装为自然菜单换装。原严格退出、断言与预算没有削减。

本轮没有新道具效果／美术。复杂主动／武器／钩索效果、实体安卓／实体手柄、玩家审美／手感与低端性能仍未验。独立[Preview预算](preview-budget.json)仅余1,358,399字节，完整游戏无法追加；没有删除旧入口或把旧网页冒充本轮。Web浏览器触屏与实体设备验收另列，原生软件GL不代签。当前质量review，不合main。

收尾真实失败也保留：首轮Harness因root在运行中更新文档／证据触发原source_guard拒绝，[原报告](history/interrupted-harness-report.json)未追签；冻结全部文件后另跑本轮10项通过。最终采录首次因旧X11显示进程已退出被拒绝，改为同一命令生命周期托管显示服务后新目录重采，未改游戏／采录守门。R2原标题直达关卡旧假设及随后原生hover失败均未放宽指针断言；等待真实布局后208／0，新源独审单列。
