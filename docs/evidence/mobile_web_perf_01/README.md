# MOBILE-WEB-PERF-01：音频与正式A/B证据归档

最新用户反馈以声音断续为主，动作几乎不卡。本轮只确认下列音频机制和有限正式消费者结果；不签手机FPS、GPU瓶颈、BGM全程连续或用户听感。两处修复已发布，保留相同UI的旧版作为独立对照；完整公开PCK与官方引擎文件均已HTTP下载核验。真机听感仍待验。

## 原件与压缩档

原始build目录、失败、漏录及漏跳数据全部保留；本轮只复制、压缩与核验，没有运行Godot/浏览器，也没有修改生产、工具或现有分析JSON。压缩档不含engine、WASM或PCK，保留原有`build/mobile_web_perf_01/...`相对路径；它们是证据包，不是可启动游戏包。每档内的`ARCHIVE-SHA256.json`登记所有成员的完整SHA256和长度，外部[全量索引](archive-index.json)还登记压缩档SHA。压缩后已逐成员重新解压读取并核SHA，原文件再核不变。

| 压缩档 | 文件数 | 压缩字节 | SHA256 |
| --- | ---: | ---: | --- |
| [runtime-audio-core-01.tar.gz](runtime-audio-core-01.tar.gz) | 197 | 12,747,607 | `c90fcf80a5b4f62087463d339e9735bc7b9485ef14b732804af6de6689b9dc1d` |
| [preliminary-audio-diagnostics-01.tar.gz](preliminary-audio-diagnostics-01.tar.gz) | 10 | 2,617,997 | `b0fb77e0fcdc58f37da074f21263c8218209d5734a6d610fb84fa42ab27ccdf1` |

核心档包含版本审计、最小复现、formal-main-02的构建/静态/源差异和冻结源、两轮正式报告/日志/WAV/截图，以及三组原生日志。初期档仅保存ab-01、extra-01、audio-route-01、official-01、official-02的报告与日志；其截图仍在原build目录，没有删除。已有[调查笔记](audio-notes.json)、[正式PCM分析](formal-audio-analysis.json)、[独审记录](review-notes.json)与[历史线程评审](threaded-review.json)保持原字节；历史候选不能视为当前批准方向。

## 基线版本审计

权威原件位于核心档`build/mobile_web_perf_01/baseline-audit/public-runtime-audit.json`，审计时间为2026-10-29 14:14:43 UTC。须分开以下两个包：

| 身份 | 值 |
| --- | --- |
| 原始main | `1b29932c5333a9dad50759afc635762163ed79f5` |
| 原始main PCK | `618eb97114e6715fc33856823c9bf23141e8e51802a886596bc9f223ed7ca691` |
| 已审计公开旧包build/source | `2caa023125bd` / `4707b9ef15fa7e89b09d3e33ef8206c0b12f64af` |
| 已审计公开旧包完整PCK SHA | `2caa023125bd6fcf2b960dcdf5ac60a6a7abdbfeb643ef0b661f80f6a15d5a31` |
| 引擎 | Godot `4.7.2.stable.official.ed1daf0bf`，engine id `d20938d2db49` |

审计实际HTTP200取得公开JS/WASM/两份worklet，字节均与本地及官方`web_nothreads_debug.zip`一致。GameAudio、GameAmbience、SelectedAmbienceRuntime和正式demo.tscn源在这两个版本间SHA相同；公开旧包的UI/渲染修改仍是包边界，不能跨包比较绝对FPS。

| 官方文件 | SHA256 |
| --- | --- |
| `index.d20938d2db49.engine.js` | `ffc3898b59fba6f5af0c02f76e5ee526cc061e65c7d2d6f4f98186876cea15c4` |
| `index.d20938d2db49.engine.wasm` | `11ea19645368f8e73cf337b59cfd7ceeb4ebb51f7a3bbf77d1a5c3ddfedbc522` |
| `index.d20938d2db49.engine.audio.worklet.js` | `5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3` |
| `index.d20938d2db49.engine.audio.position.worklet.js` | `be33985bc7160d6bf9646f259cd86b259cd67b02ccb297ee5c44f8ac84327bc8` |

