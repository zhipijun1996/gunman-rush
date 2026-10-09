# 移动与射击反冲：第一轮手感试调

以下保留上一轮历史记录。最新可变跳高、已核实社区数值及已解除Pages阻塞见 [可变跳高报告](variable_jump_report.md) 与 [交接](handoff.md)。

2026-10-09。用户实际试玩CORE-02后认为方向响应不够灵活、空中下射不能明显抬升，期望参考空洞骑士并每枪短快速位移。当前为独立候选分支feature/snappy-shot-burst，未合并或替用户认定最终手感。

## 空洞骑士资料与可信度

没有查到已核实的官方完整参数表；原版run/jump/gravity/dash精确数值、游戏单位到本项目像素的比例均未确认，禁止凭记忆填8.3/20等数值。[社区KnightInSilkSong说明](https://github.com/MCXGK3/KnightInSilkSong/blob/3c673d3cbf15928f09a4c1f477e8ed1b2c4a8901/README.md)明确这是将小骑士移植到丝之歌的mod，**不是官方原版规格**。实际读取固定提交 [HeroController.cs](https://github.com/MCXGK3/KnightInSilkSong/blob/3c673d3cbf15928f09a4c1f477e8ed1b2c4a8901/Knight/HeroController.cs)仅作为行为线索：

| 已读行为 | 资料中的字段/位置 | 可确认范围 |
| --- | --- | --- |
| 普通横移直接设置水平速度，无渐进累加 | Move约1570–1595行；RUN_SPEED字段20行 | 社区移植源码行为已读，不冒充原版实测 |
| 持续跳跃会按物理step重置上升速度，有释放状态/最短跳跃逻辑 | Jump约1597–1617行、JUMP_STEPS/JUMP_SPEED、jumpReleaseQueuing | 可变跳跃行为线索；原版持续时间/幅度未核实 |
| 冲刺期间关闭重力、固定方向速度，按计时结束 | Dash约1861–1895行、DASH_SPEED/DASH_TIME | 社区移植行为已读；原版速度/持续时间未核实 |
| 数值字段是public序列化字段，没有此源码中的默认初始值 | RUN_SPEED/JUMP_SPEED/DASH_SPEED/DASH_TIME声明 | 不能从这些声明得到原版数值，也不能用复刻参数冒充 |

有限网络检索还遇到wiki Movement路径404、标记decompiled的公开仓库为空（409）；未使用未读页面作为证据。每次查询有10秒连接/25秒总时间上限或CLI timeout25秒；停止追查以避免研究阻塞可试玩候选。这里只参考快速转向/可控短机动的方向，保持原创玩法/资产。

## 旧版为什么下射无力

旧recoil=520，tau=0.16。无限时、无地形且无重力的理想水平积分上限83.2像素；真实竖直轨迹还受重力影响，旧参数静止下射峰高仅32.403像素。下落普通速度可达900，首帧反冲约468，合成仍向下，自然无法拉升。旧空中反向理论耗时2×250/900≈0.556秒，明显不适合紧凑平台操作。

## 候选选择与折中

建议先试短爆发：成功射击仍生成攻击弹体，玩家沿其反向走恒速碰撞运动。激活清旧normal.y、短窗停止重力，让每枪在跳升/下落中有一致可预期的机动；不叠加无限速度、不增加无敌、不瞬移穿墙。代价是爆发窗口内方向锁定、普通移动不改变爆发；x输入可准备结束接管，窗口内跳跃的作用/同帧优先级须手机试玩。若用户更喜欢可随时微调，可下一轮缩短窗口或采用较强冲量混合方案，而不是同时混进多个未知参数。

| 参数/结果 | 上轮 | 本轮候选 |
| --- | --- | --- |
| 地面速度 | 250 | 330 |
| 地面加速/减速 | 1800/2200 | 19800/19800（从0到满速1tick） |
| 空中加速 | 900 | 19800（全速反向2tick≈33ms） |
| 重力 / 跳跃速度 | 1250 / -440,-400 | 2600 / -840,-800 |
| 反冲 | 520冲量，tau0.16指数衰减 | 1100恒速，0.14秒，总位移154 |
| 静止下射真实峰高 | 32.403 | 154.000（约4.75倍） |
| 最大落速时下射首tick | 仍可能向下 | 立即向上1100 |
| 冷却 / 空中射击上限 / 跳跃上限 | 0.25 / 2 / 2 | 保持；次数仍支持0/N |

所有新数值是本项目待试玩参数，**不是空洞骑士原数值**。短按小跳/长按大跳尚未实现，是下一轮值得优先尝试的手感改进；不声称当前完全复刻HK。唯一参数源仍为config/player_tuning.json，legacy_impulse保留指数反冲，完整旧物理配置可从上一实现提交恢复。

## 验证

Godot4.7.2 Standard。`python3 tools/run_tests.py`实际254断言/0失败、退出0：原232全部保留，追加22个burst真实物理/取消/量化断言；独立入口`timeout 90 bash tools/godot.sh --headless --path . --script tests/gamefeel_runner.gd`。新默认而非仅旧参数运行基础/输入/世界测试。用于指数兼容性的单一旧射击fixture明确使用legacy与1250重力；100ms缓冲边界fixture改按当前重力计算出生高度以保留指定真实落地tick，没有放宽100ms标准。

初次综合232断言出现4失败，退出1：两个固定出生高度的缓冲边界随重力改变；两个旧指数resource fixture因新版重力提前落地。分别修正测试的受控初态/兼容模式，并保留同一断言，最终254/0。真实测量记录旧/新峰高、跳升/下落初态横向距离153.99997和空中反向2tick；墙顶碰撞后不复活、连续两枪不叠加、到时/禁用/死亡/重生均覆盖。

## iPhone简易试玩可行性

优先单线程Web而非原生iOS：同版Standard模板已带web_nothreads；`python3 tools/build.py web`实际导出成功，Compatibility/WebGL2、无GDExtension/PWA，不需要额外COOP/COEP。网页触屏通过DisplayServer.is_touchscreen_available显示原双杆，不另造玩法。Chromium手机/touch模拟实际启动，触摸下射注入和截图完成，无脚本错误；favicon404非玩法文件。iPhone Safari真机、横屏、安全区域/性能仍未验证，浏览器版不能替代APK性能证据。

最简单用户入口是HTTPS链接。初次开通API返回403 Resource not accessible by integration；用户已在Settings→Pages选择GitHub Actions并授权继续。已核实Pages workflow设置与目标URL，新增限定feature/snappy-shot-burst分支push的网页部署（PR事件不发布），部署结果/真实URL检查见交接；不展开Mac/Xcode/证书/TestFlight。Safari真机仍待用户试玩，不以桌面Chromium证明iPhone。


## 提交、实际构建与发布状态

实现提交`d4878d20a3eb937acc3bed97788f6436f7c6c567`，[PR #14](https://github.com/zhipijun1996/gunman-rush/pull/14)叠加未合并#13/#12；未自动合并。随后仅补交接/证据，实际源码不变。

[push CI运行37912173147](https://github.com/zhipijun1996/gunman-rush/actions/runs/37912173147)：core（254断言与Windows）、Android、Web及各自产物上传均success；deploy_web因github-pages只允许main而failure，不能称整个workflow通过。独立文档CI成功。PR事件不发布网页。

[新版Android APK（ZIP）](https://github.com/zhipijun1996/gunman-rush/actions/runs/37912173147/artifacts/11606569311)、[Windows（ZIP）](https://github.com/zhipijun1996/gunman-rush/actions/runs/37912173147/artifacts/11606298993)、[Web文件（ZIP）](https://github.com/zhipijun1996/gunman-rush/actions/runs/37912173147/artifacts/11607585446)。保留7天；CI与本地签名/时间戳不同，摘要分开记录。debug APK覆盖旧包若出现签名冲突需卸载旧测试版再安装，不要求生产签名密钥。

Pages设置已由用户改为workflow，目标地址为https://zhipijun1996.github.io/gunman-rush/，但尚未证明内容已部署，不能把此地址当作已可玩的链接。读取部署环境仅允许main；当前连接POST添加试调分支返回403 Resource not accessible by integration。所需用户操作：Settings→Environments→github-pages→Deployment branches and tags，添加Branch规则feature/snappy-shot-burst（保留main），然后仅重跑失败部署；不合并PR来绕过。该项等待用户完成，Android包已经可下载。

本地命令实际退出码：check_docs0、py_compile0、diff-check0；run_tests0（254/0）；build android/windows/web各0；导出Windows PCK在Linux headless120帧0。故意失败入口保留，前轮实测1，本轮未重新运行，不伪造新增证据。Chromium手机触摸实际渲染0，Safari/WebKit测试运行时未安装，不继续展开复杂安装。所有本地日志在忽略的build/verification/shot-burst。

| 本地产物 | 字节数 | SHA256 |
| --- | --- | --- |
| `build/android/gunman-rush-debug.apk` | 28438635 | `475fa7c16cf849cc57ecb19caa11442e3bbb0bd23a1047bdb106d3490d038323` |
| `build/windows/gunman-rush.exe` | 103035904 | `5543ab4b6fb453c5dbe7f4effa0aad7f1cc06d73c12e8436adfc9fb266ac34ee` |
| `build/windows/gunman-rush.pck` | 178136 | `3beb39f7e83390aa9b17983cd4f44b383d029bdfc9361951e2a512dccf6212bf` |
| `build/web/index.html` | 5296 | `a7553c0e5cbcac9953f72a698b932244ad0991fdd39618863afa28faad48e8c4` |
| `build/web/index.pck` | 125576 | `414ab3dd1c48a5dc2e75942f80554956fb28b8338b7aa8ce70b6127e6d0e27cb` |
| `build/web/index.js` | 315645 | `ffc3898b59fba6f5af0c02f76e5ee526cc061e65c7d2d6f4f98186876cea15c4` |
| `build/web/index.wasm` | 37902138 | `11ea19645368f8e73cf337b59cfd7ceeb4ebb51f7a3bbf77d1a5c3ddfedbc522` |


远端CI包单独摘要：Android APK28342932字节、SHA256 `f66cbaf5e90b394c657315937240c2e33b53573e8679663dc66e870ff3536ace`；Web index.pck86232字节、SHA256 `a1422cf5139f9cd42a8c5c369888e2e25a5c41ec0c664de815a922db47549722`；均来自实现d4878d2。Cloud没有下载复验CI包，仅核实构建日志/上传step/产物API，APK签名和Chromium验证针对本地包。
