# 当前交接：D077 平原路线压力与Boss重设计

分支 `feature/plains-pressure-boss-redesign` 从最新 `feature/plains-two-maps-fog` 的 `fe17b05049c4c32a01fd887023cccaac25a533bf` 建立；初始工作区干净。已fetch，远端main仍ab51fca，PR41–45 OPEN，继承已有修复，不自动合并。[上一轮归档](archive/handoff_plains_two_maps_d076.md)，[当前实现](plains_pressure_boss.md)，[随机内容样本](evidence/plains_pressure_boss/corpus.json)。

只实现平原两张随机网状地图。一图独立16HP鸣铃巡游机，滚轮冲刺、地面铃波、预告落点与重力投铃，不再套牧风者三阶段。二图正式36HP强化牧风者，保留草台风车/真实风场/安全断桥，加入第二阶段三向锁定扇射和第三阶段落击双发，强化蓄力、重心和步幅表现。旧12HP资源仅回归入口；新候选原创机身SVG未冒称用户视觉认可。PlayerMotor、player_tuning、一跳/两发与碰撞均未改。主Boss后仍显示后续开发边界、安全回家，无森林或假能力。

水平连接填入实际齿轮、计时铃、顺序铃与反冲跨度组合；节点和较长连接增加冲撞/远射/俯冲敌人。两图敌人预算18/26，同时攻击1/2，不要求全清、不扩张掉落或强道具预算。100图保留39/44连接图、13/26实际早到Boss行程，至少5环，9/8分岔，无保底。静态统计不冒称真人趣味性验收。

本轮Core5942/0、原43套通过；地区五套：Boss专项32/0、两图/内容1400/0、连续输入物理4961/0、生命周期27/0、主Boss22/0。Boss专项使用真实弹体与伤害契约验证一跳避波、冲刺、轮转、弧线、半血连发、阶段攻击与快照不重复发射。增加内容后的两难度三骨架、固定样板和两个保底均通过原Motor连续输入正反路线与危险扫掠。既有headless退出ObjectDB/音频清理告警保留。失败反证：测试资源静态预载初始化、投铃起点过近上平台、证据目录初始化与统计写入问题已修复并复测，未删除失败断言。

MODULE LAB追加BELLSTRIDER、STORM WINDKEEPER实际练习入口；局部奖励不写永久进度。浏览器、Web/Windows导出、公开网页部署与PR证据在交付前更新。每轮玩法必须执行 `python3 tools/publish_playtest.py --ref feature/plains-pressure-boss-redesign`，核对source_commit及真实线上GUI，不能以仅推PR替代部署。

复现：`python3 tools/run_tests.py`、`python3 tools/run_plains_ten_tests.py`、`python3 tools/run_plains_region_tests.py`、`python3 tools/check_docs.py`、`python3 tools/check_world_design.py`、`python3 tools/build.py web`、`python3 tools/build.py windows`、`GUNMAN_RECORD_GUI=1 GUNMAN_AUDIO_PROBE=1 python3 tools/verify_plains_region_browser.py [线上URL]`、`GUNMAN_RECORD_GUI=1 python3 tools/verify_plains_pressure_boss_browser.py [线上URL]`。长物理测试和GUI串行。浏览器不冒称完整两图胜利；真人难度/手感、Windows实体设备、手机和手柄待验。
