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

## R09：72图标／42段表现候选与整体风格采样

本节更新R08之后的实际源阶段，保留上文各阶段及回执的历史身份。R08 style16 SHA `473a8efc6ccba6a98696a0a29dfbf980f30c65b217685fc7b885f3a319e20149`、creative19两区、registry、实际源消费者、旧图像原件、守门及原42／四check回执，在任何扩产写入前已经归档。现将那份66文件原件逐字晋级到[pre-expansion-r09](../evidence/item_art_01/source-bindings/pre-expansion-r09/manifest.json)，原manifest SHA `9eaa2d11a9569c25a8bf858b5104e649a6595fa51e8c563bd56a4a0d85d65725`保持不变，单独的promotion-receipt说明复制来源；不回写旧绑定或改签旧通过。

当前注册配置实际引用72个道具图标、42段clip和10张原PNG：保留首8图标及原P24／P14／G16源，再增加四张catalog图标源和static-entities／static-procs两张源。它们是已经存在并被实际图集配置消费的候选，不用覆盖计数代替每个图标或效果的画面验收。新原图和实测ROI／帧／pivot／尺寸／方位／演化variant均有各自来源；旧尺寸、等格、原生64和透明留白失败保留原判定，不把测得ROI或不改字节的导入过程重新命名为原规格通过。

原61项role／path／顺序完整保留，仅6项实际更新：ItemEffectView、ItemV5Entity、已存在的ItemDefenseEffects绘制叶子、ItemArtLibrary、art配置、icon元数据；其他55项逐字相同。本轮ItemPresentation未再改变。相对最初pre-art54项，当前实际变化为4项：其既有通用说明改动，加View／Entity／Defense；相对R08原54项只有后三项新增变化。继续保留原36项地形／身体／全局shader字节。末尾只追加实际6张新PNG及item-local shader，共68项，没有发明额外绘制叶子或重选全局画风。

用户强调的整体风格继续由同一已选32px／32wu、1wu／nearest、原Underworld角色／地形／光照／材质与两区Bible约束。ItemArtLibrary使用实际 `shaders/item_v5_world_sprite.gdshader`：继承canonical全局shader的vertex／light与整体1wu取样，仅增加真实边界反例需要的0.001 texel偏移和每次DRAW的REGION_RECT钳制。canonical `underworld_fine_sprite.gdshader`仍为SHA `8132707bd3baf841ceda85d1c728890f813f19c4fccfd3cb07c9fcbecc185188`，没有修改全局资源。绘制原点取整不搬动actor／弹体／碰撞／交互锚点，不用视觉缩放改变伤害半径；aim／travel／upright、radius／segment及variant来自实际事件和状态。

已有ART924、shader GL11、whole-body35与各UI／世界证据保留它们实际采集源和限定范围。本绑定不把这些数量代签72件逐一画面、所有42段连续动作、正式整局、听感、设备性能或玩家G5；新增静态或循环表现也不能替代真正命中／未命中、遮挡、卸下／死亡／失焦／暂停／换图的生命周期观察。本轮仍属同一未发表style16／creative19候选内的技术影响，没有新global style选择、复用旧审美通过或自动合main。

R09当前style16 SHA `bc3c97d31789281fdfa0679cb821243d5f4a1c796398530e0f83a9a59fdfd96a`。原32／10全部方法、旧14／15／pre-art16／R08-16及17／18／各19绑定的身份／拒绝、stage gate、漂移前后及恢复反例保留；追加R08完整61项冻结身份、实际6处变化、当前68项精确角色路径和新增7叶子反例。原202个有限输入作为原序前缀保留，仅追加实际新源及测试读取的R08快照11项为213；item-v5-art已有14个输入不变。原命令、预算、成功模式及creative全源digest不改。UI native源租约结束并冻结后才运行本轮原42／四check；尚未运行的结果不记通过。

