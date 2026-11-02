# MAIN-REFACTOR-MERGE-01

用户明确“合入main”，授权合入当前refactor/game-architecture-02的累积架构与性能实现；覆盖此前开发阶段“不自动合main”。起点35881a6e9d223a33981f7dd9ca51bffbbfe50543，main精确2ce4ffa64ef65dd5fba892776eea019c9e2841d4为祖先，108提交；main已含PR122/124，PR123关闭且不作为本轮底座，纯prepared部署分支不合入。

原Integration计划为full171/full_lanes。只沿原PR Production impact执行精确head：prepare、parallel/serial两物理通道和affected完整合流；必须成功且head不漂移才普通merge，不强推/绕过保护，不删断言或放预算。现有60f44fc1的171与10dcd39a的公开包只作原来源，不冒充最终新head完整CI。失败保留，若出现问题先定位原runner，只修实际失败并复验。

本轮默认只改合入任务/质量/交接说明，不改变生产/图声/玩法/保存/RNG。手机Chrome死亡帧时、玩家手感和完整内容G5继续未验，不因Git合入改签。main合入自动Godot core/平台构建和Pages按实际状态报告，不以排队当成功。

恢复先用`gh pr view refactor/game-architecture-02 --repo zhipijun1996/gunman-rush`和`git ls-remote origin refs/heads/main`核实际结果，PR已merged则不要重复合入。合并SHA由GitHub实际生成，精确PR/run/head/结果以Actions与Git记录为准；本文件是冻结CI前写入的执行合同，不能将旧阶段措辞当新的禁止合入。
