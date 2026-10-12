# D082 独立严格审查，第 2 轮

审查方：`/root/d082_strict_review2`。审查对象：`feature/plains-cohesion-and-pressure` 未提交工作区。仅审查；未修改实现或仓库测试。临时探针放在 `/tmp`。独立于第 1 轮，未以父代理的通过声明替代验证。

## 裁决

**初始快照否决；已指出的问题修正后，本轮有限技术复核通过。仍需下一轮针对最终实现、正式封门回退/重载、掉落表现及实际导出画面审查，不能据此声明视觉品质或趣味性获得用户认可。**

## 发现及处理

1. **P0，正式生成无法加载新增模块。** `RandomStageGenerator.definition_for` 先检查 catalog；初始 `EXPLORATION_CATALOG` 未注册 `plains_thorn_slalom` 和 `plains_remote_sequence`。独立探针得到 null，随后 `_connection_actions` 在 `definition` 中对 null 调用 duplicate；未产生完成摘要。初始日志 `/tmp/d082_review_module.log`。父代理补注册后，实际双向轨迹通过。不能只以 `.tres` 文件存在推断正式消费者可用。
2. **P1，手动出口确认可以提前暂停死亡表现。** 初始 `reward_ready_at` 仅保护 `_damage_resolved` 自动提示，`_offer_generated_exit` 本身无保护。直接/手动请求可能在掉落落地前暂停。父代理已把检查加到实际出口消费者；检查应排在 `_can_interact` 的有效性拒绝后，避免陈旧回调对 freed/null stage 取 clock。本轮已向父代理发送这一补充修正要求。
3. **P1，新的连贯地形边缘未覆盖真实支撑和 Boss 破地。** 初始 `PlainsGroundSupports._draw` 只画内填充；`WindkeeperArena._break_ground` 仅清旧 `ground_surface_regions[0]`，未更新新外露面。新增 `configure_edges(modules)` 已接入支撑实际 `_draw`，正式 assembler 调用它；Boss 破地也重新计算 union surfaces / column faces。代码复核确认实际消费者接入，仍应以正式画面验证边缘/下层不是矩形拼块。
4. **P2，新增顺序门镜像数据遗漏。** 初始 planner 只反射主门/主铃，`sequence_gate` 原样记录。父代理已反射该矩形 x。当前正式模板不镜像此模块，但共享消费者不能保留错误的端口/机关契约。
5. **测试中间状态与探针错误均保留。** 在父代理同步编辑期间，一个运行遇到 `waiter` 未声明；当前已修正。审查探针第一版未初始化移动危险前帧位置，造成 Dictionary 缺键，修正探针后才判定可达。第一版 Home 慢时测试使用错误设备名 `keyboard`，正确契约为 `keyboard_mouse`，修正后通过；这些不算最终生产失败，也不隐瞒为一次全通过。

## 独立执行结果

Godot `4.7.2.stable.official.ed1daf0bf`，固定 60 FPS，真实 PlayerMotor / 实体碰撞 / 实际弹体；仅每个独立模块/场地 fixture 初始出生，不在途中改位置、补血或补射击次数。

- `bash tools/godot.sh --headless --fixed-fps 60 --path . --script /tmp/d082_review_module.gd`：最终 `/tmp/d082_review_module5.log`，**36 assertions / 0 failures**。两个新增模块；齿轮 initial_phase 分别 0、0.25、0.5、0.75；每相位正反向；真实 24×36 身体静态及齿轮扫掠无损，真实远程顺序射击/爬升/落地完成。最早 probe 不通过，不使用重新抽种子规避失败。
- `/tmp/d082_review_lifecycle.gd`：最终 `/tmp/d082_review_lifecycle2.log`，**11 assertions / 0 failures**。家园真实跳跃、实际创建玩家弹体、空中瞄准慢时、开面板取消慢时及 touch adapter。Boss 全身体入场后关闭 layer=1 墙，实际连续向左走 120 帧被阻挡；release 后实际走出；restore_closed 恢复实体；lifetime 失效解除墙。此为隔离实际碰撞消费者，不冒充正式地图完整探索。
- `tests/plains_region_boss_runner.gd`：`/tmp/d082_review_boss.log`，**22 assertions / 0 failures**。正式小 Boss → 第二图；三阶段后真实安全奖励位置、原保证金奖唯一结算、回家记录地区完成和开发边界；同帧玩家致死优先，不产生金奖/地区完成。这是明确 outcome fixture，不冒充玩家自然击败 Boss。

日志仍有既有 ObjectDB/resources/RID 退出告警；隔离生命周期 probe 还出现继承的 windkeeper.tscn ext_resource 加载消息。不能称日志无错误；完成断言与该已知导入消息分别报告。最终导出必须独立检查。

## 下一轮必须关注

- 正式 Boss 封门后的环境段回退、第三阶段破地安全锚点，以及暂停/卸载/加载后玩家真实出生在围栏内；不能只有 standalone seal.restore_closed 测试。
- 怪物飞落时不能提前领取，拾取后收拢消失；已领取/未领取重载不重复抽奖、不刷币。Boss 爆炸及真实保证奖励箱应有清晰内容提示，保留原 mini +12 coins/+1 HP、最终 GOLD 唯一结算；不为视觉箱添加第二笔奖励。
- 最终普通浏览器输入查看 Home 共用摇杆/射击、封门震动、远距配对线索、正式新地形内填充/外边/根系和上下层背景。代码使用 AI atlas 或 world-anchored sampling 本身不能证明画面统一。
- 危险密度用正式种子分布和实际被限制的移动窗口衡量；不能只增加 recipe 名称或危险计数。保留安全教学/营地、绕路选择、基础一跳和两发契约。
