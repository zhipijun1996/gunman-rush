# 主树入口独审增补

主树 `6584d48bca916de100eed3801af6f0973ae49767`；仅只读，未运行Godot。原独审冻结矩阵仍保留原来源SHA，新的执行计划见 `entry-native-execution-plan.md/json`，不能把迁移前后SHA混写。

4处新增迁移测试路径缺陷由root机械修正：Cloud runner与demo_ui contract指向platform入口；Blob47/Windchime layout测试指向experiments/terrain/art_foundation。当前4个新字面与实际目标均核实存在，JSON保留修后源hash；原断言未在本轮执行。

旧 eight_demo/eight_run 对不存在ten_*测试的引用在2ce4ffa6已存在；不伪造替代。formal_eight.tres为明确负断言，应保持不存在。

现6条原生gate通过只证明各自断言；2条entry runner运行15个精确场景（11托管+4study）。正式191/0仍有57 ObjectDB与25 resources退出失败。未跑命令、14个额外精确场景缺口、直接启动与托管差别均在执行矩阵逐项列出。118动态加载未穷尽验证，PCK/公开网站未由本轮证明。
