# map-edit 177 份参考审计

本审计只读取游戏与编辑器源码、数据和固定版本 Git 对象，没有运行 Godot 物理，也没有授予新的模块准入。逐模块、逐源文件和逐 guard 结果见 [reference_audit.json](reference_audit.json)。`npm run check` 已实际执行，退出码 0。

## 固定来源与覆盖

| 项目 | 本轮读取版本 |
| --- | --- |
| map-edit main | `ccbb21eec9f4d92e46ab9a95d35abb664dc69189`，2026-10-22 13:26:04 UTC |
| 库的游戏来源 | `74d8a06b42cb2bc2c5023f1bfe1a4fbc4b163074` |
| 游戏 main 基线 | `e9ab0e0743466b8983e34cc7de17bab1abf9d53a` |
| 本轮最新开发集成基线 | `a074a709ffa64c1382d73d2dab6dcff673222728`，`integration/four-lines-20261023` |

177 份文件全部有唯一 ID、源路径、来源提交与原始数据。177 个工程文件的 SHA-256 全部与 catalog 吻合；190 份来源快照文件逐字节匹配固定游戏来源的 Git blob；其中索引里的 72 个 `.tres` 与 78 个生成 `.gd` 共 150 个源文件，另行核验 Git blob SHA-1 全部匹配。原 snapshot 内 5 组消费链规则的 51 个不同 guard 路径全部匹配。

| 参考来源 | 数量 | 覆盖含义 |
| --- | ---: | --- |
| `.tres` 模块资源 | 72 | 53 平原、19 通用/历史资源；枚举源目录中的全部 `.tres` |
| 森林工厂结果 | 51 | 明确适配的有限 `build` 方法、目录条目和参数变体 |
| Foundry 短语 | 36 | 固定批次内六个模板形成的开发组合 |
| Foundry 连续路线 | 18 | 固定批次的 itinerary；复用已有模块和短语 |

两个新基线中的 `.tres` 模块路径集合仍为同一 72 项，没有资源漏导入或新增未导入资源。51 份森林结果对应的工厂源码在两个新基线中均保持原字节。新开发基线的 Foundry 批次仍为同一 36+18 个 ID；36 短语的变化字段仅 `basis/hash`，18 路线为 `basis/hash/phrases`，节点几何没有因此创新。旧批次的回放收据不能仅换新 hash 后复用。

