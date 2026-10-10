# CORE-02、基础操作与 APK 测试报告

2026-10-09 UTC。分支 `feature/core02-combat-controls`；基于 `99e2fe3` 与未合并 PR #12。再次fetch确认main仍为 `64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226`。最终实现提交 `837341b8f2c99acdcb0f498eff4c191141fe2887`，完整测试 **232断言/0失败**；[PR #13](https://github.com/zhipijun1996/gunman-rush/pull/13)，测试包链接见 [交接](handoff.md)，文档后续提交不改变运行源码。没有自动合并。

## 环境

继续使用经官方SHA256与二进制核验的 **Godot 4.7.2 Standard / 4.7.2.stable.official.ed1daf0bf** 与同版导出模板，没有使用预装4.6.3。Git2.52.0、Python3.12.14、Temurin JDK17.0.20.1+1，Android CLI22/ADB37.0.1/Build Tools35.0.1/API35/CMake3.10.2/NDK28.1.13356709。环境检查21项通过、缺失为空；Windows导出条件独立检查。版本/安装来源见 [环境报告](environment_report.json)及 [上一轮报告](core01_report.md)。当前会话工具就绪；Cloud界面设置保存/发布仍待用户，见environment.md。

临时补装官方Debian Xvfb到仓库外，使用Mesa25.0.7 llvmpipe实际渲染练习/挑战并检查触控预览布局；初次无音频设备回退Dummy，最终显式选择Dummy。不能用虚拟显示/软件渲染推断Android性能、触控或Windows可玩。引擎、SDK、JDK、签名与工具下载均未提交。

## 实现

- 独立ActionResources/ShootAbility/RecoilAbility：0/N可配置射击资源、地面起飞账本、冷却拒绝不消耗或延迟、正常速度与反冲速度分离，PlayerMotor仍是唯一move_and_slide调用方。
- 同一成功射击事务生成攻击弹体并施加反冲。弹体圆形体积以cast_motion/intersect_shape扫掠，高速薄墙/擦边/初始重叠不会直接穿过；地形阻挡、射手与同阵营过滤、单次独立Damageable伤害、寿命/session/死亡清理。半径3、速度1200、伤害1、寿命2秒来自唯一调参文件。灰盒靶可击破，未实现敌人AI/Boss。
- 键鼠世界瞄准+释放射击；触屏双杆+独立跳跃+三指捕获；手柄固定tick滞回/中心确认/重武装。InputProfile Resource是输入参数唯一来源，两份JSON都明确纳入Android/Windows导出。输入取消不射击，桌面隐藏触控控件，提示随设备更新；配置接口已实现，设置UI未制作。
- 独立补充点、扫掠锯轮、周期机关、开关、单向平台、检查点、攻击靶、终点。补充延迟下一控制tick，不改冷却/跳跃，源卸载或旧session无效；安全出生形状/脚下地面/机关运动范围检查，快速重生0.15秒。下穿只对脚下已验证矩形单向平台添加临时碰撞例外，不穿普通地面。
- 练习区/固定挑战候选、暂停/重试、资源HUD与瞄准反馈；深色原创机械灰盒，尚无正式美术/音乐。固定挑战动作链和20–30秒目标尚未验收，不开始随机生成。

## 实测命令与结果

命令在仓库根目录运行，所有外部进程有有限超时。最终结果与断言数见交接；构建报告保存在忽略的build目录。

| 命令/检查 | 退出码 | 结果与限制 |
| --- | --- | --- |
| `python3 tools/check_docs.py` | 0 | 22份必需文档、链接、13项依赖、物理/输入配置检查 |
| `python3 -m py_compile tools/run_tests.py tools/build.py tools/check_docs.py` / `bash -n tools/godot.sh tools/cloud_start.sh tools/cloud_setup.sh` | 0 | Python/Shell语法 |
| `git diff --check` | 0 | 空白检查 |
| `python3 tools/run_tests.py` | 0 | import超时90秒，完整测试超时180秒；脚本错误、非零退出、缺成功终行均失败；真实碰撞与设备事件，不是只解析 |
| `timeout 30 bash tools/godot.sh --headless --path . --script tests/run_tests.gd -- --verify-failure-exit` | 1 | 保留故意失败断言，验证非零返回 |
| `timeout 30 bash tools/godot.sh --headless --path . --quit-after 120` | 0 | 主场景运行，无脚本错误 |
| Xvfb/Mesa、gl_compatibility、Dummy音频、临时渲染驱动 | 0 | 实际帧输出练习/挑战截图；强制触屏预览；不是手机执行 |
| `timeout 240 python3 tools/build.py android` | 0 | 全环境21项检查、import、APK导出、apksigner verify及两份配置包内存在 |
| `timeout 240 python3 tools/build.py windows` | 0 | 独立Windows工具检查、import、x86_64 EXE/PCK导出 |
| `timeout 30 bash tools/godot.sh --headless --main-pack build/windows/gunman-rush.pck --quit-after 120` | 0 | 导出PCK在Linux启动，无脚本错误；不代表Windows EXE运行 |

