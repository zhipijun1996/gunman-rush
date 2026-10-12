# D082 独立严格审查，第 6 轮

审查方 `/root/d082_strict_review6`，按 AGENTS 每轮新的独立审查要求执行。生产代码和仓库测试只读，唯一仓库写入为本报告；独立诊断脚本和日志在 `/tmp`。

## 基线裁决：REJECT

基线提交 `17c6ef1b1de0c34aaf83d6002c5b32344ea04237` 修复了已经关门后的高台射击资格，但关门预警仍以旧 Boss 触发矩形检查完整身体。实际最高平台起跳期间越过旧顶部，会取消预警；再次落回触发框后重新开始计时。这使正常入场跳跃延迟或反复重启封场，不符合完整入场后震动、关门的行为。

独立执行 `bash tools/godot.sh --headless --path . --script /tmp/d082_warning_jump.gd`，日志 `/tmp/d082-round6-baseline.log`。正式 `DemoApp.start_plains("d082-warning-jump")`、linked_rings 20 个区域。明确 fixture 出生于真实小 Boss 最高平台 `(800,392)`，等待 3 帧后通过真实 InputRouter held jump 起跳，42 物理帧后：

```
WARNING JUMP closed=false close_count=0 armed=true clock=0.18333333333333
```

fixture 关闭敌方攻击和 Boss 行为以隔离空间消费者，不修改人物 Motor、速度、资源、跳跃高度或碰撞，不声称自然战胜 Boss。命令尾部 `tail` 的 shell 退出码不代表该失败探针通过；脚本明确按 `closed` 输出失败退出。

## 修后独立复测：有限技术 PASS

修后工作区以同一 `BossArenaSeal.containment` 表示实际墙之间的横向范围和墙覆盖的 world bounds 上下各 200 像素。首次 arm 仍要求完整身体进入原触发框并保留左右 24 像素内缩；预警开始后，完整身体的检查使用真实围场范围，已关门射击资格读取相同范围。左右实体墙的尺寸、层级和人物碰撞没有放宽。

独立复跑同一脚本，日志 `/tmp/d082-round6-warning-fixed.log`：

```
WARNING JUMP closed=true close_count=1 armed=true clock=0.65
```

新增独立 `/tmp/d082_review6_side.gd`，日志 `/tmp/d082-round6-side.log`：明确 fixture 出生在实际入口内 `x+42`，已完整进入并开始预警；此后只通过真实 `set_move_axis(-1)` 移动 42 帧。没有瞬移离场或改速度。

```
SIDE_START armed=true closed=false x=42.0
SIDE_EXIT x=-140.0068359375 outside=true closed=false armed=false count=0 layers=0,0
SIDE_PASS=true
```

真实从侧面离开仍取消预警，墙体未关闭，未夹住玩家。此负例不是尝试逃过已经关闭的墙。

另独立复跑第 5 轮的实际上层跳跃/射击与死亡消费者探针 `/tmp/d082_review5_probe.gd`，日志 `/tmp/d082-round6-upper-death.log`，退出 0：

```
APEX core=true local=(763.333, 249.4474) eligible=1 seal=true alive=true
RESULT minimum_y=249.447387695312 above_old_trigger_frames=8 eligible_empty=false
FIX_PASS=true
SIDE_OUTSIDE_REJECT=true SINK_SIDE_REJECT=true
UNSEALED_OLD_TOP_REJECT=true SINK_UNSEALED_REJECT=true
DEATH_SUBMIT=true
DEATH_ACTIVE_FALSE=true DEAD_SHOT_REJECT=true DEAD_SINK_REJECT=true
```

上层真实跳跃/发射继续有资格；明确场外与未封场负例及通过真实 FrameDamagePolicy 的显式死亡 fixture 仍拒绝旧 receiver 和射击登记。死亡 fixture 不冒充自然死亡或自然 Boss 胜利。

独立运行 `bash tools/godot.sh --headless --path . --script tests/plains_cohesion_lifecycle_runner.gd`，日志 `/tmp/d082-round6-lifecycle.log`：退出 0，**19 assertions / 0 failures**。该真实正式消费者回归保留实际墙阻挡后退、暂停重载场内出生、内部环境回退锚点、保证掉落、动画期间不可提前领奖和 mini 原有 12 金币仅支付一次等断言；新增预警期高台跳跃断言通过。

引擎版本 `4.7.2.stable.official.ed1daf0bf`。工作区 Motor、Tuning、Input 的 git diff 为空；实际 SHA256：Motor `d5287d731fd4155250541415a529f70bb2b3818c516c72959c164862b3abe6f6`，Tuning `e5161bb8ef1855b9eda515ab0613a4a738b47abc43b0f2dc118d2e45f71b2058`，Input `4b32d1d2a2ae930d649ed4a02c19833a725b9e8669ec33a9c5393229433ad64e`。

部分退出仍有既有 ObjectDB/resource 在用日志，没有声称日志完全无 error。本轮只审查实际封场几何及相关生命周期回归，不覆盖自然 Boss 战手感、真机或最终公开部署。基线 REJECT 保留，必须使用本次修正重新导出并核验最终公开构建；此前 `17c6` 不作为这项修正的交付证明。
