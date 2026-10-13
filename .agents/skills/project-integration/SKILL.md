---
name: project-integration
description: 项目归整、冗余清理、分支合并和 Web 交付验证。
---

# project-integration

所有命令从仓库根目录运行。现行规则见 [AGENTS](../../../AGENTS.md) 与 [当前状态](../../../docs/current_state.md)；数值和玩法不在 skill 中重复定义。

1. 检查 Git 状态、分支 ancestry、当前交接、CI 和用户授权。最新分支按实际提交时间与累积内容判断，不能只按 PR 编号。确认 main 是否已包含，防止重复整合。
2. 分别识别现行规范、历史说明、运行资源、回归消费者和可重建产物；按 docs/project_structure.md 归整。删除候选必须查代码/场景/Resource/config、动态加载、manifest、工具、文档和许可。无静态引用不是可删结论。
3. 优先收敛当前入口、归档历史段落与修链接，保持稳定 res:// 路径/UID。不要因旧命名删除仍有消费者的 Lab、回归测试、母版或失败证据。不批量删除远端分支/关闭 PR。
4. harness --plan 明确检查；文档整理 docs，工具/运行/构建按影响选 profile，未知 full。改 runner 必须验证非零退出、缺成功标记与超时，不能假通过。
5. 合并前核对目标 SHA 与验证来源，保留冲突解决和未知项。已授权合并则使用普通 merge/受保护 PR 流程，不强推或绕过保护；未授权则交付可审查 PR。
6. Web 使用现有 build/check_bundle，缓存和弱网测试保留实际条件；检查提交与线上构建指纹、许可证、存档和冷暖缓存。合并 main 会触发现有 Pages 工作流，报告实际状态，不把排队当发布成功。
7. 更新当前状态、任务、交接和证据，说明实际清理了什么、保留什么及原因。

交付物：可审查结构变更、删除/保留依据、合并/构建结果与继续命令。

质量状态统一使用 [game-quality-gate](../game-quality-gate/SKILL.md) 与 [总流程](../../../docs/development_quality.md)。纯整理用 process 类型，不能用它隐藏运行文件修改；Git 交付不代表内容/设备验收。
