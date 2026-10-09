# 会话交接

2026-10-09 UTC。当前开发分支 `feature/cloud-env-platform-foundation`；[PR #12](https://github.com/zhipijun1996/gunman-rush/pull/12) 已创建，未合并。最新 main 基线 `64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226`（PR #11 已合并）；实现及最终运行验证对应 `00c7a1e11e8d18ce7a542b238547d2df996b6dc5`，后续仅追加验证/交接文档。最终分支 HEAD 以 `git status -sb`、`git log -1` 为准，避免在自身提交中记录会过期的自身 SHA。

## 已完成的可审阅准备

- 官方 Godot 4.7.2 Standard 与同版模板下载校验及实际执行；Git、Python、JDK17、Android SDK/Build Tools/CMake/NDK 就绪。21 项环境检查通过，缺失为空。
- 可重复安装、启动检查、Godot包装器、分平台构建脚本、锁文件和CI定义。工具/模板/签名文件均在仓库外；网络与进程有超时。
- Android/正式Windows/未来Steam共用架构、三种输入契约、配置、共用存档格式与可选平台层已补文档。
- CORE-01固定灰盒、统一Router/Controller/Motor、可启停N跳、土狼与缓冲。调参唯一来源仍为config/player_tuning.json。
- 解析、headless主场景、70项真实物理/事件断言通过，故意失败自检退出1；文档与空白检查通过。
- 最终源码Android debug APK导出/签名校验与Windows x86_64 EXE/PCK导出分别退出0。APK尚无触屏/射击，不代表APK-01完成。

证据：[完整报告](core01_report.md)、[环境JSON](environment_report.json)、[分项验收](acceptance_tests.md)。ENV-01/CORE-01保持review，人工/界面项没有标done；其他任务见tasks.md。

## 失败、阻塞与未验证

初始代理不可达、SDK PKIX信任失败、一次测试tick隔离失败与Android ETC2设置缺失均已修复并保留记录；输入取消与配置边界缺陷已补回归。

Cloud界面无可调用配置发布API/source_config_id：当前会话安装完成，环境设置仍需用户保存/发布，步骤见environment.md；脚本合入main前可用本PR分支测试。不会自动合并PR。

Android真机、Windows机器、图形窗口、Xvfb/Wine均无执行证据。实际SceneTree暂停/失焦、触屏、手柄、手感/性能保持unverified。文档、解析、物理、构建与真机可玩分别记录。美术/音乐未生成，没有伪造结果。APK与Windows产物在忽略的build/下，未推送二进制。

## 下一任务与恢复命令

下一项CORE-02：沿当前组件与唯一Motor实现射击反冲、冷却、可配置0/N射击资源和地面起飞账本，验收A05–A08及A18射击部分。随后INPUT-01、WORLD-01、APK-01按依赖推进；手柄/Windows正式支持按INPUT-PC-01、WIN-01。固定挑战Android真机验收后才开始GEN-01，不跳过依赖。

```sh
git fetch origin main
git status -sb
git log -1 --oneline
python3 tools/check_docs.py
bash tools/cloud_start.sh
timeout 90 bash tools/godot.sh --headless --path . --editor --quit
timeout 90 bash tools/godot.sh --headless --path . --script tests/run_tests.gd
python3 tools/build.py android
python3 tools/build.py windows
```

新环境缺工具时先执行 `bash tools/cloud_setup.sh --accept-android-licenses`。README记录灰盒按键。继续遵守AGENTS.md，不覆盖他人改动、不强推、不擅改核心玩法；每次结束更新本交接，不承诺后台无限迭代。
