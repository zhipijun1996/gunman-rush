# 合入前落地尸体保存修复

基线 `10fa5673419f460de05d360a2ea983f00a397ac6`，包含外部 PR104 的 `080ac505`，不是旧内部同名原型。仅修改 `enemy_feedback_01_remains.gd` 与 `plains_region_stage.gd`，新增两个定向回归；原 `tests/enemy_feedback_01_formal.gd` 全文件SHA保持不变，特别第214行原可见性断言未改。

现有 `PlainsRegionState.actors[id]` 增加可选 `presentation_remains`，内部version1保存真实已落地D4的stage-local位置、朝向、稳定支撑身份与support-local接触锚。原容器深拷贝透明保存，不修改顶层schema、HP、Actor、AI、奖励或美术。模块支撑使用Manifest模块名与明确平台/渡船名；地基使用原序列化column矩形；捷径使用原稳定ID，不存自动节点序号或对象引用。

恢复在正式Installer完成后应用；只沿已解析支撑接触锚±2wu验证真实接触。旧档缺字段及坏/未知版本回到原短接触兼容，不向远地面猜位置。已知支撑缺失保真实保存位置与D4，再按原有限坠落规则处理；支撑以弱引用跟随/释放，不延长生命周期。initialize与dispose清表现快照引用，不重播死亡、粒子、音效或掉落。

实际执行均在本专用worktree并source `/workspace/scratch/integration-four-20261023/enemy-save-env.sh`，Godot4.7.2、headless、fixed60、Dummy音频。原 `tools.run_tests.run_engine` 捕获实际退出与脚本/资源泄漏，预算保持120秒（import90秒）：

| 入口 | 结果 |
| --- | --- |
| 原strict `tests/enemy_feedback_01_formal.gd`，修改前 | 66/1、exit1；原214可见性失败 |
| 同一原strict，修改后 | 66/0、exit0 |
| `tests/enemy_corpse_save_integration.gd` | 72/0、exit0；继承完整原strict，另验真实静态平台/移动渡船的保存身份与局部脚锚 |
| `tests/enemy_corpse_snapshot_cases.gd` | 147/0、exit0；两表现链实弹死亡后的JSON往返、坏字段/类型/版本/NaN/溢出/自动节点路径、缺失/释放支撑与不重播 |
| 原 `tests/enemy_feedback_01_support.gd` | 199/0、exit0；原旧档短接触、移动、释放及void边界不放宽 |

复现：`bash tools/godot.sh --headless --fixed-fps 60 --audio-driver Dummy --path . --script <上述入口>`。`strict-before.log`保原失败；`regression-after03.log`含最终66/0和72/0，以及新增回归首版类型推断错误；`boundaries-after04.log`保修正后的147/0与199/0。早期修复验证与诊断日志同目录保留，未抹失败。原formal固定JSON输出会被后续原测试覆盖，修改前证据是保留的原始log，没有回填旧JSON。

两个修复中的发现也保留：Godot `float(1)` 的Array成员检索不等于int成员，且JSON数字会恢复为float，需合法数值比较；移动渡船不能用旧世界坐标当冻结断言，新增检查改为真正支撑局部锚，所有原断言不动。只修任务测试的类型错误，不修改生产断言、timeout或预算。

`source-binding.json`给出精确前后SHA。Stage直接SHA被共享style绑定，总控另做版本化影响审查/显式新绑定，本分支不刷新。未运行完整Integration/Release/GPU；艺术、用户/真机认可、森林及其他覆盖capture_state的候选Stage仍未验。无PR、部署或main合并。
