# WINDCHIME-PIXEL-01 独立审查

审查者：`/root/pixel_golden_review`，独立于实施者 `/root`。只写隔离探针、日志和本目录；没有修改被审生产代码。按 AGENTS 最新像素小样规格及 gameplay-reviewer 执行。

## 输入与范围

本次用户授权是“继续尝试”：一屏像素晨光风铃平原候选。旧暖色方案仍为用户拒绝，不能追认；16区与正式两图/Boss/存档均不在本次接受范围。

初始基线 `300d65c81b61fdfd8d0e7223e9e5a7a60e32e8de`，审查实际 dirty worktree。Web 初稿 `c6a14a42d1ec`，本地真实入口 `http://127.0.0.1:8770/?pixel_plains=1`。该包早于 PX-01/PX-02 修复，不能冒称最终冻结包。修复后探针源哈希见 `probe-catalog-recheck.json`；最终冻结身份与最终 GPU 复验待补。

实际消费者：DemoApp 的 pixel_plains 入口 → PixelPlainsPreview → 640×360 SubViewport → PixelPlainsRoom。Camera zoom 0.5 保持1280×720世界范围，实际 PlayerMotor、既有单武器/资源、既有巡逻敌人消费新表现；不是概念图或全图贴片。

## 方法与证据

独立从时间/消费者矩阵构造反例：root viewport键盘分发、可站出生、catalog与manual pause交错、Restart、Home、旧生命周期、新弹体表现、视觉开关关闭后重建，以及目录全部47态的实际Control尺寸/边界。

- `probe.log`：初版17检查/2失败，证实重开丢失视觉开关状态。
- `probe-recheck.log`：上述原17检查修后全部通过。
- `probe-catalog.log`：加47图块实际尺寸/边界反例后111检查/50失败。
- `probe-catalog-recheck.log`：同一111检查在修复后全部通过，严格 run_engine 退出0，无脚本错误或资源泄漏。
- `branch.gd` / `branch.log` / `branch-trace.json`：独立真实连续上支路8检查/0失败。只在初始出生，没有传送、注资源、修改碰撞、禁用敌人或授予H/W/D。走150 → 跳272/366 → 走300 → 跳480/334 → 跳620/366落真实one-way → Motor request_drop_through → 落620/494石庭，epoch未变、HP未减。
- `draft-01-entry.png`、`draft-04-jump.png`、`draft-05-catalog.png` 为独立Chromium WebGL实际截图；1280×720，SwiftShader，不能视为实体设备性能。原独立完整采集位于 build/pixel-review/gui/；metadata/console 已精选保留。

实际用 view_image 看过独立 `01-entry`、`02-walk`、`03-shot`、`04-jump`、`05-catalog` 原件。正常走动、实际鼠标射击反冲、跳跃、catalog、Restart与Light/Wind切换由独立Playwright实际操作。保留50.64秒录屏，但没有完整播放或听音，不能签动画自然、完整视听或正常速度全路线体验。截图取样不能替代连续录像观看。

## 发现与复验

| ID / 类型 | 实际与预期 | 修复/复验 | 当前状态 |
| --- | --- | --- | --- |
| PX-01 / 客观状态缺陷 | Light/Wind关闭后Restart新建scenery/decoration恢复true，wrapper仍false。视觉开关应该跨重开保持一致。 | 实施者在Room持久化状态并在super.restart后重应用；原反例17/0，再111/0。 | 已修，最终Web尚待复验 |
| PX-02 / 客观布局缺陷 | 先赋texture再设size受TextureRect默认最小尺寸64钳制；随后IGNORE_SIZE不自动缩回32，47图块互盖且3块超出面板。`draft-05-catalog.png` 可直接看到。 | 实施者改先IGNORE_SIZE后size；独立逐块测actual32×32与面板包含，111/0。 | 已修，最终GPU尚待复验 |
| PX-V01 / AI视觉判断 | 入口x0–350/y480–720及右岸x864+大石体仍是均匀矩形内部的重复L/斜划。远景细腻而近景稀疏，近景32px节奏显眼，可能重现用户“廉价”反馈。 | 建议有界重画风蚀材质与边缘簇，保留安静面；不是均匀叠噪或新增整区。 | 首稿未准入扩产，待实像复审 |
| PX-V02 / AI视觉判断 | 主风铃架x944/y200–480笔直杆线，仅2色，缺乏接头/风蚀/铜锈，与背景石构精度不一致。 | 建议一轮完善主焦点材质与结构，保持落点可读。 | 待实像复审 |

反证自己的批评：晨光、冷暖与远近对比已经成立；背景拱桥/远塔虽然细密，但明显退后，已看图中没有证实其遮挡玩家/唯一落点。不能仅以“背景复杂”拒绝。固定一屏没有相机横移，不能据此签多屏视差、边缘补图或正式地图迁移。

## 阶段结论

技术仅接受已实测范围：SubViewport输入、局部生命周期、47态目录尺寸、实际新弹体consumer及无伤普通跳跃返回支路。未独立复跑整个正式战役、10种子随机、Boss、存档、所有输入设备或移动平台全相位，不能外推。

**首稿视觉为 REJECT 扩产；最终候选为 UNVERIFIED，等待有界重画与冻结包实像。** 用户审美/趣味、实体设备、完整听音与最终版本Web复验均未签。即使修复客观缺陷，也不能把技术pass变成用户认可或整个风铃平原完成。
