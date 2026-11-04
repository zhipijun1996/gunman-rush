# 项目管理

GitHub 保存代码与审阅， [任务索引](tasks.md) 保存任务ID、依赖、当前状态和工作线入口。Issue／PR链接放对应工作线，任务负责人及写集按 [协作规则](cloud_production.md) 管理。

状态采用 planned → ready → in_progress → review → done；必要依赖阻塞用 blocked，缺实体设备验证用 awaiting-device。代码合入和内容质量分别记录，已合入任务仍可能等待体验验收。

main保存基线；开发使用feature／fix／docs／chore主题分支和PR。PR说明行为变化、实际验证、未验范围。合并与发布按本次用户授权执行，保护远端新增提交与用户工作区。

工具链来自 `config/toolchain.json`，日常CI由`tools/ci.py`四项检查定义，开发专项通过 [Harness](harness.md) 显式选择。产物写 `build/`；许可与素材来源随实际资产维护。代码许可尚未由用户指定。