R09作者实际纯检查已经完成：原Bible32／0，9.452秒，保留原30秒预算；方向10／0，1.797秒，保留原60秒预算；四个原Harness check全部fresh通过，未启动引擎。[准确源回执](../evidence/item_art_01/source-bindings/r09-validation/summary.json)保存完整68项引用、6个实际R08差异、原202项前缀与11项追加、原始日志与Harness报告。原件66份逐个哈希匹配、原36项与canonical全局shader保持原字节，item-v5-art的14个输入未改。这是作者技术验证；新增素材、真实原生、全部UI／世界／连续动作、独审、远端CI与玩家／设备证据继续按各自真实来源报告。

## R10：三项原始实体边界的纯元数据修订

本节在R09的68项实际源上，只更新 `config/item_v5_art.json` 一项引用；其余67项role／path／SHA完全不变。已提交checkpoint `f9fefe6e14e9a3bf7858d4f57f5fc5ea2293d5cb` 中style16、registry、两区creative19和art配置五份原件逐字冻结于[pre-envelope-r10](../evidence/item_art_01/source-bindings/pre-envelope-r10/manifest.json)，R09原检查与画面各保真实来源。没有新图像、shader、runtime、物理、资源或全局style修改，也没有新增引用。

本轮只调整g05.large_guard、p20.crystal、p25.needle_trap三项的regions／world_size／pivot，72图标及另39项clip精确不变。按原图真实轮廓裁定边界，排除的只有黑色alpha1填充，原始alpha≥2像素全部保留；该像素保留性质来自单独独立数据证明，不是本绑定的审美判断，也不修改PNG原字节。显示矩形约G05 38.82×32、P20 17.89×26.11、针阱13.30×13世界单位。针阱金属脚本地[118,212]对应显示原点下方2单位；它是只读绘制锚点，不移动实际摆放／接触／伤害位置。

最终art配置SHA为 `708017d6913cea4605f94dcdc0635d48df397e8f1c89eafe9dc0f2512a482f9b`，当前style16 SHA `aa06d0dc339247cbc5ba1068887c19d39b2b8cbfccc94c8647c6e99ae1fe0867`。此前关于“缺行”的判断已被原03字节完全相同的重放与像素计数反证；本轮不借该判断宣称修复不存在的生产问题。ART924及whole-body／pose83保留各自原生与实际GL来源；本绑定仅记录三个真实metadata envelope修订。新旧画面、正式全局流程、音画、玩家与设备认可仍分开报告。

原32／10全部方法、历史阶段身份／拒绝、原54／61／68前缀与原负例保留；追加精确R09-68原件、旧同版本绑定拒绝、当前仅一项SHA可变／67项不变，以及元数据仅这3项及3个字段组可变的断言。原有限213输入作为原序前缀保留，仅追加测试实际读取的五份R09冻结文件为218；item-v5-art14输入、全部原命令／预算／成功模式与creative全源digest不改。本轮纯检查在确认最终配置SHA与原生租约结束后运行，实际结果另附。

R10作者实际复验完成：原32／0，9.336秒；原10／0，1.951秒；四个原Harness check全部fresh通过，原30／60秒预算、命令、断言和成功模式保持。完整68项当前SHA匹配，只有art配置变化、另67项逐字相同；原213输入前缀保留为218，item-v5-art完整定义及14输入与f9 checkpoint相同。[本轮完整身份与原始回执](../evidence/item_art_01/source-bindings/r10-validation/summary.json)记录基线f9与修改中的工作树，未启动引擎。原生／实际GL83及正式画面、独立数据证明、独审和玩家／设备验收各自按真实来源报告。

## R11：P26／P27完整调用的旧确认表现清理

