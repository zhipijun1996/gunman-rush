# GAME-ARCH-01 / style26、creative29 技术绑定候选

本文件是尚未提交的技术重绑记录，当前候选生产源为 `063d6ccbd7a6ab659fd27abcb20a5c59c7308c53`，已包含 Boss 状态所有权尾项的七个生产文件。该尾项静态独审限定接受，原生尚待；同一 style26 / creative29 更新四个已绑定叶，并新增三个实际可达遭遇基类。没有额外生成版本或归档中途候选，不称任务或发布完成。

沿既有 Bible registry、style authority、两区 direction 与有限历史 source adapter 工作，没有新增运行配置/素材选择表。style26 保留原 153 个角色顺序，对真实迁移路径和字节作明确变更记录；当前另有 53 个实际生产依赖，共 206 引用。新增范围由本批语义改动/新增源与原 153 根的实际静态可达性交集限定，另含旧 v11 原始 Definition；不扫描整个 game 作为新权威。WorldAudioLifecycle 的真实五处调用属于四个 Study，不在这一正式根闭包内，仍由原 Study Harness 与原生生命周期检查绑定，不能假称已在这 206 项中。

原 style25、creative28、两区 Bible 原文、用户引述、旧接受限制和失败证据保持字节。原 P8.1 manifest `e7d7c7b0…` 与 80 文件不改，补档仍是原有限三个 source 及已有元数据迁移原件。所有原媒体引用必须与 style25 保持原 SHA；本批没有生成或替换 PNG/WAV/OGG/MP3/字体，没有代签新艺术、声音、玩法、用户或设备接受。

## 真实消费者与验证路径

`tools/region_creative_direction.py` 原先把 UnderworldPlayer 绑定固定到已迁移的旧 scripts 路径；当前版本改绑唯一 `game/presentation/actors/underworld_plains/underworld_player.gd`。明确历史 styles1–25 仍严格要求旧路径；当前不能仅复制旧路径并刷新 hash 冒充正确消费者。源丢失或漂移照常拒绝，live 验证从不读取旧 source archive 兜底。

当前两区方向的设计、生态、Boss、画风、体验内容保持不变；版本为 creative29，完整 region_bible 由原 bind_region_bible 构造，authority_sources 保留原前缀再追加新 style。旧 creative28 使用原有限来源重放仍可验证，但作为当前方向/恢复绑定必须拒绝。

原历史测试中需要读取旧源码的地方改用既有精确 adapter；当前 fixture 篡改与真实 consumer 读取改到当前路径。完整原测试文件仍在不可变归档。16 个确需迁移的原 test method，分别固定原 AST SHA 与当前完整 AST SHA并列原因，其余原 method 仍必须完整 AST 相同；另保留所有原 assertion 的多重集合约束。新增真实 guard 反例对临时 AST 注入前置 return、if False 包裹或空循环，均须拒绝。仅保断言文本不能保执行语义，因此不采用单独的 assertion-counter 替代整方法保护。

历史 motionloot 的原 368 输入前缀属于原 program/Windkeeper 祖先。现有 Windkeeper 父冻结 profile 的前 368 与原列表逐项相等；4bb 合并 profile 从索引 320 插入另一父内容，不能拿它冒充原前缀。历史前缀测试现明确读取真实父源，不再宣称这一读取证明当前 CI。

当前 CI 保真另由 [style26_input_migration.json](style26_input_migration.json) 验证：使用原不可变 profile595，加回原索引 320 的三个重复记录，逐项重建 `2ce4ffa6` 的原 598 输入并校验原向量 SHA；再应用 85 个真实路径变换，要求当前前 598 **逐项、顺序、重复次数**完全相等。此 receipt 是小型技术证据，不是第二份输入权威；现有 profiles 仍是唯一执行清单。

root 已恢复原三个重复条目。原 region-bible-tests 当前为 653 输入（映射原598 + 原后续2 + 当前新style/依赖49 + 此receipt1 + Boss基类3）；region-bible-contract 为314。另两项原无显式 inputs 的检查保留全源摘要语义。新增测试用原 harness.input_digest 核四项检查中每个当前 reference 的字节变化都会使缓存失效；没有改命令、预算或 full182 列表。

## 已取得证据与未完成项

- Boss尾项063d6ccb刷新后，原archive与当前guard合计14项通过（3.789秒）；包括新三个Encounter基类篡改/缺件、整方法AST反例及原598映射前缀。
- 两个实际 CLI：`--check-bibles`、`--directory docs/creative_direction` 均通过，仅证明技术方向绑定。
- creative-direction 原20项加新当前/历史拒绝测试，共21项通过。
- Bible 原55项全部保留，新增6项当前/历史边界检查，共61项；此前原缺件和旧实际路径失败日志均保留。最后两个旧 body 历史链读取修正后，针对2项通过；最终完整执行仍须按原30秒预算复核。
- 早先完整执行出现32.838/30秒以及30.399/30秒；当时并行引擎编译存在CPU争用，但这不是将超预算记通过的理由。原预算不变，不删断言；最终由root无编译竞争运行原四项检查。
- root报告冻结生产源上的Bell、Plan146、实体、Study65、audio-owner84、v11六项fresh专项通过。本代理没有运行Godot，也不把这些有限专项当完整CI、Foundry、PCK或实际Web通过。
- **item-v5-formal仍整体失败**：191行为断言通过，但退出报告57 ObjectDB /25资源泄漏。技术source-binding不会覆盖这个失败，不以hash、抽象去环或清理缓存代签修复。

Boss尾项真实生产叶和source_commit已刷新，须独立复审，再执行原Bible四checks、Foundry既有构建/提升流程、完整回归和实际导出/PCK。文件索引与依赖图已更新为063d6ccb候选；总报告由root同步，不自动签最终验证。

本批准确写集：新style26、现registry、两区direction、两份Bible测试、原region_creative_direction工具、此质量说明与小输入迁移receipt。profiles增补由root/CI负责，旧档案与媒体写集为空。回退以本批未来实际提交的revert及其父提交为准；本候选尚无可声称已冻结的提交SHA。
