# 钩索瞄准输入验证

本目录为 FOREST-GRAPPLE-02 的本地输入专项原件。`results.json` 保存退出码、断言数和运行后依赖 SHA256；该工作树快照不是最终发布身份。

`grapple_aim_input04.log`：原完整 input_tests 保留，额外经真实适配器→InputRouter→PlayerController 检查枪械、PC 钩索、LB 钩索、触屏钩索均请求 15% 慢时；检查取消、真实暂停、设备切换、双持枪/钩输入、E+右键聚合、中心回退、未解锁能力不抢输入和无幽灵射击。113 项通过。

`grapple_actor_actions01.log`：原共享动作运行器 2872 项通过，原 180 秒预算未改。既有 LB 即按即放的旧断言随明确新控制合同改为按住瞄准无事件，并保留松开恰好一次钩索且无主武器事件。

首轮 `grapple_aim_input01.log` 的 1 失败保留：实际 Controller 推进后身体移动，鼠标固定世界点的真实方向变化，原期望仍要求初始化角度。后续期望使用释放瞬间实际坐标；没有改玩家物理或缩小断言要求。02 包含重复原 AirFocus 世界/弹体比例 0.138，位于原 0.02 容差内；不冒称恰为 0.150。父任务另有原 AirFocus 专项。

重放：`GUNMAN_TOOLCHAIN_ROOT=/workspace/toolchains timeout 90 flock build/verification/engine.lock bash tools/godot.sh --headless --path . --script res://tests/grapple_aim_input_runner.gd`。原动作：同工具链 `timeout 180 flock build/verification/engine.lock bash tools/godot.sh --headless --path . --max-fps 120 --script tests/actor_actions_runner.gd`。

这是逻辑/物理输入验证，不是手感、实际硬件、趣味或商业品质认可。完整 CI、最终同源性与发布验证由主任务记录。
