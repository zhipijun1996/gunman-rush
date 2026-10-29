# AUDIO-ROLLOUT-01 · 正式装配与发布证据

用户已明确“快速合入main，并部署试玩”；按平原A／森林A与家园life的原选择装配，不重做素材。工程验证与最终公开试玩分别记录，当前尚未合入或发布。

三平台精确导出16个原始音频与4份JSON，正常导入资源同时保留。新增专项`tests/selected_audio_export.gd`实际26／0且严格退出通过；原PNG专项30／0、Python原导出测试2／0通过。初次正式场景专项native-01／02两次均45／0，但退出脚本资源泄漏使严格runner拒绝，原失败日志与报告已归档，不能称通过。5种隔离服务／正式title／Home消费者诊断及双App实际Home均未复现。随后compile-only副本不执行任何场景仍复现相同2个GDScript资源泄漏，定位为新增专项的编译依赖图；仅改变测试服务类型引用的dynamic-services副本实际16／0且严格退出无泄漏。正式专项仅等价调整测试服务类型边界，仍核真实父App直接子节点的GameAudio脚本继承链；全部45动作／期望／预算保持。native-03实际45／0、strict runner通过，16.966秒，无错误／资源泄漏。生产共享音频脚本未改，两个真实App后端均已释放。隔离诊断不替代这个完整专项。

前置提交3e6bf692的远端run40817435165、parallel job123264533279实际quality失败：`AUDIO-DIRECTOR-01.json: Evidence hash mismatch: audio-style-v1`。原风格在e55910ec追加环境混音反馈，旧冻结引用未迁移。现逐字恢复3cc6c620的`docs/audio_director/style_bible.md`为[frozen原件](frozen/style_bible_candidate_v1.md.txt)，4586字节、SHA256 `08371f6f30e21e2de656c0afddd52c934a7961fe5e09d74831cc9a7e4a042cbb`。文件扩展名用于保留原字节与原相对链接语境；原文链接以原路径为上下文。仅迁移旧evidence.path，保留原source26e7／版本／SHA／方法／结论，当前活风格及quiet-02反馈不改。独审见[迁移核验](review-style-freeze-migration.json)。后续通过不追签这个失败run。

本地稀疏checkout的全局quality检查因未物化的历史证据失败，未称通过或为此刷新旧SHA；本任务record结构errors=[]，actual-base quality diff通过，最终CI仍按原输入预检物化后校验。结构检查首次因3个原跟踪小文件未物化失败，逐字恢复原件后`tools/check_project.py`通过，无源码变更。

最终精确head完整双通道／affected、实际main源Web导出、PCK逐项SHA／长度、公开metadata／完整包及真实GUI证据仍待执行。实体设备／全自然路线／玩家听感没有代签。
