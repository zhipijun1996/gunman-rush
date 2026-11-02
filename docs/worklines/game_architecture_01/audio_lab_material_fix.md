# AUDIO-LAB-MATERIAL-01：显式受伤试听与怪物材质路由

状态：独立原缺陷修复，`small_fix`，工作流继续 `in_progress`。精确候选的 Reels 原生检查已在两个引擎 lane 限定通过，正式集成仍待验证。质量记录见 [AUDIO-LAB-MATERIAL-01](../../quality/records/AUDIO-LAB-MATERIAL-01.json)。这不是保持行为不变的重构成果。

精确基线为 `2ce4ffa64ef65dd5fba892776eea019c9e2841d4`。七种平原怪物的真实 accepted hurt 经 `PlainsEnemyAudio.hurt` 进入 `GameAudio.play_enemy_material`；原路径播放当前材质 WAV，却绕过 Lab 显式 `enemy_hurt` ABC 候选。原 Reels 使用受支持的 plains_sentry，因此事件标签可以声明 ABC，但实际候选播放计数为零。早期通过的 Reels 报告先于材质路由引入，不能代表此基线通过。

主代理已在同一诊断 C 引擎下运行精确 main 基线的原完整脚本：`checks=126 failures=3`，三项分别为 enemy_hurt A/B/C，退出码 1，133.340010 秒，原预算 180 秒。脚本 SHA256 为 `d64e4d97f90cc6a6735da837776ba743d3173e1ca9c65017cb9820cf6e757850`；引擎 SHA256 为 `c54ecbeb70aa099d3e985b6e3098b84540491c567578b0dce838ca0922f33311`。报告记录 `source_clean_after=true`，integration 恢复到 `691c9316aa5c82bc7e48916138291bf430efbfe8`。这证明原缺陷可复现，不是正式工具链激活或候选通过。

原件归档：[运行报告](../../evidence/game_architecture_02/audio-lab-material-01/baseline/report.json)、[原失败日志](../../evidence/game_architecture_02/audio-lab-material-01/baseline/reels.log)、[只读来源对照](../../evidence/game_architecture_02/audio-lab-material-01/baseline/readonly-report.json)。同目录保留 import、before、checkout、restore 原件；质量卡逐一绑定实际 SHA256。只读报告当时未运行历史基线的限制原文保留，后续精确运行由独立 report.json 记录。没有复制缓存或用户数据。

修复限于现有 `game/presentation/audio/game_audio.gd` 的材质播放边界：显式 `enemy_hurt` audition focus 且非 original profile 时，委托既有候选播放；真实伤害/去重仍由原消费者负责。`tests/audio_director_reels.gd` 保留原 126 检查，追加无 focus、清除 focus、original/selected、反向抑制及 death/land 边界验证。不得用更换怪物 fixture、伪造播放计数或修改候选预期绕过问题。

保留普通游戏与 original 试听的当前材质 WAV、正式选择、既有随机/资源/伤害规则、声部池/优先级，以及 owner、暂停和清理守门；不重新生成或替换任何美术/音频。共享 GameAudio 的正式消费者仍须回归，因此质量卡声明 formal_impact=true，含义是回归责任而非正式音效改版。

当前测试源为基点 `59a6e46e88750d2afc719a3c35b8346a69a04431` 加未提交候选，不是仅该 commit 的原字节：

| 文件 | 候选 SHA256 |
| --- | --- |
| game/presentation/audio/game_audio.gd | `79bd8fc3aacad831947f1035d40930b35e91ba5c03cbfbad4ef09a1f25a27235` |
| tests/audio_director_reels.gd | `93f93e1123c5f7ab650a3b69cbe8f67294ba00df39f33e4f7a0549f602270a11` |

同一候选保留原 126 项检查，追加 28 项材质/试听边界验证。诊断 C 实际 `154/0`、116.478/180 秒；实际 optimized editor lane `154/0`、32.176/180 秒。两次退出码均为 0，没有 strict exit error，前后 1905 项源清单一致。见[诊断 C 报告](../../evidence/game_architecture_02/audio-lab-material-01/native/report.json)与[optimized 报告](../../evidence/game_architecture_02/audio-lab-material-01/optimized/report.json)，各目录同时归档日志、candidate 和 source-before/after 原件。optimized 的 [report.raw.json](../../evidence/game_architecture_02/audio-lab-material-01/optimized/report.raw.json) 保留原 runner 复制来的旧 scope 文字；report.json 只澄清实际 lane 范围，命令、SHA、日志及结果不变。这里不以耗时对比签整体性能优化。

[静态独审原件](../../evidence/game_architecture_02/audio-lab-material-01/review/audio-lab-material-independent-review.json)和[测试变更理由](../../evidence/game_architecture_02/audio-lab-material-01/review/audio-lab-material-test-change-justification.json)保留审查当时 native pending 的文字，不用后来结果重写历史报告。[fresh native 绑定独审](../../evidence/game_architecture_02/audio-lab-material-01/review/audio-lab-material-native-independent-binding.json)已限定接受精确两文件与两次 154 结果。1905 项只覆盖运行器列出的文本/资源扩展及根，不是全部媒体、导入或导出闭包。该独审还记录 optimized editor 的生命周期 28、原 upstream、PREDELETE 与 4 个负例；这些结果属于独立引擎范围，本卡不据此签正式游戏、完整工具链或其他音频套件通过。

待验证：候选最终提交、原材质/owner/其他音频套件与完整正式消费者回归。GUI 听音、玩家/设备验收、完整 Harness/full182、最终导出与工具链整体激活均未由本卡验证，不继承其他批次结果。回退应撤回本独立修复的 GameAudio 与新增测试 hunk，保留基线失败与证据；具体可回退提交须在候选提交后由主代理填写，不将整仓回退至历史 2ce。


## 补充的优化编辑器原生预检

实际优化编辑器 eeaec2b6 上，原严格 import90秒/正式120秒诊断入口分别8.190秒及10.044秒通过，原正式191/0且退出干净；原AudioDirectorV2 66/0，19.826秒/180秒通过。原命令、原断言和失败保持，原生日志与报告见本任务证据下 `optimized-formal-v2/`。这是同一候选两源码SHA的额外单lane预检，不是主Harness完整182、模板激活或GUI通过；质量卡较早的154限定接受不扩大签署范围。
