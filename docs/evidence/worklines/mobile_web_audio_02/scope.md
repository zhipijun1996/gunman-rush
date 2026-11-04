# MOBILE-WEB-AUDIO-02

用户真机反馈3866985a声音仍卡且工坊已选音效听成旧版。先前两条Sample缺陷及旧动作声PCM证明保留，但不代表已选音色/Stream连续性达标。正式GameAudio默认original且V1 bank，SelectedAmbienceRuntime仅选环境音；selected.json从未应用到formal demo。

使用现有13明选+1派生的14event_profiles，一次正式场景装配V3+selected，保原jump/land、手里剑/炸弹原项、五BGM和所有画面/物理。精确核5JSON、11已选import资源，普通入口不增加逐帧采集。必须实际demo.tscn与标准Web验证，不以helper单测或旧pulse波形签新声音。

持续断续沿单线程Web STREAM供音路径调查。用同PCK/JS/WASM、同画质的50/200ms缓冲诊断记录实际worklet ring underrun；工作簿仅增加计数的独立worklet，另有PCM/source observer开销，两组均同观察器。不称此诊断为普通网页零观察开销基线。云端SwiftShader数据不代签手机；缓冲候选无真机证据前不宣称根因已消除。不改全体声音为Stream，不删画质或重做素材。

继续PR117，不自动merge。快速发布恢复已选音色的标准包及可供真机使用的缓冲诊断，核公开metadata/PCK/真实GUI；真机确认和完整长BGM连续性保持未验。

追加定位：时序探针每32次read附一次关联元数据，区分主线程排队、WASM同步混音、post和音频线程收块；前后窗口保原ring缺帧。另用配套官方4.7.2 threaded JS/WASM＋独立COI worker复用同PCK，实际核共享环与PCM后再交手机。普通入口不改，所有加载失败与导出指纹保留。Home普通导航不暂停tree，关卡pause需单独验证。