R10 checkpoint `01e05bd4edc5724b5386a5129bc6974a2da9f3ce` 的style16、registry、两区creative19及View／Defense两份旧绘制消费者源，逐字冻结于[pre-legacy-cues-r11](../evidence/item_art_01/source-bindings/pre-legacy-cues-r11/manifest.json)。原R10技术通过仍绑定其旧源。本轮68项role／path／顺序不变，只更新ItemEffectView与ItemDefenseEffects两项SHA，其余66项包括art配置 `708017d6913cea4605f94dcdc0635d48df397e8f1c89eafe9dc0f2512a482f9b`、全部PNG／shader／尺寸／pivot／语义映射完全不变；没有新资产生产或global style选择。

实际完整P26／P27调用专项暴露旧generic确认与已接受专属art重叠，以及资源回调改变装备／选择后旧确认使用新origin或留下ghost的失败。修前40检查／6失败和修后40／0保留原样；原924断言继续保留，当前完整ART1077／0按其真实源报告。这些数字不是新画面、全局手感或玩家认可。

Runtime在原激活路径前保存original activated ID、presentation context和castpoint；Defense在原spend回调前保存visual receipt，之后旧确认携带该原身份。View对legacy active／defense_active同样校验当前来源与会话，并在已接受专属art帧去重旧generic确认。资源回调造成的卸装／改选／失效不能把旧表现指到新道具，或凭空复活旧显示。Runtime仍属伤害／资源／技能与来源生命周期的技术闭包，不新加为绘制叶子；原HP、消耗、on_skill、技能提交与几何规则不变。

当前style16 SHA `9dcfa6c4aa17c84f7d54492df8aefa78718adf17c2346c91823d14bea4b25e42`。原32／10方法、历史身份、前缀、全部负例／漂移／恢复／阶段守门保留；原R10“一份配置变化／其余67项不变”的断言改以精确冻结R09→R10比较继续保留，再追加当前R10→R11“两份绘制源变化／其余66项不变”、旧源快照与旧同版本绑定拒绝。原218个有限输入前缀完整保留，只追加这6份实际被测试读取的冻结文件为224；art14定义、原命令／预算／成功模式及creative全源digest不改。纯检查待root完成实际文档／证据写入并冻结后执行，不把旧通过挪作新源通过。

## 原始Markdown归档导航修正

四份冻结Markdown直接搬入新目录后，其原相对链接失效。本轮保持原字节／SHA，以同路径`.md.txt`保存逐字原件；原`.md`改为明确的归档说明，只链接逐字原件和实际原始文档当前工作版。三份原manifest也逐字保留为`manifest.before-markdown-relocation.json.txt`；现manifest只追加relocation和原JSON副本说明，原path／sha256／bytes不删改。当前绑定的历史manifest引用改指向保留原hash的JSON文本原件，冻结的历史style／方向本身不改写。完整迁移来源与哈希见[迁移回执](../evidence/item_art_01/source-bindings/markdown-archive-relocation.json)，不复制数百份链接闭包，不将wrapper说成历史原件。

原32方法内增加4份文本原件及3份原manifest的精确字节守门，并核实所有历史字段保留。原224个输入保留，只追加实际读取的10份txt／manifest为234。所有旧守门、旧输入和原预算不变；归档修正不涉及runtime／配置／图像／shader或生产规则。

## R12：dedicated heal／barrier跨spend回调的原始身份

R11预稿在独审发现P27／N02 spend回调卸装后重装的专属heal／barrier会重新获取新context后，未执行本阶段纯检查，不能标为通过。其style16／registry／两区creative19原件和旧Defense字节已冻结于[pre-spend-proof-r12](../evidence/item_art_01/source-bindings/pre-spend-proof-r12/manifest.json)。旧Defense由已提交01e基线及已记录R11补丁恢复，完整SHA与冻结R11引用7bd276完全一致；该恢复不是新运行或旧观察采集。R10、R09及更早证据保留各自来源与结论。

