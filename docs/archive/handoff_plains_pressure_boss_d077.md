# 当前交接：D077 平原路线压力与Boss重设计

分支 `feature/plains-pressure-boss-redesign` 从最新 `feature/plains-two-maps-fog` 的 `fe17b05049c4c32a01fd887023cccaac25a533bf` 建立；初始工作区干净。已fetch，远端main仍ab51fca，PR41–45 OPEN，继承已有修复，不自动合并。[上一轮归档](handoff_plains_two_maps_d076.md)，[当前实现](../plains_pressure_boss.md)，[随机内容样本](../evidence/plains_pressure_boss/corpus.json)。

只实现平原两张随机网状地图。一图独立16HP鸣铃巡游机，滚轮冲刺、地面铃波、预告落点与重力投铃，不再套牧风者三阶段。二图正式36HP强化牧风者，保留草台风车/真实风场/安全断桥，加入第二阶段三向锁定扇射和第三阶段落击双发，强化蓄力、重心和步幅表现。旧12HP资源仅回归入口；新候选原创机身SVG未冒称用户视觉认可。PlayerMotor、player_tuning、一跳/两发与碰撞均未改。主Boss后仍显示后续开发边界、安全回家，无森林或假能力。

水平连接填入实际齿轮、计时铃、顺序铃与反冲跨度组合；节点和较长连接增加冲撞/远射/俯冲敌人。两图敌人预算18/26，同时攻击1/2，不要求全清、不扩张掉落或强道具预算。100图保留39/44连接图、13/26实际早到Boss行程，至少5环，9/8分岔，无保底。静态统计不冒称真人趣味性验收。

本轮Core5942/0、原43套通过；地区五套：Boss专项32/0、两图/内容1400/0、连续输入物理4961/0、生命周期27/0、主Boss22/0。Boss专项使用真实弹体与伤害契约验证一跳避波、冲刺、轮转、弧线、半血连发、阶段攻击与快照不重复发射。增加内容后的两难度三骨架、固定样板和两个保底均通过原Motor连续输入正反路线与危险扫掠。既有headless退出ObjectDB/音频清理告警保留。失败反证：测试资源静态预载初始化、投铃起点过近上平台、证据目录初始化与统计写入问题已修复并复测，未删除失败断言。

MODULE LAB追加BELLSTRIDER、STORM WINDKEEPER实际练习入口；局部奖励不写永久进度。闭甲挡弹反馈和停机接触伤害分离，冲刺预告覆盖完整位移及接触前缘、受场地边界限制。正式小Boss血条只标记实际半血强化点；OFL子集覆盖205个UI字符，新Boss及正式HUD的65个汉字全部实查覆盖。

公开试玩已更新：[版本185f9fe26ef9](https://zhipijun1996.github.io/gunman-rush/?v=185f9fe26ef9)，运行提交 `67232084544bf6ef8624cc4b20adaba7eeb51574`。[PR46](https://github.com/zhipijun1996/gunman-rush/pull/46) OPEN，未自动合并。[发布工作流38151249569](https://github.com/zhipijun1996/gunman-rush/actions/runs/38151249569)全部必要测试、Web/Windows导出与部署成功。线上build-info.source_commit匹配，canonical root也显示新标记。公开GUI两个检查均0失败：Home真实购买/刷新保留/出门、20节点非保底随机地图、迷雾小地图→大地图定位/滚轮/拖动/关闭、真实教学移动/跳跃/射击释放；实际练习点击显示小Boss16/大Boss36HP，动作与正常输入可见。WebAudio峰值0.388783，无脚本/着色器错误，保留favicon404。购买9音符为隔离fixture，不冒称实际赚取；此GUI不冒称完整真人两图通关。

[完整证据](../evidence/plains_pressure_boss/verification.json)记录发布/基础提交、CI与本地各测试、100图内容/预算/物理统计、保护文件、公开根页面、原始日志与截图/录像哈希。最终本地PCK `ae11bade9b9e`，线上CI PCK `185f9fe26ef9`，分别实测并记录，不假称文件相同；源码运行提交相同。Web/Windows包：`build/gunman-rush-plains-pressure-boss-web.zip`、`build/gunman-rush-plains-pressure-boss-windows.zip`；审查包：`build/gunman-rush-plains-pressure-boss-review.zip`。修正预告、挡弹及新字体前的三个候选发布在部署前主动取消，原始失败/取消日志保留。后续每轮玩法执行 `python3 tools/publish_playtest.py --ref <已推送已测分支>`，不能以仅推PR替代部署。

复现：`python3 tools/run_tests.py`、`python3 tools/run_plains_ten_tests.py`、`python3 tools/run_plains_region_tests.py`、`python3 tools/check_docs.py`、`python3 tools/check_world_design.py`、`python3 tools/build.py web`、`python3 tools/build.py windows`、`GUNMAN_RECORD_GUI=1 GUNMAN_AUDIO_PROBE=1 python3 tools/verify_plains_region_browser.py [线上URL]`、`GUNMAN_RECORD_GUI=1 python3 tools/verify_plains_pressure_boss_browser.py [线上URL]`。长物理测试和GUI串行。浏览器不冒称完整两图胜利；真人难度/手感、Windows实体设备、手机和手柄待验。
