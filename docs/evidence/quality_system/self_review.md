# QUALITY-SYSTEM-01 实现者自检

日期 2026-10-12；实现者和自检者都是本次 Codex 会话。mode=self_review，independent_review=unverified，actual_isolated_skill_invocation=unverified。本报告不是独立 ACCEPT 证据。按仓库 gameplay-reviewer 的检查表阅读代码、模板和差异；未修改正式游戏代码。

| 发现 | 可复现反例/风险 | 处理与验证 |
| --- | --- | --- |
| Q01 | 可选维度 failed 仍可能只按必需维度计算完成 | 所有 failed 门槛/维度阻止完成；test_failed_optional_dimension_prevents_done |
| Q02 | region 的新增动画若标 unverified 可能被类型最小集合忽略 | 内容的非 not_applicable 维度也必须通过；test_optional_content_work_needs_pass_or_explicit_inapplicability |
| Q03 | 自称用户已确认但不绑定原始反馈 | creative decision 必须引用 user/accepted 证据；test_creative_confirmation_requires_linked_user_evidence |
| Q04 | 后续改工具/代码还复用旧完成记录 | PR 对照 reviewed_commit 文件内容；test_diff_guard_rejects_reusing_old_completed_evidence |
| Q05 | small_fix 修改生产路径却声称 formal_impact=false | 差异守卫拒绝该归类；正式 GUI 维度必须有证据 |
| Q06 | 模板演练结果带了不存在的 Region 判据编号 | 对齐实际 R01–R04、B02，反例仍为 4/4/5 项，不降低拒绝条件 |
| Q07 | 新美术强制重复灰盒成本过高 | art 复用已验玩法，G1 可不适用；一旦改操作规则重新归类 |
| Q08 | 无记录运行 require-complete 可能给空集合通过 | CLI 显式非零退出；init 始终未验，无自动 PASS |

真实源代码检查：PlayerMotor、碰撞、资源、Boss、生成算法、正式入口和运行资产相对 da76b0a 没有修改。旧断言、harness 错误检测和全量套件未删除或放宽。项目现状、基线失败、未实现能力和历史流程边界已明确。

限制：文件后缀不证明媒体有效或内容质量；producer/reviewer 字符串不认证人的身份；文本差异守卫无法证明保留断言却改辅助函数的语义等价。必须查原始证据并实际独立审查。基线 Web Parse Error 保留；未在本任务中修 Boss。下一步是真实宿主调用小切片及独立审查，不能将本自检转为独立通过。
