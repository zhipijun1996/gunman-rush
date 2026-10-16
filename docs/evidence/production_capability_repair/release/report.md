# 发布专项：真实根因、修复与边界

基线 PR69 `4f2066fd610faa1b86de5a942fa7c1c0bdacda26`；本目录是本轮实际原件，不表示最终整合源或远端发布通过。

- 原发布 terrain-family failed，远端内部日志未上传，具体原因为 unknown。同 HEAD 后续 CI terrain passed 不能消除原失败。
- 本地4.7.2固定帧 touch 原版438/0、进程exit0，但有24 ObjectDB/4 resources；verbose准确定位 click/land Ogg播放。对照 max-fps60清洁。引擎4.7.2源码 stop_playback_stream 只标FADE_OUT_TO_DELETION，独立音频mix才真正释放，快速quit可能先结束。GameAudio新增有墙钟上限的shutdown，记录所有实际播放的WeakRef，停止并等后台实际释放；保留原fixed-fps、音频与错误守门。
- 实际Ogg生命周期正例37/0、无退出错误；不drain负例34/0、native exit0但ObjectDB/Ogg泄漏被wrapper正确拒绝。缺完成标记、非零退出及timeout分别实际拒绝，见runner-guard-report.json。没有用sleep或提高游戏帧率掩盖该问题。
- 新wrapper用于CI的三个Foundry专项：native exit0不再掩盖stderr错误。terrain入口增加verbose、每阶段时间、超时原始输出与失败分类；cold import也拒绝ERROR。
- 旧模板下载真实curl28在180s后从0重试，累计210.119s后人工终止；新实现保留同SHA partial，有界3尝试，只重试已分类的传输/5xx/429，403/校验失败终止，进程互斥、校验后原子发布、坏档隔离。实测attempt1 180.014s超时保留1,147,880,236B，attempt2从该offset续传23.596s完成1,281,349,702B且锁SHA通过；整个恢复安装217.618s，其中传输203.610s，其余14.008s包含校验/提取/拷贝/检查，不能再虚拆。warm setup0.128s、无下载。
- 实际本地HTTP/curl测试5项通过：断连接curl18→Range续传、新调用持久断点、403终止、503有界恢复、错误SHA不安装、verified-cache零HTTP请求。见download-tests-final.log。
- CI真实无效../缓存路径改为RUNNER_TEMP下清洁绝对路径；安装验证后立即单独保存工具链，后续测试失败不会丢掉已验证工具链；失败下载部分用每次运行键保存并以前缀恢复。原部署依赖和测试门槛保持。

Foundry整合后的实际重验待统一fresh basis：本地一次touch-after因源码basis改变失去24样例，原件保留，75.247s后人工终止，native exit -15，不能称音频补丁失败或timeout。未为此启动昂贵重建。正式完整terrain/Foundry、独立审查及远端构建/发布必须由集成阶段实跑，不在此冒称完成。工具链全部官方模板和4.7.2已安装并check_environment通过；未修改核心物理。

Token、价格未由工具暴露，统一not_exposed。原远端日志路径为/workspace/scratch/release-core-remote.log和latest-core-remote.log；音频引擎源码调查副本在/workspace/scratch/audio_server.cpp和audio_stream_player_internal.cpp（Godot4.7.2-stable）。

## 发布断点工具追加

`tools/publish_playtest.py`已从一次性dispatch+poll升级为原子checkpoint与互斥恢复：绑定repo/ref/完整resolved SHA/run_id/run_attempt；dispatch前先保存不确定状态，写请求仅一次，丢响应后resume只发现或轮询现run；发现多个同源run拒绝，由显式新checkpoint `--run-id/--attempt`收养。401和403分别记录身份/权限问题，不归成网络；只读网络/429/5xx最多3次，CI失败不自动重跑。绑定attempt的deploy_web和verify_public必须真实success，不能用未部署的绿色CI签发布；测试产物唯一artifact ID及四项metadata必须与公开build-info准确相同，最终再检查run attempt和artifact未在下载期间变化。

隔离测试`python3 tools/test_publish_playtest.py`实际10项通过（9.785s）。每项调用真实publisher subprocess、fake gh executable与本地HTTP服务；不调用远端dispatch。原始stdout/stderr/fake调用/HTTP次数/checkpoint保留在`publish-fixtures/*.json`。覆盖响应丢失仅一次dispatch、超时后恢复、错SHA/ref/attempt、并发rerun、401/403/502、CI失败不重跑、503恢复/403终止、同source错build、非部署green CI、错artifact及歧义dispatch。整体真实发布与恢复仍待集成阶段按授权执行，fixture通过不是上线证明。

真实调用示例（由主集成者执行，不代表已经运行）：初次`python3 tools/publish_playtest.py --repo zhipijun1996/gunman-rush --ref feature/production-capability-repair --expected-commit FULL_SHA --checkpoint build/production_repair/release/live-publish.json --timeout 60`；后续同样绑定参数加`--resume --timeout 3600`，不会再次dispatch。Web artifact首次下载耗时计入github_read事件并保存metadata，后续resume复用且重新核验artifact ID；publisher_invocation是包含子调用的总时间，不能与子阶段相加重复计费。未暴露token/价格仍为not_exposed。
