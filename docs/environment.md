# 工具链与 Codex Cloud 环境

## 锁定版本与来源

工具链锁定在 `config/toolchain.json`，Godot **4.7.2 Standard**，不使用 Mono/.NET。官方 release：<https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable>。必须同时验证实际 `--version`、安装包 SHA256 和同版本导出模板，不以网站摘要代替二进制验证；指定版本下载失败时安装脚本返回非零，不自动换版。用户允许无法取得指定版本时考虑 4.6.3，但当前 4.7.2 已取得且实际运行，无需回退。

Godot Linux x86_64 SHA256：`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`。Standard templates SHA256：`f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`。实际安装与命令证据由 `docs/acceptance_tests.md`、`docs/handoff.md` 和环境检查 JSON 保存。

Git >= 2.30、Python >= 3.12、curl 为安装脚本前置条件，优先复用 Cloud 已有版本。Godot 安装自动化目前支持 Linux x86_64；其他系统明确报错，不偷偷使用不同构建。

对应版本 Android 官方文档：<https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html>。推荐 JDK 17；较高版本可用，但本项目安装固定 Temurin 17.0.20.1。JDK 官方来源 <https://github.com/adoptium/temurin17-binaries>，具体文件与 SHA256 在锁文件。Android SDK 包：platform-tools >= 35、build-tools 35.0.1、platforms android-35、cmdline-tools latest（bootstrap 15859902）、cmake 3.10.2.4988404、NDK 28.1.13356709。SDK 管理器从官方 Google repository 获取，安装具体包并检查存在与可执行命令；`sdkmanager --licenses` 返回零不能单独证明 SDK 已安装。

## 可重复安装与启动

在仓库根目录运行：

```sh
bash tools/cloud_setup.sh --accept-android-licenses
bash tools/cloud_start.sh
python3 tools/check_environment.py --output build/environment-report.json
bash tools/godot.sh --version
```

`--accept-android-licenses` 明确授权接受官方 SDK 许可；未传且需要安装 SDK 包时，脚本说明原因并失败。只准备引擎与 Windows 模板可使用 `bash tools/cloud_setup.sh --godot-only` 和 `bash tools/cloud_start.sh --godot-only`，其成功不表示 Android 就绪。

默认工具链根为仓库父目录下 `toolchains`，可通过 `GUNMAN_TOOLCHAIN_ROOT` 选择仓库外目录；脚本拒绝把工具链安装进仓库。引擎、模板、下载缓存、私有 JDK、Android SDK 均保存在那里，不提交二进制。可复用 `GODOT_BIN`、`JAVA_HOME`、`ANDROID_HOME`、`GUNMAN_DATA_HOME`，但引擎必须符合锁定版本。包装器设置工具链内的用户数据、配置与缓存目录，不依赖用户手写本机绝对路径到工程。

安装脚本检查下载 SHA256，保留匹配缓存，安装失败或缺失依赖返回非零。启动脚本只运行检查，不每次下载。检查 JSON 记录 OS/架构、命令、输出、退出码、缺失项，并用变量占位替换本机路径；不得把包含密钥的其他诊断输出提交。`JAVA_HOME` 指向私有工具链 JDK 时，可从 `GUNMAN_PROXY_CA_FILE`、`NODE_EXTRA_CA_CERTS` 或 `CODEX_PROXY_CERT` 把会话 CA 导入该 JDK truststore。只修改私有 JDK，不改系统信任或关闭 TLS。SDK 管理器代理来自当前 `HTTPS_PROXY`，不把代理凭据写到仓库。

Android 导出所需 Godot editor settings 写入工具链的 `user-config/godot/editor_settings-4.7.tres`；保留已有设置，只更新 SDK/JDK 路径。该文件属于当前机器，不提交。引擎与模板成功安装、脚本解析、物理测试、APK 构建、真机可玩分别记录，任何一步成功都不能代替后续验证。

## Codex Cloud 界面设置

当前会话有命令执行能力；未提供可发布环境配置的 configuration API/source_config_id，因此脚本已准备不等于界面环境已发布。用户需在 Codex 的环境设置中：

