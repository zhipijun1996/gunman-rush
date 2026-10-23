# DEMO-UI-01 R3：时间能量与无框 HUD

运行源码 `8dc2f4e6a2c6f511c22004784cb71b5f3d0d7a96`，Web build `5e9adddb1662`；分支 feature/demo-ui-01，[草稿 PR105](https://github.com/zhipijun1996/gunman-rush/pull/105)，不合 main。初始主线基线 e9ab0e0743466b8983e34cc7de17bab1abf9d53a，本轮反馈基线2cf83fa07e0b7aab0e36d44c25c2aaaf38a32d62。后续证据/文档提交不冒称重建运行源。

- [独立可操作 Web Preview](https://zhipijun1996.github.io/gunman-rush-previews/previews/DEMO-UI-01/8dc2f4e6a2c6f511c22004784cb71b5f3d0d7a96/5e9adddb1662/)：标题开始进入完整游戏，开发入口保留；刷新同一精确构建，不替换 main。
- [29.621333 秒真实 Godot 前后对照视频](https://zhipijun1996.github.io/gunman-rush-previews/deliveries/DEMO-UI-01/8dc2f4e6a2c6f511c22004784cb71b5f3d0d7a96/39407371e603/comparison.mp4)。前段为原 R2/source1d1d8368 的原字节录像，后段为本轮8dc2f4e；[单独新版14.8秒](https://zhipijun1996.github.io/gunman-rush-previews/deliveries/DEMO-UI-01/8dc2f4e6a2c6f511c22004784cb71b5f3d0d7a96/39407371e603/after.mp4)，[下载与来源](https://zhipijun1996.github.io/gunman-rush-previews/deliveries/DEMO-UI-01/8dc2f4e6a2c6f511c22004784cb71b5f3d0d7a96/39407371e603/download.json)。
- Pages [39890389002](https://github.com/zhipijun1996/gunman-rush-previews/actions/runs/39890389002) 已成功，托管提交981883aa5870a157199ff1909de49675b561a005。公开完整PCK146861240bytes、SHA5e9adddb1662e91690fb3d398534dc71e559e04e5bb3f21b1753ecfd20b9a3e0，与本地及页面/影片逐字节一致。main build703f9b040e5f/source9c349f44元信息前后相同。

本轮修改

开枪不消耗/不受时间能量限制，激光持续开火也不直接扣能；空中枪械和钩索实际慢时共用 AirFocus 唯一资源，按原真实秒政策消耗，接地渐回。慢时圆环读取实际人物Canvas位置与真实余额；取消、暂停、落地/结束慢时、死亡和解绑会清显示。既有单次飞行预算/耗尽再武装、伤害、冷却、存档和输入取消保持原规则。基础空中弹药改为配置1，现有实际命中/接地补弹保留，能力图标读取真实D/H资格，不预授能力。

左上去武器与底框：现有角色图集头像、右侧爱心与精确生命值、下方真实共鸣细线；单发弹药与已解锁且可用的二跳/钩索图标。成长后的爱心自动换行，数字保持一行。R2统一 Fusion Pixel 字体、圆角铜质按钮、标题背景/大钟Logo、四个真实主入口和暂停分页继续使用。

为避免原道具失效，5件旧耗能道具版本化接到真实现有慢时参数：握柄消耗×.8，铃匣接地恢复+5，绳索接地恢复×1.35，金回响接地恢复+10，风叶再武装门槛×.65；授予/重复/移除经BuildState重算。原图标不变，没有新增玩法属性或假资源。

共享边界与接入影响见[范围](r3/scope.md)：config单发、ShotEnergyDefinition政策版本、Controller可选历史Definition、ShotEnergyPolicy、激光guard、JumpAbility只读资格、BuildState/Modifier既有慢时参数、五道具/说明与生成Manifest政策标记。没有改 Motor、伤害、授予路径、拓扑或存档；Foundry36短语/18连续路线按原工具真实重验并stamp，不手换SHA。旧D079和高级两发测试显式绑定历史fixture；原断言/预算保留，新规则另注册Harness检查。

实际验证

- 同一干净8dc2f4e下，原Harness6组通过：core5681、actor-actions2872、all-weapons2381、action-budget7305、grapple六专项450、current time-energy140，均0失败。包含显式历史规则，不能把它们都叫当前新政策测试；新政策140项单列。
- 冻结UI6组通过：实际原生菜单/资源147，标题/字体/尺寸223，历史能源与正式App/lab537，地区生命周期27，原Underworld UI260，Cloud Preview25；手机窗口、鼠标、模拟触屏/手柄、焦点返回及输入取消在实际消费者验证。窗口尺寸与PNG viewport尺寸分别记，非实体设备。
- 正式地区原baseline：150强制家族+50自动家族生成样本及真实App，一发配置1274断言0失败；模块原门槛保留。未据此宣称自然完整探索或真人时长。
- 公网Chromium154：桌面10+DOM模拟手机11，21项0失败、engine errors为空；实际点标题/设定/原生选项/应用/暂停/返回/地图/缩放/关闭/触控取消。另实际鼠标持枪瞄准后跳跃采得人物环，再松手见单发弹药耗尽；不读取/注入引擎状态。原首张名为ring的候选截图其实已落地未见环，仅作失败定位，不把文件名当证明。
- 实际MovieWriter：880轨迹帧/888录制帧，1280×720/60FPS/48kHz stereo，受伤/恢复为明确官方policy fixture，跳跃/瞄准/开枪/菜单鼠标真实输入。不是自然战斗流程或目标设备性能测量。独审按0.25秒连续采样，不声称原速完整播放或听音轨。
- 独立审查[review-02](../../evidence/demo_ui_01/r3/independent/review-02.md)限定 ACCEPT；三项发现均保留原拒绝并修复复验：D飞行cap误报、地面H误报、增长生命数字换行。

已知边界与恢复

美术/信息密度仍待用户试玩评价，实体触屏/手柄、设备性能、完整Integration/Release未验。完整静态quality检查因稀疏工作区缺历史证据及中央任务未登记DEMO-UI-01实际失败，原日志保留；本线不越权改中央tasks/current_state/handoff、不恢复全仓历史。当前卡仅一致性通过，content_complete=false。production_plan因共享配置保守要求完整集成，由总控安排；没有改原断言/预算或把Development升签Release。

托管最终925761724/943718400bytes。仅本任务过期R2包与3份旧重复影片可恢复归档，完整SHA清单与原分块保留，已重建R2精确PCK校验。其他工作线最新页面/入口均保留，合并并发f71d956页面后再部署，无强推。R2视频与R1一份原视频仍在线。

恢复本轮：git checkout 8dc2f4e6a2c6f511c22004784cb71b5f3d0d7a96；使用bash tools/godot.sh（4.7.2 Standard）。专项入口 tools/demo_ui_01/run_time_energy.py；适用原Harness命令/预算和失败全件见[证据](../../evidence/demo_ui_01/r3/README.md)。此前交付保存在[r2_delivery](r3/r2_delivery.md.txt)。

请用户实际评价：头像/爱心与共鸣的大小、单发弹药是否一眼可读、时间能量环是否清楚且不挡人物、解锁D/H后图标消失/补充是否容易理解。
