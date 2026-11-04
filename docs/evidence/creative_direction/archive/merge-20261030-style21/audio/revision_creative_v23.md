# AUDIO-FEEDBACK-05：style20／creative-v23 技术重绑

本次只修复音频试玩反馈后已经发生的消费者来源漂移。原检查在 `build/audio_feedback_05/creative-binding-02.log`、`bible-binding-01.log` 拒绝旧引用；保留原失败，不以刷新旧版本 SHA 恢复旧通过。新绑定见 [style20](bibles/style-continuity-20261030-v20-audio-feedback.json) 和两区当前总谱；[creative-v22 原件及技术源码清单](archive/creative-v22/manifest.json) 保留原字节。原 style19 文件未改。

新版本是技术身份迁移：旧 style19 绑定81个真实消费者，3个文件实际改变；当前方向的完整 Bible 绑定又包含 registry/style SHA，因此两区 creative-v22 也必须升级。未重新选择地区方向或声音，不复制第二套权威系统。

| 真实消费者 | style19 SHA256 | style20 SHA256 | 实际影响 |
| --- | --- | --- | --- |
| `scripts/demo/demo_app.gd` | `31880e9ce16bd7c3c90443e4c237dda3de62e0aec804560b3c6d04eb90f30aa9` | `3e9e9baf24da3e08cc53890d41d1f995f78c280d90666f514e47b4cda6555c5f` | 成功 COMMITTED 奖励／开箱／商店音效接点；普通转区保留已提交奖励乐句，真正结束／标题清理。交易、掉落和玩法结果不由音效决定。 |
| `scripts/ui/demo_menu.gd` | `1552093205becf49569ae581747e4f8d71fc6f5b1552d021bb0aa7490f95471f` | `af2f5a92ca800bcbe4340c23d3007e9d37b93dff96e9720df102cb17040c930d` | Web 标题原字幕位置加入真实手势 LinkButton；不新增美术或改共享画布尺寸。按钮是音频入口，不能据此推导实体设备认可。 |
| `scripts/items/v5/item_v5_shop_presenter.gd` | `8335b5d879bf54eb4e720ab5fcf6163ae840de54c1ad3d94bd5b8b5d663b0cc4` | `2b803f8f23154de50f1471033d030eb1329196d0505a4119706742879cfa7a7b` | 真实 COMMITTED 购买播放获得声，REPLAY 不重播；重置／修理及购买结果维持原语义。 |

81项 role、path、顺序不变，仅上表3项SHA改变，另78项逐项相同。原3份源码从 `5f55716a` 恢复，并与 style19 完整 SHA 核对后保存为 `.gd.txt`，不是新运行脚本。原 registry、两区 creative-v22 完整归档。新 registry 仅改变 `shared_style_authority`，16区／原 Bible／用户选择证据不变。新两区总谱只改变版本、完整绑定、追加 style20 来源及本次影响说明，原其余字段／方向认可范围不变。

地形、敌人、Boss、角色、宝箱 PNG、全部其他像素／atlas／TileSet／shader、32px／32wu、1wu nearest 与地区材料语言不受本次元数据迁移影响。未更改音频素材、选音记录、配方、混音、BGM、音频导出或正式游戏源码；本轮不重新导出。已有本次音频原生／浏览器／影片证据继续按各自精确来源判断，不由此文代签，也不将旧 style19／creative22 通过继承给新版本。

验证保持原套件全部方法与断言、旧绑定拒绝、来源漂移／恢复拒绝及原预算。历史 v18→19、creative21→22 比较改读冻结的真实旧源，新增 style19→20 与 creative22→23 有限正反例。Harness `region-bible-tests` 原323输入顺序完整保留，只追加8个新实际读取的版本／归档输入至331，不改命令、时限、场景或成功标记。须 fresh 执行两个原 Python 套件及两条原 CLI；技术通过仅说明绑定一致，独审另录。

运行日志统一保存在 `build/audio_feedback_05/binding-migration/`。首轮直接 Python 执行真实遇到旧证据未物化：Bible 34项／8 errors，direction 12项／4 errors，保留 `*-tests-01.log`。使用原 `cloud_inputs.py` 对选定检查补取 skip-worktree 原件后复跑，不删断言、不换假 fixture。最终次数／状态和独审以本轮交付收据为准。

本次不签音效商业品质、新美术、完整G5、玩家听感或实体设备通过；用户仍通过真实试玩评价这些内容。

本轮实际执行：`bible-tests-02.log` 为34项／0失败（25.094s），`direction-tests-02.log` 为12项／0失败（4.486s）；`direction-check-01.log` 为两区总谱PASS，`bible-check-01.log` 为原文／注册表PASS。原测试方法33→34、11→12，AST中的 assert 调用309→332、142→155；原方法未删除。`inputs-01.json` 记录原工具实际补取16,453,016字节、未改 sparse patterns。这些结果是本次纯Python绑定回归，不是全量CI或新的音画／设备验收。独审结果由审查者另行记录。