覆盖范围来自 [提取器](https://github.com/zhipijun1996/map-edit/blob/ccbb21eec9f4d92e46ab9a95d35abb664dc69189/tools/extract_modules.gd#L32)。`.tres` 自动枚举；森林代码工厂为硬编码适配表，并非所有 `scripts/generation` 代码的通用解释器。快照索引中的 156 项含 `.gd` 和 UID，不能把它们当成 156 个已导入模块。

没有枚举无限种子整图、运行时接缝、完整地图额外敌人/Boss、无 `build` 实现的提案。没有把编辑器时间轴当真实物理。仅导入有限源对象的原形、路由意图和运动参数，这一边界在 [README](https://github.com/zhipijun1996/map-edit/blob/ccbb21eec9f4d92e46ab9a95d35abb664dc69189/README.md#L32) 与 [构建器](https://github.com/zhipijun1996/map-edit/blob/ccbb21eec9f4d92e46ab9a95d35abb664dc69189/tools/build_library.py#L305) 都明确保留。

## “已接入”证据的版本边界

旧来源签名为 25 formal、82 development、70 unverified。这里的 formal 指源码消费者能走到该源模块，不意味着编辑草稿已写回、每个种子会选中、物理已通过或已获玩家认可。

| 基线 | 190 份来源文件中的变化 | 旧 guard 应有结果 |
| --- | --- | --- |
| main | `scripts/demo/demo_app.gd` | 该文件在全部 5 组 guard 中，107 条旧链路签名失效；加上原未知 70 条，共 177 unverified |
| 最新开发 | `project.godot`、`config/foundry_capabilities.json`、`resources/foundry/batch.json`、`scripts/generation/plains_region_generator.gd`、`scripts/ui/demo_menu.gd`、`scripts/demo/demo_app.gd` | 其中 5 条为 guard 路径，全部 5 组失效，共 177 unverified |

这是旧证据的保守失效，不代表游戏实际接入数量变为零。人工检查 main 的唯一差异：`demo_app._ready` 仅新增显式 `--cloud-preview` 跳转，普通启动保留旧菜单和区域链路，其余相关来源文件同字节。因而 main 普通入口的 107 条旧源码链路有延续依据；本报告没有伪造新运行收据或重签库文件。开发集成分支的 UI、正式平原生成器及 Foundry 批次变化，需要从新入口重新审查，并由运行验证签技术状态。

[status_for](https://github.com/zhipijun1996/map-edit/blob/ccbb21eec9f4d92e46ab9a95d35abb664dc69189/tools/integration_status.py#L14) 按首个匹配规则判断，5 组规则中存在重复模块，但最终覆盖 107 个不同 ID。任何匹配 guard 漂移即返回 unknown，不会退到较后的另一条链路以维持绿灯。70 条没有完整来源调用链的参考仍保持 unknown。

当前网页加载的是已生成 catalog；[LibraryClient.checkUpdate](https://github.com/zhipijun1996/map-edit/blob/ccbb21eec9f4d92e46ab9a95d35abb664dc69189/library-client.js#L42) 固定编辑器 commit 读取新库，不会在浏览器现场重新分析游戏最新代码。因此网页显示的旧 formal/development 是历史快照结论；新的审计消费者必须检查 `sourceCommit`，不能把加载成功解释为最新游戏已重新认可。同步流程重新下载全部来源并应用原 guards，漂移会变 unknown，不自动重签。

## 能力声明可信度

| 来源 | partial | unspecified | defined |
| --- | ---: | ---: | ---: |
| 72 资源 | 51 | 21 | 0 |
| 51 森林 | 33 | 18 | 0 |
| 54 工坊 | 54 | 0 | 0 |
| 合计 | 138 | 39 | 0 |

能力字段的结构可信，最低能力需求尚未被证明。全部 177 份均不应进入“已完整定义且满足能力”的正式白名单。39 unspecified 也不能当作无能力锁。`evaluateRequirements` 在已知项缺失时返回 false，partial 满足时仍返回 null；源码误声明也会造成保守误拒绝。

可复用的导入方式见 [capability_requirements.py](https://github.com/zhipijun1996/map-edit/blob/ccbb21eec9f4d92e46ab9a95d35abb664dc69189/tools/capability_requirements.py#L5)：森林逐字导入 `requires`；资源及 Foundry 合并显式最小跳跃/空中射击/爆发反冲要求，保留原始数值与来源位置；Foundry `capability_profile` 明确仅为验证配置。以下缺口应由统一契约/物理证据补足：

- 森林 [forest_exploration_modules.gd:58](../../scripts/generation/forest_exploration_modules.gd#L58) 为整族统一填写 `grapple`。其中 `root_meadow` 的主路只有两次基础跨隙和行走，源码未要求钩索动作。这证明该声明不能直接视为已经证明的“每条解法都必须拥有钩索”。本审计没有运行删能力反例，不据此直接删声明。
- 导入器只读取 `module/entry_port/exit_port`，没有遍历 `entry_ports/exit_ports` 的全部可选端口。原数组仍保留在 `source.original`，契约迁移必须读取这些原值。
- `resource_evidence` 只收录正值 `min_/minimum_/maximum_` 和 `requires_burst`，端口 `max_normal_speed/max_recoil_speed/max_shot_cooldown` 不在此提炼字段中；零上限也不代表无约束。原 [PlatformingModulePort](../../scripts/generation/platforming_module_port.gd) 有这些连接参数，不能用能力标签替代连接验证。
- 33 个森林 `grapple` 标签与 Foundry 中未实现的 `hook` profile 分属不同消费者。后者的 implemented=false 不能推导整个游戏没有真实钩索，前者的文字标签也不能证明 Foundry 已支持它。
- 最新开发的 `foundry_capabilities` 已把 base/double_jump 显示从“两发”改为“一发”，air_chain 保留显式历史四发。旧库的 profile 文字、旧 basis 与回放条件应保留原版本，不混用最新资源条件。

全部 177 份 `difficulty.score` 为 null。森林的 easy/normal/hard、资源的 platform/timing pressure、工坊 profile 都没有被擅自转成 1–10 分，这个不确定性处理应保留。

## 177 的数量不能代表玩法多样性

固定字段的严格源几何比较发现下列载体相同组。比较保留所列原始几何和宿主字段，排除外部风铃配置、动作程序和运行生态，因此这些组只提供相似性审查入口，不直接判定重复或劣质：

- `plains_door_landing / micro_board`
- `plains_windchime_lesson / plains_windchime_timed / plains_patrol_meadow / plains_windchime_sequence`
- `plains_ferry_one / plains_windchime_ferry`
- `forest_air_chain_geometry__recoil_hook / __recoil_hook_recoil`
- `forest_air_chain_geometry__arch_four / forest_directional_geometry__build`
- `forest_hollow_trunk_geometry__cavity / forest_hollow_upper_candidate__build_cavity`

例如同一平台载体配不同风铃门控制关系，可能形成不同观察和风险决策；同一载体只换动作标签，则需要轨迹、替代解和行为差异证明。54 份 Foundry 内容由既有资源组合而来，适合验证动作衔接和资源连续性，本身不构成 54 种新玩法证据。

## 运行消费者与适配边界

map-edit 的 `gunman-rush-level-sketch/v1` 是独立草图格式。全库保留 `source.original`、`editorTranslation`、轨道/机关绑定以及动作意图；资源的静态平台几何、原锯轮轨迹和 roundtrip 已由本轮 `npm run check` 实际检查。普通路由点来自 main_route/steps；无采样位置的反冲点标为 schematic，不能作为真实行动轨迹。

本轮在游戏 `scripts/tools/config/resources` 中检索 `capabilityRequirements`、`gunman-rush-level-sketch` 与 `.mapnote` 未找到正式运行消费者。草稿没有自动写回游戏；[README:95](https://github.com/zhipijun1996/map-edit/blob/ccbb21eec9f4d92e46ab9a95d35abb664dc69189/README.md#L95) 也把导出转换器列为后续接入。应从原数据映射到现有 `PlatformingModuleDefinition`、森林工厂及现有 assembler，再走原物理验证器。弧轨等没有现成消费者的对象应明确拒绝或保留设计需求，不能静默降级。

森林 33 份保留的 admission 为 geometry=candidate、motor/visual=unverified、production_pool=false；其余 18 份为 production_pool=false、native_verified=false。这些是原源元数据，不能覆盖其他历史专项已有的限定证据；同样不能从文档库存在推导新准入。统一系统应记录证据适用的版本、端口、解法、能力条件及 scope。

## 复现

在同一固定 checkout 中执行：

```sh
cd /workspace/map-edit
npm run check
```

逐项 JSON 的重核方法：对 `modules[].document_sha256` 用对应 `library/modules/<id>.json` 实际字节计算 SHA-256；对 `sources[]` 用 `git -C /workspace/gunman-rush show <source_commit>:<path>` 与 `library/source/<path>` 逐字节比较；对两个 baselines 的每条 rule guard 计算同一 Git blob 的 SHA-256，对照 `expected_sha256`。主报告中的 changed paths、hash mismatch 和模块状态均来自这些实测比较，没有按引用次数推断。

本轮没有重新运行 Godot 提取或关卡物理；没有观看实际输入录像，也没有真人试玩证据。导入与格式审计通过、设计评价、真实可行性和真人趣味认可必须保持独立。