1. 审阅本次 PR 后由用户决定合并；脚本合入后，关联 GitHub 仓库 `zhipijun1996/gunman-rush`，默认分支选择 `main`。合并前可用 PR 分支测试环境配置，不能假定当前 main 已有这些脚本。
2. 安装命令设置为 `bash tools/cloud_setup.sh --accept-android-licenses`，启动命令设置为 `bash tools/cloud_start.sh`。
3. 安装阶段允许访问 GitHub release、Google Android repository 与官方文档；若使用代理，保留 Cloud 注入的代理与 CA 设置。
4. 保存/发布该环境，并在新任务中验证启动日志。若配置界面没有独立 startup 字段，在启动任务执行检查命令，不把检查成功误报为界面发布成功。

安装通常需要数 GB 空间与网络；下载超时、DNS、TLS、HTTP 错误如实记录，失败时仍可推进独立文档工作。本会话曾有网络策略/代理阻塞，之后权限变更解除；私有 JDK 首次不信任会话 CA 导致 SDK manifest 的 PKIX 错误，必须修复信任并重新验证实际 SDK 包。

下载有 10 秒连接超时、180 秒单次总超时及有限重试，SDK 命令也有总超时，均非无限等待。长命令分段检查输出；权限请求或执行无进展时明确报告阻塞并继续独立工作。

## Android 与 Windows 构建路径

Android 当前优先横屏、debug APK。运行项目验收与导出入口（preset 存在后）：

```sh
python3 tools/check_docs.py
bash tools/godot.sh --headless --path . --editor --quit
bash tools/godot.sh --headless --path . --script tests/run_tests.gd
python3 tools/build.py android
python3 tools/build.py windows
```

Windows 是未来正式平台，第一版 Steam 优先 Windows x86_64。Linux 环境用同版本 `windows_debug_x86_64.exe` 与 `windows_release_x86_64.exe` 模板可导出 unsigned Windows 程序，不需 Steam SDK、Steam 账号或 Windows SDK。代码签名/商店发布单独处理。没有 Steam SDK 时通过空平台适配器运行普通游戏；当前不做完整 Steamworks 接入、不创建商店发布。

Linux 导出成功不能证明 Windows 可执行或键鼠/手柄手感通过；需要 Windows 实机独立验收。Android 真机触控、手感与性能由用户验收。Linux、macOS、Steam Deck 后续分别验证。当前 CI 仅声明文档、Godot 安装检查、工程解析和 CORE 自动测试；远端 workflow 是否通过需查看真实 run，不据本地结果推断。无图形显示、Xvfb、Wine 时仅记录 headless 执行证据，桌面窗口/Windows 启动保持待验证。

当前 Android preset 使用官方预构建 APK 模板；构建实测会提示按 SDK 目标选择 Build Tools 回退到 35.0.1，签名和 APK 校验仍通过。`aapt dump badging` 实测该官方模板 minSdk 24、targetSdk 36，不能把已安装 API 35 写成产物 targetSdk。Gradle 自定义模板和商店 SDK 政策在后续 APK 任务单独验证；本次不据成功导出推断 Gradle 或商店发布可用。

## 本会话已执行检查（2026-10-09）

Linux x86_64；`bash tools/cloud_setup.sh --godot-only`、`bash tools/cloud_setup.sh`（复用已有 SDK/JDK）、`python3 tools/check_environment.py`、`python3 tools/check_docs.py` 均实际退出 0。安装步骤与版本核验不是计划命令，以下工具已真实执行：

| 命令 | 实际输出版本 | 退出码 |
| --- | --- | --- |
| `git --version` | 2.52.0 | 0 |
| `python3 --version` | 3.12.14 | 0 |
| `bash tools/godot.sh --version` | 4.7.2.stable.official.ed1daf0bf | 0 |
| `java -version`（私有 JDK） | Temurin 17.0.20.1+1 | 0 |
| `sdkmanager --version` | 22.0（官方提示未来用 Android CLI，不影响本次退出码） | 0 |
| `adb version` | 1.0.41 / platform-tools 37.0.1-15733141 | 0 |
| `aapt2 version` | 2.19-12874835 / build-tools 35.0.1 | 0 |

SDK metadata 检查通过：Android API 35 revision 2、CMake 3.10.2、NDK 28.1.13356709；Standard Linux、Android 和 Windows x86_64 导出模板非空。Android SDK 最初 PKIX 失败修复后重新安装，当前完整环境检查缺失列表为空。完整项目解析、物理测试、各平台导出结果见独立验收报告，真机与 Windows 启动不由该检查替代。
