# 地区权威输入提取

`tools/level_region_context.py` 为 Level Design Harness 的 route/mission prepare 提供离线设计输入。它读取现有文档和真实定义，不维护第二份十六地区表，不授予能力，不修改生成器、保存或正式地区。

```bash
python3 tools/level_region_context.py --region thorn_forest --output build/level_design_v2/forest_context.json
python3 -m unittest discover -s tests -p 'test_level_region_context.py'
```

Python 消费接口：`build_region_context(region_id, root=ROOT)`。输入接受 `world_regions.json` 的地区 ID 或精确中文名；未知地区、重复条目、阶段冲突、未识别硬锁语法和失效权威链接均抛出 `ContextError`，不能悄悄改成平原。

请求路由使用 `resolve_region_id(request, root=ROOT)`：从 `region_registry()` 的目录全名、ID、无歧义中文末两字及英文 ID 词推导别名，例如“制作森林”与 `glacier`。未知请求返回 `None`，同时出现多个地区抛 `ContextError`；路由消费者应保留待澄清状态。没有额外复制地区别名表。

输出 `schema_version=1`、`kind=extracted_design_input_not_runtime_configuration`：

| 字段 | 来源与用途 |
| --- | --- |
| `design.stage/gate/optional_gate/identity` | 从 regions V0.3 的矩阵逐行提取。硬锁 `alternatives` 是析取的合取列表，供制作任务列举所需测试；不是物理可达证明。 |
| `design.learning/region_blueprint` | 同一文档的地区 I/C/X、空间、机制和 Boss 蓝图，保留候选状态与原文。 |
| `design.world_location` | 现有世界目录的前后地区及文档建议新增边；全部为候选拓扑。 |
| `design.art` | 世界目录的视觉母题、叙事、场景引入、材质灯光和模块拼接要求。 |
| `locked_principles` | 用户确认的六阶段、S2 单能力、S4 替代解法、S5 双移动能力、能力授予和必需验证要求。 |
| `overrides` | 设计入口中的最新用户补充，附新版合同路径和 SHA；必须优先于旧钩索横向/旧位移描述。 |
| `weapon_context` | 武器设计的确认方向、开放事项，以及实际 WeaponCatalog 和每个 `.tres` 解析出的等级/分支。一次只使用一种装备。 |
| `implementation` | 静态源码存在性、开发工坊授予调用和正式消费者线索，与设计状态分开；不推断本局已获得任何能力。 |
| `sources` | 所有读取文件的版本、SHA256、行号；行级设计字段另带具体引用。 |

矩阵标题仍为“V0.3 设计候选”，所以具体矩阵行标 `PROPOSED_MATRIX_SUBJECT_TO_LOCKED_PRINCIPLES`；用户已确认原则标 `LOCKED`。当前任务若收到更新用户指令，应在任务层记录该更高优先级来源，不能悄悄改写原文状态。Lv.3 资源文件存在并不表示六个技能已获得最终设计认可。

`world_regions.json.runtime_available` 含历史值，甚至平原仍为 false。输出保留该原值用于审计，但明确其不决定正式实现状态。平原通过 DemoApp/RunProfile 源码消费者核对；森林没有同等正式消费者。三项独立移动能力已有 grant 处理与 ActionStudio 调用，与正式地区成长发放分开。`runtime_available=null` 表示本工具没有实际启动游戏，不签运行 PASS。真实能力、资源、设备、轨迹证据仍由现有 CapabilitySnapshot 和 Godot capture 取得。

森林 dry-run 应得到 S2、主路 H、隐藏线不得强制 W/D/U1/U2、树干竖井/枝台/树冠身份、皇家花园叙事和材质构图输入；钩索源码存在但森林保持未来地区。下一步任务应据此制作经过真实 Motor 与视觉审核的最小样板，再进入现有 G0–G5，不能直接宣布森林完成。

该提取器只解析当前明确文法。文档增加新的锁表达式、重命名地区或改变表结构时应失败并更新适配器和测试；无需用户重复填写文档已有内容。源码静态核查不替代装载 Resource、真实输入回放、设备测试或真人体验。
