# AUDIO-DIRECTOR-04 独立审查

2026-10-28；审查者 `/root/v2_review`，实现者为主控、candidate/runtime/Lab agents。使用仓库 gameplay-reviewer 流程；只修改本文件，不修改实现、不启动 Godot、不提交。下文保留早期发现与返工历史；最终为**限定工程 ACCEPT，组合审美/实体设备 UNVERIFIED**，精确范围见末节。原 V3 技术认可不继承为本轮新源码或用户组合认可。

## 授权与身份

基线合入最新 main `879b39ea`，当前工作分支合流提交 `dc2e015d`。用户回传原件：`/tmp/codex-remote-attachments/01a175cd-2da8-720e-9806-24f5e731b099/47579f75-16a3-41e0-853d-a764458c14bb/1-audio-director-reel-choices.json`。独立读取其原字节，与 `config/audio_director/selected/user-20261028.json` 完全一致，SHA-256 `56a0dd359fe5c53169794e28dcd7f333cea686d9f1d147ca70d3a3419d2ed072`。

13行选择明确为：coin/heal/chest_open/shot_pulse A；item_get/click/confirm/denied/hurt C；enemy_hit/enemy_hurt B；shot_shuriken/shot_bomb original。bomb_explode original 为记录中同一原版复合炸弹动作的窄范围推导，`selection_status=derived`、`user_selected=false`，不是第14条显式选择。UI三行各有独立事件ID，不把 `ui_c` 当成所有事件的声音ID。缺选、拒绝项保持未知或拒绝的原声，不伪造采用认可。

用户批准的是上述单项音色选择；正式默认仍 original，完整组合、自然战斗混音、审美和实体设备均未认可。

## 已实际执行的独立检查

- `python3 -m unittest discover -s tests -p test_audio_reel_choices.py -v`：9项通过，0.771秒，exit0。实际测试包含版本/事件/时间/来源/路径/WAV指纹、重复键与事件、缺选、不推导UI同组、原版炸弹窄推导及冲突、失败不覆盖原件。
- 独立调用 `verified_selection()`，实际得到上述14事件映射。隔离临时目录复制真实原件、reels、manifest、WAV和导入工具：未改控制例通过；仅改 `event_profiles.coin=C` 拒绝；仅改原件来源SHA拒绝；仅改importer SHA拒绝。临时副本未修改真实资源。首次用越界symlink建立控制例被路径边界正确拒绝，不计为漂移反例；改为真实临时复制后才计入上述控制/拒绝结论。
- 只读检查 `game_audio.gd`、motion/weapon音频消费者、`audio_director_reels.gd`、`audio_reels_capture.gd`、`capture_selected_audio.py` 和新原生测试。原版回退走实际原weapon/motion家族；`cue_event(chest_open, confirm)` 在 chest_open 选择 original 或缺选时绕过 confirm 的 C 候选。此处是静态结论，原生执行由引擎租约持有者完成后另审。
- 当前capture校验器 SHA `926240631b32a150ffbda55ab97e8b02663bd1e6667dd57245e945c780e1d388`：使用旧真实trace构造**内存schema夹具**（不是新Godot采证），控制例通过；movie_clock错误、version/FPS错误、selected事件actual profile错误均拒绝。

## 早期发现与返工状态

**R1 · 已见实现修正，待最终冻结复核。** 初版capture只比较trace内selected与磁盘selected，未从保留原件重建；合法ABC值可漂移但保留旧provenance。主控已加 `verified_selection()`，重跑normalize、全结果对照、三输入与importer指纹；上面的独立临时反例拒绝成立。初版缺movieclock/version/FPS、actual event_profile与引擎身份；当前源码已补前三类校验及engine version/binary SHA记录，最终实际媒体仍待核验。

**R2 · 已见实现修正，待实际trace复核。** 上述通过控制例中，把全部physics行 `movie_frame=0` 仍被接受；在原版/selected双方同时删除coin的同一 `action_frame`，也仍被接受。原校验仅比较双方position/HP序列，不能证明逐段完整逐帧采样。主控提交 `a93dfb5b` 已补逐段action样本连续覆盖、physics_tick+1、movie帧递增及段范围；等待新录屏实际trace做控制与反例。此为校验器反例，不代表实际录屏已损坏。

