# 平原精修真实浏览器验证

命令：`timeout 260 python3 tools/verify_plains_polish_browser.py`（本地 `build/web`）；可追加公开 URL。总预算 240 秒，失败返回非零。使用 Chromium 移动触屏模拟、真实键盘/触屏、截图和 OCR；不读取引擎状态、不传送、不修改游戏脚本。需要 Playwright、Chromium、Pillow、Tesseract。

9 音符只在隔离浏览器首次加载时写入合法 SaveService fixture，用于真实按钮购买/刷新存档验证；不作为通过游戏赚音符的证据。脚本计划真实行走到家园工匠、购买、实际 reload、重新行走确认购买，再走到出发门进入正式十关，并移动/短跳留存表现截图。截图变化本身不等于已证明视差；远景与平台位移差需另行识别。

本地包 `286a7b8368cc` 两次有界运行均非零，未报告完成：首次宽范围 Home OCR 混入背景，精确 Notes 区域已修正；第二次实际 Title→家园 NOTES 9→D 行走到 Artisan→W 打开升级面板已执行，焦点升级按钮的白色字/浅金底无法被 OCR 定位 `SPEND NOTES`。购买、reload、出发门及平原表现仍未验证。首次与第二次失败保留在 `build/verification/plains-polish-browser/first-ocr-failure.json` 与 `browser-report.json`，实际屏幕保留 `title.png`、`home-initial.png`、`artisan-approach.png`、`upgrade-panel.png`。应先改善焦点文字对比度，再对新包重跑，不把当前失败改报成功。

真实 Android、iPhone Safari、完整十关、全 Seed 可达性、用户视觉与手感认可均未由此脚本验证。

焦点文字修复后的新包 `cd9d54510f45` 单次有界重跑，三个检查通过后非零停止：实际 Home 行走到工匠、W 打开面板、点击升级从9音符到4音符 / vitality 1，真正 reload 后重复行走检查仍为4/1；同包 ID 已核实。然后行走到出发门（真实画面提示 Plains / Begin adventure），第一次 W 未打开出发面板，`departure-panel.png` 仍是 Home，因此进入第一关和表现检查尚未通过。疑似键盘释放发生在面板禁用适配器期间，恢复后的首次 W 被旧 `_blocked_until_release` 拦截；已反馈，应修复输入取消/恢复边界后验证，不能把这一失败视为已进入关卡。`focus-fixed-run.log` / `browser-report.json` 保留此证据；旧第二次失败另存 `second-focus-ocr-failure.json`。

包 `99e75c94c91b` 修复输入释放边界后，第一次重跑实际购买通过，但固定1.35秒行走在刷新后仅到家园x约430，尚未到工匠，无法验证等级，未证明存档丢失（Home仍显示4音符）。随后工具改成单段30秒预算、观察真实ARTISAN/PLAINS提示的小步移动；授权重试时截图仍处 Godot 启动logo/进度条，因此真实 Title 断言非零停止。`networkidle + 800ms` 不能代表引擎可交互，需要进一步改为有界实际 Title 像素就绪等待。截图及日志均保存，不把加载中的画面误算通过。

最终测量工具统一改为真实截图就绪轮询：启动/重载最多45秒等待ENTER HOME；NPC最多30秒小步行走等待实际提示；面板最多10秒等待对应标题；整次240秒上限。包 `99e75c94c91b` 该次命令 exit0，**6项检查通过**：Title→真实 Home，实际工匠购买9→4音符/vitality1，真正 reload4/1，同包实际出发门进入COMBAT1/10，真实移动/短跳前后截图变化，无script/page/shader错误。`visual-ready-run.log` 与 `browser-report.json` 为本次最终技术证据，旧失败均单独保留。

实际截图 `room-entry.png` / `room-moved.png` 的角色明显增大（约55屏幕像素高），但背景仍强蓝色/亮白云，不代表灰度雾化已通过；已反馈远景 shader 末尾 `* COLOR` 可能将原始已采样纹理再次乘回，需独立修复和截图。该短移动未获得足够镜头横向位移，尚未证明分层视差，也不能只凭截图变化宣称粒子视觉验收。最新表现须在对应修复的新包复验，6项技术成功保留其真实范围。

对同次 `room-jump.png` 进一步真实画面核查：HUD NOTES 从入口4变5，普通行走/短跳确实拾取一枚音符；本次未额外刷新新赚5音符，不能宣称这枚的刷新持久已验证。镜头已随短跳后的移动滚动：同一前景平台右边缘约从x947到x622（约-325px），入口云层块 `(190,310,120,80)` 在短跳截图全RGB位移匹配 `dx=-13, dy=0, MSE=3.2503`（搜索dx±80/dy±8）。远云与前景速度不同，构成真实相对视差证据；先前仅观察room-moved未发现镜头位移的结论被room-jump这张补充证据细化。完整观察保存 `visual-observations.json`。灰雾颜色仍未达成，粒子暂未获得独立清晰验收。

## Shader 修复后最终 WebGL 证据

最新包 `39edfde252ed`：`timeout 260 python3 tools/verify_plains_polish_browser.py http://127.0.0.1:8778/` **exit0，8项检查通过**，报告 `browser-report.json` / `shader-fixed-run.log`。工具在本次追加真实赚币验证：普通行走和短跳实际令 NOTES 4→5，按Escape打开暂停、点击RETURN TO HOME、点击LEAVE RUN确认后家园显示5；实际 reload、真实ENTER HOME后仍5，同包ID已核实。这个新增音符来自实际游戏，9音符初值仍明确为购买fixture，两类证据没有混淆。

实际截图 `room-entry.png` 显示灰蓝、虚化、雾化远景，草色平台/危险/角色维持更强颜色；旧shader蓝色问题已在新包真实WebGL中修复。无HUD背景区 `(700,180,1000,400)` 平均RGB最大最小通道跨度从旧包102.97降为16.63。实际 `room-jump.png` 云块匹配dx=-10、dy=0、MSE0.641，前景同一平台右边缘约x947→702（约-245px），不同位移证明层间视差；角色屏幕高度约55px。观察保存 `visual-observations-shader-fixed.json`，色彩指标只证明去饱和实际渲染，不代表用户主观认可最终美术。枪口/反冲拖尾/独立粒子清晰截图未纳入本次已启动的实例，仍待视觉验收，不把移动截图变化当作粒子通过。

此为 Chromium SwiftShader WebGL 软件图形管线实际渲染，不是真实Android/iPhone硬件GPU验收；公开部署对应包另行确认，不能用本地URL替代公开版本证据。