正式A/B从原main PCK派生，保持原project.binary、demo.tscn remap及编译场景；`formal-main-02/static-source-comparison.json`记录3245项原入口精确不变、18项替换字节验证、0项未登记生产正文漂移。公共观测器也有开销，original是有共同仪表的基线，不冒称整个诊断包与官方PCK逐字节相等。四case统一音频延迟50ms、GPU query默认off。

## 最小Web复现：计数与实际PCM

原main1b PCK追加最小Node入口，不实例化主游戏。single和multi是两次全新Chromium/Engine启动；single始终只有原Master且从未ensure_buses，multi直接执行原GameAudio.ensure_buses（源SHA `e08004d5fea8ddce976088dc64af43a0b2f3bdb2fb428a8699d25bd66c9e4609`），没有修写官方引擎/Bus实现。

每段WAV均为真实destination旁路混合PCM，保留原连接，observer经gain0接出；44100Hz、双声道、2秒/88200帧，Float32转PCM16。表中native顺序为created/start/ended/stop；GDS为play调用/finished。

| 启动/政策 | GDS帧数 | native | GDS | 非零PCM帧 | 峰值 |
| --- | ---: | --- | --- | ---: | ---: |
| single / sample_once | 94 | 1/1/1/1 | 1/1 | 22589 | 0.890222 |
| single / stream_once | 104 | 0/0/0/0 | 1/1 | 22052 | 0.890198 |
| single / pause_none | 133 | 1/1/1/1 | 1/1 | 22589 | 0.890222 |
| single / pause_always_false | 143 | 27/27/27/1 | 1/1 | 11426 | 0.000325 |
| single / pause_guard_false | 136 | 1/1/1/1 | 1/1 | 22589 | 0.890222 |
| multi / sample_once | 135 | 1/1/1/1 | 1/1 | 0 | 0.000000 |
| multi / stream_once | 129 | 0/0/0/0 | 1/1 | 22052 | 0.890198 |

clean single中SAMPLE和STREAM都有实际非零输出；multi的逻辑5总线名称/send正确，但原生样本图出现跨三组Gain的9节点反馈环，SAMPLE虽start/finished均成功，WAV仍全零；同次启动的STREAM有输出。不能把这个已见环简化为已证明“Master单独自连”。

单Master中每process写false会把一次play扩成27次原生创建/重启，峰值由0.890222降到0.000325；不写或仅值变化时写都保留一次start和正常波形。构造器/factory双入口去重、ended监听、原异常/返回保持及旧probe纯mock已通过；原命令、计数、WAV和SHA在最小复现原件中。

## 正式四case：帧时间与保护矩形

四组均运行真实原demo.tscn、真实触控跳跃及右摇杆释放，统一853×290 CSS / DPR2.5 / plains-run。original保原实现；bus_only只将总线追加改为增大bus_count再保原name/send；pause_only只改环境声暂停状态的重复写入；ambience_off在SelectedAmbienceRuntime附着前返回。官方引擎与美术/UI未因case改变。

以下为Cloud Chromium **SwiftShader软件WebGL**的单轮原始16段结果。original Home首段有明显冷启动/负载波动；不以此排序音频改动的帧率收益，不外推手机GPU，不声称修音频等于修画面。表中n/FPS以及p50/p95毫秒原样取总报告。

