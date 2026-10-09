# 工具链与环境

2026-10-09：仓库为空，已 clone 并关联 origin；GitHub 连接有 push 权限。Python 3.12.14 可用；godot/godot4/gh 未发现。Android SDK/JDK/导出模板尚待 ENV-01 探测，不把未探测写成不存在。

目标 Godot 4.7.2 Standard：官方主页检索已确认 Latest 4.7.2；需要下载真实二进制、校验来源并记录 `godot --version`，不能只信搜索摘要。引擎与导出模板必须同版本。

ENV-01：检测 OS/架构、Java、SDK、模板；按该版本官方 Android 文档选择 JDK/SDK，建立 machine-local 环境配置并记录版本，不提交绝对本机 SDK 路径、签名密钥或密码。

计划命令：
- `python3 tools/check_docs.py`（现在可用）
- `godot --headless --path . --editor --quit`（工程创建后）
- `godot --headless --path . --script tests/run_tests.gd`（测试入口实现后）
- `godot --headless --path . --export-debug Android build/gunman-rush-debug.apk`（Android preset、SDK 与模板齐全后）

官方文档：https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html 。未配置 Android preset 前不能执行最后一项。先 debug APK，签名发布另行处理。
