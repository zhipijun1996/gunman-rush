# CI-FOUNDRY-CONSUMERS-01：Foundry真实消费者与同源CI产物

独立small_fix、formal_impact=true，[质量卡](../../quality/records/CI-FOUNDRY-CONSUMERS-01.json)绑定b893b45e基点上63个WIP文件：56个实际guard重建JSON、3个既有测试脚本，以及environment/profiles/deliver/原production_plan测试。当前有限技术与独审通过；185=95+90只表示已注册，**完整185未运行**，工作流in_progress。

Android独立checkout原先漏收prepare同一次运行的validated-foundry。四行补丁复用原download-artifact到resources/foundry，保needs、manual条件、30分钟、原SDK/build及source/stamp拒绝。首run41192769750的prepare已过checkout/Python，质量证据检查被取消；core聚合require-both-lanes失败，其余核心步骤skipped，其他六job取消无步骤。它不是full185通过或完整测试失败；原run/jobs/CLI收据保留。旧canonical池本地stamper实际exit1拒绝也单独保留。

root沿原`python3 tools/foundry.py build --count 24 --promote`与原stamper生成24+6+6=36开发短句、18连接证明，新basis为4b8bf84672a16f455651397c900287f1d8ba605c34bbf6d8b6ddc5c20f716e19。非作者[56JSON独审](../../evidence/game_architecture_02/ci-foundry-consumers-01/review/foundry-current-basis-independent-review.json)确认436叶仅basis164/engine110/hash108/manifest_hash54，54replay共56113帧、108manifest几何、随机/能力/repair/ticks/shots和连接选择均不变。原56文件精确b893 Git与外部备份保留；仅归档小清单/日志，不重复4.8MB旧replays或媒体。不手改basis、不修改production_pool=false及awaiting_playtest。

原三UI首次补验均失败：Lab35/2含过时2shot条件且MP3退出泄漏；Touch439/0、Feedback12/0虽nativeexit0，严格wrapper仍因退出ERROR拒绝。三份原native日志、报告及协调日志完整保留。最小测试迁移只将Lab两个条件接回既有当前配置，并复用GameAudio.for_origin与audio_teardown.drain_world清理真实world；保35/439/12断言数、标签、6replay循环、动作、帧等待、pause/return及180秒预算。当前配置迁移不冒称旧期望等价，不改任何生产能力/物理/音频实现。

迁移后原wrapper三项35/439/12均0fail、strict clean，native8.800/5.688/5.083秒；56pool+3GD前后冻结未变。单次skip-drain实际34/0、exit0、无ERROR、wrapperpassed8.144秒，明确NOT_A_COUNTEREXAMPLE，不改failed、不循环挑样本；原Touch/Feedback退出错误被拒才是已观察到的错误守门证据。

185注册复用唯一profiles authority：保原full182与gameplay167完整有序前缀，尾追加三serial；原215check字典/其他profiles/预算不变。只调整既有test_production_plan一个method的后继投影，保168/170/172/173/174/180/181/182原历史断言和182/95/87，并加前缀hash与185/95/90；不删旧guard。environment的额外3wrapper块与deliver在gameplay Harness后的3次直跑移除，统一由原Harness注册调度，非删除入口；service/GPU/artifacts、Androidartifact、delivery其他AST和freeze索引1保留。完整test_change_justification列于质量卡。

[注册独审](../../evidence/game_architecture_02/ci-foundry-consumers-01/registration/independent-review.json)限定接受四文件变更。注册前原91/20.024秒保留；注册后原91/19.353秒、原37/0.119秒真实通过。三个新增checks再经[原Harness实际selected](../../evidence/game_architecture_02/ci-foundry-consumers-01/selected/report.json.gz)全部fresh通过、未复用、内外180不变，输入digest/源码无漂移。原报告含大范围源码指纹，采用可逐字还原的gzip归档，原解压SHA在卡中；该报告是targeted_checks=true，不能称full185；selected inputs仅availability，不是额外测试结果。

最终63文件候选可由root提交并启动完整CI；当前不签实际Android/Web/Windows导出、GUI/设备或用户接受。所有旧失败、取消与未构成反例的原件保持原来源和字节。
