# ENV-01 与 CORE-01 实际验证报告

2026-10-09 UTC。基线：最新 main `64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226`（合并 PR #11）；提交前再次 fetch，main 未变化。分支 `feature/cloud-env-platform-foundation`；实现提交 `00c7a1e11e8d18ce7a542b238547d2df996b6dc5`；[PR #12](https://github.com/zhipijun1996/gunman-rush/pull/12)。后续证据提交只更新文档，不改变测试源码。

## 环境与来源

Debian GNU/Linux 13.6、Linux x86_64。Git 2.52.0、Python 3.12.14。预装 Godot 4.6.3 和系统 JDK21 已探测，但没有用于项目验证；官方 Standard 4.7.2 下载后 SHA256 校验通过，实际二进制 `4.7.2.stable.official.ed1daf0bf`。用户允许指定版本实在无法取得时回退 4.6.3，本次无需回退。

来源与锁值：[配置](../config/toolchain.json)、[Godot 官方 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)、[Godot 4.7 Android 文档](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)、[Windows 文档](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_windows.html)。引擎/同版 Standard 模板/JDK17/Android CLI 下载均校验官方来源 SHA256；SDK 包经官方 sdkmanager 安装。私有 JDK Temurin 17.0.20.1+1，SDK/API35、Build Tools35.0.1、CMake3.10.2、NDK28.1.13356709 等实际版本见 [环境 JSON](environment_report.json)：21 项通过，缺失为空。

当前会话工具链就绪；Cloud 界面配置未保存/发布，见 [具体设置步骤](environment.md)。未提交 SDK/引擎二进制、签名文件、凭据或机器绝对路径。

## 实测命令

全部在仓库根目录执行，包装器选择同一固定 Godot 二进制并设置本机路径。

| 命令 | 退出码 | 结果 |
| --- | --- | --- |
| `bash tools/cloud_setup.sh --godot-only` | 0 | 引擎/模板复用核验 |
| `bash tools/cloud_setup.sh` | 0 | 复用完整已安装工具链 |
| `python3 tools/check_environment.py --output docs/environment_report.json` | 0 | 21 项通过、缺失为空 |
| 故意以不存在工具链目录运行 checker | 1 | 缺失真实失败 |
| `python3 tools/check_docs.py` | 0 | 22 份必需文档、相对链接、13 项任务依赖与调参 |
| `python3 -m py_compile tools/check_docs.py tools/check_environment.py tools/setup_environment.py tools/build.py` | 0 | Python 语法 |
| `bash -n tools/cloud_setup.sh tools/cloud_start.sh tools/godot.sh` | 0 | Shell 语法 |
| `git diff --check` | 0 | 空白检查 |
| `timeout 90 bash tools/godot.sh --headless --path . --editor --quit` | 0 | 无脚本解析错误 |
| `timeout 90 bash tools/godot.sh --headless --path . --script tests/run_tests.gd` | 0 | 70 assertions / 0 failures |
| `timeout 30 bash tools/godot.sh --headless --path . --script tests/run_tests.gd -- --verify-failure-exit` | 1 | 故意失败验证非零返回 |
| `timeout 30 bash tools/godot.sh --headless --path . --quit-after 120` | 0 | headless 主场景启动，无窗口证据 |
| `timeout 240 python3 tools/build.py android` | 0 | 最终源码 APK 导出与签名校验 |
| `timeout 240 python3 tools/build.py windows` | 0 | 最终源码 Windows x86_64 EXE/PCK 导出 |

自动覆盖：真实地面与0/1/2/3/5跳、启停、空中上限变化、土狼内外、实际落地缓冲一次、移动减速/空控、墙/低顶、取消/去重/队列上限/过期、死亡重生、键盘事件重武装、零缓冲即时意图、100ms边界、能力禁用定向清旧队列。时间窗口采用 `age < duration`：60Hz 下83.333ms有效，100ms与116.667ms过期；1e-9秒仅消除浮点残差。队列上限测试产生一条预期 queue_full 警告。

## 失败与修复

- 初始 clone 退出128、curl退出7：`Failed to connect to proxy port 8080`。运行权限调整后恢复；先通过 GitHub 连接读取全部最新文件并核实原始 blob/tree/commit，再 Git fetch 核对 main，没有使用旧缓存。
- 初始 SDK manifest 报 `PKIX path building failed`，platform-tools安装退出1。一次 licenses返回0但源下载失败，未计 SDK 安装成功；只将会话 CA 导入私有 JDK 信任库、保留 TLS 校验后重装并核验通过。
- 中间自动测试53断言/1失败、退出1：过期队列测试把主 Router tick 推进10000，污染随后重生；用独立 Router 隔离，没有改玩法掩盖失败。最终新增回归后70项通过。
- 独立 review 发现空手取消吞首按键、零缓冲禁用即时跳跃、能力重启复活旧动作，分别修复并增加回归；Controller重生改为请求Motor执行位移。
- 初始 Android export 退出1：缺ETC2/ASTC设置；补齐并重新import后导出和签名校验通过。
- editor/export有ADB daemon `tcp:5037 Connection refused`消息，无设备连接证据；解析/导出仍退出0。Build Tools选择提示回退35.0.1；APK manifest实测minSdk24/targetSdk36（官方预构建模板），不把已安装API35推断为产物targetSdk。

## 最终灰盒产物

仅位于忽略的build目录，未提交Git。Android无触屏/射击；Windows未启动试玩。

| 路径 | 字节数 | SHA256 |
| --- | --- | --- |
| `build/android/gunman-rush-debug.apk` | 28268682 | `8d22eff78d9c409fc622c5024339097cd6451238f412f4e11705e614619825e4` |
| `build/windows/gunman-rush.exe` | 103035904 | `5543ab4b6fb453c5dbe7f4effa0aad7f1cc06d73c12e8436adfc9fb266ac34ee` |
| `build/windows/gunman-rush.pck` | 20884 | `bc38d5b8d308e5ae431ca25121caab98f866f0f2c73fa7016c2bca5bf5d37f30` |

## 未验证

桌面窗口、真实SceneTree暂停/恢复与平台失焦、Android真机触控/手感/性能、Windows实机/手柄、Gradle自定义构建、Linux/macOS/Steam Deck。远端CI以真实workflow run为准，不推断远端通过。正式美术/音乐未生成，灰盒不代表样片验收。

跨平台架构已补共用逻辑、输入提示/配置、存档格式与可选平台层；手柄/触屏/存档/Steamworks未因文档变成已实现。下一项CORE-02；固定挑战真机验收后才允许模块化随机。
