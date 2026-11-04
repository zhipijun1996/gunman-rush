# 项目管理

GitHub 保存代码与审阅， [任务索引](tasks.md) 只展示当前议题及下一动作；[归档任务](archive/tasks.md) 保留旧 ID、依赖、验收状态和证据入口。Issue／PR链接放对应工作线，任务负责人及写集按 [协作规则](cloud_production.md) 管理。

状态采用 planned → ready → in_progress → review → done；必要依赖阻塞用 blocked，缺实体设备验证用 awaiting-device。代码合入和内容质量分别记录，已合入任务仍可能等待体验验收。活跃视图“本轮工作”标出当前 PR 范围，状态明确在做或待审；待验收／待决定／待排期不自动执行。旧架构撤销、被新方案替代或多轮迭代结束时退出活跃表，验收缺口归并到一个明确当前议题，保留原状态，不用归档冒充完成。

main保存基线；开发使用feature／fix／docs／chore主题分支和PR。PR说明行为变化、实际验证、未验范围。合并与发布按本次用户授权执行，保护远端新增提交与用户工作区。

工具链来自 `config/toolchain.json`，日常CI由`tools/ci.py`四项检查定义，开发专项通过 [Harness](harness.md) 显式选择。产物写 `build/`；许可与素材来源随实际资产维护。代码许可尚未由用户指定。

文档职责、当前设计圣经、原始来源与专项报告的分类见 [项目结构](project_structure.md)。设计规则维护在主题正文，任务进度维护在工作线，已执行证据不改签。