**R3 · 静态接口已修正，待浏览器复核。** 初版capture生成每章 `id=s['reel']`，原版/selected两章重复同一ID；初版播放器 `validateChapters()` 要求全局唯一ID，因此20章会被页面拒绝。现HTML使用 `[reel,profile]` tuple生成内部唯一key，不改录制/章节原始身份；同时将旧V3“选择来源4d”与新影片 `capture.commit` 分开显示，要求report.passed后才启用播放。此处不需重采声音，最终仍以实际20章浏览器验证为准。

只读核实作者原生报告：`build/audio_director_04/selected-native-39bb62cd/report.json` exit0、108项/0、0.884秒；`reels-native-39bb62cd/report.json` exit0、126项/0、55.628秒。本人未启动引擎，不把作者运行写为本人独立实机执行。当前capture producer冻结 `a8350cbf`，游戏脚本仍与39bb原生测试输入相同；后续工具增加完整trace守门，新的十场景聚合MovieMaker预算900秒与原90秒严格native专项分开，旧专项预算/断言不改。第一次 `capture-final` 由主控主动中断，原failed report/log/AVI保留，未追签；第二次 `capture-selected-final` 仍在采集，60Hz/1280×720保持。

独立逐字比较42个 `assets/audio/director_v3/*.wav` 和5首 `assets/audio/bgm/*.mp3` 与V3原生产 `4d724a73293aa6f9b94fe51e4884ff5102802ccc`：47文件全部相同。本轮未重加工候选或替换音乐。

非阻断的日志范围：旧 `AUDIO_LAB_V2 accepted_event` 广播发生于子类修正candidate ID之前，可能显示 `coin_selected` 一类中间标签；不能拿此旧bridge日志字段当作已核实际候选ID。最终审查以修正后的trace、实际director_events/播放计数和原音轨为准。本轮交付为录屏，不因此要求改冻结运行源重采。

## 尚未验证

网页真实点击/无Range/延迟取消、最终部署待新证据；媒体与源复核进度见下。未启动引擎、未完整播放或听完本轮组合、未做实体手机/Safari或物理声画延迟检查。不得以本轮Python通过宣称听感或商业品质通过。

## 实际影片与独立后验证复核

实际 `build/audio_director_04/capture-selected-final` 为producer `a8350cbf5ceecb401933a1a9263672019ce20f49`；4704帧/78.4秒/6,281,615字节，十场景×原版/selected共20章。原 `report.json` 的failed/`Selection receipt drift` 保留：775.172秒含编码完成，Godot JSON往返只截短26个 `events/*/evidence/start,end` 小数，如5.816666666666666→5.81666666666667，其他字段未漂移。两个明示mix重建边界均action连续、physics/movie共同gap2、enemy HP -1→3；原一律physics+1守门也会拒绝该明确fixture切换。

作者新增 `tools/revalidate_selected_audio.py` 独立后验，不重录/修改原AVI、MP4、trace或failed报告。当前 `post-validation.json` 标记后验passed，producer仍a835，postvalidator提交 `d2b567cad880650ec6397bfc13fac2d920f53e8c`，并保留capture_attempt_status/error。仅放行已知证据时间数值≤1e-12秒的往返误差；其他选择内容仍要相同。每个mix/profile只准一次gap2及上述真实敌人状态转换，其他physics/movie必须逐帧+1。

本人独立实读并核验：3663项冻结输入键未变，仅 `tools/capture_selected_audio.py` 这一后验校验器发生允许漂移；Git a835中的原工具SHA与原报告source_before相符。MP4 SHA、trace SHA、原failed-report SHA均与后验收据一致；原failed报告未被覆盖。trace SHA `b47345739dad161251954021d3d2fb95b0a84a4ed37d57dc825990e32b07b138`。未重复运行FFT；作者后验报告18次新候选波形支持11种选中声音，相关性0.575439–0.999254、报告偏移1.375–10.708毫秒，只是源波形技术支持，不签感知同步或音质。

本人以**实际trace副本**运行当前validator SHA `9aa6ae55d596d0914b8df6483fbc34ce17626242b5bc26ebd4407ebb05384c36`：控制通过；原版/selected同时删同一action帧、全部movie_frame置零、event_profile错误、候选ID错误、钱包0、mix gap3、错误敌人状态转换、selection映射漂移、非时间证据数微漂移、时间超界+1e-11均拒绝；时间+1e-13按窄容差通过。R2在真实trace上的上述反例已闭合。

