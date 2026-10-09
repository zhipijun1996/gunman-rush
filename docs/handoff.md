# 会话交接

2026-10-09 UTC。当前分支 `feature/core02-combat-controls`；[PR #13](https://github.com/zhipijun1996/gunman-rush/pull/13) 已创建未合并，base是 `feature/cloud-env-platform-foundation`，依赖尚未合并的 [PR #12](https://github.com/zhipijun1996/gunman-rush/pull/12)。没有自动合并、强推或覆盖main。最新main仍是 `64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226`。本轮最终实现提交 **`837341b8f2c99acdcb0f498eff4c191141fe2887`**（初始实现cb26073，追加失焦修复837341b）；随后仅记录证据/交接，最终HEAD以git log -1为准。

## 本轮完成

- Godot4.7.2 Standard、同版模板、JDK17、SDK/构建依赖仍可执行，完整环境21项通过。Android与Windows分别导出，无版本回退；安装/网络/测试/导出均有限超时。
- CORE-02射击反冲与圆形sweep攻击弹体，独立Shoot/Recoil/ActionResources/Damageable组件，0/N次数配置；统一PlayerMotor保持唯一运动执行。
- 触屏双杆与独立跳跃/三指、键鼠释放射击、手柄回中防抖与重武装、配置与提示。暂停/失焦/断连/死亡取消不射击；失焦期间三设备输入被拦截，恢复须新手势。
- 独立补充点、机关/锯轮、开关、矩形单向平台下穿、安全检查点0.15s快速重生、攻击靶/终点；固定练习区与挑战候选。
- **232 assertions / 0 failures，退出0**（基础70、战斗58、输入68、世界36）；实际SceneTree暂停冻结弹体、注入失焦持续采样/恢复回归。故意失败自检退出1，Python包装器拒绝脚本错误或未完成。
- 文档/链接/依赖/配置、Python/Shell语法与空白检查通过。Xvfb/Mesa实际渲染练习/挑战及触控预览；新APK签名校验+两份JSON包内存在通过；Windows EXE/PCK独立导出，导出PCK在Linux启动通过。

[本轮完整报告](core02_report.md)、[分项验收](acceptance_tests.md)、[环境JSON](environment_report.json)。CORE-02保持review，INPUT-01/INPUT-PC-01/WORLD-01/APK-01/LEVEL-01/WIN-01人工设备部分保持awaiting-device；没有把固定挑战候选标成已验收。

## 可下载测试包与远端验证

实现提交837341b的 [Actions运行](https://github.com/zhipijun1996/gunman-rush/actions/runs/37907521057) 已真实完成success：core自动测试/Windows导出/产物上传通过，Android完整环境安装/导出/产物上传也通过。远端 [文档CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/37907520950) 通过。后续仅文档提交触发的CI不视为已经运行完成。

- [Android debug APK下载（ZIP）](https://github.com/zhipijun1996/gunman-rush/actions/runs/37907521057/artifacts/11604917656)：`gunman-rush-android-debug`，解压后安装gunman-rush-debug.apk。
- [Windows debug下载（ZIP）](https://github.com/zhipijun1996/gunman-rush/actions/runs/37907521057/artifacts/11604564627)：EXE与PCK须放同一目录；尚未Windows实机试玩。

Actions产物保留7天，当前过期日2026-10-16；需要GitHub登录下载，过期后可按分支重跑。下载文件来自同一实现提交的CI构建，独立debug签名及时间戳使其哈希不必等于本地包。CI APK构建日志：28342932字节、SHA256 `1e9872452c6d6e7b864238f83523e792c80a50b86cedc7ddbaaa85807da2782f`。Cloud下载该Actions文件的Azure Blob重定向被Forbidden拦截，未声称本会话下载/再验过CI APK；已核实上传step成功和产物API存在、未过期。

本地APK在 `build/android/gunman-rush-debug.apk`；Windows在build/windows；完整日志截图在build/verification，ZIP在build/。只位于忽略目录，未提交二进制到Git。曾尝试上传GitHub草稿附件，但uploads.github.com返回401 Bad credentials；普通Git/API工作正常，空草稿已清理，未正式发布。最终采用Actions产物提供下载。

| 本地产物 | 字节数 | SHA256 |
| --- | --- | --- |
| `build/android/gunman-rush-debug.apk` | 28380386 | `cd844e02105d9136c01d976969df6b1871c04dd8bc58cce73bf2f271d26bec5f` |
| `build/windows/gunman-rush.exe` | 103035904 | `5543ab4b6fb453c5dbe7f4effa0aad7f1cc06d73c12e8436adfc9fb266ac34ee` |
| `build/windows/gunman-rush.pck` | 123760 | `1d3deb147dbdc2f9fbcc56bd50c535b84b44c907fb76e909b1694cf14e0c0630` |


## 阻塞与未验证

Android真机触屏/切后台、手感、固定挑战动作链与20–30秒目标、3次通关、60fps/p95帧时和20分钟稳定性未验证。Windows本机与实体手柄未验证。A27两个宽高比完整物理轨迹矩阵尚未完成。暂时只针对标准矩形单向平台提供下穿，不宣称复杂旋转/多形状支持。正式美术/音乐、敌人/Boss、持久存档/Steam、Linux/macOS/Steam Deck未开展。

Cloud界面配置仍无可调用发布API/source_config_id，用户需按environment.md保存/发布安装及启动设置；当前会话实际安装已完成。Android使用官方模板导出，不代表Gradle自定义构建或手机运行通过。APK manifest实测minSdk24/targetSdk36；aapt2有官方模板themed_icon引用缺文件警告，尚无手机安装证据。ADB无设备连接消息保留。

此前CI因README引用报告先于报告文件提交而失败，现已补齐并远端文档通过；输入数值类型、来源guard、暂停弹体、失焦采样与导出JSON等缺陷已修复并回归。原失败保留于core02_report，不降低验收标准。

## 下一任务与恢复

先用户安装APK测试Practice基础操作，再验收/调优LEVEL-01固定挑战与INPUT/WORLD手感，依据真实反馈修复。GEN-01保持planned，必须固定挑战Android真机验收后开始。可独立继续A27跨屏轨迹矩阵；不改变核心玩法，也不承诺后台无限迭代。

```sh
git fetch origin main feature/core02-combat-controls
git status -sb
git log -1 --oneline
python3 tools/check_docs.py
bash tools/cloud_start.sh
python3 tools/run_tests.py
python3 tools/build.py android
python3 tools/build.py windows
```

新环境缺工具先运行 `bash tools/cloud_setup.sh --accept-android-licenses`。测试脚本有90/180秒超时，构建有分步骤超时；网络下载连接10秒/单次180秒与有限重试。遵守AGENTS，不自动合并/发布商店，设备验收结果先更新本交接与验收表。
