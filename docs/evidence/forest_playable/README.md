# FOREST-PLAYABLE-01 实际证据

本轮实现森林第二地区、能力／地区选择与调试直选。原生冻结源 `0ed19bb2f9b50b5fcc191ded67b077b81b1fadea`；本地Web build_id `bc1d2928a011`，PCK完整SHA `bc1d2928a011cbfbe71c4228bdce0c33bb61e48e0418316274b9eb54f0374a3b`。当前尚未发布本轮公开试玩，完整回归阻塞未冲销。

| 范围 | 实际结果与原件 |
| --- | --- |
| 正式森林路线 | 10root×两图×三策略60/60；55710真实physics tick、52实际射击、34正式击杀；[summary](final/native_matrix_summary.json)、[分析](final/native_matrix_analysis.json) |
| 原host执行 | 真实implement→七项fresh→不同作者review，scope complete、content_complete=false；[state](final/native_host_state.json)、[原收据包](final/final_original_host_receipts.tar.gz) |
| 七项原生 | progression29/0、campaign37/0、debug42/0、ecology51/0、短H黄金、再次60/60、正式combat27/0；[实际stdout](final/native_runtime_outputs.json) |
| 独立审查 | /root/forest_runtime_review实际缓存复现、原29/0、60份复算与删证反例、查看带时码帧，有界原生ACCEPT；[原回复](final/independent_review.json) |
| Boss实战 | 守卫10实际弹体/681tick/两阶段；女王18实际弹体/1345tick/三阶段，实际走到奖励门并领奖；[capture](final/formal_combat_capture.json) |
| 连续画面 | 真实OpenGL 60fps成长18.17s／高奖返程18.68s；[成长](final/growth.mp4)、[返程](final/cache_return.mp4)、[原始trace与影片元数据包](final/final_native_routes_and_movies.tar.gz) |
| Web真实GUI | 8个鼠标／CDP模拟触摸区域图入口，16检查、exactlyonce、暂停／恢复、零引擎错误，逐case前后完整90,009,228bytes PCK；[report](final/browser_gui_report.json)、[原件及失败包](final/browser_gui_and_retained_failures.tar.gz) |
| 原三个浏览器消费者 | 原脚本／原超时全部72断言通过（action_budget24、studio40、all_weapon8）；[便携实际证据与旧失败](final/original-local-Web-72assertions-0ed19bb-bc1d2928a011.tar.gz)、[receipt](final/original_browsers_72_receipt.json)，仅本地同源包，非CI ZIP验收 |
| CI原失败完整证据 | 正常GitHub连接器取得[完整日志](final/ci_0ed_core_job_connector.log)和[API摘要绑定ZIP](final/ci_0ed_harness_gameplay_connector.zip)，[receipt](final/ci_0ed_connector_receipt.json)；原grammar72路线23180/0后Ogg泄漏真实拒绝 |
| 原完整grammar修复验证 | [完整stdout](final/grammar_audio_fixed_full.log)、[实际计时](final/grammar_audio_fixed_full.json)、[72路线corpus](final/grammar_audio_fixed_corpus.json)、[独立测试清理审查](final/grammar_audio_cleanup_review.json)；23252/0、178.918秒、严格干净退出 |
| 测试音频退出定位 | [便携对照原件](final/grammar_fallback_audio_diagnosis_portable.tar.gz)、[成员SHA](final/grammar_fallback_audio_diagnosis_portable.members.json)，真实pending>0观测释放，保留第一次pending0不足证据尝试 |
| 工具边界 | 原冻结Web脚本失败保留；实际通过用明确SHA/diff的build副本，只改全PCK传输／实际MENU文字OCR和顺序；最终同字节副本已晋入tracked工具；[守门](final/browser_tool_promoted_guards.json) |
| 旧失败 | 全高藤门48/60、受伤恢复／营地／清敌驾驶失败、环境中断、bootstrap不足均保留；[失败与同driver对照](final/retained_failures_and_controls.tar.gz)、[索引](final/retained_failures_and_controls.json) |
| 完整CI | run38948942344失败：Web控制器60秒超时、core原grammar23180/0完成后4ObjectDB／2resources退出泄漏；CLI下载403后已由正常GitHub连接器取得完整日志与摘要验证ZIP；[Web注释](final/ci_0ed19bb_web_annotations.json)、[core注释](final/ci_0ed19bb_core_annotations.json) |

新增完整CI实际终态：ab46 run38953347549的Web／Windows和完整generated31通过，region随后在新森林护符中文缺字检查失败，见[完整core日志](final/ci_ab46_complete_core.log)。现同原源SHA验证OFL字体重建417字、保留旧407并补10字，[字体比较](final/font_subset_comparison.json)、[源下载](final/font_source_download.json)、[实际运行531/0](final/forest_reward_font_final_runtime.log)。这是字体字形修复，冻结0ed的游戏逻辑／地图／资源参数不变；旧影片不签新字体视觉效果。PR精确路径已修复。首Connected适配44测试通过但独审实际发现额外ROOT／反射逃逸，[原REJECT](final/finite_connected_adapter_rejected_review.json)保留；第二版只冻结loader仍被[跨脚本直调反例拒绝](final/finite_connected_frozen_adapter_rejected_review.json)。最终适配冻结已有loader／调用者，并扫描所有生产GDScript的显式类、脚本路径及read_family引用，新caller／别名／反射文字需更新适配；继续实际manifest/raw/SHA验证，[最终45测试](final/quality_all_after_caller_adapter.log)、[最终PR base差异检查](final/quality_diff_after_caller_adapter.log)通过，未扩大目录白名单；[不同作者实际复验限定ACCEPT](final/finite_connected_caller_adapter_review.json)，不宣称一般GDScript动态可达性证明。