实际232项：基础70、战斗58、输入68、世界36，0失败。覆盖原70基础断言及战斗、输入、世界组件回归。实际SceneTree暂停/恢复、弹体冻结与恢复已测试；失焦通过FOCUS_OUT/IN通知与持续采样/事件回归测试，OS真实切后台/实体手柄仍未验证。预期队列上限测试产生一次queue_full警告，不算失败。

## 失败与修复

- 输入JSON数值由Godot解析为float，按键映射与InputEventKey的int不一致；规范化为Array[int]，保留原70断言。
- 补充来源guard推断不满足类型化脚本解析，明确bool类型。一次临时驱动遇到脚本错误但Godot仍退出0；新增Python测试包装器拒绝SCRIPT ERROR/Parse Error与缺完成终行，没有将零退出误记通过。
- 场景菜单根节点ALWAYS会导致默认继承的玩法/弹体在暂停中继续执行；玩家、世界对象、弹体显式PAUSABLE，新增实际暂停回归。
- 静态审查发现失焦仅clear一次，手柄下一tick仍可采样重新武装；Router新增焦点状态与拒绝入口，三种适配器失焦停止采样，恢复再次取消并要求新武装。补12项持续失焦/恢复回归，修复后重测和重新导出。
- 新输入JSON原先未加入export include_filter；同时补Android/Windows并在APK检查两份文件实际存在。
- 虚拟显示检查发现练习出生位置受左杆遮挡、HUD文字与按钮重叠；调整相机左边界和按钮位置，重新渲染检查。
- 第一次远端push的README报告链接比报告文件先提交，CI文档检查失败，Android被跳过；补齐报告文件与最终文档后重新触发，远端最终状态独立记录，不由本地通过推断。
- Android export日志有ADB tcp:5037连接拒绝/无设备，不是手机启动证据；构建及签名退出0。Build Tools回退35.0.1提示保留；使用官方预构建模板，未声称Gradle自定义构建通过。

## 产物与待用户验收

APK为debug签名、横屏，默认进入Practice；右杆有效方向松手发射子弹并反冲，左杆移动、JUMP跳跃。Challenge切固定候选，Retry重生/重试，Pause暂停。资源耗尽时拒绝射击，落地恢复，空中补充点+1。附带Windows debug包和日志/截图，不提交二进制到Git，不发布商店。

最终APK/EXE/PCK尺寸与SHA256由build_report.json产生并复制到交接。aapt2实际读取APK manifest：minSdk24、targetSdk36；同时出现官方模板themed_icon引用缺文件警告，尚未在Android安装验证，不能将该警告推断为安装通过或失败。不能以安装的SDK版本推断产物targetSdk。真机三指、切后台、手感、固定挑战3次通关、60fps/p95帧时及20分钟稳定性均awaiting-device；Windows实机键鼠/手柄亦未验证。A27两宽高比物理轨迹矩阵未完整完成，不能用鼠标相机转换断言代替。Linux/macOS/Steam Deck、敌人/Boss、持久存档、Steamworks未开展。

下一步依据用户APK试玩反馈修复基础操作与挑战，验收LEVEL-01后才进入GEN-01；不会后台无限迭代。


| 最终产物 | 字节数 | SHA256 |
| --- | --- | --- |
| `build/android/gunman-rush-debug.apk` | 28380386 | `cd844e02105d9136c01d976969df6b1871c04dd8bc58cce73bf2f271d26bec5f` |
| `build/windows/gunman-rush.exe` | 103035904 | `5543ab4b6fb453c5dbe7f4effa0aad7f1cc06d73c12e8436adfc9fb266ac34ee` |
| `build/windows/gunman-rush.pck` | 123760 | `1d3deb147dbdc2f9fbcc56bd50c535b84b44c907fb76e909b1694cf14e0c0630` |

GitHub草稿附件上传请求返回HTTP401 Bad credentials（uploads.github.com）；普通git push/API读写正常。空草稿已清理，没有正式发布，也没有把二进制提交Git。Actions上传产物路径与当前状态见交接；本地APK已完成导出，不把附件交付问题记成构建失败。


## 远端CI实际结果

实现提交837341b对应 [Actions run 37907521057](https://github.com/zhipijun1996/gunman-rush/actions/runs/37907521057) 已完成success，core测试/Windows导出与Android完整安装/导出均通过，两种产物上传step成功。文档CI run37907520950亦success。下载入口见交接，产物当前未过期、保留7天。

远端Android APK实测构建日志记录28342932字节，SHA256 `1e9872452c6d6e7b864238f83523e792c80a50b86cedc7ddbaaa85807da2782f`；这是CI包摘要，与上表本地包分别记录。Cloud尝试下载CI artifact的Azure Blob跳转被Forbidden拦截；没有声称本会话下载复验CI APK，用户通过GitHub登录下载该Actions产物。附件上传401与Cloud下载403分别属于交付接口限制，不改写真实本地和远端构建通过的结论。
