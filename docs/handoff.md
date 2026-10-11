# 当前交接：D078 平原弹道、AI美术与空间战斗

[公开试玩](https://zhipijun1996.github.io/gunman-rush/?v=f2f5c883f8b5)已更新，版本f2f5c883f8b5；运行提交363095b0c73310f9570a03adae7119273c1d3a93。[发布CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/38159128675)成功，线上build-info.source_commit与canonical root新版本/资源标记实查一致。最终交接提交只补文档、证据和浏览器取样时机，不再更改已发布玩法。

分支feature/plains-spatial-combat-art从最新远端D077的16dee9a0ac187993790e8fcc699748a97f65fac2建立，初始工作区干净；已fetch核实main为ab51fca及PR41–46 OPEN，继承有效修复。[PR47](https://github.com/zhipijun1996/gunman-rush/pull/47)以feature/plains-pressure-boss-redesign为base，只审查D078差异，保持OPEN，不自动合并。[D077归档](archive/handoff_plains_pressure_boss_d077.md)、[当前实现](plains_spatial_combat.md)、[验收证据](evidence/plains_spatial_combat/verification.json)。

玩家独立弹体持续重绘AI弹头/七点尾迹；实际鼠标与枪口射线对齐，快照扣扳机前枪口，消除反冲姿态事件再偏移。保留18px铃芯、3px弹体/1200弹速、地形挡弹与资源。小Boss正式采用AI中央大铃机身、木铜轮/木支架，旧SVG无正式消费者；苔木无人机与完整AI平原全景接入。地下色带/固定矩形改为连续世界深度雾，既有AI角色/地形/机关复用。三个原始生成PNG保留哈希/来源/透明/裁剪/消费者证据。

正式牧风者36HP与三阶段保留，storm资源版本3；第二阶段风场攻击持续−70左向速度，背铃只接受上侧向下射击，箭头/HUD/护甲提示真实消费。原安全断桥/死亡优先/奖励账本保留。摆渡交接、齿轮落点、射铃窗口优先配置三类实际模块俯冲拦截，稳定ID、115px俯冲、边界/实体避让、45px安全锚点/视线/预警/恢复/同时攻击限制保留。敌人预算18/26、掉落预算不增加，不要求清怪。PlayerMotor、player_tuning与input_profile逐字保持D077版本；仍一跳/两发、只平原两图，Boss后后续开发边界安全返回。

本地及发布CI：Core5942/0、原43套通过、地区五套47/3484/4961/27/22全部零失败；Web/Windows导出成功。文档33项/124任务依赖、世界16/29/6、96目录美术和各AI源包检查通过。100图有三骨架、39/44连接图、13/26早到Boss行程、至少5环和9/8分岔，无保底；实际三类模块遭遇覆盖两图，首图18敌人，次图17–26（平均23.62）。本地PCK cf7042577269与CI公开PCK f2f5c883f8b5分别记录，不假定跨平台导出字节相同。

最终本地和公开网页实际GUI均通过：普通鼠标瞄准开放铃芯后小Boss16→15、飞行弹头/尾迹、16/36HP独立练习；正常Title→Home购买/重载保存→正式随机20/23节点地图，迷雾不泄露未知目的地，点击/缩放/拖动/关闭和实际音频有输出。Home购买使用隔离9音符fixture，不冒称实战赚取。截图/录像/日志存build/verification/d078-local和d078-public，命令/哈希/范围在验收JSON中；完整真人两图通关、手机/手柄/Windows实机和画风/难度待玩家验收，任务保持review。

失败过程保留：风场血量fixture、首次遭遇类别分配、旧中心射线断言、奖励压力显式类型、发射姿态偏差及严格擦边/风铃井探针均已修正后复验，不删除断言/放宽碰撞/增加动作资源。公开第一次自动命中因OCR耗时约2.6秒错过开放窗口；保留失败日志，等待实绘铃圈关闭再新开放后立即点击，保留正常16→15断言，不改游戏窗口。远射取样先因Boss关闭/下一草台真实挡弹而失败，改为正常地面移动到Boss右侧、射向无遮挡通道，以只读合成器连续帧验证实际移动尾迹；不修改挡弹/弹速/游戏状态。原headless清理警告与网页favicon404保留。

复现：python3 tools/run_tests.py、run_plains_ten_tests.py、run_plains_region_tests.py、check_docs.py、check_world_design.py、check_plains_spatial_art.py；python3 tools/build.py web/windows。实际GUI：GUNMAN_RECORD_GUI=1 python3 tools/verify_plains_pressure_boss_browser.py [URL]；GUNMAN_RECORD_GUI=1 GUNMAN_AUDIO_PROBE=1 python3 tools/verify_plains_region_browser.py [URL]。后续玩法迭代继续发布已验证ref并核对线上，不自动合并PR。下一任务是玩家实测上侧射铃/持续风场、模块拦截和上下层画风/探索节奏；本轮不扩展森林或能力系统。