| case | 区域 | 正常 n/FPS | 正常 p50/p95 ms | 菜单 n/FPS | 菜单 p50/p95 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| original | home | 17/1.49 | 405.8/1934.5 | 39/6.47 | 150.5/201.7 |
| original | plains | 88/8.72 | 101.4/222.2 | 57/9.34 | 98.7/169.5 |
| bus_only | home | 88/8.79 | 108.0/187.6 | 47/7.83 | 123.1/183.2 |
| bus_only | plains | 99/9.90 | 97.5/147.7 | 58/9.49 | 97.3/165.2 |
| pause_only | home | 79/7.74 | 115.5/165.5 | 43/7.16 | 128.9/252.1 |
| pause_only | plains | 90/8.85 | 85.1/198.4 | 60/9.82 | 97.8/147.8 |
| ambience_off | home | 85/8.43 | 108.4/189.6 | 46/7.57 | 123.6/187.1 |
| ambience_off | plains | 126/12.56 | 75.9/115.7 | 61/10.13 | 94.4/136.9 |

四case在相同区域/状态下的前景计数字段一致。Home菜单阻断输入，但`tree_paused=false`；Plains菜单才是`tree_paused=true`，不能将两者都称为相同暂停实验。以下是producer的不同原字段口径，不能相加或把uploaded当唯一世界保护矩形数：

| 状态 | tree_paused | protect | static | dynamic | mask_rectangles_uploaded |
| --- | --- | ---: | ---: | ---: | ---: |
| home/idle | false | 19 | 54 | 3 | 17 |
| home/menu | false | 1 | 60 | 3 | 5 |
| plains/idle | false | 2 | 56 | 3 | 9 |
| plains/menu | true | 1 | 87 | 3 | 6 |

## 正式动作声：恢复范围和未通过边界

第一轮formal-ab-01的实际录音只有2秒：runner虽请求4秒，旧worklet上限仍2秒，且start/begin字段读错；动作大多晚于WAV结束。原漏录、null字段和相关分析失败全部保留。即时1Hz状态里shot_fired有时为0，后续原menu快照确认四组Home/Plains各jump/shot一次；没有改写即时记录。

formal-action-02仅定向补录，不重复帧矩阵；坐标在录音前算好，实际8秒/352800帧、start/end齐全。15个已记录原动作及相应native源均被完整覆盖；ambience_off Home没有触发jump（无原jumped、motion事件或对应native源），该项不能作为声音缺失的负对照。其余各组原信号按实际保留。

bus_only的动作WAV按真实variant取jump/pulse源，重采样并与原生起点锚定匹配；四者最佳波形起点都为native起点+2采样帧，约45µs。原始来源、全SHA、错variant/反向控制、拟合增益和分析命令见[正式PCM分析](formal-audio-analysis.json)。

| bus_only场景 | 源 | 相关系数ρ | 最强错variant ρ | 拟合增益 | 限定判断 |
| --- | --- | ---: | ---: | ---: | --- |
| home | jump_0.wav | 0.991712 | 0.726011 | 0.174883 | 强全波形匹配 |
| home | pulse_0.wav | 0.999634 | 0.653871 | 0.175820 | 强全波形匹配 |
| plains | jump_1.wav | 0.709302 | 0.556170 | 0.159478 | 混音中存在；不签完整保真 |
| plains | pulse_1.wav | 0.994032 | 0.657800 | 0.175273 | 强全波形匹配 |

这足以限定确认bus_only正式Home/Plains中这四次真实动作声进入最终混合PCM；其余11个已触发负对照未识别出对应声源指纹。post-ended的source_routes全False可能来自断连、回收或增益归零，不用于判断play时通路；bus_only全图无环是独立证据。以上不签所有SFX、音乐/环境全程连续、真机或用户听感。

## 已有原生专项与初期记录

以下仅复述已存在日志，本归档没有重跑。退出码均为0，时长含启动/音频teardown，不是设备性能数据；生产修复的最终源码/发布身份仍由root后续收据绑定。

| 专项 | checks / failures | 秒 |
| --- | ---: | ---: |
| ambience | 55 / 0 | 0.872 |
| home | 60 / 0 | 27.996 |
| selected | 45 / 0 | 17.100 |

