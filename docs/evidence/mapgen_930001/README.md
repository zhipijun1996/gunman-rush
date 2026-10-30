# MAPGEN-930001-01 验收记录

## 当前 candidate-v2：新版正式平原表现（2026-10-30）

用户指出 v1 美术错误：固定宿主漏接正式表现层。下面原 v1 图、原测试和原 Web 包保留作历史，不能再当作本轮美术交付。

实际冻结源码 `cce9d74f408f2229d092909f88054a177de2668d`（生产修复 `6f1ae4b`）：复用当前正式 native32 草岩、三层背景、玩家身体、机关/移动台/刺面、光照与前景；18只原怪物仍为13 diver、4 sentry、1 charger，后两类使用当前 PlainsRevision 身体，diver沿正式 aerial反馈身体，不抽怪、不改AI/HP/掉落。M29金色占位改用正式medium蓝箱闭/开姿态，原交易与脚底支撑不改。独立预览提供主游戏同款唯一V2音频服务，两个feel同享原12声池。

- [实际出生](art-v2/spawn.png) · [M06哨兵/俯冲怪](art-v2/M06-sentry-diver.png) · [哨兵受击](art-v2/M06-sentry-hit.png) · [M28冲锋怪](art-v2/M28-charger.png) · [14.33秒真实Godot影片](art-v2/plains.mp4)。影片保原连续0–859帧；M06/M28为明确观察位置fixture，未改怪/补资源。源前后3378项（含producer）一致，[媒体回执](art-v2/receipt.json)不签自然整图或用户审美。
- 最终[严格回执](art-v2/final-report.json)：**845项，842通过、3失败**；3377运行输入前后稳定，实际exit1，原M24站立/领取/完整11点覆盖失败完整保留。[原生日志](art-v2/final-native.log.gz)和[全轨迹](art-v2/final-runtime.json.gz)。原721套件不删断言，追加124项；含原18只怪的正式身体绑定、旧地形只隐藏绘制/无新碰撞、Boss断桥后视觉并集/阴影同步、真正bootstrap单服务/旧服务释放/返回session-only菜单、新箱闭/开交易状态。
- 原art-art、underworld-terrain、underworld-formal、underworld-mechanisms四项Harness fresh通过；修改bootstrap后cloud-preview-runtime与underworld-formal再fresh通过，原[相关日志](art-v2/related-harness.log.gz)与[宿主日志](art-v2/host-harness.log.gz)保留。完整168 Integration/Release未执行；docs仍是原3条归档相对链接失败，[本轮原输出](art-v2/docs-final.log.gz)。
- 最终cce源又完成原6项串行fresh检查：上述4项＋cloud-preview-runtime＋underworld-player-animation，实际6/6通过、exit0、无源漂移，[最终Harness回执](art-v2/related-final-harness-report.json)。此前并写文档的一次、Godot自动补148个历史docs导入伴随文件的一次，均被严格源冻结拒绝，失败原件保留；第三轮先预热并保留这些伴随文件再冻结，不改guard/预算。退出后仅清理未跟踪的历史docs自动导入文件，不修改已测生产字节。[最终独审](art-v2/review.md)限定接受表现接入，整图仍REJECT。
- [M29真实右缘落地](art-v2/M29-landing.json)：正中完整身体[208,45.9]命中Seal_C；封口[128,0,128,32]到单向平台y64仅留32px，玩家36px，不能把中心当站点。右缘[270,45.9]无overlap；从[270,20]实际落到[270,46]、grounded=true，距原箱62px<80交互半径。此前两次正中落点影片的claimed=false和图片按failed-center保留。没有为了美术改封口、平台或玩家物理。
- [M29闭箱](art-v2/M29-edge-closed.png) → [原生选择菜单](art-v2/M29-edge-menu.png) → [开盖＋4金币](art-v2/M29-edge-open.png)：独立GL右缘fixture后真实W和鼠标点击(465.5,530)，未调用choiceAPI，[实际回执](art-v2/M29-edge-gui.json)显示grounded/claimed/openpose=true。它补足本地原生GUI选择，仍不签自然到达或浏览器宝箱选择。
- 较早[Boss第三阶段GL画面](art-v2/M40-phase3.png)及9/0日志仅绑定pre-keepout开发源，未重标最终SHA；最终845中的真实原生Boss战仍检查断桥后无旧地形/旧遮光体。最终源Boss图形全状态与全部动态相位未签。

