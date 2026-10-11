# 当前交接：D074 房间内路线语法十轮迭代

分支 `feature/plains-room-grammar`，基线 `d61c503`，包含尚未合并的PR41/42。[上一轮归档](archive/handoff_plains_feedback_d073.md)，[十轮实施](plains_room_grammar.md)，[逐轮提交](evidence/plains_room_grammar/iterations.json)，[验收清单](evidence/plains_room_grammar/verification.json)。运行实现提交 `af588fe`；本轮不自动合并或部署。

完成10组完整动作短语、20种几何变体；横渡/攀升两骨架、独立局内模板袋、能力/阶段/反冲/渡台预算过滤、实际节点角色和目录指纹；金币房更长安全探索、观察/恢复点不生成敌人。保留一跳、两发、260速度、0.55地面反冲、0.20慢时、正式8关和末端门。第3～6关进入新模板，第7整备、第8Boss保持。原42套未删，新增一套变为43套。

Godot `4.7.2.stable.official.ed1daf0bf`。最终完整43套退出0、Core5942/0；组合23180/0、72条上下完整路线；另四相位80条完整路线24937/0；分岔16568/0、蓝图14678/0、生成4791/0、低天花板/敌人316/0、App156/0、镜头9642/0。200固定第五关combat样本全部10模板9～34次、保底0；40Seed×第3～6关实际遵守唯一请求；原180样本117布局/30模块，三家族113/43/44。完整证据见上方清单。

失败均保留/修正：首轮分布bramble_clock仅1/200、金币房同质化/原渡台稀少、旧v8根Seed荆棘位置改变、JSON浮点节点导致恢复点排除失效。保留原丰富度/家族/躲避/回放断言；旧碰撞用原地图整数单独重建，未开放旧RunManifest迁移。

Web与Windows导出0，PCK均 `a60b842be578`；模板JSON显式进入三平台导出规则，OFL及Kenney许可保留。新包 `build/gunman-rush-plains-grammar-windows.zip`、`build/gunman-rush-plains-grammar-web.zip`。正式Web浏览器实操正在运行，随后记录PR/报告。Windows/手机/实体手柄和主观趣味性待验，森林关闭；两宏观骨架不冒称三骨架/回环完成。快速headless仍有音频资源清理告警。

复现：`python3 tools/run_tests.py`、`python3 tools/run_plains_ten_tests.py`、`bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/plains_room_grammar_runner.gd -- --phase-sweep`、`python3 tools/check_docs.py`、`python3 tools/check_world_design.py`、`python3 tools/build.py web`、`python3 tools/build.py windows`、`GUNMAN_RECORD_GUI=1 GUNMAN_AUDIO_PROBE=1 python3 tools/verify_living_plains_browser.py`。GUI应与长headless轨迹串行运行。下一步为设备试玩、实际路线选择/耗时/趣味性反馈，非无限后台迭代。
