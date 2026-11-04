# 地区上下文

`tools/level_region_context.py` 提取现行设计与实际消费者的带出处信息，不授予能力，也不证明生成可达或内容完成。

```sh
python3 tools/level_region_context.py --region thorn_forest --output build/forest-context.json
python3 tests/test_level_region_context.py
```

地区矩阵来自 `docs/bible/regions.md`，区域体验来自对应 `docs/bible/regions/` 正文，武器与能力来自当前对象规范和动作合同。原始附件不参与当前规则解析。世界目录提供候选连接，运行配置和真实代码分别说明参数与消费者；静态存在不代表角色已获能力。

每条信息附段落、行号和SHA。未知／歧义地区、重复条目、阶段与能力锁冲突、失效链接明确失败。候选地块与拓扑不是已实现结论；真实路线、连续操作和体验另行验证。

默认森林与实际选择见 [当前状态](current_state.md)，具体代码与检查见 [模块导航](module_map.md)。按任务读取对应对象，不通读旧报告和全部附件。
