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
