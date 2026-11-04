# 地区上下文提取

`tools/level_region_context.py` 为地区路由提供带出处的离线设计输入。它核原始来源、当前合同、世界目录和真实代码／资源，不授予能力，也不签生成可达或内容完成。

```sh
python3 tools/level_region_context.py --region thorn_forest --output build/forest-context.json
python3 tests/test_level_region_context.py
```

地区 ID 和别名从目录推导；未知、歧义、重复条目、阶段／能力锁语法冲突和失效引用明确失败，不回退为另一个地区。

## 输出含义

- 原始设计来源保留可追溯的段落、行号和 SHA，用于核对方向与候选。
- 当前动作入口和其链接的资源／输入合同决定现在的行为；原附件的旧武器／H／D 描述不是当前规则。
- 实现观察只说明真实消费者、Definition 和授予代码存在，不推断当前角色已获能力。
- 地区拓扑、学习目标、艺术意图和能力条件分别标明状态；真实 Manifest、输入轨迹、正式体验与设备另行验证。

默认森林是 v15，其他版本需显式选择。运行事实见 [当前状态](current_state.md)，设计入口见 [文档总览](../README.md)，具体代码与检查见 [模块导航](module_map.md)。提取文法变化时同步适配器与针对性回归，不从旧报告借通过。
