# 移动 Web 音频跟进：已选音色与持续断续分开验证

用户对3866985a1e8b的实际反馈是“还是一样卡”“音效工坊的音效没了，变成旧音效”。先前总线顺序与重复unpause两处最小复现仍成立，但它们没有完成手机连续声音目标。原失败、旧PCM与发布记录保留于相邻mobile_web_perf_01，不能把旧pulse输出证据追签成selected音色。

## 已选音效恢复

正式demo.tscn只有SelectedAmbienceRuntime，GameAudio仍默认original/V1；五份选择JSON与十一份已选导入资源实际存在于旧PCK。问题是没有正式装配选择，而不是素材消失或下载回退。

运行源b7406284e8bb53dd0ff202af08fd59260312abbe增加一次性SelectedSfxRuntime：核原五JSON、十一import指纹、14事件映射，调用现有V3/selected接口。原jump/land、三项明确original武器声、五BGM及画面保持。标准入口不增加逐帧采集。

- 原生真实demo专项63/0、环境装配回归45/0；第一次专项63/2是测试未结束旧run便进入Forest，失败保留，第二次只补原有abandon_run测试准备，未删断言。
- 标准Web真实触屏Home→Explore→Plains，原jump与已选pulse_a均在实际混合PCM中匹配。Pulse A相关系数Home0.995106、Plains0.900286；旧pulse、B/C和反向负控最高0.222051/0.233501。十一selected资源和14映射已核，但这段录音只证明实际操作过的jump/pulse，不冒称所有事件或真机听感。
- 独立静态审查与输出复核在相邻目录followup-review.json、selected-sfx-output-review.json；后者为作者对声音证据的复核，不能冒称对其自写接入的独立代码审查。
- 标准Web build1d3791a7c290，PCK208700940字节，SHA256 `1d3791a7c29031550f5e950bcd5b68f2b3bec7aee0a2c75b02d849d2044e50e2`。官方nothreads引擎d20938d2db49不变。
- Actions40905791224发布成功。public-http-01.json完整下载新旧两PCK及8份官方引擎文件，10/0。公开真实GUI及后续诊断发布另记，HTTP字节核验不能代替它们。

## 持续断续的定位

原BGM与环境底声使用STREAM。当前单线程Web的官方RingBuffer收到音频线程read消息后，在浏览器主线程同步调用WASM out_callback，然后postMessage chunk。音频线程独立运行不等于供音独立于主线程。

独立诊断入口保持同1d PCK、WASM、画面和资源，只有另名JS/worklet带计数与每32次请求一次的时序记录。测量请求发出→主线程接收→同步混音→发送→音频线程实际收块；回ACK再次等主线程的时间单独记录，不能算成音频收块延迟。原官方普通入口不改。观察器有真实开销（PCM分支、Sample扫描、RAF/LongTask统计），两缓冲组一致，不能称零观察开销基线。

云端SwiftShader的50ms Home窗口11条时序：请求等待P50/P95约473/769ms，混音0.3/1.7ms，postMessage0.1/0.2ms。200ms Home45条：等待398/499ms，混音0.2/5.2ms。实际环形缓冲缺帧分别约89.60%/55.60%；更大缓冲缓解云端极端阻塞，但不能解决它，更不能作为手机修复完成依据。

家园普通menu的SceneTree.paused=false，源码只阻止Home输入。这组必须标为Home navigation menu，不能称关卡暂停。用户的关卡暂停现象需要真实Plains pause另验。

当前数据支持该云端配置的主线程供音排队为主要断续环节，不支持音频素材解码本身很重、手机GPU一定有问题或前景shader已经排除。手机的真正耗时分布必须由同诊断入口取得；也不能从云端软件渲染FPS推断荣耀60Pro性能。

独立threaded官方4.7.2引擎对照使用同PCK、同原viewport/canvas/CSS与原8/4线程池。实际COI、共享环、音频线程true、PCM及underrun必须在浏览器确认后才可交付；仅导出或存在SharedArrayBuffer不算成功。当前运行结果另附，不能提前签修复。

本任务保持in_progress，PR117保持draft、不合main。手机连续性与用户最终听感未验。