Web build `6726edd6c91b`，PCK 230,181,840 bytes，SHA-256 `6726edd6c91b0bb32daa3f9472dc3afc25f1ecee21d4ede46d1ae3e74976c6cf`。原722交付文件再次verify通过；PCK在无源码目录启动46实例通过。本地真实Chromium/SwiftShader已看[新版出生](art-v2/web-spawn.png)、总览、射击移动、暂停恢复、[返回正式标题](art-v2/web-return-menu.png)，无uncaught JS/native错误；完整console仍保Emscripten主线程阻塞与软件ReadPixels警告，不签性能或console零error。

新版本地包 `build/mapgen_930001/mapgen-930001-web-6726edd6c91b.zip`，495,289,806 bytes，SHA-256 `93d59ddf1f4443194745a85c0b2af253b055951bd4c90d74e2b24e28129cae39`；解压后 `python3 serve.py --directory . --port 8807`。完整[构建身份](art-v2/build.json)。公开独立preview再次被原900MiB守门拒绝，[原日志](art-v2/stage-preview.log.gz)保留；没有发布新网站或提高上限。PR123续同分支，不合main。

M24缺口、整图从出生经六奖励到Boss的自然连续路线、所有动态相位、完整168、听感、设备与当前用户视觉认可继续failed/unverified；不得用这次换肤和局部实测签整图完成。

## 以下为原 candidate-v1 历史

状态：开发接入，尚未认证全图自然通关。静态核验、真实玩家局部输入、物理扫掠、显式位置 fixture、GUI 和设备分别记录。

- 交付 ZIP SHA-256：`1c190a0a3918ece39e3a3aac7d35dbc855b9f4c87ebafbaa11f32c820a333b25`，原始 722 文件 verify_delivery.py PASS，见 [原校验回执](delivery_verification.json)。
- [宿主静态兼容审计](host_compatibility.json)：1600 路径，1529 一致、71 变化、0 缺失。不覆盖主游戏历史资源。
- [独立审查](review.md)保留发现、修复及未验状态；全图自然通关、所有机制动态相位、实体设备与用户认可未签。
- 操作和重跑入口见[运行说明](../../worklines/mapgen_930001/README.md)。最终运行记录与失败清单将附此目录，不以静态校验冒称物理通过。

已确认的具体交付缺口：M24 / idea-orbit-choice-001 / Port C，gear-seal [256,0,128,32] 覆盖奖励唯一支撑 [288,32,64,16]。原领取 region [300,-10,80,56] 内所有可站身体候选与 Seal_C 相撞；站在封口上方的玩家中心 y=-18 又在领取区域之外。本房不是六个目标奖励房，奖励、封口及原始数据完整保留，禁止移动奖励、开封口或补造 Route 来签通过。

## 当前实际结果（acceptance-04，提交前源稳定实跑）

Godot4.7.2 / headless1280×720 / 60Hz，原包装器exit1。721断言718通过、3失败均来自M24站立/领取以及严格11点覆盖。原始运行报告见 [运行明细](acceptance-04-runtime.json.gz)、[原生日志](acceptance-04-native.log.gz)、[包装回执](acceptance-04-report.json)，源前后3376项逐件一致；没有脚本/资源退出错误。

- 46实例精确Block平移、唯一地形、18条原生敌人记录、11奖励点全部存在；另保留M29原生二选一宝箱。
- M01(96,206)真实落地→原生射击开铃→M02.R连续通过；HP5、同一Player与原配置，未传送或补充资源。
- 55连接的权限/真实完整身体扫掠已检查；7个向下单向接口补实际原生drop_through。它们是端口局部初态诊断，不是连续模块路线。40封口均命中该封口实际碰撞体。
- 10/11奖励点实际领取（共72金币）；六目标奖励M41–M46均通过，11点完整覆盖保持失败。M29分别在独立局真实W打开原生OR菜单、经声明的原生选择API确认4金币或1音符，重复请求不发钱；尚不冒称实际鼠标点选。
- M41普通与M43奖励配对门同局卸载/复建、wrong-wallet拒绝、claimed状态/门状态/不重发金币均通过。复杂实例卸载明确拒绝并保持活实例；不提供完整跨进程存档。
- M40实际入口fixture后全战无再传送/补血/调参：36原生射击，Boss36→0，经历1/2/3阶段及断桥，玩家5→3HP，outcome=victory且lifetime结束；exit实际封口战后仍挡。另用明确事务fixture验证同帧玩家死亡优先，不能把该负例当自然战斗。
- 原生M/Esc、旧鼠标取消、恢复后新D/新射击、原生宝箱暂停所有权均通过。

