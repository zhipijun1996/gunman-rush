# AUDIO-MERGE-120-121

用户原话：“受伤选用A，连同pr120一起合并到main”。此授权覆盖此前两条开发线“不自动合main”的阶段限制，无需再次询问。

从实际main5f55716a整合PR120 head11f910f0与PR121 head2f3a5d9e，保双方完整历史。两者游戏代码无交叉；仅current_state/tasks有内容冲突，保留双方块，handoff正常合并。PR120 foreground、原严格formal+cache等价runner、prepared部署校验及其证据逐字保留；PR121音频修复/声源/五BGM/声池/物理与交易逐字保留。

受伤正式采用已试听的hurt_feedback_06_a / audio-feedback-06-v1。新增逐字用户选择与manifest/WAV完整SHA账本，SelectedSfxRuntime读取并pin该选择；默认实际声音不改变，显式B/C试听仍可用。brief自动读取最新选择，不把已选A继续标未选；原14项V3选择、旧C/05拒绝原件及所有已发布包身份不回写。

root仅拥有合并冲突文档、选择账本、SelectedSfxRuntime最小读取、brief上下文、对应专项增量、AGENTS最新授权、任务/质量/本轮证据及收口。独立审查只读组合差异，Godot/WASM/导出仍root单租约。原165前缀+audio-feedback=166、两lane和affected聚合守门、预算与所有旧失败保留；源码冻结后完整实际CI通过才普通合入，不强推或绕过红灯。若PR120因其head已完整进入main而自动标merged，复核Git祖先及两PR实际状态，不重复合入。

这次批准仅签确切受伤A和两PR合并，不推导B/C、全系统审美、整体FPS、实体设备或长自然路线通过。正式main自动部署结果按实际workflow/包指纹另记，不用旧试听包冒充合并成果。
