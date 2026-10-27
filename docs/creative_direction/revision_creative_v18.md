# ITEM-V5-01：style-v15／creative-v18 技术绑定

本轮是正式道具 V5 的消费者版本化，不重新选择地区主题或像素规范。原生 32px/32wu、世界 1wu/nearest、Underworld 家族、47 邻接和精确边界合同继续有效，两份用户 Bible 与原始选择依据不改写。root 已冻结本次实际视觉消费者的字节，style-v15／creative-v18 已按本轮源激活。哈希只标识本绑定的字节；测试与输入负例的实际结果见 `build/item_v5/style-binding/`，不以绑定代替验收。

## 历史原件与变化边界

style-v14 原件 `bibles/style-continuity-20261026-v14-run-gear.json` 保持 SHA256 `a9fba5dd2cadbc1d36abda4928f4d473bd8849d882346abd70870a68900dc366`。新版本保留原 36 项引用顺序，仅更新其中 DemoApp 的实际完整字节绑定；另外 35 项不变。在末尾追加 18 个真实界面／绘制消费者，总计 54 项；不把未改绘制的 PlayerProjectile 或所有道具玩法代码加入共享美术闭包。

creative-v17 的平原、森林、注册表按原字节归档到 [archive/creative-v17](archive/creative-v17/registry.json)：

| 原件 | SHA256 |
| --- | --- |
| registry.json | `5d1e3bd9544d960f8dfc359682293f7729b02c7cc15d76b20115431e9e67b1d8` |
| windchime_plains.json | `ea67a36b0ce4a1606bca185c87879048493546d1602d8772b802f0d94ae93849` |
| thorn_forest.json | `4a61fefb33edffd734302eb32fa1a8dbe3b0f06f8212d3dc21923a92665860f8` |

creative-v18 只更改版本、完整 Bible 注册绑定、追加 style-v15 的 authority source 和版本化影响记录。原地区意图、玩家行为、主题、美术要求、原始用户引文与旧 authority_sources 前缀保留。方向的 `user_confirmed` 仍仅指原 Bible 方向选择，不是这轮道具、美术或真机验收。

## 追加的实际消费者

| 消费者 | 真实生产关系 |
| --- | --- |
| ItemEffectView／item_v5_feedback.json | DemoApp 将 ItemEffects 挂在正式 stage；仅观察已接受 effect_cued，按配置绘制有界反馈。 |
| ItemV5Entity／item_v5_entities.json | 主动与伙伴效果模块创建实体视图；现有机械／齿轮主题绘制飞轮、陷阱、无人机与护卫，不产生新图像素材。 |
| ItemDefenseEffects／item_v5_defense.json | 真实角色上的 CrystalGlyph／GuardGlyph 绘制；配置控制可见半径与轨道角速度。 |
| ActorResourcesHUD | 通过真实 actor.item_runtime 显示当前屏障数量。 |
| DemoMenu | 暂停背包实际等级、损坏状态、主动选择、装卸与修复入口。 |
| ItemPresentation／ItemCard／ItemAcquiredToast | 同一真实文本格式器、现有图标字体；奖励、商店与拾取显示当前等级实际效果。 |
| ItemShopModal／StageRewardModal／ItemV5ShopPresenter | 正式商人与奖励选择的实际卡片、刷新、修复及失败文案；Presenter 由 DemoApp 创建并驱动该模态框。 |
| TouchOverlay | 正式横屏触控的独立道具技能按钮及名字。 |
| WeaponActionRuntime／WeaponFeel／WeaponVfxV2 | 已装备激光宽度实际影响 runtime fallback、经典与当前默认视图的 draw_line 宽度；不是仅有纯逻辑函数的绑定。 |

完整 role/path/SHA 与实际消费者边记录由 style-v15 保存。未进入此有限视觉闭包的伤害、穿透、时间、经济、物理和生命周期变化仍由原专项与受影响的正式消费者验证；本绑定不豁免它们。

## 守门与输入闭包

原 Bible 32 与方向 10 测试入口、全部原适用断言、G2/content／未正式开放边界、30／60 秒预算与 `^OK$` 保留。新增精确 54 项及原 36 项前缀校验，style-v14 与 creative-v17 原字节身份、旧绑定拒绝，追加消费者的漂移前后／恢复反例。作者的准备与运行结果不能当独立审查。

Harness 的 region-bible-tests 保原139项有限输入并追加48项实际依赖，总187项；原命令、预算和全部旧输入保留。creative-direction-tests 恢复原缺省全源码 digest，没有新增 glob 或生产基础设施语义。作者曾添加120项有限输入，独立审查发现其遗漏从动作设计README链接读取的契约，且实际 source_files/snapshot 动态扫描全源码；该收窄已撤回，原失败与收据保留。独立选择creative的稀疏availability不宣称完整运行闭包；本轮最终选择同时包含region的必需输入。官方 materialize 的 ready 只证明输入可用，不证明测试通过；隔离缺件负例也不证明完整运行闭包。

