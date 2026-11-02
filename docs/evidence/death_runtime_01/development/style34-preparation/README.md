# DEATH-RUNTIME-01 style34 / creative37 技术绑定预备

状态：**仅外部预备，最终五GD待root测试/接受/冻结，不可应用**。本批不生成含候选SHA的live metadata，不把当前外部候选或旧局部通过当最终源。未改主树、未运行engine/browser/Python tests/CI/full/Foundry。

基点 `5d3303b78d4db374300d4a0266bde8eb1a6de5b2`，当前style33原件 SHA `ed7088cd28ad66a0e5da12905abb971a682319782ed49e5e4a6325ffeeb45d55`。已只读核当前206引用均匹配实际旧源字节，其中86非GD。最终要求仍为206条同角色/路径/顺序，仅下列5个GD允许变化，其余201条与86非GD原字节不变：

- `architecture_plains_revision_pose` → `game/enemies/presentation/plains_revision_pose.gd`
- `architecture_plains_revision_ground` → `game/enemies/presentation/plains_revision_ground.gd`
- `architecture_plains_revision_flora` → `game/enemies/presentation/plains_revision_flora.gd`
- `architecture_plains_revision_skin` → `game/enemies/presentation/plains_revision_skin.gd`
- `windkeeper_pressure_stage_visual` → `game/presentation/world/art/plains_stage_visual.gd`

Loot只选**共享material**。不采用optional warming，不改既有 `canvas_shader_preparation.gd` SHA `8fa37476532b4655936bb381eff7480a0e19fe819ebd4082ea459bee94690912`，不加style角色、不改shader/贴图/其他非GD。

现有外部candidate仅13文件：新 `death-runtime-before-style34` 有限旧33归档包含5原GD `.txt`、原registry/两direction/两test/profiles共6原件及manifest（合12文件）；另1份现有history薄adapter延续。11份归档原件均来自确切Git基点，未用工作树候选代替。manifest SHA `0f2e6ae2da8bf141a46b1ca5beb0621cce26d1c3f18138a76b0adc2a85291d8b`。

薄adapter只让原 `style32_source` 未索引路径续到 `style33_source`，新reader只索引上述五旧叶；manifest或索引叶缺失/损坏继续拒绝，不回落live。live validators不调用history reader。旧style33原件与更早归档不修改。

收到root最终五源freeze后，预计最终完整写集20文件：现13文件＋4live metadata（新style34、registry、两creative37）＋原2test modules＋原profiles。完整路径清单、每旧源SHA、方法身份及门槛在 `plan.json`、`proof.json`、`original-test-identities.json`；最终接受前不应用、不刷新实际SHA。

原94 Bible＋30 creative方法全保留；预计沿同一版本回归族追加4＋1，形成 current46/history52/creative31。旧33两实际源测试改为finite frozen33回放，旧creative36迁移同样回放原33；当前三版本断言与显式normalization有限续34/37。现历史lifecycle reader已有style32 finite接口，其链将读取五旧33叶，不需要改旧SHA或断言。完整方法AST/源逆还原与旧所有断言/循环/门槛继续保留，旧已接受身份数组只追加、不覆盖。新33→34测试保206 exact/5GD/负例/manifest拒签/输入前缀及return/dead-body/empty-loop反例，不新建平行框架。

原 `region-bible-tests` inputs671→673、`region-bible-contract`329→331，各仅尾加新style34和有限归档目录，保全部原序/重复项/argv/30秒budget。creative-direction、creative-direction-tests与manual history仍无inputs（原whole-snapshot语义），原60/30秒预算、full171与profiles集合/IDs/selector不变。creative37必须采用**完整old36 authority_sources前缀＋registry的新style34引用**，不凭候选数组最后项推断。

最终freeze只授权生成完整外部可审候选与逆补丁，应用/执行由root后续协调；实际专项、完整集成、手机/用户/性能/美术结论均未签。本准备没有运行检查命令，只做读取、Hash/AST盘点和外部归档。
