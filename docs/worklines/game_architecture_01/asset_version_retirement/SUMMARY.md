# 是否应把旧资源全删？

**不应全删。固定正式选择、排除不需要发布的内容，才能避免混用；有消费者的旧文件直接删除会破坏功能。** 本报告只读绑定 C59：`c59c24fb76762a0f66033e0f79d7b2cba7a84444`，未改资源、未跑引擎、未检查最终 C59 PCK。

| 轴 | 当前正式版本 | 不能混同的旧/候选用途 |
|---|---|---|
| 场景美术 | Underworld 暖光 + fine32 地形；森林复用 Underworld 森林天空/道具 | `style_exploration` 目录中的 Underworld 森林图仍是正式资产；其他风格有独立实验入口 |
| 平原普通怪 | 六种 `plains_revision_01` 身体 + 俯冲怪 `frames_v8/underworld_diver` | 六怪不是全部普通怪；旧 Underworld aerial 图仍供俯冲怪锚点，旧图也仍被 preload |
| 森林怪 | forest_bible_v2 的 fine32 身体、weaver_silk_bell_v5；charger复用正式 Underworld renderer | 地图默认 v15；v16–18 是显式其他布局，数字更大不代表已替代默认 |
| Boss | Bellstrider 当前 MACHINE+BELL rig；Windkeeper Pressure 当前 rig | 使用已有 Underworld PNG，不因设计迭代就换图；旧Boss仍有明确历史消费者 |
| 主角 | 默认新 courier；经典 courier_classic 仍可选 | 默认身体继承旧 UnderworldPlayer，原 run/states 图仍有实际用途 |
| 音效 | 正式 selected v3 + hurt A、plains_feedback_02 材质声、选定 A 环境声与 Home life、原 BGM | v2、ABC、原 bank 是显式试听/回退消费者；完整环境声校验还要求 A/B 原16文件 |

当前正式绑定已有 Underworld 防降级措施，注册表不会因为目录有旧文件就随机选旧版本。`legacy/plains_charger_v2.tres` 只有 **623 bytes**，是旧森林 v11 的 **28×32 Definition**，不是旧贴图。当前默认 v3 为28×28。旧 Manifest 按精确SHA请求它，导出同时保存原 `.tres` bytes 和正常 `.remap/.res`，分别供 SHA校验与ResourceLoader使用；删除会破坏明确保留的历史消费者。

**确切清理候选：** `assets/plains_revision_01/source/first-palette.png` 与 `master.png` 两张绘制母版，正式 Skin 只读六张裁切图；两母版约4.16 MB原PNG。它们仍有生成/质量来源用途，应优先**保留原件、精确排除导出**，而不是删除来源。不能排除所有 `source/`：当前Root Bell脉冲就直接读 burst/source/master.png。

**发布污染风险是真实的：** 三个平台均为 `all_resources`，未排除 experiments；两母版没有排除或gdignore。Painterly旧13张图在Web全排除、Win/Android仅排除6张，存在平台差异。以上是静态候选，不是已检查的PCK成员/节省大小。

**可立即证明无任何运行、实验、历史、来源依赖并物理删除的文件：本次为零。** 已定位“无正式绘制用途但有来源用途”与“无当前formal外部边但有独立旧场景”的具体对象，不能用一次字符串零命中代替删除证明。

建议分三步：

1. 先用现有 Registry/manifest/入口矩阵固定当前正式选择，保留显式实验/历史消费者，不新增平行版本表。
2. 小批精确排除发布母版与确定的历史专用内容，分别验证正式包、保留实验入口、raw/remap和实际各平台PCK；不先删除源文件。
3. 对已无消费者的具体叶子，再沿现有有限归档/许可机制保原SHA后物理删除。涉及替换实验外观、移除经典角色或历史地图的项，另列内容迁移，不能算等价清理。

每批回退以其实际父提交为准；首批对照 C59。详表、行号与批次文件见 `report.md`；完整静态引用在 `family-reference-evidence.json`。没有代签 full185、设备、用户或新美术认可。
