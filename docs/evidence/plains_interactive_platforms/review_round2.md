# D081 第二轮独立严格审查（WIP 快照）

审查者：`d081_strict_review2`。只读 production，独立编写 `/tmp` 诊断脚本；本报告为唯一仓库写入。审查期间根代理继续修复，下面区分发现时状态与已收到的修复，不把 WIP 否决当最终分支状态。

结论：**当前 WIP 不通过“第三阶段要求换台”的玩法门槛。** 四个新模块双向物理遍历与机关独立时钟可接受；固定草台解析断言没有覆盖实际左岸反冲输出反例。未发现 P0。未执行公开网页、完整两图真人体验或本轮美术设备验收。

## 已独立执行的证据

Godot 官方 `4.7.2.stable.official.ed1daf0bf`，全部命令在 `/workspace/gunman-rush`，`--headless --path . --fixed-fps 60`。

| 命令 / 证据 | 结果与边界 |
| --- | --- |
| `bash tools/godot.sh … --script tests/plains_interactive_platforms_runner.gd`；`/tmp/d081-review2-interactive.log` | **102 assertions / 0 failures**。四种新模块、四初相位、双向真实 Motor 遍历与启停通过。退出仍有 ObjectDB/resource/RID 清理警告，不归类为运行 Parse/SCRIPT ERROR，也不掩盖。 |
| `… --script /tmp/d081_review2_shore.gd`；`/tmp/d081-review2-shore2.log` | **第三阶段左岸固定站位输出成立**：Boss HP `12→10`，玩家 `5→5`，两次独立巡回后实际弹体命中，x 范围仅 `260.15..266.05`，没有上任何草台。真实断桥消费者、Boss 弹体与 FrameDamagePolicy 保留。 |
| `… --script /tmp/d081_review2_ferry.gd`；`/tmp/d081-review2-ferry2.log` | 真正射铃启动平台；暂停 60 render 帧，模块/latch/motion 时钟与位置冻结；恢复继续；`cancel_pending` 不重置 carrier 相位；卸载无旧 callback 错误。**没有捕获 accepted pending 与死亡同帧**，日志 `PRE DEATH pending={}`，因此该门槛未验证。 |
| `… --script /tmp/d081_review2_sweep.gd`；`/tmp/d081-review2-sweep.log` | 真实 PlayerProjectile + 友方 Area + 2px 薄墙/目标：无遮挡目标 `3→2`；友方 Area 后有墙时目标仍 `3`；`SWEEP failures=0`。支持最新 stationary overlap / cast 修复，不能替代全 combat 回归。 |

诊断 fixture 只在初始设置实例位置与阶段进入血量；之后通过普通路由跳跃、射击、轴向输入行动，没有回合中搬角色/补血/补资源或修改 Boss 模式。Boss 阶段三反例是在初始 HP12 后自然过场、自然巡回，核心接受的是实际 PlayerProjectile，不是直接调用 direction predicate。

## P1：第三阶段固定左岸反冲可农输出

`WindkeeperEncounter.core_offset()` 第三阶段为 `direction * 84, -140`。返程时 Boss 朝左，到左草台中心约350，铃芯约 `(266,395)`；该位置在保留下来的左岸上方。玩家可一直留在左岸 `(266,582)`：

1. 等返程左墩 `pier_warning` 剩不到0.2秒。
2. 原地普通跳；12 帧时向下空射一次获得反冲高度。
3. 30 帧时向下瞄准铃芯，命中；自然落回同一左岸。
4. 等下一次往返，重复。

日志两次真实命中且不掉血。第一版探针射得太早，在 warning 中射到关闭核心，结果0命中；保留 `/tmp/d081-review2-shore.log`，第二版只修正输入时机，没有修改游戏窗口。

这不证明所有方向都不能通关，也不否定射击反冲本身；它证明当前 `CHANGE SHELF` 提示和“第三阶段逐渐要求换台”的设计尚未由实际空间约束保证。`highest=(640,452-held_jump_height-8)` 的解析测试只排除了中间固定高台一次起跳的部分角度，漏掉了岸边 + 反冲 + 等返程。

建议将返程铃位保持在对应草台上方的实用击铃窗口，或引入可见、实际消费的当前台挑战条件；普通上台/跨台与反冲均应保留。补充真正两处以上桥墩连续输入攻击，以及本反例不能重复有效输出的对照验证。不要靠取消反冲、加二跳、放宽核心或删除测试解决。

## 已反馈并修复的表现 P1

最初 `PlainsInteractiveArt.draw_thorns` 仅 LEFT 使用竖墙刺 source；水平反射生成 RIGHT 后，落入 else，把顶刺横图压成窄竖条，根朝向错误。几何反射测试通过却不能证明视觉正确。已即时反馈根代理；最新源码 RIGHT 使用竖墙刺 source + 水平 canvas 变换，BOTTOM 使用顶刺 source + 竖变换，根床延伸8px进入真实承载面。**代码复核合理，未执行该反射实例的网页截图验收。**

## 其他审查结果与 P2

- `PlatformThornDefinition` 从实际 host 平台索引与面派生危险矩形，左右两格数据明确；`static_dangers` 与渲染读取同一 attachment，优于独立浮刺矩形。当前 raw AI source 区域和透明度已检查；仍应实拍危险格/安全格边缘及 RIGHT 壁面，确认缩放后可辨。
- 正式风铃与目标使用配对图形 + 唯一 LINK 编号；三图形重复不构成歧义，因为编号不同。远门630px分离确实改变位置，不能声称所有门都必须射铃：高台跳过某些门可能是合法旁路，应明确设计意图，不能同时把这条路宣传为强制限时射铃挑战。
- `toggle_ferry` 有独立 `motion_clock` / `motion_running`，不是冻结整个 module.clock；两岸实际 bell 接收器支持返回，阶段快照包含局部相位。静态读取 restore 分支合理；**独立探针没有实际卸载→重建 region 后再乘船**，因此 reload 乘员连续性仍须正式 lifecycle 测试。
- 原第一版 ferry death 检查错误要求 `motion_running==true`，实际上第二发在死亡前已正常停车；false 由诊断断言错误造成，不是发现产品 bug。更正日志清楚显示死亡时没有 pending，不能把“没错”包装成同帧死亡优先验收。
- stationary overlap / cast 修复保留半径、碰撞层和真实薄墙阻挡；独立友方 Area+薄墙反例通过。尚须原子弹高速扫掠、枪口贴墙、多目标、Boss近距离、真实命中返能全回归。
- Boss AI三形态、提示、咆哮粒子、相机 impulse 与过场条幅都有实际消费者，表现不直接提交伤害。技术接入不代表美术风格/形态动作/完整过场趣味已获真人认可。StageCameraRig 的 shake 为局部表现，核心 Motor 未改。
- 运行诊断残留 resource/RID 清理警告应记录并缩小生命周期泄漏；本轮测试不存在 Parse/SCRIPT ERROR。不能用退出码0抹去警告，也不能把该清理问题误报为当前可达性失败。

## 下一轮严格门槛

修复固定左岸反冲输出；保留地面第一阶段真实命中、第二阶段真实上侧命中且地面侧拒绝、第三阶段空中下射拒绝/接受；至少两个实际桥墩的连续换台命中与左右返程。独立执行真实 pending 同帧死亡、地区卸载恢复 carrier 相位及帧内阻挡回归。公开网页演出、附着刺视觉和完整两图趣味仍需分别验收，不以102个局部断言替代。
