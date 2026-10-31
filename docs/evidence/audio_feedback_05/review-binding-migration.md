# AUDIO-FEEDBACK-05 · style20／creative23 技术迁移独审

**限定元数据／测试迁移工程范围 ACCEPT。** 对象为基线 `9f3dbef3a34be265f04669a70bfb584ec6490740` 上当前未提交迁移，准确字节见文末SHA；不填写未知提交或追签旧失败。审查者只读生产，独立执行两个原CLI及内存反例，没有运行Godot、亲自浏览器或听音。本次只新增此文件，原 [review](review.md) 与 [binding](review-binding.json) 均未改。

## 原件与实际影响

旧style19文件仍为 `7e1a7710028253ce9d6bde253227eb745aef32cd133c9aa3959f5a081219537e`。独立逐项核81个引用，role/path/顺序和全部非SHA属性相同，恰3个SHA更新：

- DemoApp：实际COMMITTED奖励、生命周期与声音接点。
- DemoMenu：既有标题字幕位置的Web音频手势LinkButton。
- ItemV5ShopPresenter：COMMITTED购买音效接点，REPLAY不重播。

其余78引用逐字相同且全部81新SHA匹配当前实际文件。新style20除version、runtime引用SHA、supersedes与本次impact外，原用户quote、共享尺度／采样／画风／边界／适用区和验收约束全部保留；未新画素材，也不宣称标题交互改变没有任何视觉差异。

archive/creative-v22的manifest所列7原件（旧registry、两区总谱、原style19、三份旧consumer源码）逐件核SHA/长度，且实际字节逐件等于main `5f55716a838a754a938997920ff18cb3b17452b5`对应Git blob。三旧源码为`.gd.txt`历史文本，未作为新运行代码。两份完整用户Bible及user-request与基线原字节相同。

新registry仅更改shared_style_authority；16区／原Bible／选择证据不动。新creative-v23两区除version、完整Bible绑定、追加style20来源和impact外，原所有字段完全相同；region_bible仅registry SHA及supplement指针/SHA迁移，原方向和用户认可范围未扩大。新版本接回真实消费者来源，不是重选风格、重签旧19／22或把hash更新当新美术认可。

## 测试与负例

原checker/production_loop/harness/run_tests代码均与基线相同。完整profiles对象独立深比较，除region-bible-tests的inputs尾追加8件外完全相同；原323输入原序保留至331，命令、30秒时限、success marker及所有其它check不变。新增文件是新测试确实读取的版本／归档原件，没有目录通配或未知路径特免。

原测试33个Bible方法与11个direction方法均保留，各新增1个。AST中的assert调用分别309→332、142→155。既有current-version期望必要迁到20／23；历史18→19、21→22比较改读真实旧版本和仅3叶冻结字节，原断言及旧绑定拒绝保留，新方法再核当前全部81真实SHA和旧指针拒绝。未新增skip、删除旧失败场景、放宽阈值或换假像素原件。

读取作者fresh第二轮日志：Bible34/0，25.094秒；direction12/0，4.486秒。首轮34项/8 errors与12项/4 errors是未物化的旧云证据，原日志保留；使用原cloud_inputs精确补取后重跑，没有以缺件为由跳过旧断言。路径为 `build/audio_feedback_05/binding-migration/{bible-tests,direction-tests}-0{1,2}.log`。

审查者另实际运行原两个CLI，均退出0：

- `PYTHONDONTWRITEBYTECODE=1 python3 tools/region_creative_direction.py --directory docs/creative_direction`：两区当前方向通过。
- `PYTHONDONTWRITEBYTECODE=1 python3 tools/region_creative_direction.py --check-bibles`：原Bible及当前补充权威绑定通过。

独立执行5个负例，全部被未修改的validator拒绝：两份真实旧creative22、当前binding换回旧style19，以及仅内存读取夹具模拟DemoApp／实际terrain source PNG的原字节漂移。后两项不写生产文件，仍触发原Shared Plains style reference SHA changed；旧指针仍触发binding changed。未以刷新下游hash消除反例。

## 接受边界

此迁移不修改正式游戏／音频源码、音效／BGM／美术文件或导出；原音频审查14项SHA仍全同。现有PCK、原生录屏和站点继续按各自原始producer与收据判断，不因本次metadata升级重标来源。本审查只接纳版本化技术绑定，不增加声音审美、真实Web输出、手机／iOS Safari、新美术、长路线、玩家认可或商业品质验收，也不签完整CI、main合并状态。

原style19、creative22及两份真实checker拒绝日志保留。旧review SHA仍为 `4bb6eb07e0b744c3cf125bb2ea0a671ef99c07ba3ea7065b2aa46887c94f3827`，旧binding SHA仍为 `873a21f7aca0ba7b91734ac773cf84e5ed85c6168c9eac4daf00dc5d1abfb86b`。

## 当前迁移SHA

| 路径 | SHA256 |
| --- | --- |
| `docs/creative_direction/bibles/style-continuity-20261030-v20-audio-feedback.json` | `66d75a2ea49cf0126cfbe5585daf2099ec3b1e883e8b5cd01e5ff78b77ac92f8` |
| `docs/creative_direction/bibles/registry.json` | `d82579efc0fdd3313d71bed1ad225fd450be90e6d511d30fa2035c59f60ff0c0` |
| `docs/creative_direction/windchime_plains.json` | `eb285418637b24afdd9e0c621d61245642547335d77ddbe9874aa8574b8f07e8` |
| `docs/creative_direction/thorn_forest.json` | `4eb43e7bd2bb0868b6957b2e8e66ed42b1d7fc406876b859f5e724dc76911fb8` |
| `docs/creative_direction/archive/creative-v22/manifest.json` | `edb99db3c34ff269c21ccf2f20b049edb530d306b56e06612895ecd2e06ff4e7` |
| `docs/creative_direction/revision_creative_v23.md` | `d05d4da7dd1ae77e1fec691882abc25b7d2709564739aa34e2955a354618d6f1` |
| `tests/test_region_bible.py` | `462cc62a3fa21fae63999715a43251843ce31c647376c5c43f7cbab252893703` |
| `tests/test_region_creative_direction.py` | `99cc9e719c53e65a921e56867767521c0d9339d7b757f0289f30bfdd73a70e33` |
| `tools/harness/profiles.json` | `5d0a012fc83144bd4cd4bd1a10cbd02636329044b4ab477c7eff80925067be1c` |
