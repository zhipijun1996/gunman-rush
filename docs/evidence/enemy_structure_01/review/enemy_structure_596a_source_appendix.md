# 596a精确源闭包补充独审

2026-10-29，/root/enemy_review。只读Git对象／归档原件；无共享源写入、无Godot。本附录只确认来源等价及既有独审适用范围，不签CI或成品质量。

冻结提交`596a2eee230eb1b9d23dc2ff878c1ff3259cf293`，父`3bc1759b17a0d06be94ef43f85f2116631437aef`，tree `64bc5a3262e3dcded32ec00b04124384526c194b`。当前工作树干净。

独立核3bc性能叶与先前已审/tmp候选逐字相同：

- `scripts/enemies/forest_motion_02.gd`：`3fac77a231eb8dd6475ea5e80c02963eef44158b720a60525362113f50234ca7`。
- `scripts/enemies/enemy_actor.gd`：`b4e6fff4c1e7785f1f2eaa19c25a64d2c99f2e40c2a75857cab17f77961cf7a9`。

3bc归档的`docs/worklines/enemy_structure_01/enemy_structure_performance_candidate_review.md`与本代理原报告完全相同。native-07-perf-contract／gpu-perf-08报告保留真实“5b＋working_files”采证来源，其中两性能叶SHA与上述精确相同；未重标为3bc fresh结果，这两份报告在596a也未改。

对3bc→596a的`scripts/scenes/resources/config/assets/shaders`逐目录比较，全部0diff。非docs变更恰好两个已审文件：

- `tools/run_forest_depth_region.py`：SHA256 `781469d74f1b51520da10d94aed822e6b2e78cc1dc645b69bd49abeda0581667`，正是已接受CPU调度／遥测候选。
- `tests/test_forest_region_scheduler.py`：SHA256 `d90f9d5b0a49ec4b278b54e9339b97bbb4d8b27914942f834aa85fbb1a99bb5c`，与上轮独审绑定一致；原两个class／14测试逐字保留，追加13项，共27。

因此原性能叶源码审查和CPU调度／计时限定独审可按原范围引用至596a。独立Python27/27仍保其实际候选字节与日志，不升级为原80／600、完整CI、GPU画面或用户通过。后继若仅改docs，可在明确比较闭包后引用本附录；任何工具／测试／生产字节变化仍须另审。新math helper由本代理编写，未借本源复核自签其测试设计充分性。