原host本轮2调用，加此前2个真实拒绝共4/6，无预算退款，token／price未暴露。实施者root／forest_progression／forest_ecology／forest_traversal；审查者为不同实际代理，未编辑生产代码。

三种空间嵌入有转折／高度／镜像差异，共享分岔回合宏观图；不宣称三种不同图拓扑或以Hash签丰富度。最终清敌driver与旧恢复driver不同；历史局部同字节对照仅证明门底／营地厚度因果，不把全部新成功归因于内容变化。

每图Boss实战是独立debug入口；campaign结算fixture只签状态与Viewport指针衔接，不冒称自然连续平原→森林完整战役。浏览器是真实DOM鼠标／模拟触摸，不是实体手机；本次目标菜单原本可见，未实际发生touch scroll，不能签其覆盖。影片仅抽帧审查，未完整播放或听音；原AVI留本地，Git内提供实际连续MP4与源hash／帧率／trace，不承诺未归档AVI可从Git取得。

原未改grammar本地23180/0、194.018秒严格通过；远端完整日志现确认同23180/0后4ObjectDB／2resources泄漏，并非已证超时。新增分片baseline-only2293/0也严格退出泄漏，已回退，保留[原败与复验](final/grammar_shard_failed_and_verbose.tar.gz)。后续同字节、预先加载工具的实际单路线反事实定位为bell.ogg后台对象：原路径间歇泄漏；真实播放弱引用捕获后停止／断开stream／free并等待实际释放42／56ms，普通及verbose严格通过。补丁仅使用既有AudioTeardown清理测试拥有的世界，1000ms超时仍失败，不放松守门、不增加固定drain；完整原grammar严格复验通过：72路线、23252/0（原23180加72真实资源释放检查）、178.918秒、无退出泄漏；独立只读审查接受测试清理。控制器87项优化仅复用5个fakeworker稳定preflight，全部原断言保留、首尾真实扫描，23.840秒通过。

功能已接入，艺术保持明确玩法原型。商业画质、全部合法武器／最坏相位、完整自然战役、完整音频／性能、实体设备与用户趣味审美仍未验；质量记录保持review，不能签content_complete或发布成功。

字体更新后，原冻结v9回归正确拒绝缺少历史字体blob的工程（[原失败](final/frozen_assets_font_final.log)）。已将两份精确旧Git blob按原ID放入既有portable asset_blobs，原Manifest／484资产身份均不改，[5项含浅克隆测试通过](final/frozen_assets_font_portable_fixed.log)、[精确来源与SHA](final/font_frozen_original_portability.json)。不把新字体冒充旧冻结版本。

全region在75c6cc3真实执行到第10 fixture时，玩法66/0后严格Ogg退出失败；28清单中9已过、1失败、18未执行（[完整观察及对照包](final/region_audio_cleanup_portable.tar.gz)、[成员SHA](final/region_audio_cleanup_portable.members.json)）。在真实trace owner边界显式清理后，同3969ticks/8shots/safe，normal/verbose各1个真实playback在64/19ms释放、67/0严格通过；[独立测试清理审查](final/region_audio_cleanup_review.json)限定接受，完整15套件/28清单正在重跑，不能把单fixture替代全部回归。

**引擎归属纠正**：region_audio_cleanup初轮normal/verbose小探针日志实际为系统Godot4.6.3，原件保留，67/0及64/19ms仅作该旧版本诊断，撤回其作为4.7.2验收用途；原审查仅保留代码生命周期范围。正式root全region始终使用wrapper4.7.2，最新完整复跑前12套件及导入通过后baseline120s实际超时，仍严格失败，不能签完整回归。原grammar小探针与23252全量复验日志均确认为4.7.2，不受此次归属纠正影响。

当前4.7.2补证：[三组短对照与两实际route原件](final/region_audio_performance_portable.tar.gz)、[lazy源码审查](final/region_audio_cleanup_472_lazy_review.json)。短20seed不签性能根因。root另独立新采[完整命令与源前后SHA](final/region_lazy_actual_472.json)、[实际stdout](final/region_lazy_actual_472.log)，同3969tick／8shots／67-0，真实1bell playback20ms释放；[原200样本baseline](final/region_lazy_baseline_472_ledger.json)1274/0、112.455秒通过原120秒，仍为targeted而非完整全套。前一top-preload完整运行超时[原件](final/region_preload_full_472_timeout.tar.gz)与[receipt](final/region_preload_full_472_timeout_receipt.json)保留。