## 运行图与导出

[实际出生画面](spawn.png) · [实际装配总览](overview.png)。OpenGL4.5 llvmpipe/Xvfb1280×720，真实Godot帧；总览与交付reference/seed-930001.png的实例方位/镜像标签对应。不是概念图，不代签完整美术/设备。

Web导出第一次拒绝插件枚举API错误，修正为现有导出失败路径后，第二次被旧Foundry basis拒绝。使用原生foundry build --count24 --promote实测重建（36短语/18行程）后，Web实际导出成功；此为主游戏已有开发池导出守门，不移植map-gen算法。原包722原字节在PCK内保留。已在无源码的隔离目录使用实际PCK启动固定场景，MAPGEN_READY=46，出生(96,206)。首次包绑定开发基线，最终准确source/build与发布状态另附，不将该包标签冒称新提交。

## 失败及未验证

all-dev01=670/133（真实镜像复制缺陷与诊断初态/单向着陆解释错误）；all-dev02=719/9；acceptance-03=721/8；所有原报告/日志压缩保留。测试的延迟load场景曾导致脚本资源图退出保留，常量preload固定加载次序后claim-preload和acceptance-04实际clean；未修改生产清理逻辑或屏蔽诊断。

完整production_plan按新边界保守升级为168项，目前未执行完整Integration/Release。docs专项在实际补齐输入后仍有3条main已有归档相对链接错误，原日志保留；未改历史归档来冲绿。任务质量记录结构可验证，技术/全图状态明确failed/blocked，不声明done。

## 最终冻结源与本地 Web（2026-10-30）

运行源 `b2f71528b2516a6cada72bc726834e9a05c0cf4f`（后继仅交接/证据）。在该精确源上重新实跑的 [最终回执](final-report.json) 仍为 **721 / 3失败**，3376运行输入前后稳定，native退出clean；[完整原日志](final-native.log.gz)和[完整轨迹/断言](final-runtime.json.gz)保留。

Web build `054648325c2e`，完整PCK 230,175,116 bytes，SHA-256 `054648325c2e495711e657b494e354d5d6215d7981d97e7a8998bb616277d00c`。原字节打包曾被严格PCK解析器发现配置重复条目；只增加正常导出skip来确保单次收录，完整SHA检查不变。最终PCK在无源码目录实际启动exit0，MAPGEN_READY46。

本地Chromium/SwiftShader1280×720实际加载现有CloudPreviewBootstrap的固定场景，真实指针打开风铃、D移动、M总览与Esc恢复，无uncaughtJS或SCRIPT错误。[操作后画面](browser-after-input.png)与[实际返回主游戏标题](browser-return-title.png)已由独审查看；返回后正常标题/开始游戏/继续/设定/新手教程可见，原bootstrap console确认persistence=false。原console保留Emscripten主线程阻塞与ReadPixels警告，未宣称性能或所有consoleerror为0。M29二选一尚未实际鼠标点选认证。

[构建身份及ZIP指纹](build.json)。本地Web包 `build/mapgen_930001/mapgen-930001-web-054648325c2e.zip`，444,566,770 bytes，ZIP SHA-256 `8ad6648fdeb99c63fc321b9a06888bf2249bb3633ca68da3a46360b9d88ef118`；解压后 `python3 serve.py --directory . --port 8807`，打开 http://127.0.0.1:8807/。包含准确原包、完整主游戏菜单与固定地图启动参数。

公开独立Preview实际staging被现有900MiB（含PCK重建）上限拒绝，未发布/未覆盖旧站/未提高上限，[原拒绝日志](stage-preview-03.log.gz)保留。GitHub草稿[PR123](https://github.com/zhipijun1996/gunman-rush/pull/123)已推送；main未合并。M24/自然全图仍BLOCKED，不扩展其他seed。
