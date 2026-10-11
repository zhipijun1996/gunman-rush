# 当前交接：D075 单张随机连通平原

分支 `feature/plains-connected-region` 从最新 `feature/plains-room-grammar` 的 `733b21a` 建立，初始工作区干净。fetch检查main=`ab51fca`；PR41/42/43尚未合并，依次包含前轮修复，本分支全部保留。没有自动合并或部署。[上一轮归档](archive/handoff_plains_grammar_d074.md)，[本轮实现](plains_connected_region.md)，[验收证据](evidence/plains_connected_region/verification.json)。

正式默认出门为一张20/23节点地图，三类实际不同连接骨架，12节点固定样板、完整23节点保底。短教学、高处/地表/地下、多次交汇与环路、两个上侧开启实体捷径、非必经商人、两条高级可选组合、独立牧风者核心。位置奖励、固定强奖励预算、稳定ID账本跨回退与场景重建。旧八关和危险回归保留在DEVELOPMENT。未改PlayerMotor、player_tuning、跳数、空中弹数、碰撞或恢复。Boss金奖完成平原，提示大能力选择和下一地区仍在开发，未发能力，安全回Home，未实现森林。

Godot `4.7.2.stable.official.ed1daf0bf`。新三套：拓扑/真实移动3271断言、生命周期26、Boss20，全0失败；Core5942/0，原43套通过，恢复修复另跑旧敌人攻击专项。150指定+50自动骨架种子保底0；三骨架图关系43/40/45种，实际早到Boss路线51种，150个指定骨架样本最少5环/8有效分岔。连续输入原一跳两发角色，快速到整备约32–49秒、成长约72–84秒、全连接正反巡游约7–9分钟；几何轨迹未加入敌人伤害，不冒称真人经济和通关体验。App另验真实敌人/奖励/商店/机关/卸载重建及三阶段Boss结算/同批死亡优先。

失败修正保留反证：样板闭锁边造成环不足；重复地面堵下降；斜向渡台与公共风铃重叠；深层渡台侵入阶梯/齿轮；反向顺序铃第一铃挡第二发；自动骨架随机流与指定回放不一致导致正式入口一直保底；导出.tres重映射影响源哈希。用真实几何、合法输入、同流消耗与加载后物理数据指纹修复，未删断言或增加动作资源。

Web/Windows从最终运行提交分别导出；实际Web验证默认Home购买/刷新、正常出门20/23节点非保底、教学移动/跳跃/释放和只读WebAudio非零输出。仅此GUI范围，不冒称浏览器完整地区通关。原始日志/截图/录像/构建清单在审查包。headless仍有既有音频/资源退出清理告警，无脚本/着色器错误；浏览器仅favicon404。Windows设备、Android/iPhone、实体手柄、完整真人探索/经济及趣味性待验。

复现：`python3 tools/run_tests.py`、`python3 tools/run_plains_ten_tests.py`、`python3 tools/run_plains_region_tests.py`、`python3 tools/check_docs.py`、`python3 tools/check_world_design.py`、`python3 tools/build.py web`、`python3 tools/build.py windows`、`GUNMAN_RECORD_GUI=1 GUNMAN_AUDIO_PROBE=1 python3 tools/verify_plains_region_browser.py`。GUI与长headless轨迹串行执行。`verify_living_plains_browser.py`也转向当前正式地区。下一步为用户设备探索反馈，不开放森林或假能力。

运行提交 `a2afcea3b946762cba128c1b5ebda43623a93904`；[PR44](https://github.com/zhipijun1996/gunman-rush/pull/44) OPEN，未自动合并。最终Web/Windows游戏PCK同为 `d6c4b502c31a`；浏览器最终检查0失败，正式23节点woven_layers非保底，WebAudio峰值0.281679。试玩包 `build/gunman-rush-plains-region-windows.zip`、`build/gunman-rush-plains-region-web.zip`；审查包 `build/gunman-rush-plains-region-review.zip`。GitHub CI状态另查，未以本地结果声称远端已通过。
