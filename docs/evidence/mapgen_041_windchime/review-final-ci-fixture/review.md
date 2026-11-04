# CI输入磁盘诊断与音频池夹具独审

审查者 `/root/final_ci_fixture_review`，只读审查；未改被审源码、未运行 Godot/浏览器，未 stage/commit。

接受本轮磁盘统计/不足早拒绝和当前音频夹具实施。完整 CI 就绪状态仍因 `CI-WINDCHIME-PROFILE-TAIL-01` 拒绝：独跑 selector54 项有4失败，必须修正新windchime尾对历史去尾重放的影响后重验。该失败不改变原旧run的身份，也不允许删原检查。

## 实际验证

- 输入45项通过（7.534秒）；工作流4项通过（0.007秒）。
- 原178有序前缀及所有原check字段逐项核实；唯一旧M35差异为补真实restore fixture输入。新增1项windchime，gameplay同样追加；原Harness字节不变。新wrapper沿单一240秒总截止时间递减，三消费者不能各自再获240秒。
- 独立静态/捕获241项检查通过，原音频41个静态check表达式（不是先前口头39）逐字节顺序保留，原6个cases.append及pool_case外函数逐字节保留。GameAudio、ForestBibleAmbience、原wrapper和音频资产保持原生产字节。
- 根因对照：旧capture93/0的实际hold_wall_ms为0.111。create_timer(0.05)在fixed-fps下仅50毫秒模拟时间，不能称50毫秒墙钟；旧结果保持原身份。指出后root仅在test改用Time.get_ticks_usec单调墙钟循环并追加>=50断言。
- 已读root新原始report/capture/native.log：94/0，实际hold_wall_ms50.005，9.2688秒，source_stable=true/严格退出清理。其37项source SHA全部与当前文件独立匹配。12个真实playing+has_stream_playback、原codec payload与loop设置不变、13th拒绝不计数、释放一个slot后原note被接受且复用同一voice均有实际原件。`wall-hold-recheck.json`保存新原件路径与SHA。审查者没有将此复核称作自己运行Godot。

## 不降标分析

夹具只让本测试实例缓存中的原导入payload副本loop，不写磁盘或生产共享流。真实GameAudio.play、12voice上限、cue tags/counts、释放slot复用和清理都仍由生产实现执行。若cap变成13、永远拒绝note、篡改原payload、替换已占voice或错误计数，保留/新增断言会失败。其他pause/event/selective-stop/actor-release场景仍走全新正式fixture。

磁盘新增逻辑在新tar/stage写入前记录实际目标volume/free/required logical bytes，确定低于所需逻辑字节则明确失败并保原输入/归档。PAX长UTF8路径和10240记录填充实测计入；restore逐成员完整验证stage并hardlink发布，没有第三份完整物化。manifest/文件系统metadata/并发需求明确不在“足够”承诺内，真实4.43GB工件与最终CI仍须实跑。

## 未通过项

selector原54项的4个失败保存在 `selector-independent.log`，属于增加新consumer后的历史fixture迁移，不是已证实产品求解/场景故障。最小建议沿既有 `prior_profile_tail` 增加显式windchime外层重放，并新增当前179/sourceconsumer正反守门；不能删旧方法、改原budget或只改总数。最终精确head完整179和affected、实际大包资源峰值、浏览器与玩家/真机认可均未代签。
