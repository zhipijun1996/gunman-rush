# Level Design Harness V2：设计合同 v1

任务 `LEVEL-HARNESS-V2-01`。实现是 [tools/level_design_contracts.py](../../tools/level_design_contracts.py) 的 `SCHEMA` 和 `validate_design(data)`，消费者是同一关卡专项 CLI / Harness 与 LEVEL FOUNDRY 的黄金卡绑定。输入 JSON，输出 `{code, path, message}` 错误数组。空数组只表示**设计声明及声明图一致**，不代表物理可达、素材完成、趣味认可或 G5。未知字段和版本直接拒绝，禁止把运行结果塞进设计意图后宣称通过。

## 分层与真实消费者

| 字段 | 用途 | 消费与证明边界 |
| --- | --- | --- |
| `schema_version`, `artifact_kind`, `id`, `status`, `source_refs` | 稳定身份、来源与设计/技术切片边界 | CLI 校验；来源是设计引用，不是运行源码指纹证明 |
| `biome` | 身份、空间语法、行为、机制、生态、视觉、探索奖励、八类体验、十轴难度、展示→练习→组合 | Skills 设计输入及结构校验；十轴用文字相对样板描述，不虚构趣味分数 |
| `capabilities.catalog/guaranteed/optional/future` | 当前实现状态与地区授予边界分开 | 每项恰属一组，guaranteed/optional 必须声明已实现，future 必须未实现；正式主路不能依赖 future |
| `capabilities.supported_builds` | 一种当前装备、可装备集合、等级、能力、构筑修饰、容量、资源、空中限制、冷却与恢复来源 | 每种基础构筑单独图搜索，不把可装备武器当成同时生效；真实参数由运行捕获读取 Definition 和配置 |
| `topology` | 非规则坐标节点、语义、授予、奖励、单向出口、主/支/隐藏/捷径边 | 拒绝孤立节点；节点+已获能力状态搜索；逐构筑 goal 可达、授予不可循环锁、每个已达状态能返回，或明确为最终出口。**只证明图** |
| `atomic_actions → phrases → challenges` | 实现来源、双重用途、连续衔接、挑战入口出口位置/速度/资源、相位、观察、恢复、容错、设备、奖励 | 检查动作引用与逐步衔接、要求包含动作使用的能力、范围合法、主路无大师。自然流畅与资源可行必须再做真实 Motor |
| `rooms`, `encounters`, `pacing` | 房间多标签、敌人与平台关系、合法落点、反制、压力与真实路线策略 | 引用与有向策略路径检查；文本预算是待校准设计，路线诊断消费真实 trace，不凭总体数量打分 |
| `scene_compositions` | 焦点、轮廓、前中后层、地标、疏密、引导、端头接缝、比例锚点、遮挡、相机、氛围、资产来源许可版本复用 | 缺项拒绝；没有实际截图不能宣称合屏好看，planned 资产不得冒充已产出 |
| `evidence_boundary` | `generated/runtime/physics/subjective` 四类均为 `unverified` | 设计文件不能自签运行/物理/玩家通过；实际 Manifest、运行快照、Motor evidence、人工评价保存在单独报告并带来源 |

`topology.edges[].challenge_ids` 是该边必须完成的全部挑战；`rooms[].challenge_ids` 是空间内的挑战目录，可能包含自愿入口，不能自动当作全都必经。替代短语在本版共享该挑战的能力与资源前置要求；不同装备或前置能力的替代通路应建不同边与挑战，不能把互斥装备能力合并。`available_weapons` 只记录构筑可选范围；图搜索固定 `equipped_weapon`。实际换装、资源耗尽、冷却、机关相位和身体碰撞不由该静态图证明。

`equipped_weapon`、`available_weapons`、能力目录和 `source_refs` 在本静态入口都是**声明**：校验器验证单装备和引用一致性，不读取或证明该武器的真实 Definition 存在、等级匹配、资源参数或实现来源正确。运行捕获必须从真实 WeaponCatalog/Definition/PlayerTuning 读取身份、等级与参数并附来源指纹；无法读取时保持 unverified，不允许用设计文件自报值替代。静态 design-valid 绝不等于合法运行构筑已验证。

`foundry` 是当前现有工坊适配器合同：`kind=template` 必须 `phrase_count=1`；`kind=itinerary` 必须 `template_id=mixed, phrase_count=3`，且只接受整数，拒绝 bool/float。来源为 `tools/foundry_validate.gd` 的 connection proof（最多选择三个不同模板）；实际验收绑定还必须核对同 Manifest 的三段 `phrase_ids`，少于三段直接拒绝。该约束是当前适配器兼容限制，不是全游戏挑战长度规则；以后支持其他长度需同时显式迁移合同/适配器/测试。卡与回放绑定只能证明所绑定的结构和已执行回放，完整动作顺序、入口出口、资源与相位意图仍须逐项验收，不能自动变成 passed。

