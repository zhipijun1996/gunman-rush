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

## R08：首8图标与三组VFX的实际黄金消费者

本节覆盖上文“仅G0、54项”的当前阶段描述，保留其历史原貌。完成初版通用说明的checkpoint `df5b075799e36624597b780a17d88850f0b4ff21` 中，style16 SHA `fe89f171ad210b0ddc16c355c94c48b34d1a66891fd6ca25c0810c6f32aa336f`、creative19两区、registry、原影响说明及三份变化消费者旧源按原字节归档于[pre-golden-r08](../evidence/item_art_01/source-bindings/pre-golden-r08/manifest.json)。这是未发表style16／creative19候选内的新实际资产阶段，不覆盖已交付style15／creative18原件，不继承前轮42／四check或旧美术通过。

当前实际54项前缀仅ItemPresentation、ItemEffectView、ItemV5Entity三份源改变，其他51项及原36项前缀不变。追加7项实际依赖为61：ItemArtLibrary、item_v5_art配置、提供icon_key的item_v5_authoring元数据、首8图标原PNG以及P24／P14／G16三个VFX原PNG。前者真实加载和采样Texture2D／AtlasTexture并按配置绘制；View／Entity消费动画帧，ItemPresentation按声明key取图。ItemRuntime的新accepted-HP桥接属于技术效果／来源／生命周期闭包，另做原生验证，没有把它冒充一个额外绘制叶子。

新首8图标是B01／B03／B11／P24／P14／G14／G16／N01。原图1774×887，采用真实独审允许的八个340×340非均匀ROI并保留原始字节；源请求1024×512、等格、native64与透明留白约束的失败仍保持失败。独立ImageTexture小样的52／90可见观察只允许这8项进入真实黄金界面集成，不能代签实际导入、Menu／Card／奖励／商店／960小屏或VFX连续动作，也不允许整72项扩产。

VFX仅P24／P14／G16候选。实际投射体／伙伴身体与cast／muzzle／committed-impact映射、帧长、尺寸和pivot由注册配置消费；表现观察已接受事件，不能决定伤害。当前世界／来源／装备修订／run-stage-actor／武器epoch失效时撤销表现，不用动画碰撞或假命中补玩法证据。原生ART156／0与孤立采样评审保留它们真实来源；本R08绑定还需协调冻结后的原42／四check、正式App黄金、实际两尺寸界面、连续VFX动作与独审。当前不声明美术完成、全72覆盖、原生64合规、玩家或实体设备认可。

当前R08 style16 SHA `473a8efc6ccba6a98696a0a29dfbf980f30c65b217685fc7b885f3a319e20149`。原32／10守门保留全部历史14／15／17／18身份与拒绝，并加冻结pre-art16／19身份和旧绑定拒绝、原54项前缀精确变更及新7项精确role／path／SHA、全部新叶子漂移前后与恢复拒绝；不缩短预算、不移除原断言。新的实际运行结果另记，旧技术回执不能为后续资产签字。

R08作者技术复验已实际完成：原Bible32／0（6.316秒）、方向10／0（1.467秒），原四个Harness check全部fresh通过。当前61项SHA匹配；原54项role／path顺序保留，其中三项实际改变、51项不变，原36项逐字相同。原有限191输入前缀逐字保留，仅追加11项真实新依赖与历史快照为202，原creative全源digest、命令、预算、成功模式及历史断言不改。[分源回执与完整引用身份](../evidence/item_art_01/source-bindings/r08-golden-validation/summary.json)记录checkpoint df5b与修改中的工作树；没有启动Godot。这是作者技术绑定复验，真实原生、界面／世界／连续影片、独立审查与实体设备认可分别记录。
