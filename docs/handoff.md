# 会话交接

2026-10-09 UTC。当前分支**feature/snappy-shot-burst**；实现提交**d4878d20a3eb937acc3bed97788f6436f7c6c567**，后续仅证据/交接提交，最终HEAD以git log -1为准。[PR #14](https://github.com/zhipijun1996/gunman-rush/pull/14) base是feature/core02-combat-controls，叠加尚未合并的[PR #13](https://github.com/zhipijun1996/gunman-rush/pull/13)及[PR #12](https://github.com/zhipijun1996/gunman-rush/pull/12)。再次fetch的main仍64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226；没有自动合并/强推/覆盖他人。

## 用户最新反馈与本轮变化

用户实际试玩前轮APK，认为不够灵活、下射抬升弱，希望参考空洞骑士并每枪短快速位移；又要求若简单则让iPhone试玩，已在GitHub界面开启Pages并明确授权继续。

默认shot_burst（保留legacy_impulse指数模式）：每枪反向1100×0.14秒，位移154；清旧普通竖直速度、短窗重力冻结/普通位移抑制，x输入准备结束接管；仍唯一Motor碰撞移动，无无敌/瞬移，墙顶投影不复活。普通330速度、地面/空中加减速19800、gravity2600/jumps[-840,-800]。次数、冷却、攻击弹体及资源规则保持。

原版HK完整精确数值未核实；实际读到固定提交社区KnightInSilkSong控制器即时横移/恒速关重力冲刺/持续跳跃行为，严格区分社区行为与官方原参数，本项目候选不是原版数值。短按小跳/长按大跳尚未实现；爆发内跳跃与同帧优先级列试玩项。

Godot4.7.2 Standard、同版模板/JDK17/SDK条件不变；综合**254断言/0失败，退出0**（原232+爆发22），实际静止下射峰高32.403→154，跳升/下落横爆发均154，最大落速首tick向上1100，空中全速反向2tick（33ms）。初次4失败均保留并修正受控fixture，无删除断言/放宽100ms时限。详见[手感试调与报告](gamefeel_tuning.md)，历史[CORE-02报告](core02_report.md)/[CORE-01报告](core01_report.md)保留当时事实。

## 构建、下载、发布（分别记录）

- 本地Android导出/签名/两JSON检查通过；Windows独立导出/PCK Linux启动通过；单线程Web导出通过。版本/字节/SHA256/命令在手感报告，日志在忽略的build/verification/shot-burst。
- 单线程Web、WebGL2/Compatibility、无GDExtension；浏览器触屏检测复用原TouchOverlay。Chromium手机/touch模拟实际渲染并注入下射，无脚本错误；Safari/iPhone真机未验证。WebKit运行时未安装，不展开原生iOS签名/TestFlight。
- [push CI 37912173147](https://github.com/zhipijun1996/gunman-rush/actions/runs/37912173147)：core（254/Windows）、Android、Web及各自产物上传success；deploy_web失败，整体workflow不能称通过。独立文档CI成功；PR事件不会部署。
- **[新版APK ZIP下载](https://github.com/zhipijun1996/gunman-rush/actions/runs/37912173147/artifacts/11606569311)**，解压安装gunman-rush-debug.apk；[Windows包](https://github.com/zhipijun1996/gunman-rush/actions/runs/37912173147/artifacts/11606298993)、[Web导出文件](https://github.com/zhipijun1996/gunman-rush/actions/runs/37912173147/artifacts/11607585446)。保留7天；debug签名变化导致覆盖失败时卸载旧测试包再装，不提交密钥。

## 当前网页部署阻塞

Pages已核实build_type=workflow，地址https://zhipijun1996.github.io/gunman-rush/，**尚未部署验证，不能宣称可试玩**。环境github-pages的Deployment branch policies仍仅main，试调分支未合并被阻止；API尝试添加feature/snappy-shot-burst返回403 Resource not accessible by integration。不是Godot/Web构建失败。

已通过异步问题告知用户所需具体操作：Settings→Environments→github-pages→Deployment branches and tags，添加Branch规则feature/snappy-shot-burst（保留main）。等待用户完成；不通过自动合并main或改其他环境来绕过。规则变更后仅重跑失败的deploy_web，核实Actions发布成功、HTTPS页面/JS/WASM/PCK可取、浏览器启动，再更新本交接和PR。如果用户放弃苹果，则保留导出路径、停止部署，不阻碍Android试玩。

## 未验证与下一任务

新版Android真实触控/手感/切后台、固定挑战动作链/20–30秒目标/3次通关/60fps/p95/20分钟稳定性，Windows实机与实体手柄，iPhone Safari/安全区域/性能仍awaiting-device；A27跨两宽高比完整物理轨迹矩阵未做。正式美术/音乐、敌人/Boss、存档/Steam尚未开展。Cloud安装/启动配置界面发布仍按environment.md待用户，当前会话实际安装可用。

先完成网页部署缺失权限并实测公开入口；用户试玩短爆发候选决定下一轮窗口/强度与可变跳高。固定挑战Android真机验收前不推进GEN-01，不承诺后台无限迭代。

```sh
git fetch origin main feature/snappy-shot-burst
git status -sb
git log -1 --oneline
python3 tools/check_docs.py
bash tools/cloud_start.sh
python3 tools/run_tests.py
python3 tools/build.py android
python3 tools/build.py windows
python3 tools/build.py web
```

新环境先bash tools/cloud_setup.sh --accept-android-licenses。进程/网络均有限超时；按照AGENTS更新证据、推送/PR，不自动合并，不伪造真机/原版参数/已发布结果。
