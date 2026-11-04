# CI 与专项测试

日常 CI 固定 **4 项检查**，由 [production.yml](../.github/workflows/production.yml) 和 [tools/ci.py](../tools/ci.py) 定义。PR、main push 和手动运行使用同一套命令，目标 2–5 分钟，整个 Actions job 硬限 5 分钟。没有路径过滤、影响升级、full、双通道或历史证据恢复。

| 检查 | 内容 |
| --- | --- |
| project | 主场景、当前运行依赖、JSON 配置、非运行目录导入隔离 |
| import | 锁定 Godot 编辑器导入；脚本/Shader 错误、非零退出、超时失败 |
| smoke | 从 project.godot 主场景进入家园，正常 Explore 启动正式平原，验证玩家/控制器/存活并返回家园；运行错误和退出泄漏失败 |
| contracts | 原 input、variable_jump、resource、damage、economy 测试，以及原 meta_notes_save 存档测试；断言、成功标记、退出、超时严格校验 |

```sh
python3 tools/setup_environment.py --engine-only
python3 tools/ci.py
# 修改相关部分时，显式选其中一项；smoke/contracts 首次运行前先 import。
python3 tools/ci.py --check import --check smoke
```

日常只安装锁定编辑器，不安装导出模板、Android SDK、Node、ffmpeg 或媒体依赖。冷导入时 Godot 在字体导入前可能输出 project font 缺失；随后真实启动必须无引擎错误。没有把历史质量卡、证据 hash、录像审查或完整路线藏在上述四项下。

## 开发专项

保留的游戏测试与手动工具见 [测试取舍](ci-test-inventory.md)。开发者选择与改动相关的测试，不要求 docs/full 或额外质量卡。运行结果只说明实际执行的范围。

```sh
python3 tools/harness.py --list
python3 tools/harness.py --check core --plan
python3 tools/harness.py --check core
# 也可以直接执行具体 wrapper 或 Godot runner。
python3 tests/test_harness.py
```

Harness 不带参数只列命令；不自动选范围。`--check` 可重复，顺序执行且首个失败终止。只记录本地日志和简短结果；旧 `--profile/--reuse/--jobs/--lane/--verify-lanes/--mission` 已撤销。原游戏测试、历史 fixtures、录像与美术审查源码保留用于专项，不要求日常 CI 重放。与已删除架构绑定的旧 Python 流程断言不属于当前门禁。

## 发布和试玩

[environment.yml](../.github/workflows/environment.yml) 仅手动触发，选择 Web、Windows、Android 或 Windows+Web；使用 `tools/deliver.py` 先运行四项 CI，再准备当前 Foundry 并导出选定平台。导出包检查和许可复制继续由原 `build.py/check_web_bundle.py` 负责。勾选 `deploy_playtest` 才更新 Pages，main push 不再自动导出或部署。

已有 Web 包继续通过 [deploy-prepared-playtest.yml](../.github/workflows/deploy-prepared-playtest.yml) 部署，不重跑完整测试。引擎构建工作流仍是手动工具。无需为纯 CI 修改发布新游戏版本。

```sh
bash tools/cloud_setup.sh --godot-only  # 发布需编辑器和导出模板
python3 tools/deliver.py web
python3 tools/deliver.py all --plan
```

## GitHub 必需检查

仅把 **`affected`** 配为 required status check。它是唯一日常 job，保留原 PR 汇总名称；四项验证在这个 job 内直接执行。没有 `paths` 过滤或条件跳过，也没有可能被 skip 的依赖汇总。失败/超时会有明确结论。

撤销旧 `prepare`、`checks (parallel/serial)`、`core_checks (parallel/serial)`、`core`、`windows`、`web`、`docs`、`art` 等必需 context。不要把手动发布/部署 job 设为必需项。仓库管理权限和 GitHub App 的 Administration API 权限不同；迁移时应实际读取分支保护验证，权限不足必须披露，不能声称已更新远端保护。
