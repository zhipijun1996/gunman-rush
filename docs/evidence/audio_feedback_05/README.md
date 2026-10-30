# AUDIO-FEEDBACK-05 · 五项声音反馈修复

主实现`d466ed277cb99613ad2040a70574f85939eecd87`，基线main5f55716a；独立分支fix/audio-playtest-feedback-20261030，未自动合main。Web build`1b5989bf6054`，完整PCK208,763,932B，SHA见[收据](receipt.json)。[独立试听与试玩](https://clock-audio-feedback-05.zhipijun1996.chatgpt.site)已发布（owner-private，同一ChatGPT账号）。当前主站ad78未替换。

- 标题首次真实手势即以原MusicGain开始，原字幕位置可开启音乐并留在标题；后续换曲仍0.9秒，五首MP3不变。
- hero hurt改另名feedback05的柔软身体/布料2变体；旧C及旧选择原件保留。墙地用独立石粒/空气3变体，60ms/至多2声，未误借敌伤B，物理/RNG不变。
- 机制铃原quiet-02原件保留，只该cue+12dB并能抢占低优先级voice；总池仍12、pause/mute不放宽。
- 正式开盖/物品/商店沿COMMITTED接反馈，拒绝/取消/REPLAY静音；资源分型。菜单暂停允许成功反馈完成，普通换层保尾，真结束/title清尾。

原Harness新增一项audio-feedback、四consumer194断言全fresh严格通过；原165及其预算/场景完整保留，全profile现166，不冒称已跑full166。原report仍保5f+dirty身份，独审14 blob证明实际所测生产字节与d466相同：[原Harness](harness-194.json)、[四consumer](native-suite.json)、[独审](review.md)及[绑定](review-binding.json)。30/70/63/31分别为新动作/正式奖励/既有selected/上一轮focus+bell守门，原完整日志压缩保留。

[真实原音轨影片](feedback.mp4)为1994帧（约33.23秒）连续MovieMaker，producer9f3；标题/Home起落/真实弹丸碰地、一次原HP事务fixture、固定Seed正式Plains真实铃碰撞及开箱领物。位置/debug/交易fixture明示，不称自然整局通关。全部physical/MovieWriter连续、实际960×540、原BGM和源稳定守门通过，[报告](capture-02-report.json)／[逐帧trace](capture-02-trace.json)／[章节](capture-02-chapters.json)。每章有真实混合PCM；这不等于已经把每个cue从混音独立分离或人耳认可。capture01音频/技术通过但字幕遮HUD，保旧report；producer-only字幕移到中间后的02才选为用户交付，不追签旧美观。

[本地真实浏览器11项](web-local.json)：以Sites将用的同一chunk-only资源集，普通HTTP无服务器COI头冷启动，原worker真实COI/SAB；可信title触摸有原生非零混音且留在title；同一启动进入Home、原枪A、真实录音旁路、无script/shader/page错误。手机尺寸试听页实际播MP4并保存候选/版本。原扬声器连接未移除、未生成音频或强制resume，[旁路](web-local-observer.js)／[实际driver](web-local-driver.py.txt)。完整PCK与五正常音频导入派生[逐项核对](pack-audio-05.json)，[Web资源守门](web-bundle-01.json)通过。

原独立GH host接近900MiB，新建host被403拒绝，保[实际响应](hosting-create-denied.json)；Sites只变独立owner-private站，不替换原主站。静态站保全部哈希chunks和官方threaded runtime；超25MiB raw PCK/WASM仅在静态运输中省略，由既有worker完整校验重建，这个精确无raw集合已实际浏览器验证。Sites源码单次push64MiB上限，按原服务提示分5次小提交上传，最终树与原已验树完全相同；不放宽限额、不改包、不删旧版本。

首字体import、首smoke错两帧及CLI导入/参数失败都在[失败原件](failures/)保留；修后smoke404帧/source_stable通过。新素材加工/反例重建见[source-validation](source-validation.log)与[counterexamples](source-counterexamples.log)，原manifest/配方和许可索引见仓库。实际手机、长自然路线、听感/疲劳及商业品质仍未验。

实际Sites部署[succeeded收据](site-deploy.json)，来源82bb1d54，archive219,245,876B，版本ID原样保留；[运输树与archive SHA](site-package.json)。原生影片之外另有[完整音效对比包](audio-comparison.zip)，包括旧C的V3原来源/配方与BSD条款。未登录executor对私站三资源HTTP403见[访问边界](site-access-probe.json)，未使用Git凭据绕过，也未擅自公开站点；不能冒签实际私站owner浏览器通过。本地11项仍按其真实localhost身份。

补原BGM专项[Harness](bgm-harness.json)为fresh89／0、36.648秒，原MP3播放/loop/各地区与Boss曲生命周期；原日志压缩保留。实际音频194＋89、浏览器11与style技术绑定46项按各自范围报告，不称full166。

收口前原creative检查因3个音频消费者来源漂移真实拒绝，按[影响分析](../../creative_direction/revision_creative_v23.md)版本化style20／creative23：81保序，仅App/Menu/ShopPresenter三SHA更新，另78项、原style19/两Bible/用户原件字节不变。原34＋12纯Python及两个原CLI重新通过，先前缺16,453,016B历史输入失败保留，补取后再跑；[独审](review-binding-migration.md)实际两CLI及5个反例通过。此后技术元数据与brief上下文不重标已导出PCK或影片的来源，不把新引用更新冒称已进入1b包或新美术认可。

本地完整docs预检仍需额外1,257,029,114B已知历史＋未知对象，超过剩余磁盘；原Harness拒绝在缺件状态放行，保[预检](docs-input-plan.json)/失败日志。未删旧文件、放宽检查或冒称docs/full166通过；PR自动CI在有完整输入的runner上仍需独立验收。
