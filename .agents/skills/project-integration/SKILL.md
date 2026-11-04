---
name: project-integration
description: 项目归整、冗余清理、分支合并和 Web 交付验证。
---

# project-integration

从仓库根目录执行。先看 AGENTS、docs/current_state.md 最新相关段落、Git 状态与用户授权，再从最新 main 创建独立分支。用户最新指令覆盖历史流程；默认交付 PR，不自动合并。

1. 区分运行代码/资源、当前测试、手动测试、废弃实现。删除前查静态引用、动态加载、manifest、导出、工具和实际消费者；旧命名或不参与 CI 不代表可删。保持游戏资源/UID、许可和用户改动。
2. 开发只运行修改相关专项：`python3 tools/harness.py --list`、`--check ID --plan`、`--check ID`，或直接运行具体 runner。没有隐式 full、影响升级、缓存证明或双 lane。修改 runner 要实际验证非零退出、缺成功标记、脚本错误和超时拒绝。
3. 日常 CI 固定四项，见 [Harness](../../../docs/harness.md)。不要因历史技能/质量卡要求补回全量检查、证据哈希、录像审查或十一维流程卡。不能把未跑的专项写成通过。
4. 正式导出使用 `tools/deliver.py web|windows|android|all`，先安装发布工具链；手动 Release and playtest 工作流提供相同入口。发布与日常 CI 分开，main push 不自动发布。
5. 试玩已有同源 Web 包时复用，通过 `deploy-prepared-playtest.yml` 部署；无包或运行源变化才重建。核对实际 source commit/build id、公开 metadata、完整 PCK 和基本入口，不能用旧站冒充新候选。技术、用户、真机认可分别说明。
6. 合并必须有用户授权，使用普通 merge/受保护 PR，不强推、不绕过红灯。源码分支与纯部署产物分支分开，不批量删远端分支或关闭 PR。
7. 在 tasks/current_state/handoff 更新本次范围、实际验证、删除/保留依据和未完成事项。测试日志留 build/；不为普通工程改动新增证据框架或质量卡。

复杂画面/玩法工作按真实需要做 GUI、录屏或设备验证；不作为无关 CI 工程修改的固定交付。真实交互不能用数值或 Hash 代签，失败不得伪造为通过。
