# 发布修复的精选原件与结论边界

本目录保留实际作者和独立审查原字节，[artifact_index.json](artifact_index.json)逐文件绑定来源、大小和原始/复制SHA。189345058字节旧ZIP未提交，保留API digest、实际PCK流验和独立复核回执；不包含凭据或签名下载URL。这里不是本轮最终构建/公开发布通过证明。

| 事件 | 实际证据和分类 | 可以得出的结论 |
|---|---|---|
| PR69旧远端terrain失败 | [旧远端外层日志](remote/release-core-remote.log)；原生内部日志当时未上传 | 旧具体根因unknown。同HEAD后续绿色或本地复现不能冲销该失败，也不能推定同因 |
| Ogg退出生命周期 | [有drain正例](audio-positive/report.json)、[无drain负例](audio-negative/report.json)、[独立受限强引用反例](independent/audio-bound/report.json)、[源码调查摘录](engine_source/audio_server.cpp.lines_1289_1325.source) | 真实fixed-FPS退出前，stop只进入淡出删除队列；原生mix尚持有播放。GameAudio有界等待实际WeakRef释放，保留stderr/超时守门。这是实际代码/生命周期缺陷，不叫flaky网络 |
| 静态类型收窄与load-only释放 | [独立旧声明坏例](independent/ecology-load-bad/report.json)与[显式cast好例](independent/ecology-load-good/report.json)，同目录原生log和原脚本.source | 最小加载可复现的类型/引用生命周期差异；没有把它当完整遭遇、音频或整个旧远端terrain根因 |
| 模板curl28 | [真实两次续传记录](godot-export-templates.tpz.attempts.jsonl)、[恢复耗时](toolchain-efficiency.json)、[本地HTTP/curl专项](download-tests-final.log) | 传输超时类别，保留同SHA断点并有界恢复；217.618秒安装包络包含203.610秒传输，余14.008秒不再虚拆。错误SHA/403终止，不按临时网络重试 |
| GitHub归档403 | [13项最终fixture入口](artifact-fallback/tests.log)、[真实旧ZIP作者校验](artifact-fallback/actual-old-archive-verified.json)、[独立流验](independent/publisher-actual-old-archive.json)与[独立坏例/CLI测试](independent/publisher-archive-tests.log) | 403是权限类别；显式API digest绑定ZIP是单独恢复通道，不是改身份或自动重发dispatch。原run38846504655失败未部署；旧build8c8eb15dcba3不等于旧本地42cd或本轮新发布 |

[发布恢复通道说明](artifact-fallback/README.md)列出精确run/attempt/source、ZIP/PCK/hash、唯一build-info、安全路径/重复成员/大小界限及原始CLI反例。13项fixture确实执行publisher subprocess、fake gh和本地HTTP，但不是真实GitHub部署。全部非零、缺标记、超时和退出资源错误继续由[实际守门反例](runner-guard-report.json)拒绝。

最终源、有效构建、deploy_web/verify_public和公开build-info必须由父交付阶段提供新的实际证据；这份as-of工程原件不代签它们。tokens和price未暴露，保持not_exposed。
