# 平原最新手绘素材接入

本轮按用户“使用最新的美术资源”授权，选择性接入 `origin/feature/painterly-plains-v2@3bacc32` 的 `assets/painterly_v2` 原始素材及来源清单；没有合并该美术分支的旧工程、旧设计或控制参数。原 PNG 保持 SHA256 不变，区域选择只在 Godot 绘制时执行。

## 当前实际消费者

`PlainsBackground` 使用最新天空、远山、草甸三层。它们不是已验收的循环纹理，因此采用全视口等比例 overscan 和有界水平漂移；关卡大高差不会造成竖向重复天空或空白。暂不使用无界循环视差，远景不是实际关卡地图。

`PlainsTerrainSkin` 共用于固定关、模块实验室和生成关：草岩平台与木板使用固定 0.14 的等比例像素尺寸，任意平台宽度以端头和中心裁切拼装，端头不拉伸；薄平台与移动板采用木材。站立锚点草岩 y=324、木板 y=295 对齐原碰撞平面，1px 细线明确真正落点。此为运行时裁切适配，不声明原画通过无缝纹理验收；中段重复接缝和手机缩小效果仍需视觉反馈。深岩填充继续用此前通过逐像素接缝检查的 SVG，最新 rock_fill 的边缘差高于内部变化，不将未通过的候选铺满场景。

锯轮使用最新黄铜原画，依据清单中心 (626.5,617.5) 裁切。按原 gameplay radius 等比例显示，危险圆轮廓保留，贴图不替代碰撞半径。安全锚点使用维修风铃站原画，底部与脚底对齐，高40世界单位；其画面不代表加血、家园或存档。

## 角色候选边界

原包 idle/run/actions 的20帧及武器全部保留，独立六动作候选可运行。包明确 `independent_aim_approved=false`：枪已画进身体，不能把默认玩家替换后声称360度瞄准正常。实际玩家继续使用已有独立枪向 CourierVisual；下一批需要无持枪身体及逐帧肩轴，保持 feet 原点、名义36高度、24×36碰撞。新图集不因“最新”而覆盖核心瞄准的正确性。

原图 alpha 边缘、远山少量青色轮廓、角色脚底校准与手机内存尚待检查。未用角色/独立候选、未通过的岩填充、README/来源 JSON 应明确从运行导出排除，原件仍在仓库可审查。不把源素材可加载当最终美术或真机性能通过。

## 实际检查

Godot `4.7.2.stable.official.ed1daf0bf`，均由 `bash tools/godot.sh` 调用。

- `python3 tools/check_painterly_pack.py`：退出0；13张 PNG 原件 hash、尺寸、20帧区域/pivot、六状态与非独立瞄准标记通过。
- `timeout 90 bash tools/godot.sh --headless --path . --editor --quit`：退出0；导入成功。编辑器扫描先前 build 截图出现重复UID警告；本机adb5037未启动，不能据此宣称Android设备通过。
- `timeout 90 bash tools/godot.sh --headless --path . --script tests/painterly_skin_runner.gd`：18断言/0失败，退出0；真实贴图导入、固定绘制比例、共享背景、三类viewport有界漂移覆盖检查。headless没有光栅画面，接缝/阅读性不能由此断言通过。
- `timeout 90 bash tools/godot.sh --headless --path . --script tests/player_visual_runner.gd`：20断言/0失败，退出0；默认角色独立瞄准、表现无资源与位置副作用、24×36碰撞及脚底对齐保持。
- `timeout 90 bash tools/godot.sh --headless --path . --script tools/check_painterly_visual.gd`：退出0；候选六动作、两朝向、144帧采样；仍是独立候选，不是默认角色替换。

- `timeout 180 bash tools/godot.sh --headless --path . --export-debug "Web Playtest"`（输出参数为临时试玩目录中的index.html，不记录本机绝对路径）：退出0。此次单独导出尚未排除未用新素材，PCK约14MiB，最终过滤后的体积由交接记录补充。
- 本地HTTP + Chromium真实Web渲染：主页点击 RANDOM STAGE、等待实际游戏、点击 MAP OVERVIEW，零 pageerror。截图保存在不提交的 `build/verification/latest-plains-art/entry.png` 与 `overview.png`，已目视检查最新云层/风车背景、草木平台及锯轮实际出现。总体视图的背景细节较强，细平台的对比和手机缩放阅读性待用户验；不将此两张截图冒称完整十关操作验收。

最终整轮回归与过滤后导出体积由交接记录补充；以上检查不替代Android/iPhone/Safari/Windows与最终风格用户验收。
