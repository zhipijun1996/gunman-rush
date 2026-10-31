# P8 独立静态审查

结论：**修正两处 Lab helper 归属后，路径与源码静态审查接受；未运行 native/PCK。**

- 生产迁移冻结：`4f2fb531e12dce576d144800904799a1cf95d50a`。
- 已审查最终源码：`9e42173d07965f47a8dd688d1ae664ca33aaa519`；工作树 clean。
- 两处反依赖已由 `9d08d7f19` 纯搬至各自 experiments；`c4a317ef` 保留其测试输入闭包。

## 实际核验

| 项目 | 静态结果 |
|---|---|
| 实际路径映射 | 1124 个目标均存在，无冲突、无旧搬迁源残留 |
| 原样 / 精确路径替换 | 873 / 237；11 个独立修复差异单列，另3处路径/来源适配已解释 |
| UID | 491 个搬迁 UID 原字节与相邻脚本配对一致；活动 runtime 无重复 UID |
| 协议旧路径 | 357 path-holds、366 byte-holds；仅 v10/v11 两源随已明确的 legacy charger 修复变化 |
| 生产依赖 | 842 文件、3450 边；无 tests 实现加载；非 application 的 game→experiments 为0 |
| 实验启动 | DemoApp 明确启动实验的13条边保留，不伪装成核心反依赖 |
| 源码检查输入 | 120072 条原 mapped input 边无遗漏；profiles 和非 inputs 字段未变 |
| Foundry 来源集合 | 251 个原来源全保留，扩至273；3 tests 文件仅用于来源哈希，template 走导出 stamp |
| assets 技术 JSON | 11份、41个叶差异仅consumer指针；均有现存目标且与map一致；原件归档逐字一致 |
| 图像/音频本体 | 无额外 assets 改动，未改资源选用 |
| 35入口 | 全部新场景和其直接 ext_resource 存在；95份矩阵源SHA已刷新 |

## 必须保留的边界

118 项动态加载全部标记 **UNVERIFIED_NOT_PASS**，本审查执行数为0。静态 class/literal 图不证明 ResourceLoader、导出 pack、import UID、声音或游戏功能。

Foundry 的 `tests/` 字符串是来源指纹输入，不是测试实现被运行加载；不要声称所有测试路径字符串已消失。原 protected_files 7项也不是7项字节全未变：`test_region_bible.py`、`forest_legacy_fixture.py`、`region_style_history.py` 三处有限归档/测试/输入范围适配已明确列出，原 style25 e7d7 manifest 指纹保持。

旧 Courier 的未声明默认回落、明确历史实验、光照实验音频 opt-in 和 Boss8 fixture 原缺陷继续分列于入口矩阵；目录迁移不替代内容迁移决定。

后续须运行冷导入、35入口就绪/暂停/重试/退出、两正式地区与存档、Cloud新路径和真实PCK动态消费者。旧 main840108da 的35启动日志不当成P8成功证据。

详细证据：`p8-entry-independent-review.json`、`p8-entry-independent-integrity.json`、`final-entry-matrix-frozen-candidate.json`。本审查未修改生产或测试文件，未运行 Godot。
