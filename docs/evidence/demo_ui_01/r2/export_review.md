# DEMO-UI-01 R2 冻结源码／导出限定独审

审查者 `/root/independent_review`，非实现作者，2026-10-23。此次只读检查 Git、既有报告和实际截图／影片抽帧；未运行 Godot、浏览器、导出或生产修改。唯一新增文件为本报告。前次静态方向结论与缺口见 `complete_review.md`，不把 R1 用户拒绝冲销。

**限定 ACCEPT：下述两个提交的运行源码树等价、冻结专项证据可归属、实际桌面 Web 菜单／HUD 静态输出与所审 R2 方向一致。** 手机浏览器当前报告存在失败项，整体手机 Web 操作不签通过；完整影片播放／听音、实体设备、用户审美与完整 Integration／Release 均为 **UNVERIFIED**。本结论不是公开部署成功证明。

## 源码与测试变更

- Web 与本轮影片运行源：`1d1d8368ffd03de38e59fbd1140d44c5ba95c403`，Web build `7127eaf8cef7`。
- 最新冻结原生专项源：`dce1a7172fd122ed1fd7f1e7d3263c87caf5d74b`。检查时 HEAD 为此提交，`git status --short` 为空。
- 实际读取完整 `git diff 1d1d8368..dce1a717`：**全仓唯一差异**为 `tests/underworld_plains/test_underworld_ui.gd` 的三行新增，点击 helper 在调用祖先 ScrollContainer.ensure_control_visible 前等待4帧，以免尚未结束的焦点恢复撤销滚动。没有删除断言、改预算或改生产行为。
- 另实际运行定向 Git diff：`scripts assets scenes config resources tools project.godot export_presets.cfg` 无差异。因此两提交的运行／资源／项目／导出设置树相同；不是说提交对象相同，也没有把 dce1 的测试执行冒称1d1当时执行。
- 实际读取1d1的原 MENU 断言迁移：旧 `UnderworldUI.INK` 色值快照替换为实际 App MENU 与 HUD 共用 `_chrome_theme` 的身份，以及有效 CompactButton 正常底色。仍检查原正式消费者；对应用户要求的圆角材质替换，未以保留被拒黑底来满足旧截图色值。1d1其余影片阶段 trace 标注不改变伤害／恢复／资源生产规则。

## 实际看过的文件

本次逐一用图像工具打开：

1. `build/verification/demo-ui-r2/browser-local-v4/desktop-pause.png`
2. 同目录 `desktop-actual-hud.png`。
3. 同目录 `mobile-title.png`，为额外核实失败断言的静态表现。
4. `build/verification/demo-ui-r2/frozen-v3/native/title.png`
5. 同目录 `formal-hud.png`。
6. `build/verification/demo-ui-r2/film-v2/frame-03.png`
7. 同目录 `frame-05.png`、`frame-07.png`。

原生标题名称／四项主按钮与钟表徽章完整；正式 HUD 的爱心、精力刻度、弹匣、独立钱包及导航与前次准入方向一致。实际 Web 桌面图的中文字没有方框，MENU 确有圆角、铜边及厚底边。暂停页标题、页签、金色继续按钮、设置／说明及返回家园清楚，装备页保留禁用及未开放说明。Web 截图带 build 短号与开发 Preview 标识，未把原生截图当作 Web 像素。

额外手机标题图左右为黑色 letterbox，四项主操作、中文名称与右侧徽章肉眼均完整，未见可确认的裁切或重叠；这不能自行把自动断言失败翻为通过，也不证明后续触控流程完成。

影片 frame-03 显示5/5生命的恢复青色与“恢复 +1”，frame-05显示4/5生命及真实暂停页，frame-07为真实早期迷雾地图。地图已探索区域对比偏弱的低优先问题仍在；未将迷雾空白误称缺失地图。只审了这些抽帧，不能凭静帧签连续反馈节奏、声音或影片无卡顿。

