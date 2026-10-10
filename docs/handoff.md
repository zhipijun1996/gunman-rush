# 会话交接

2026-10-10 UTC。分支 **feature/ten-stage-menus**，从干净的feature/playable-demo-loop@060d881创建；已fetch最新main=64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226，PR #18仍OPEN。不自动合并、不强推、不覆盖他人改动。前轮证据见[三关demo历史交接](archive/handoff_playable_demo.md)。

## 本轮实现

RUN-TEN-01：主菜单可选三关快试或10关固定大关试炼；实际六类房间（Combat/Shop/Coins/Health/Items/Boss）、1–9推进、第9两个出口均Boss10。金币10、当前HP回血2、追加伤害/反冲/最大HP道具是可配置开发fixture，不确定正式平衡或血量奖励策略。重复道具房从合法权重池选两个不同候选；BuildState负责上限与互斥。领取、购买、出口及Boss奖励沿用幂等账本，回退不重置世界。

十关领取金道具后ENDING_BIOME/biome_complete返回Home，Meta.completed_biomes独立计数，不增加整局成功/失败，不把Q001未定的大关总数写成一个。三关仍development_only；正式10/10校验不变。随机地图GEN未实现，LEVEL-02真机门槛保留。

UI-01：主菜单栏、模式选择和Seed；局内MENU/Esc→继续/设置/操作/构筑/确认返回家园。隐藏旧直接reset，离开需LEAVE RUN，KEEP PLAYING保留当前局。取消旧输入与待提交交互、停止慢时，暂停世界时钟；菜单组件只发局部请求。统一Router接入左右灵敏度、触屏死区和手柄双阈值，非法组合拒绝。RESTORE DEFAULTS仅预览，还需APPLY；设置会话内新局保留，没有永久存储。HUD有独立背景与信息层次，窄横屏菜单可滚动。UI英文避免Web缺少中文字体。

Manifest记录实际输入值/修改、9个内容定义及版本、每关候选/选择/交易/结算；reward版本升2，旧reward1明确不兼容，schema仍1。地图固定，不宣称完整生成器或Run恢复存档。

## 实际验证

Godot4.7.2 Standard官方ed1daf0bf，保持现有引擎/模板。`python3 tools/run_tests.py`实际 **1012 assertions / 0 failures，退出0**，含editor import；保留前轮622，新增route119/reward63/menu15/实际十关场景193。三个Seed完整十关链覆盖六类型，两个9关出口Boss必达、一次结算与金奖励，菜单冻结/输入取消/设置继承/Leave确认均测试。初次集成曾Godot数组类型错误，wrapper正确返回1，修复typed Array后全套通过；不把只报告断言0失败但有SCRIPT ERROR视为成功。队列满警告来自既有有界队列测试。

`python3 tools/check_docs.py`27必需文档/34任务依赖/本地链接/契约退出0；`git diff --check`退出0。文档同步AGENTS/README/试玩/路线/输入/模块/路线图，旧阶段验收标历史基线。

`python3 tools/build.py web/windows/android`各自退出0；APK签名验证0。Windows仅导出，不宣称EXE实机通过；Android设备未连接，adb daemon refused提示如实记录，不影响export/signature。SDK CLI弃用/35.0.1 fallback提示不掩盖。本地APK SHA256=6f1d0a606ed1cc0d01b7cb33a83021b55229e8ba01c9216aefb5365bd67fc147（后续源变化重建以build_report为准）。

`python3 tools/verify_demo_browser.py`本地实际Chromium手机触屏模拟退出0：移动、多指跳跃/慢时黄边透明中心、真实松手弹体击败敌人、菜单设置/Escape回退、KEEP PLAYING与确认离开、十关入口；1280×720及960×540截图已检查，无SCRIPT/SHADER/PAGE异常。非阻塞favicon404保留日志。不是Android真机或iPhone Safari证据。截图/版本/报告在忽略的build/verification/demo；平台产物在build/{web,windows,android}。

## 提交、PR与公开试玩

代码提交 **c633f2fe93d7542d6998e4323a32cc898c4c4c19**；[PR #19](https://github.com/zhipijun1996/gunman-rush/pull/19) OPEN，base feature/playable-demo-loop，依赖未合并#18，不自动合并。工作流已为本分支配置独立Web发布路径。[文档CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/38008943487)success；[Godot/Windows/Web/Pages CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/38008943307)已success：core实际1012/0+Windows export/upload，web export/upload，deploy_web全部通过。Android CI按条件skipped，本地APK另实际export/signature0。

公开[新版Web试玩](https://zhipijun1996.github.io/gunman-rush/?v=fe6f2ed148da)已部署；build-info实际返回fe6f2ed148da与index.fe6f2ed148da.pck，区别于本地c1451b4df841。同一浏览器脚本已对公开版实际通过，退出0：新PCK HTTP200、Godot4.7.2 WebGL启动、三关/十关入口、移动、多指慢时、真实松手射弹击败敌人、菜单设置/返回与确认离开、960×540菜单渲染均正常，无SCRIPT/SHADER/PAGE异常。Android/iPhone物理真机仍待验证。

最终代码本地Web build_id=c1451b4df841，PCK HTTP200，重复实际浏览器检查退出0。Windows PCK在Linux引擎headless启动退出0，只是同包资源加载证据，不是Windows EXE实机。故意失败入口退出1。临时干净检出首次未设置共享工具链，默认fallback发现4.6.3，wrapper拒绝退出1；随后显式GUNMAN_TOOLCHAIN_ROOT指向已安装工具链，不更改引擎版本或提交绝对路径。干净检出c633f2f完成完整1012/0、退出0，临时worktree已移除。

## 未验证与下一项

LEVEL-02 awaiting-device：Android浏览器/iPhone Safari分别横屏，三次固定链通关、双杆多点、短长跳/向下反冲/慢时/遮罩/UI安全区与性能。十关内容也待真实试玩；Windows EXE、实体手柄、APK真机分别待验证。现有原创灰盒，不虚构音乐/完整美术。

GEN-01严格依赖LEVEL-02；当前可独立下一项ART-01原创风格样片与工具评估。Q001–Q013仍待决策；永久经济、SaveService、剧情、多大关串联、完整Steam集成未实现，不擅自推进需决策的兑换/精力/血量策略。

复现：`python3 tools/check_docs.py`；`python3 tools/run_tests.py`；`python3 tools/build.py web`（windows/android分别执行）；`python3 tools/verify_demo_browser.py [URL]`。网络命令20–25秒，import90秒、suite180秒、export180秒，有界失败，不承诺后台无限迭代。不提交SDK/引擎/密钥/机器绝对路径。

本代码验证和部署指向c633f2f；后续提交仅补充此交接与公开验证证据，不改变玩法。最终分支HEAD以git log -1为准，文档补证触发的后续CI须另看状态，不能冒称已经运行通过。