`entry/exit.position` 是设计局部参考系的目标区间，`velocity` 是意图区间；样例零速度为静止安全站位的假设，不是实测可行包络。数值来自技术样板测量后应放到独立物理证据，设计字段不能标 `measured` 冒充证据。所有数值必须有限，最小值不得大于最大值。

无论边或挑战被标注为 main/reward/hidden，每个合法基础构筑必须在**排除全部大师挑战边**后，仍能从原始入口能力状态到达目标；重新搜索不得继承先前穿越大师挑战取得的能力。否则报 `mandatory_master`。这防止把唯一必经挑战改名为隐藏，或把主路必需能力藏在大师挑战之后。真正可选大师支线仍允许存在，并继续执行原能力与回程检查。

图搜索有 16,384 个能力状态的确定上限；超过直接报错，不把部分搜索当成功，不无限重抽。能力授予单调累积，不模拟失去道具或消耗资源；此类状态必须交给真实回放验证。无合法返回时只能把目标节点明确声明 `one_way_exit`，不能在普通奖励点使用退出豁免。

## 可调用样例与反例

三份 JSON 都是完整 `level_design_intent`，使用相同入口：

- [plains_design.json](../../tests/fixtures/level_design_v2/plains_design.json)：以正式平原基础武器/动作边界建技术设计卡；图本身是 fixture，**不是正式平原 Manifest**。钩索已在练习 Runtime 实现但正式平原未授予，列 optional；不继承旧 foundry_capabilities 的未实现描述。
- [thorn_forest_design.json](../../tests/fixtures/level_design_v2/thorn_forest_design.json)：非规则树冠支路/下降汇合/回程；专属荆棘机制与整套资产仍 design-only。现有反冲模块只是可复用技术底座，不新开放森林或锁定地区顺序。
- [golden_challenges.json](../../tests/fixtures/level_design_v2/golden_challenges.json)：`challenges` 中 `ordinary/advanced/master` 三卡。普通绑定 `height_then_precision`，进阶绑定 `resource_then_rhythm`；大师 `foundry.kind=itinerary, template_id=mixed, phrase_count=3`，实际组合取同 Seed Manifest，`module_ids` 只是候选支持范围。现有工坊连续回放仅证明技术底座，不能把随机三段称为完成的大师挑战。

```python
import json
from tools.level_design_contracts import validate_design

with open('tests/fixtures/level_design_v2/plains_design.json') as stream:
    design = json.load(stream)
errors = validate_design(design)
assert errors == []  # design-valid only
# 可证伪反例：能力在锁后授予，不能先借用它通过锁。
design['topology']['edges'][0]['requires'].append('hook')
design['topology']['nodes'][1]['grants'].append('hook')
assert {'goal_unreachable', 'grant_unreachable'} <= {e['code'] for e in validate_design(design)}
```

自动回归：`python3 -m unittest discover -s tests -p test_level_design_contracts.py -v`。测试覆盖三份正例、每个已出现必填字段的删除/错类型、空合同、未知字段/引用、重复 ID、非有限数、能力分组、八类体验、单装备与多构筑、动作衔接、主路大师/未来能力、状态区间、证据越界、循环授予锁、不可互返分支授予不得合并、孤立节点、回程、策略路径、资产/设备缺项、有界搜索失败及 Foundry 绑定。测试通过不代签 Motor。

## 兼容与准入

本合同不改 RunManifest、模块 Definition、随机流、PlayerMotor、资源、保存或两张正式平原流程；它是离线意图侧车。旧 Manifest 保持版本和消费者，由分析适配器提取生成事实，不能因设计声明覆盖生成结果。将来字段语义不兼容时升级 `schema_version`，提供显式迁移，并保留旧输入及失败样例；本版对未知字段 fail closed，避免静默漏检。

设计层可用只代表 G0/G1 的部分输入具备。后续仍通过已有 G0–G5：真实输入/连续路线与相位资源验证、正式尺寸合屏及资产许可、正式消费者回归、独立反例审查、玩家和设备验收。缺设备记 awaiting-device，缺视觉/趣味证据记 unverified/review。不得将未来能力、未来区域、文字许可占位或黄金技术切片准入正式模块池。
