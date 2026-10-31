# RUN-GEAR-MERGE-04：PR110 合入守门

用户已明确“合入到main”，授权当前背包／齿轮／暂停分页工作线正常merge；此前不合并边界是开发阶段快照。先核[PR110](https://github.com/zhipijun1996/gunman-rush/pull/110)实际状态与最新精确head；若已merged则核main和自动构建，不重复合并。技术合入不代签实体设备／用户G5。

原完整CI [40316936625](https://github.com/zhipijun1996/gunman-rush/actions/runs/40316936625) 源`5618462`：prepare成功、serial55项全部成功；parallel66通过后在`creative-direction-tests`失败，余22项未执行。整轮失败，不能用已过的局部通道或原本地专项签成完整通过。[原机器状态](previous-ci-state.json)、[失败原phase报告](failed-parallel-report.json)、[原失败check日志](failed-ci-creative.log)。

实际失败是`test_selected_direction_binds_every_specialist_and_retains_stage_gates`仍精确期望creative-v16，而本轮原技术绑定已产生creative-v17，当前两区域和registry确为17。修复提交`fae1799c869feb891f01afd5a912ab1b0fde3594`只改这一个精确字面量为v17；保所有历史字节／权威拒绝、G2／content／禁止正式开放断言，不改生产／工具／资源或降低预算，不生成美术。

本地明确物化原知识ledger及历史引用后，用原10tests实际重现1失败：[原失败](creative-before.log)。修复后原Harness单项fresh通过：[phase报告](creative-harness-report.json)、[原10tests日志](creative-after.log)。不同只读作者再独立执行原10tests，10／0、exit0、1.128秒，11个相关源前后稳定，实际加载两区archive-v16仍被拒绝；原v16归档字节等于前驱main。见[独审](independent-review.md)、[机器审查](review.json)、[原执行收据](independent-receipt.json)。局部验证不替代修复后完整CI。

下一动作：同一PR推送当前测试／证据小修，等待最新同head的prepare、两full通道与affected全部通过，使用固定head和普通merge合入；不强推、admin绕过或把旧源通过追签新源。游戏运行源仍`bb4bf46`，R2入口测试源11a4216；本修只有测试版本行变化。网页是否更新以合并后自动Godot／Pages实际结果为准。
