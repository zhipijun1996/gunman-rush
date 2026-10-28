# ITEM-AUTHORING-01：style-v16／creative-v19 技术绑定

本轮在已经交付的道具V5源 `d9445c0e5d6516d4eb93ebbfbc5639efddf7fc04` 上改进新增道具的编写流程。新数据式静态被动道具通过同一当前等级参数生成数值说明，不再要求为每个新ID添加UI分支。实际视觉消费者只有 `scripts/ui/item_presentation.gd`；目录、准入和随机池的作者工具改动由各自运行契约验证，不机械加入共享美术引用。

## 原件与变化边界

style-v15原文件继续保持 SHA256 `6d0303e867592d72723973f29060902226b1f25e31aff24fcd065fff427cbfd0`。新style-v16复制原54项role／path／顺序，仅把ItemPresentation的完整SHA绑定到当前实现，其他53项精确不变，原36项前缀完全不变。32px／32wu、1wu／nearest、Underworld家族、47邻接／精确边界、原Bible、原始用户引文和许可继续有效。

creative-v18两区方向和registry逐字归档于 [archive/creative-v18](archive/creative-v18/registry.json)，同时将style15、方向、registry、旧影响说明与真实旧ItemPresentation字节复制到[版本原件](../evidence/item_authoring_01/source-bindings/before-v16/manifest.json)。旧证据保留其原来源，不为本轮重签通过。

| 原件 | SHA256 |
| --- | --- |
| creative18 registry | `706ebe31662101266b55bb832cfab6ccf4a9b7b00b6d36ee62d30a7d1ec788ec` |
| creative18 平原方向 | `3fc390336ca7650562b287b9082279a7e647a9e89cc302170c088c9c015d5ca9` |
| creative18 森林方向 | `d48147cf7ee5b6648cff51b579a6f776620263d30ef7528f5094bf27cc0fef20` |

新creative-v19保留原总谱内容、旧authority_sources前缀，再追加style16，完整region_bible绑定同时版本化。方向中的user_confirmed仍仅指原Bible选择，不是对新道具编写工具、美术、效果或设备的认可。

## 当前实际消费与后续美术

ItemPresentation先保留已有特殊机制的显式格式；对没有ID分支的新静态道具，按当前等级解析后的参数生成最大生命、反冲、离台宽限与时间能量等实际数值说明，无法生成时使用配置的description。正式奖励、商店、背包、详情和Toast继续使用同一格式器。该改动不授予能力、不提交交易、不改变BuildState重算。

ITEM-ART-01独立图标和技能VFX改进目前处于G0规划。本绑定没有添加任何尚未存在的图像、图集或表现消费者引用，也不宣称已经生成、导入或验收美术。后续真实资产和消费者改动必须保留本候选源与回执，明确影响后重新绑定实际字节，再做真实导入、黄金合屏、连续画面、事件和生命周期验证及独审；不靠更新SHA继承旧画面通过。

## 验证与未验边界

原Bible32和方向10测试的命令、预算、全部原适用断言保留；当前精确版本更新16／19，保留原style14的36项、旧版本SHA／拒绝与stage gate，并追加已交付style15的54项冻结身份、53项不变、新旧当前消费者完整SHA及creative18原件拒绝。原四个pure Harness入口、argv、预算和成功模式不改。有限输入清单只追加新版本及真实历史依赖，不删除旧输入；creative-direction-tests继续使用原全源码digest。

上述测试须在root协调的实际源码窗口运行。作者技术验证、独立审查、原生正式消费者、实际GUI／画面、远端CI、玩家和实体设备分别记录。当前文件只说明版本影响；测试与美术没有运行的部分保持未验证，不能以绑定当作完成、生产准入或艺术认可。

本阶段实际作者验证：原32＋10均零失败，四个原Harness check均fresh通过，未启动Godot。精确style16 SHA `fe89f171ad210b0ddc16c355c94c48b34d1a66891fd6ca25c0810c6f32aa336f`，全部54当前引用匹配，仅ItemPresentation变化，其他53项与原36项前缀逐字相同。原有限187输入只追加4个新版本／历史依赖为191，creative全源码digest保留。[分源原始回执](../evidence/item_authoring_01/source-bindings/pre-art-v16-validation/summary.json)记录基线D944及修改中的工作树，不能把随后新增美术或源代码宣称为本轮已验；当前为独审前作者技术结果。
