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

## 同种子正式场景对照与公开交付

独立review见fixed-seed-stream-review.json。两版都从真实标题进入Home，通过原Home导航RUN SEED输入框填写`mobile-audio-stream-01`再Explore。正式关卡`debug_entry=false`，Manifest均为`f3a63393145ea3b96d4f0bd0cdfe0fe1cafd544353e0cb40b42c932997ec156a`；无替换DemoApp、无移动/冻结世界注入。两版canvas2132×725、CSS852×290、DPR2.5（整个viewport截图2133×725）相同。

| 观测窗口 | 单线程Stream欠载 | 独立线程Stream欠载 | 线程实际读取帧数 |
| --- | ---: | ---: | ---: |
| Home | 88.2430% | 0% | 423168 |
| Home普通导航菜单，tree未暂停 | 91.1774% | 0% | 423168 |
| Plains | 80.6240% | 0% | 423168 |
| Plains暂停菜单，tree已暂停 | 86.2976% | 0% | 467712 |

这是云端SwiftShader、同50ms请求缓冲和同PCK的四个counter窗口；counter区间约8.84–10.61audio秒，不冒充准确10秒wall采样或手机数据。线程四窗新增混合PCM块均非全零，STREAM read_frames持续推进，实际COI、共享三视图、threads=true均成立。主线程长RAF仍在（线程Home P50/P95约269/628ms），音频没有随渲染继续大量断供，支持供音依赖主事件循环是此复现的主要环节。此结果不定位为单一shader、GPU或GDS物理耗时，也不说明图形FPS提升。

四窗之外、场景/菜单过渡期间仍累计1408欠载frames≈31.93ms，最长连续1024frames≈23.22ms；不能写全会话完全零欠载。官方threaded模板输出了Emscripten blocking-on-main的error级警告，favicon404也保留，不能称console完全clean。没有SCRIPT/SHADER/PAGE异常。

诊断工具冻结f21b221f355fb21d25d26c87fbd960bd22271207，prepared84ddcb0fe502dbf8ffa0db188d285bc1efefbb27。Actions40911443229成功，重建全站1002703008字节，低于1GiB；普通index/PCK/官方nothreads引擎保留，threaded用匹配4.7.2官方另一套JS/WASM和独立作用域COI worker。新worker版本由其静态文件集合指纹派生；首次本地安装竞争通过等待activated及最多两次reload处理，保原2秒deadline，无绕隔离或加预算。

公网新诊断11份HTML/JS/worklet全部完整HTTP SHA匹配；同PCK208700940字节及官方threaded WASM38349395字节也完整下载匹配。首次公网worker变redundant并180秒超时的失败保留，未抓到当时安装异常，不能断定网络/缓存原因；后续同字节网络探针已COI成功，第二次全新浏览器真实Home→Plains动作也成功，不再盲改worker。

公网实际两段8秒混合WAV确认新pulse A与jump在原生Source时间对齐45µs；线程版Home/Plains pulse相关系数0.766872/0.675617，普通新版公网为0.995612/0.994351。背景音乐现在持续混入会降低单声相关度，具体负控与原BGM逐段匹配另见public-threaded-output-review.json，不能只看相关度升降评质量。公网动作前后较宽counter窗口Home仍1792/556800欠载≈0.322%、Plains0/478848，保留其差异，不拿本地四窗0冒称所有公开窗口0。

[线程对照](https://zhipijun1996.github.io/gunman-rush/audio-threaded/?latency=50&audio_probe=1) · [同版主线程50ms](https://zhipijun1996.github.io/gunman-rush/audio-stream-test.html?latency=50&audio_probe=1&diag=timing-v1) · [全部对照](https://zhipijun1996.github.io/gunman-rush/audio-compare.html)。页面可手动记录游戏/菜单各10秒并下载JSON。请区分Home导航与关卡暂停；手机/桌面保相同逻辑比例，不改原画质。

f21b源定向docs/web-cache/web-bundle三项全fresh通过，见targeted-harness；不是完整CI。原始证据`followup-raw.tar.gz`及逐文件SHA见followup-raw-index.json，包含63/2旧native准备失败、threaded首次本地启动失败和公网首次安装失败。手机连续声音、长时BGM和最终玩家认可仍awaiting-device；根因结论仅限已测环境，PR117不合main。

公网声音独立负控复核已完成：Home原BGM整8秒rho0.986599/gain0.112087，Plains rho0.930016/gain0.112112（原0.16×0.7=0.112）；各16个连续半秒片段，参考时间逐帧推进且偏差0，没有重启/跳帧，错曲/反序负控显著更低。每个真实8秒WAV落入counter包围区间，窗内underrun增量0；较宽动作counter窗口的Home1792欠载发生在录音窗外。已选pulse A比旧pulse/B/C/reverse负控的相关度优势Home0.529422、Plains0.484071。报告public-threaded-output-review.json保全部区间与负控，不签完整曲目或手机。
