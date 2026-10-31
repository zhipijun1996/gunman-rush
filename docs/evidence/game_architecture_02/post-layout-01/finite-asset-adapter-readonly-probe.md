# 有限资产适配器与宝箱 provenance 只读复核

结论：只需拟议更新一项精确源码绑定；宝箱已有 provenance 记录，不需新登记。生产、工具、metadata 未修改，未运行引擎。读取 HEAD 6584d48b，工作树并发变更；逐文件SHA见JSON。

## 固定源码绑定（全部8项）

| 源码 | 当前绑定 | 与2ce差异 |
|---|---|---|
| `game/presentation/world/art/plains_connected_landscape.gd` | 匹配，保留 | 字节不变 |
| `game/presentation/world/art/plains_region_composition.gd` | 匹配，保留 | 字节不变 |
| `game/presentation/world/art/plains_landscape_observer.gd` | 唯一需更新候选 | 仅已声明路径替换，逐字证明 |
| `game/presentation/world/style_exploration/style_terrain.gd` | 匹配，保留 | 字节不变 |
| `game/presentation/actors/style_exploration/style_actor_visual.gd` | 匹配，保留 | 字节不变 |
| `game/presentation/world/style_exploration/style_scenery.gd` | 匹配，保留 | 仅已声明路径替换，逐字证明 |
| `game/loadout/effects/item_art_library.gd` | 匹配，保留 | 字节不变 |
| `game/presentation/audio/game_ambience.gd` | 匹配，保留 | 字节不变 |

唯一候选为 `plains_landscape_observer.gd` 的 `19cdab9eed2c620931fbf248599dd1df72a4705935d6b1f37235f77a4322080e` → `f017e38da1d03790432ed5389e217bcb9b82b6c0af62475ccd07c9e9ba31c782`。与2ce唯一行差异是 `OBSERVER_PATH` 从 `scripts/art/plains_landscape_observer.gd` 改到当前实际文件。该常量用于write_capture报告的observer.path与FileAccess自哈希，不读取或选择美术；采样、对象遍历、输出限制、计算与资源载入语义未改。现有精确绑定继续阻断任何未来未审源码变化。

style_scenery此前绑定已正确更新，唯一差异是StylePalette preload路径。其余6项源码字节与2ce完全一致，均不得批量刷新。

## 宝箱已有记录与实际缺口

`docs/quality/asset_records/CHEST-ART-01-source04.json` 已通过 associated_files/source_contract 关联 `assets/objects/chests/manifest.json`，记录SHA与实际 `21db7e569f2c6958504a391c139bd3ba7f09853e4e5144567f65728c6c478f7f` 相等。Manifest仅6个runtime_consumers路径迁移，图像、采用记录及配置未改。

validate_asset只报两份生成原件本地缺失：`request-04.json`、`prompt-04.txt`，均在`docs/evidence/chest_art_01/raw/generation/`。`git ls-files -v`为S（sparse跳过），2ce与HEAD Git blob哈希分别逐字匹配记录中的244015...与3ecf62...。因此整份资产记录未进入valid_assets，随后quality diff才报manifest缺provenance。应恢复原Git文件并重验，不应删除关联、重签生成记录或另建asset registry。

## 验证边界

只在Python进程内替换唯一候选哈希重新调用既有known_asset_consumers，结果：无错误，590个known assets。磁盘工具未改。这不代表完整quality diff、动态加载、GUI或设备通过；测试守门独审等其他阻塞仍保留。

## 并发后续观察

最终验证前，其他工作者已在工作树完成上述单哈希替换并恢复两份Git原件；本审查者没有编辑这些文件。因此最终probe的before=None是当前修正后结果，不能冒称重演旧失败。已核工具diff仅该一项，known_asset_consumers返回590项无错，宝箱validate_asset返回空错误。初次8项旧绑定及两项缺文件错误仍保留在JSON原始rows与chest_record_errors中。
