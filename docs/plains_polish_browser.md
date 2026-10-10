# 平原精修真实浏览器验证

命令：`timeout 260 python3 tools/verify_plains_polish_browser.py`（本地 `build/web`）；可追加公开 URL。总预算 240 秒，失败返回非零。使用 Chromium 移动触屏模拟、真实键盘/触屏、截图和 OCR；不读取引擎状态、不传送、不修改游戏脚本。需要 Playwright、Chromium、Pillow、Tesseract。

9 音符只在隔离浏览器首次加载时写入合法 SaveService fixture，用于真实按钮购买/刷新存档验证；不作为通过游戏赚音符的证据。脚本计划真实行走到家园工匠、购买、实际 reload、重新行走确认购买，再走到出发门进入正式十关，并移动/短跳留存表现截图。截图变化本身不等于已证明视差；远景与平台位移差需另行识别。

本地包 `286a7b8368cc` 两次有界运行均非零，未报告完成：首次宽范围 Home OCR 混入背景，精确 Notes 区域已修正；第二次实际 Title→家园 NOTES 9→D 行走到 Artisan→W 打开升级面板已执行，焦点升级按钮的白色字/浅金底无法被 OCR 定位 `SPEND NOTES`。购买、reload、出发门及平原表现仍未验证。首次与第二次失败保留在 `build/verification/plains-polish-browser/first-ocr-failure.json` 与 `browser-report.json`，实际屏幕保留 `title.png`、`home-initial.png`、`artisan-approach.png`、`upgrade-panel.png`。应先改善焦点文字对比度，再对新包重跑，不把当前失败改报成功。

真实 Android、iPhone Safari、完整十关、全 Seed 可达性、用户视觉与手感认可均未由此脚本验证。

焦点文字修复后的新包 `cd9d54510f45` 单次有界重跑，三个检查通过后非零停止：实际 Home 行走到工匠、W 打开面板、点击升级从9音符到4音符 / vitality 1，真正 reload 后重复行走检查仍为4/1；同包 ID 已核实。然后行走到出发门（真实画面提示 Plains / Begin adventure），第一次 W 未打开出发面板，`departure-panel.png` 仍是 Home，因此进入第一关和表现检查尚未通过。疑似键盘释放发生在面板禁用适配器期间，恢复后的首次 W 被旧 `_blocked_until_release` 拦截；已反馈，应修复输入取消/恢复边界后验证，不能把这一失败视为已进入关卡。`focus-fixed-run.log` / `browser-report.json` 保留此证据；旧第二次失败另存 `second-focus-ocr-failure.json`。

包 `99e75c94c91b` 修复输入释放边界后，第一次重跑实际购买通过，但固定1.35秒行走在刷新后仅到家园x约430，尚未到工匠，无法验证等级，未证明存档丢失（Home仍显示4音符）。随后工具改成单段30秒预算、观察真实ARTISAN/PLAINS提示的小步移动；授权重试时截图仍处 Godot 启动logo/进度条，因此真实 Title 断言非零停止。`networkidle + 800ms` 不能代表引擎可交互，需要进一步改为有界实际 Title 像素就绪等待。截图及日志均保存，不把加载中的画面误算通过。