最终修订仅在现有Defense绘制叶子传入原始pre-spend visual proof，Runtime的heal／barrier技术桥接受该既有proof。明确提供的stale／empty proof保持失效，不在回调后重取新身份；普通地图／伤害授予路径继续本地取证。HP、屏障数量、接受成本、on_skill、几何、素材、配置与shader不改。原1077守门继续保留，最新完整ART1185／0、失败反例与独审报告各按实际来源说明，不能由本绑定代签画面／玩家／设备。

当前style16 SHA `079de07b65d33c4e12364a22fa2f8408b0cd63b6044570bb6c7b5800799cf403`，68项role／path／顺序不变，相对R11只更新Defense一项SHA，其他67项精确相同；View仍为09ddea、art配置仍为708017。Runtime仍属技术来源闭包，不添加虚构绘制叶子。原32／10全部方法与历史负例保留：R10单配置比较、R11两叶比较分别在其精确冻结阶段继续验证，再追加最终R11→R12单Defense／67不变和旧同版本绑定拒绝。仅追加5份实际读到的R11原件输入，有限清单从234到239；原224前缀、art14、原命令／预算／成功模式及creative全源digest不变。最终原42／四Harness待root文档／证据冻结后统一执行，输出build再归档，不继承任何未执行的R11通过。

## R13：合入最新main的用户选定声音消费者

原R12源在原32／10与四个Harness fresh通过后提交为 `0a45623b`，随后发现main已更新为 `11e35968323bbc3d3e95a0b0c0c4fc9378e702cd`。本分支以 `4de01808f28e9471016e15155f0c36b8fbae75ab` 合入最新main，保留用户选定的声音资源／配置／调用与导出、两侧文档原文；旧R12检查不签该新源。其style16／registry／两区creative19与旧WeaponFeel原件逐字冻结于[pre-main-audio-r13](../evidence/item_art_01/source-bindings/pre-main-audio-r13/manifest.json)。

实际68引用仅现有 `scripts/dev/player_presentation_01/weapon_feel.gd` 的SHA变化：原 `_sound` 的 `audio.weapon_cue` 调用增加实际 `controller.shoot_ability.weapon.id`，使main新声音选择按真实武器路由。除这一参数外，完整原源与_draw／beam表现字节保持相同；其他67引用、专属cue修复、配置708017、PNG、shader与整体像素规范不变。EnemyActor的main声音调用属于正式音频／玩法技术消费者，不额外发明美术叶子，也不生成替代用户音效。

当前style16 SHA `62befdd0e89ea7b17b649b93dce977b1a35eb2164bad1b9500c108b33309b6da`。原R12及所有先前历史守门在精确pre-audio引用上保留，新增当前仅一个WeaponFeel叶变化／67项不变、原源只差实际weapon-ID调用参数和旧同版本绑定拒绝。原239输入前缀完整保留，仅追加5份实际读取的R12原件为244；art14定义、原预算／命令／成功模式、creative全源digest与Harness全局源码守门不变。

merge重启sparse可用性后，使用原cloud_inputs对最终选定30scope按精确HEAD恢复所需输入，完整结果保存在build。该步骤只证明输入可用，不是测试通过。原32＋10／四Harness须在物化与producer源码最终冻结后重新fresh执行，仅向build输出，再由root归档。声音听感、正式完整流程、用户／真机与full CI各按实际来源验证，本技术绑定不代签。

R13首次实际执行中Bible32／0，但方向10在读取冻结creative-v17平原原件时因sparse缺件失败，四项Harness尚未启动；原失败日志保留为validation01。官方30scope的ready只覆盖已声明输入，不能证明这条遗漏的历史直接读取链可用。核实后保留244项前缀，仅追加方向测试真实读取的v2两区、v3森林和v17三份历史JSON，共6项为250；旧HUD／foreground历史链继续原preflight显式规则，不缩creative全源digest，不删负例或放预算。再用原cloud_inputs按精确HEAD恢复缺件后，按同一原42／四Harness重跑。这里是输入可用性声明补齐，不把失败改签通过或新增玩法兼容任务。