**R4 · 最后窄类型缺口，已交主控。** 上述实际trace中，仅将 `selection.schema_version` 改为JSON true仍通过；仅将accepted coin.details.wallet改为true也通过，因为Python true与1比较相等。要声明除上述时间往返外严格相同、以及真实数值钱包，需排除bool↔number及计数字段bool，不能改原媒体/报告追签。其余实际反例通过不覆盖此缺陷，最终限定结论等待修正复验。

实际武器trace：original使用pulse变体0/blade1/blast2；selected仅 `shot_pulse_a` 新候选，旧weapon_events为blade0/blast1，播放计数各1，手里剑/炸弹/爆破接受事件的event_profile均original。原版家族回退成立到代码、原生报告与真实播放回执范围；原三变体机制使两段可能不同原声变体，不宣称逐波形相同。

实际打开 `build/audio_director_04/listen-selected/poster.jpg`：可见真实Home角色、`已发生 coin · coin_a`字幕和金币1；仅签此静帧所见，未把静帧当作连续画面或听音证据。

## 最终复审 · 限定工程 ACCEPT

最终校验器提交 `66d400ec601cb78cbad1ea0be4a0517da0f1356e`，`capture_selected_audio.py` SHA `cd02c703d9ccfcb5a2f1641edd2210cd29efe5a1154153ad6bc9dfe6912952aa`。递归same_json区别bool与数值，仅允许有限且相等的int/float；证据中的钱包/生命/构筑计数及movieclock.index_base排除bool。前置 `verified_selection()` 也使用相同严格比较。本人在真实临时副本复验：控制通过，磁盘selected.schema_version=true与events[0].evidence.input_row=false两反例均拒绝。实际trace15例复验中，控制和合法1e-13秒往返扰动通过，其余13种反例拒绝（含schema/wallet/movieclock三种bool）；最终工具实际trace正例再跑通过。R1/R2/R4在此范围闭合，旧错误接受结果保留上述历史。

最终独立后验收据为 `build/audio_director_04/capture-selected-final/post-validation-v3.json`，v1/v2与原failed报告全部保留。后验工具SHA `003da88cca08b8447ceda5a10381480d028d4d1006cc826fc01d4c335bad3d3c`；capture producer仍为a835。本人再次实算MP4、trace、原报告指纹，与v3相符：MP4 `2103c528bedb5dc7a9e59621a55b353d174f8eca3cf7ee2fd1b05de8ffa96141`，原报告 `195e3b20f9f53e3f7e44d524ed7b112835b06b7dbca76a50084edd8e4a454de7`。不把后验成功追写为原采集校验通过。

网页证据为作者执行、本人实读的 `build/audio_director_04/browser-final/report.json`，SHA `41601f988188749b9dbc73ad6b36ec1ac6b011f80294ef97a85b40b5be4d16c6`：普通无Range HTTP、390px软件Chromium、真实指针手势、无autoplay豁免；20章全部报告解码视频帧和AAC音轨字节增长，声音未静音；段末停止/不循环、Stop、自然结束、受控DOM visibility事件暂停及故意延迟实际MP4下载取消均通过，errors数组为空。受控visibility不是实体后台切换；本人未重新执行浏览器或完整听音。实际layout宽度/scroll均390，显示选择来源4d及本片a835，R3得到新网页证据闭合。

本人逐字比较已测包 `listen-selected-final` 与最终 `listen-selected-verified` 的index.html、selected.mp4、chapters.json、selected.json、user-choices.json：五文件全部相同；最终包report.json确为v3新后验收据。只更新后验metadata，不用旧录屏或未测试UI冒充本轮影片。最终上线及私有Sites远端冒烟由主控另证，本文件不签尚未验证的部署。

ACCEPT范围为：保留并准确导入13条用户选择、窄推导原版炸弹爆破、显式混合profile与缺选回退、原生专项与旧专项回归证据、真实开发场景原版/所选录屏、完整同条件物理HP轨迹与声源技术后验、当前无Range网页章节播放。正式默认original；没有推广完整正式消费者，没有改变伤害/物理/操作/规则，没有重加工42候选或五首音乐。

不签：完整组合审美、声音响度平衡的主观满意、商业品质、自然关卡连续混音、全部正式消费者、实体手机/Safari、物理声画延迟/低端性能、未实际验证的最终发布。用户原件足以认可逐项音色，不能外推为对本轮78.4秒组合或上述设备范围认可。