最终冻结后须新鲜执行原 32＋10、原 Harness、独立精确源码审查以及 root 统一引擎租约下的道具／受影响玩法、GL 和连续操作采证。这里不签用户审美、手感、平衡、实体 Android／手柄性能或地区开放；旧 PASS 不自动继承到新版本。

本次作者实际验证：原 Bible 32／0、方向 10／0，相关四个原 Harness check fresh passed；隔离 Git 完整 index／选定字节夹具上，两次原输入 CLI ready、五个真实 S 缺件均 exit2 阻断（旧 v3、前版 v17、当前 v15、反馈视图、docs/.gdignore）。第一次夹具 write-tree 因 partial clone 无关对象未缓存而 exit128，保留为基础设施失败；不计入负例通过。原始命令、日志、全部54引用与历史字节 SHA、夹具身份及限定见 `build/item_v5/style-binding/final/summary.json`；这些是作者工程验证，不代替独立审查、真实画面或完整 CI。

独立审查后修订：旧 `final/summary.json`、四check及2ready／5blocked收据保留原身份，其中creative120有限清单已撤回，不能作为当前完整运行闭包证据。恢复原全源digest后的新作者原42／相关原Harness结果记录于 `build/item_v5/style-binding/post-audit/`；独立复核由另一作者执行。

## 未发表候选内的 tooltip／RNG 边界修复

GL02实际暴露了背包图标tooltip吞掉第一次Escape；本轮由DemoMenu._input提前处理取消，保留原_unhandled fallback及关闭后的输入隔离。缓存、Boss奖励和商店随机内容另改用显式稳定seed／map／source上下文；局内钱包、实例、offer与交易账本仍保持会话唯一键，不能把去重身份混入内容RNG。

这是同一main14→15／creative18未发表候选的修正，不另开美术生产或继承旧通过。前候选style15 SHA `af4c96718fe41aff2b11f5b81409c538963144967b01f2123589b3000ca56ec6`、旧active方向／registry及原H开发42与4check回执已按原字节保存在[pre-tooltip-rng归档](../evidence/item_v5_01/source-bindings/pre-tooltip-rng/manifest.json)，build有同字节副本；旧主线style14／creative17及原Bible不变。新revision_impact记录3个实际消费者App／Menu／Presenter的旧／新完整SHA及archive manifest，原36项顺序和另外35引用不改，总54项保持。

重验必须绑定本次3hash：原32＋10、四个原Harness门禁fresh；原pause-escape真实tooltip首按取消、pool／formal跨runprefix的缓存／Boss／商店确定性与交易唯一性反例，以及修复后真实GL连续操作由root原租约执行。此前GL和H证据保留各自版本，不替新修复签字；这里不代签用户、实体设备或视觉最终认可。

## 未发表候选内的当前 Manifest 回放修复

最终受影响29项检查中的森林跨区流程拒绝了旧候选：正式V5商店启用后，legacy商店分支误连带跳过region_map记录；原资源式回放也不能表达已升级或损坏的V5装备。原REJECT保持失败。当前App把地图身份记录移出legacy商店条件，并记录版本化的已装备实例定义／版本／指纹／等级／损坏状态与配置齿轮等级／容量；BuildState与Manifest共享同一纯Modifier计算，以原stage_tuning严格校验重建。该元数据只复现地图内容，不是恢复完整背包、账本、HP或技能状态的存档接口。

前候选style15 `67b7acb8d6f6b555af60649fd838c5b5eb876248be24219ee89168d8149638ef`、两区方向、registry、实际旧App字节及原tooltip／RNG阶段42与四check回执已原样归档于[pre-manifest-repair](../evidence/item_v5_01/source-bindings/pre-manifest-repair/manifest.json)。本次只更新54项引用中的实际App完整SHA，其他53项、原36项顺序、style14／creative17原件与所有Bible不变；新旧差异与复验要求写入manifest_repair_iteration，不覆盖前轮tooltip／RNG影响记录。不新增美术生产，不从旧测试继承通过或用户／实体设备认可。当前原42、四check与新Manifest／原campaign运行结果须各自记录真实来源。

Manifest修订作者验证已完成：原32＋10分别零失败，原四个Harness check均fresh通过，所有54引用匹配当前源，原36前缀中除App外35项逐字相同。当前style SHA `6d0303e867592d72723973f29060902226b1f25e31aff24fcd065fff427cbfd0`，App SHA `f75f32cc918d3368d6aa55be94206465163ed7706eb31b19690811da6d009119`。首轮因作者重绑顺序遗漏registry_sha256而被原守门拒绝，补完整绑定后原样重跑；首失败及后通过均保存在[分源回执](../evidence/item_v5_01/source-bindings/manifest-repair-validation/summary.json)。这些检查只验证技术绑定；新的原生回放／跨区、最终完整CI与独审另计。
