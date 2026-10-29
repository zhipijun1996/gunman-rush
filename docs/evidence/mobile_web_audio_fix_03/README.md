# MOBILE-WEB-AUDIO-FIX-03

生产源fb5dc84b：官方4.7.2 threaded导出；原缓存worker为HTML/运行时添加同源隔离头，精确worker握手后只一次隔离导航；官方audio worklet原字节，普通入口无诊断探针。

真实demo专项31/0：瞄准进出无新增cue，selected pulse A仍一声且物理反冲存在，实际碰撞命中机关触发plains_chime_a一次，拒绝/取消/重复不重响；原selected专项63/0。日志和退出码见相邻目录。这是原生行为验证，不代签手机/自然整局听感。

原同PCK主线程/线程PCM和时序证据见../mobile_web_audio_02/README.md；用户已确认线程测试页加载后声音正常。新普通入口实际Web和完整CI进行中。初次定向Harness因测试工具同时编辑触发source drift而失败，保留build/verification/harness/20261029T180723.783056Z；单独全历史quality检查因稀疏工作区未物化旧证据失败，不是新运行源回归。后续按正式cloud_inputs/CI还原输入并验证，不删除旧要求。

用户已授权完成后合main；检查通过后正常merge并部署实际main，不以分支包冒充main。

正式分支包683cf2cce4d6/engine9c119194046e已在无服务器COI头的本地实际Chrome冷启动，检测COI/SAB/共享audio ring均true；Home/Plains各8秒原PCM验证跳跃与选定pulse A，官方worklet仍原SHA。截图及原始report/WAV见web-01.tar.gz，有限窗口不代签全会话。

真实桌面旧worker迁移一次reload成功，1280×720、localStorage保留、page errors0；见migration.json。独审review/review.json限定静态/13组缓存mock/真实HTML假资源构包夹具接受，无阻塞；测试夹具不包含真实游戏/WASM，未入生产。前CI40923215796因旧AUDIO02测量条目缺device/environment/scenario/budget_source被质量门拒绝，本轮补实际cloud字段，本地quality-diff通过，未删检查。
