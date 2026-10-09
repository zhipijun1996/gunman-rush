# 项目管理

GitHub 是代码、任务和审阅入口。docs/tasks.md 是跨会话执行索引；Issue 保存任务讨论与验收，编号回填索引。

状态：planned → ready → in_progress → review → done；外部依赖用 blocked，真机项用 awaiting-device。任务需一个负责人、前置依赖、交付物和验收；并发只针对互不依赖工作。

main 保存基线；分支 docs/*、feature/*、fix/*。每个 PR 对应可审阅的行为变化，描述结果、验证、未验证项。禁止 force push 和直接覆盖用户改动。初始化空仓库可直接建立 main；后续默认 PR，不自动合并。

里程碑使用 M0–M5；当前能力允许建 Issue/PR，未配置原生 Projects 看板、branch protection 或自动合并。阶段表是当前管理视图，不声称已设置 GitHub 原生 milestone。后续如工具支持可迁移。

CI 初期只检查文档；M1 接入引擎解析与物理测试，M2 接 Android debug 构建。CI 使用最小 contents:read，固定依赖版本；生成 APK 作为 artifact 不提交 Git。

发版需版本号、commit、工具链、验收报告、APK hash、已知限制；真机与授权检查完整后才提出发布。仓库 public：不放家庭、医疗、个人会话或密钥。

所有代码许可当前待用户决定；不擅自添加开源许可证。依赖与生成素材授权分别追踪。
