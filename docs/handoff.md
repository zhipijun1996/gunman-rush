# 会话交接

2026-10-09：完成空仓库关联与 M0 设计/管理基线。游戏、引擎运行、自动物理测试、APK 与真机均未验证。

下一任务 ENV-01：先读 AGENTS.md、environment.md、tasks.md。安装/核实固定工具链，然后 CORE-01；缺少网络或工具时记录阻塞并完成独立准备。

继续指令：
> 按 AGENTS.md 和 docs/tasks.md 从第一个依赖满足的任务继续。小步实现、执行验证、记录证据、推送分支并创建 PR。真机项保持待验证；不要自动合并或更改确定玩法。结束前更新本交接。

Git 分支与提交以 `git status -sb`、`git log -1` 为准；不要依赖文档里会过期的静态 SHA。

## M0 验证与关联结果

- 25 个基线文件已同步 main，10 个开发 Issues 已建立并回填任务清单。
- 本地 `python3 tools/check_docs.py` 与 `git diff --check` 退出码 0。
- GitHub Documentation workflow 已成功：[运行记录](https://github.com/zhipijun1996/gunman-rush/actions/runs/37896406132)，对应提交 639c55ce37c6ac22ebc3333ae8845e28e933742b。
- 当前 Git CLI 可 clone/fetch，但 push 缺少凭据；远程写入已使用授权 GitHub 连接完成。不得在源码保存 token。
- 当前未设置原生 Projects、milestone、保护规则；任务管理由 Issues 与 docs/tasks.md 实现。

2026-10-09 架构补强：增加整体风格、能力组件、地图组件、敌人/Boss 四份契约；默认调参改为 max_jumps 与 jump_speeds 数组。尚无游戏实现，所有新增运行验收未验证。


## 2026-10-10 平原 demo 美术交付

分支 `feature/demo-plains-art`，基于 main `64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226`。通过 GitHub 连接器提交，远程最新 SHA 以分支为准；本地通过文件快照恢复，local git 历史不同，不可直接强推。91 件运行候选（89 SVG + 手绘平台、锯轮 PNG）、两张参考母版、角色六类程序动作、资源清单、随机视觉预览与同步监控脚本已制作。角色手绘清理候选因残留 halo 拒绝运行使用，记录保留。

验证：build_art_catalog、check_art、check_docs、node --check 预览 JS 均退出 0；Godot 4.6.3 角色六动作/四方向与地形栅格接缝检查通过，但仓库目标 4.7.2 未验证。Inkscape 合屏渲染退出 0；Chromium 交互检查因 sandbox socket 权限失败，额外权限重试被中止，未验证浏览器交互。真机可读性/性能、玩法分支集成尚未完成，ART-01 保持 awaiting-device。

入口：docs/demo_art_route.md、assets/manifest.json、preview/index.html。后续：用户指定另一个 Codex 分支后重新读取该分支 AGENTS/表现接口，适配场景并完成 Godot 4.7.2 与 Android 验收；不得修改碰撞与物理来迁就图片。同步脚本有限次数 fetch，无后台无限运行或自动合并。
