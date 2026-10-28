# 道具数据与效果维护

道具的数值、持有与装备、效果逻辑、图标与特效分别维护。调整价格或伤害不应修改背包事务；新增机制需要对应效果组件，不能只注册一个没有行为的 ID。

| 层 | 文件／模块 | 修改范围 |
| --- | --- | --- |
| 原表基表 | `config/items_v5.json`、`tools/import_items_v5.py` | 保留原附件及严格导入，可重建；不直接在生成文件里调参 |
| 实施声明和设计覆写 | `config/item_v5_authoring.json` | 标签、前置、图标键、出现权重、参数、价格、停用与新增常规属性道具 |
| 持有与装备 | `RunInventory`、`EquipmentService`、`BuildState` | 稳定实例、成长、原子校验、容量与从基础重算；不按新道具逐件加分支 |
| 机制组件 | `scripts/items/v5/item_*_effects.gd`、`ItemRuntime` | 六类真实效果，消费已接受事件；新增机制在对应组件实现并验证撤销与生命周期 |
| 表现 | `ItemPresentation`、`ItemEffectView`、`ItemV5Entity` | 消费定义与真实结果；独立图标／特效资源工作见[美术工作线](worklines/item_art_01/) |

覆写层包含 `schema_version`、`metadata`、`overrides`、`additions`、`disabled_ids`。`metadata` 是开发者维护的组件身份声明；日常数值、图标和出现率在 `overrides` 调整。覆写不能把被动道具伪装成主动、伴随、标记或投射主动，也不能修改绑定的组件通道；注册全新机制时必须同时实现组件和审查身份声明。

## 日常命令

全局选项放在子命令前。所有写入先校验，失败保持原文件；成功替换前把原字节备份至 `build/item_authoring/edits/`。

```bash
python3 tools/edit_item_catalog.py list
python3 tools/edit_item_catalog.py show B11
python3 tools/edit_item_catalog.py set B11 effect_parameters.max_hp_add_by_level '[2,3,4]'
python3 tools/edit_item_catalog.py set B11 shop_price '45'
python3 tools/edit_item_catalog.py disable B11
python3 tools/edit_item_catalog.py enable B11
python3 tools/edit_item_catalog.py reset B11
```

`disable` 是下架：权重变为零，不再进入新奖励或商品池，定义仍可供持有实例和 Manifest 识别。它不强删玩家背包、不退款，也不重抽已经冻结的奖励。`enable` 只移除下架标记；原本配置为零的权重仍为零。`reset` 只撤销该 ID 的覆写，不删除新增定义或下架标记。已删除的旧 ID 不复用。

需要先查看提案时，写入独立文件：

```bash
python3 tools/edit_item_catalog.py --output build/my-item-proposal.json set B11 shop_price '45'
```

工具验证结构及参数契约，完整准入以 Godot 为准。修改后运行对应检查，重新开始一局验证；当前不提供跨已有实例、旧报价和冷却状态的热更新承诺。

```bash
python3 tools/edit_item_catalog.py check
python3 tools/harness.py --check item-authoring-tools --check item-v5-authoring --jobs 1
```

## 新增常规属性道具

```bash
python3 tools/edit_item_catalog.py add-static EXTRA_HEART --name '备用心匣' --params '{"max_hp_add":2}' --gear-cost 2 --price 35
```

当前数据式新增支持六种已实现的参数：`max_hp_add`、`max_hp_multiplier`、`ground_recoil_multiplier`、`coyote_time_add_s`、`focus_stamina_drain_multiplier`、`focus_stamina_recovery_multiplier`。使用 `*_by_level` 的三个数值可创建 Lv1–3 成长。卡片读取当前等级的实际数值，不要求为新 ID 再写一条 UI 文案分支。

普通静态新增不能声明主动或召唤能力。新增投掷物、特殊伤害、防御或召唤机制，需要在对应效果组件实现、注册并补实际行为验证；已有代码不会把未知效果当作实现成功。新增道具不需要修改背包、负荷、装备事务或钱包核心。

参数须符合原参数契约：未知键、拼写错误、非有限值、非法数量、缺失等级、以文本伪装数值都拒绝。修改现有道具的参数只能覆写已声明键。版本与指纹用于识别真实定义；涉及上线定义变化时同步维护 `definition_version`，保留旧证据，不改写原附件。

## 图标与技能美术

`config/item_v5_art.json` 是表现资源目录：`icons` 映射图标键到真实 PNG 与整数 `region`；`clips` 声明帧窗口、fps、循环、世界画布和归一化锚点；`entities`／`cues` 把实际实体种类或事件及定义来源映射到片段。定义用 `runtime_metadata.icon_key` 引用 `item_<ID>`，ItemCard、背包、详情、奖励和商店共用 ItemPresentation，不在各个界面重复写 ID 分支。

新增美术须登记原始来源、提示／参考、SHA、导入与采样方式，并在实际52px网格、90px详情和世界比例查看。图集可以共享，但每件图标必须有独立、可辨的实际区域；把同一窗口改名不算新图标。显式请求缺图会诊断并返回空，不能静默借用通用图冒称已完成。新道具通过数据维护检查不等于美术完成，完整美术检查还要求新增道具也有独立资源。

效果组件仍拥有伤害、共鸣、状态与生命周期。ItemArtLibrary 只缓存资源，ItemV5Entity／ItemEffectView 只表现已存在的状态和事件；炮口／施放事件与实际正 HP 提交后的接收事件分开。素材不能触发伤害或返能。PNG 不持有角色，表现受原世界时钟、装备来源和 epoch 约束。

维护检查区分冻结原表与当前配置：原72件的既有指纹和目录断言保留在未覆写基表上，当前目录另按实际覆写／新增声明验证。合法调参不应被维护检查硬编码的旧价格或数量拒绝；固定战斗场景的平衡预期仍须随设计变更逐项审查，不承诺任意数值修改都能通过全部玩法回归。