## 冻结原生专项证据

读取 `build/verification/demo-ui-r2/frozen-v3/report.json`：source commit dce1、工作区干净、`source_stable=true`，九个 targeted rows 均 exit_code0／passed。交叉读取各原始日志的完成标记：

| 专项 | 原始计数 |
| --- | --- |
| UI contract | 146 checks／0 failures |
| R2 title／font／native GUI | 223／0 |
| original Underworld UI | 260／0 |
| cloud preview | 25 assertions／0 failures |
| legacy | 101／0 |
| settings lifecycle | 14 assertions／0 failures |
| grapple focus HUD | 25／0 |
| menu scroll touch | 44／0 |
| art | 222 assets，hash／尺寸／pivot／SVG 检查 passed；设备视觉明确未验 |

前八项合计838，素材222不是额外222次游戏交互。都是实现者实际执行、独审核查的 Development 专项；本独审未另起引擎执行。`frozen-v3/report.json` SHA256：`3e6b93bcd7f2e54bec9aa529a7c976f7d6964dfadd09f8fd13d3cc3a71a567f4`。

## 本地 Web 证据边界

读取 `browser-local-v4/partial-report.json`、`desktop-console.json`、`desktop-events.json`。实际 URL 为本地服务器 `http://127.0.0.1:8765/previews/DEMO-UI-01/1d1d8368ffd03de38e59fbd1140d44c5ba95c403/7127eaf8cef7/`，不是公网可访问证明。

桌面10项 passed：标题、设置、实际 Popup 指针提交并关闭、Apply、主入口正式平原、MENU暂停、设置Escape回暂停、地图、关闭、首个Space不重开UI。事件记录证明装配正式 Plains，seed `level-design-v2-baseline/08`，manifest `bf16916866572af8d7e96e9e80b11a840282e02b152c4bdfb62f4015176cc51f`。报告 `errors=[]`；console 同时保留一条404资源请求，不能写成零 console 异常或擅自判定其具体资源。

截至读取时，partial report 还包含 mobile 标题断言 **passed=false**，其后手机 Popup／滑动／Apply／暂停／地图等完成证据未见。该失败不是已证实产品故障，但此轮不能签整套 Web／手机通过。必须保留原失败并在后续准确归因或追加新证据，不能只因静态标题看起来正常忽略报告。

## 影片归属与载体

读取 `film-v2/report.json`、`after.json`、`before.json` 和提帧日志。报告 source1d1、clean、`source_stable=true`、Godot MovieWriter运行passed。新 after trace 为880帧，旧 before900帧；双方 damage_observed／heal_observed／shot_cost_observed 均 true。它们来自正式伤害 policy／SupplyHealEffect 的显式 fixture 与真实跳跃／瞄准／松键射击，不能称自然战斗路线或设备性能证明。

before 精确复用原 R1 `df5207ccc920f5d48813412a27d9d72dc79510ab` 影片与自己的旧 driver归属；after为1d1。新 driver 接受实际中文操作元数据、最后静止尾段短20帧；原报告明确列出输入位置和时长差异，没有重标旧片为新源。不是完全逐帧等条件前后对照。

本人用 ffprobe 检查 comparison.mp4：1280×720、H.264、60fps、AAC音轨，时长 **29.954667秒**；有音轨不等于本人听过。实际重新计算 comparison SHA256为 `4df0009a01755edb7492825954582a996c0faeb53b990822c1b773c8be0a9523`，after trace为 `496d49d417b12134875bdaa5f22607ff02b80c31ca045dc442c05e2baba03b3d`，before trace为 `a61f32f9fbc573066081703c01b250bc083fcbf6f0b3516c5811a13dfde693a0`，与报告相符。

未完整播放、未听音轨、未亲自操作本轮浏览器或实体设备，未验证公网托管、完整PCK下载与最终视频公网身份。本报告不越过以上边界；不存在用 R1 公网通过代替 R2 的认可。