初期ab/extra/route/official报告仅作历史定位。精确欠载来自明确标识的诊断worklet副本，不能把混合PCM零块直接等同欠载计数，也不把曾经SAMPLE原生start等同可听。全停音频对照、重复pause、旧坏图与旧候选失败均保留；当前不继续线程/GPU方向探索，也不由云端帧数代签用户真机。

## 标准生产包与已发布对照

[修复版3866985a1e8b](https://zhipijun1996.github.io/gunman-rush/?v=3866985a1e8b) · [修复前2caa独立入口](https://zhipijun1996.github.io/gunman-rush/audio-before/) · [前后选择页](https://zhipijun1996.github.io/gunman-rush/audio-compare.html)。两个目录各有实际固定PCK、metadata、原官方engine与cache worker，查询参数不承担切换旧包的功能。一次关闭上一游戏标签再比较。

标准修复包source `ccc11e1a9b8fbf305c926b410dcf46c8f4b52a83`、PCK `3866985a1e8b5db39e3400b452b2b46339073e010659c9b367b71e385b3afd21`／208691528字节。对旧UI包仅两份audio.gdc与两个引擎cache变化，3257项相同，无新增或移除entry；见[生产构建](production-build.json)。Godot4.7.2官方JS/WASM/worklets字节不变，不强制全Stream/Sample、不删功能或改声音素材。原生55+45+60=160／0，[源码独审](production-review.json)、[部署审查](delivery-review.json)、[守门审查](guard-review.json)限定通过。

[标准Web实际触屏/录音](production-browser/report.json)使用未改PCK及官方引擎，普通触屏跳跃/射击、实际Home菜单Explore进入关卡；只在浏览器外接只读PCM tap。两段实际8秒WAV：[家园](production-browser/home-actions.wav)、[关卡](production-browser/plains-actions.wav)。[独立PCM复核](production-audio-analysis.json)确认：

| 正式修复包场景 | jumpρ | pulseρ | 对应native时间差 |
| --- | ---: | ---: | --- |
| Home | 0.997125 | 0.999833 | 两声均+2采样／45µs |
| Plains | 0.891302 | 0.994043 | 两声均+2采样／45µs |

所有正确variant匹配均强于错variant及反序负控，完整窗口覆盖、observer错误0、graph无反馈环。仅签四个动作声存在，不签全部音色、完整长BGM连续性、实体设备或FPS。

首轮标准包录音失败：真实cache ServiceWorker绕过Playwright route，observer Worklet404而就绪超时；PCK/engine不变。第二轮只读observer改为顺序单init与blob，成功。首轮、构建、其他验证失败和UID自动改写恢复见[日志档](production-run-failures-and-logs.tar.gz)与[成员SHA](production-log-index.json)，未追签旧失败。

[Actions40896322142](https://github.com/zhipijun1996/gunman-rush/actions/runs/40896322142)已成功，[公开完整下载](public-download.json)实际读完两份PCK与两目录各四官方engine文件，10项均HTTP200且完整长度/SHA一致。[目录身份](comparison-builds.json)与[部署收据](deployment.json)保留。[修复版公开GUI](public-gui-after/report.json)与[旧版公开GUI](public-gui-before/report.json)均通过：普通触屏点击设置/返回/进入家园/菜单HOME关闭及844×390调整，page/script/shader错误0。最终[三项定向Harness](validation/harness-report.json)全部fresh通过，原失败、57项quality测试、实际base质量差异和发布守门见[验证摘要](validation/summary.json)。源码[PR117](https://github.com/zhipijun1996/gunman-rush/pull/117)保持draft，未合main；不以发布代签main合并、完整CI、真机或玩家认可。

有限资产adapter仍按GameAmbience精确单SHA守门，只重绑已审pause状态修改，原17项负例专项及57项quality测试通过。旧UI记录补的是既有公开source4707真实mobile GUI的有界库存引用，未补造fresh执行。实际base1b质量差异检查已通过，原失配与守门失败日志保留。
