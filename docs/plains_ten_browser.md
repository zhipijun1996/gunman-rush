# 平原十关 Web GUI 验证

本轮工具 `tools/verify_plains_ten_browser.py` 保留旧 SVG/灰盒工具与断言，独立检查新平原正式生成消费者。使用 Chromium 触屏模拟、实际截图/OCR和普通触屏/键盘，不读取引擎状态或传送人物。总超时240秒，OCR每次8秒，页面加载45秒，任何失败退出非零。

验证范围：Home 的 Windchime Plains 十关入口；真实第一关的关号、金币/音符分离、触屏跳跃键与最新手绘纹理；第一对无缝模块的触屏横移与世界镜头；暂停时取消右摇杆瞄准不产生松手射击。

浏览器存储专项使用隔离浏览器 profile 中的**9音符存档 fixture**，通过真实 Home 升级按钮消耗5音符，然后真实刷新页面，检查4音符和永久生命升级等级1仍然可见。fixture 仅用于验证版本化存储读取、真实UI购买和实际刷新后的持久化，**不代表通过游戏操作赚取音符、通关或其他平台存储通过**。不以每次刷新重新注入 fixture 掩盖存储错误。

实际执行：`timeout 260s python3 tools/verify_plains_ten_browser.py`，本地 HTTP `http://127.0.0.1:8774/`，最终实际加载包 `212641aed7ad`，Godot `4.7.2.stable.official.ed1daf0bf`，最终退出0，**7项检查 / 0失败**。这是本地导出包证据，不声明公共 Pages 部署已更新。Home初始和刷新后的截图脚标OCR均为`212641ae`，与最终包ID前缀一致；执行期间运行源码和本地包均冻结。此前中间包`aec44988067e`也7项/0失败，其报告保留`intermediate-aec44988067e-pass.json`。

镜像首关实际触屏从 `WORLD X 220 / ROUTE 1/10` 移动到 `WORLD X -14 / ROUTE 2/10`，镜头 `CAMERA X -400` 保持玩家可见；截图同时显示局内拾取后 `COINS 1 / NOTES 4`。手绘天空和草地合屏已目视检查，世界区域225703种RGB颜色、天空25059种RGB颜色，只用于纹理渲染烟测，不代表用户最终美术认可。暂停前后截图相同，取消横向瞄准后人物横坐标未移动。

永久升级专项：独立fixture从9音符开始，真实按钮购买后4音符/等级1，真实页面刷新仍然4音符/等级1；不是重新注入fixture。结果与截图在忽略目录 `build/verification/plains-ten-browser/browser-report.json`、`reloaded-home.png`、`room-one-entry.png`、`touch-first-seam.png`，最近一次追加拾取探索的失败日志为 `build/verification/plains-ten-browser/second-note-exploration-failed.log`，不当作七项通过日志。

首次真实Web执行退出1，发现 `MetaSaveService.commit` 将JavaScriptBridge整数1与布尔true比较，运行时报错，余额保持9。已修复桥接返回值并重新导出，失败报告保留为 `first-failure-web-bridge.json` 和 `.log`。随后工具有两次OCR定位失败（数字0读成O、JUMP字样被复杂背景干扰），目视原截图确认值/按键仍正确；只调整数字0/O读法和文字裁剪，不修改游戏或降低玩法断言。失败报告另存 `second-failure-ocr.json`、`third-failure-ocr-jump.json`。最终脚本/page/shader错误检查均通过。

未验证：完整十关真实 GUI 操作、Boss 手感、两出口真实触屏选择、真实游戏拾取音符、Android/iPhone Safari 真机、性能和最终美术确认。SceneTree 的十关逻辑/物理证据单独记录，不替代这些证据。

实际音符拾取追加探索：同包212两次有界触屏尝试均退出1，分别只到WORLD X -121/-127、NOTES仍4，未到约-180的目标位置；CDP双指释放跳跃后横向触屏已停止，不能凭延长等待当成继续横移。无新增引擎错误。失败报告保留first-note-exploration-failed.json与second-note-exploration-failed.json。工具将此专项保留为可选`--collect-notes`，要求实际取得音符、确认回家与真实刷新，未达到时非零退出；默认七项已通过范围不变，不以存档fixture代替游戏拾取。

公开复验：代码提交`5bbc34d`的[CI 38030702436](https://github.com/zhipijun1996/gunman-rush/actions/runs/38030702436)全部通过并部署。[公开试玩](https://zhipijun1996.github.io/gunman-rush/?v=5bbc34d)实际包`ed504122edb4`，下载PCK计算SHA256与CI导出日志一致。针对该URL真实执行同一默认浏览器检查，7项/0失败、退出0；首接缝WORLD X220→−32、ROUTE1/10→2/10，CAMERA−400。真正购买与刷新仍是9音符独立fixture→4音符/等级1，未使用可选拾取探索，不扩张为实际赚币或完整十关证据。公开报告在`build/verification/plains-ten-browser/browser-report.json`，原本地报告/失败探索另留`build/verification/plains-ten-browser-local/`；运行日志`build/verification/plains-ten/public-browser.log`。
