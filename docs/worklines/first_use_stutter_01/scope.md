# FIRST-USE-STUTTER-01

状态：in_progress。用户报告 Chrome 首次空中射击卡、第二次不再卡，敌战仍部分卡。工作基点 `23ba7a79bbfca7f0f1662088f611911dbfd0725b`；第一批采用已通过冷启动 GL 验证的 Focus V3；敌战仍有未归因时间，不签整体消卡。

范围仅现有 `game/presentation/ui/focus_vignette.gd` 与既有 `tests/grapple_focus_hud_runner.gd` 中必要的最小测试候选；测试候选保持原完整 runner 与预算，实际执行仍待。保输入、物理、碰撞、伤害、资源、奖励、RNG、存档、图声和原预算。不用预演射击或改变游戏状态假装预热，不先把持续卡顿归因给首次编译。

已有事实：原首次 air 出现 Focus edge_width shader 编译，重复为零。V2 虽在 Home 编译2/link1，首次真实 air 仍编译2/link1，原 LINK_STATUS 等待47.285ms，**实际REJECT**，未达零新增编译门槛。基线15.735ms与候选47.285ms为不同页面/新进程单次测量，不能量化改善或回归；也不能解释整段掉帧。

敌战只有一次30秒插桩观测：4发pulse、3次命中、1次击杀，charger HP3→2→1→0，玩家HP5。首次命中间隔225.030ms，死亡61.405ms，未复现特殊死亡帧尖峰。CPU方法为含子调用全局批次，不可相加或归到单只敌人；无GPU计时、无未插桩配对，云端SwiftShader不是用户手机FPS。全部地面射击，不冒充空中证据。

下一步仅依据真实首次提交变体收敛Focus候选，复核原首次air零compile/link、启动代价、无可见闪烁与生命周期；敌战按实际热点继续有界归因，不放规则或预算。上轮COMBAT通过/公开包不代签本任务。

原证据外部保留（未改签）：

- `/workspace/refactor-evidence/first-use-stutter-01/focus-candidate/browser-ab/summary.json`，SHA256 `0f0029f958859e7e2db1aef2210b5fd3d6581b15316635181a8d4ca2618e03dc`：V2 REJECT及原始计时/限定结论。
- `/workspace/refactor-evidence/first-use-stutter-01/first-enemy-capture/summary.json`，SHA256 `2de22a05c815a3ed39b2c59e9f09dd8e18dd4ae519fab8e1e5d56ab238242124`：4pulse/3hit/1kill实际诊断。
- `/workspace/refactor-evidence/first-use-stutter-01/observations-01/facts-and-next.md`：有限事实/待办索引。

实验派生自公开运行源F60f44；Focus包52f83e4c96d1、CPU插桩包527508c4472b均不是未改公开包506a4e40a1ee。所有旧失败与成功原件保留；未签修复、全CI、真机或玩家认可。质量卡reviewed_commit仅已知基点占位，最终production_snapshot须走原工具实际绑定，不在调查时制造验收。

本批进一步验证共享 `game/presentation/rendering/canvas_shader_preparation.gd`，两个真实消费者为 FocusVignette 与 UnderworldPresentation。后者仅在已有世界表现就绪时提交离屏有灯／无灯三角和线段，覆盖已证首枪 Canvas 变体编译；不触发射击、伤害、声音、游戏对象或随机调用。需单独实际验证，不以 Focus V3 结果签首枪或首次命中卡顿已解决。权威元数据只技术重绑 world_presentation 一叶，旧版本与原测试断言／预算全部保留。
