# AUDIO-DIRECTOR-02 独立审查

审查者 `/root/v2_review`，独立子代理；没有编写被审生产/测试代码，只写本报告。基线为第一轮分支 `4f230705`，对照 main `26e7f2a`。最终冻结提交与来源由主线收据绑定。本轮读取了 AGENTS、gameplay-reviewer、用户原反馈与 AUDIO-DIRECTOR-02 scope，以及候选/运行时/HTML/构建代码。

当前为制作中的初审。未完成的场景或尚未出最终证据不自动判实现失败；以下已执行反例保留原事实，后续修复另列。没有聆听音轨，不签悦耳、风格匹配或商业品质；没有启动Godot（主线独占），不把其他作者的引擎证据写成独立执行。

## 初审 · REVISE

### V2-R1 · validate未核运行时播放绑定（实际反例）

位置 `tools/audio_candidates_v2.py:validate`。使用 importlib 导入当前模块，只把 `DEST` 指向临时目录，临时manifest第一个候选的 `path` 和 `variants` 改为 `res://assets/audio/director_candidates/hurt_a.wav`；保留其54个 `renders`、配方、原料、源指纹不变。

实际结果：`AUDIO_CANDIDATES_V2_OK events=9 sets=3 rendered_files=54`，没有拒绝。HTML与GameAudio实际读取variants，因此该守门可以验证54个正确文件却播放另外一个未验证路径。当前真实manifest本来正确，此反例不声称当前已错播。

要求：逐事件/候选对照当前recipes的ID/profile/source，核path等于首render路径、variants与render路径顺序相同、source_ids与recipe sources相同，摘要SHA/metrics等于首render。拒绝profile/version/preserved声明偏离config。临时篡改不得改真实生产文件。

### V2-R2 · 停止后延迟ACK仍可开启单声BGM（实际HTML反例）

位置 `tools/sound_lab/v2_index.html` 的 `single-music` onclick。实际在本机Chromium读取当前HTML和原MP3，用明确的mock iframe协议将 `pause_audio` ACK延迟500ms：点击“播放音乐”，50ms后点“停止声音”，等待ACK。

实际结果：`musicPaused=false`、`musicTime=0.718709`，按钮为“暂停音乐”，bridge显示场景已静音。`bgm.play()` 在停止后的await continuation内发生。复现脚本 `/workspace/scratch/review_v2_music_race.cjs`，只在scratch，不改生产。此项只验证HTML/mock异步协议，不是Godot实际动作或听感。

要求：单独音乐epoch/取消token，stopMusic/停止/visibility/context/demo使未完成的音乐播放请求失效，await前后核token；补延迟ACK后stop不发声反例。

### V2-R3 · 停止示范未取消未发射的敌弹（静态确定路径，待运行复核）

位置 `AudioDirectorLabV2._fire_enemy_once/stop_demo`。`run_demo`在telegraph timer期间停止，只递增 `_demo_serial`；计时结束只核 `_fixture_serial` 和behavior有效，仍会执行 `_fire()`。fixture没重建时，已取消示范仍可能继续发弹并造成真实受伤。

要求：发射请求独立可取消序号或携带demo token，telegraph后再核；停止时取消pending telegraph/behavior。手动受伤按钮的待发请求也要能停止。没有独立启动Godot，因此不虚构已采到HP变化轨迹；这条由原代码路径推导，需当前原生专项证明取消后的零发射。

### V2-R4 · 场景选择音乐可能被Home每帧覆盖（静态风险，待运行复核）

DemoApp._process每帧调用 `_sync_music`，Home状态选home。初版Lab的 `set_lab_music` 只即时request所选track并ACK，没有override该父方法。选择forest/plains后，后续帧可能回home而父页仍显示已确认。

要求：Lab显式依据 `_track` 同步试听音乐，原生至少跨多帧检查 `requested_track`，不能只验证bool/ACK。

## 已读代码边界

- 新候选声明9事件、三profile、54个真实不同take；单原料，不改pitch；原五曲与旧候选原件保留。
- 新bank只在Lab显式配置；motion/weapon现改为bank含事件才映射，缺jump/land/shot继续走原MOTION/WEAPONS，避免新bank吞掉用户认可声音。
- 显式单事件焦点屏蔽另一层，仅Lab调用；原版与新profile比较同一层。不能把此样板叫自然完整混音。
- 真实UI走ShopService；拾取Area接触后调用正式钱包/回血/音符服务；战斗使用正式EnemyActor/Projectile/FrameDamagePolicy。此处为静态调用审查，成功受付需当前原生/浏览器证据。
- parent与iframe双向检查origin/source，未提供任意eval命令。页面用真实ACK后再显示实际profile/context；mock验证不能升级为实际Godot证据。

## 后续复审

等待以上返工和当前版本原生/浏览器证据。即便工程限定ACCEPT，用户音色、真机、Safari、完整自然战斗/钩索仍保持UNVERIFIED；原v1用户拒绝不被V2技术通过改签。

## 复审 · 四项初审关闭，真实Web交付待绑定

### V2-R1 · CLOSED（独立重跑）

当前`validate()`逐一核对recipe/event/candidate ID及顺序、profile、source_ids、原料路径、固定输出路径、path/variants与renders的顺序一致、摘要SHA/指标和原事件保留策略。独立重跑`python3 -m unittest discover -s tests -p 'test_audio_candidates_v2.py' -v`，9项通过，含指纹漂移、坏原料/输出、重复take、语义/播放重定向、部分重建字节不变。

独立另建完整临时ROOT副本，将第一个候选path/variants指向旧v1 hurt文件；当前精确失败为`ValueError: Candidate playback path/variants differ from renders`。没有修改真实候选。注意临时DEST必须仍在临时ROOT下；离开ROOT导致relative_to报错不算此项有效反例。

当前manifest独立计数9事件、27候选、54renders，54个source ID及54个输出SHA均唯一，单层且original_pitch=true。最高样本峰值约-5.99995dBFS。全部保留事件均未被加入新bank。五首MP3分别与`git show 26e7f2a:<path>`核对，字节不变。此次未以峰值/检查通过推导听感。

### V2-R2 · CLOSED（独立重跑实际HTML／mock协议）

当前音乐播放增加musicEpoch，在unlock、静音ACK与play continuation处核取消状态，stopMusic使pending请求过期。独立复用相同500ms延迟ACK反例，读取新版实际HTML（本地8792），50ms后停止；结果musicPaused=true、musicTime=0、按钮“播放音乐”。脚本位于`/workspace/scratch/review_v2_music_race_fixed.cjs`。此范围仍是HTML加mock iframe，不能代替真实Godot。

作者`web-protocol-music-guard/report.json`另覆盖Stop与hidden、延迟decode、ACK和source/origin拒绝；63音效和5首MP3可解码。该报告自标MOCK，本审查保持该边界。

### V2-R3 · CLOSED（静态复核＋作者原生专项证据）

当前`_fire_enemy_once`捕获独立_attack_serial；telegraph结束同时核attack token、fixture、paused、behavior有效与scope.active。`stop_demo`增序号并调用正式behavior.cancel。手动触发与演示均走同一取消路径。新增原生测试分别在telegraph内Stop/Pause，等待110个physics frame，要求原HP不变且正式behavior._projectiles为空。

已读`build/audio_director_v2/scene-native-third/native.log`及report：作者执行22.37秒、66 checks、0 failures、exit0；没有冒称本审查独立跑引擎。

### V2-R4 · CLOSED（静态复核＋作者跨帧原生证据）

Lab现在override `_sync_music`，始终依据 `_track`，不再依据Home状态覆盖用户试听选择。原生专项分别选择forest与空track后跨45个physics frame检查_music.requested_track，均包含在上述66/0中，超出即时bool/ACK检查。

### 许可与工程边界补查

54个原料分属4个来源快照目录（hit12、material6、rpg18、ui18）；独立逐目录核source-page.html SHA与全部source记录一致。保留作者页面许可、CC0全文及Kenney原readme（明确personal/commercial、credit非必须）。来源为rubberduck的Breaking/Falling/Hit、metal/wood、RPG与Kenney UI，均在manifest保留源URL、文件SHA、archive SHA、日期、许可、作者。没有将Sonniss混入CC0。

实际动作成功证据来自作者本轮原生专项：四profile的正式ShopService钱包/装备结果、真实Area接触的正式钱包/Health结果、正式Projectile/FrameDamagePolicy改变敌人和玩家HP，原Router跳跃走motion_jump而非director_jump；只用accepted_event列表无法证明发声音频，因此本审查不将该列表升级为实际扬声器听感。单事件焦点、固定位置与重置是显式dev fixture，不是自然完整关卡。

仍待本轮实际Web冷启动、3情境×4profile、声音解锁与当前构建源绑定收据；最终部署URL可达与用户主观评价另验。构建器自身是否在复制前调用候选validate已向主线提出，当前真实manifest正确不代表今后可跳过守门。

### 构建入口复审 · CLOSED（独立临时反例）

冻结实现`340b249bd59d0cb7c564cf2bf168341276e5ce0e`的`audio_lab_v2.build`已在任何mkdir/复制前调用候选validate。独立再建完整临时ROOT，复制tools/config/director_v2，将首候选path/variants改为旧v1 hurt，直接调用lab.build(temp/delivery)：精确拒绝`ValueError: Candidate playback path/variants differ from renders`，且`delivery_directory_created=False`。真实生产资源未改。该HEAD独立再次运行`python3 tools/audio_candidates_v2.py validate`，9事件/3套/54文件通过。

同一冻结版HTML解锁提示已读`web-protocol-unlock-final/report.json`：390/390无横向溢出、63音效/5MP3、errors=[]；这是mock协议。当前Lab提供“点一下开启场景声音”的真实GUI入口，在GameMusic处理真实输入后上报其实际_unlocked，页面将声音解锁状态与profile/context ACK区分，未用假输入把已请求当作已可听。

## 真实Web首轮 · 保留局部通过，拾取情境返工

已读取主线实际`build/audio_director_v2/web-actual-first/report.json`，该报告为340b249b／build71031d53a0e1真实冷启动Godot iframe，不能替代我独立执行浏览器；与前述mock报告范围不同。12组合均实际收到选择ACK和正式accepted_event：UI四profile各click/confirm/denied；拾取各hurt/coin/heal/reward；普通战斗各enemy_hit。真实pointer开启后两个AudioContext处于running，记录1648个采样、peak约0.07529、errors=[]。这能证明本次实际Web连接与非零音频输出，不能区分每个候选的具体波形/听感；此次Web没有单独覆盖enemy_hurt和主角hurt，后两者只在作者原生66/0中覆盖。

### V2-R5 · 拾取情境混入非目标伤音 · REVISE

真实轨迹在全部四profile的拾取情境先出现hurt再拾取。冻结版run_demo的拾取分支显式调用_fire_enemy_once并等待，原fixture也生成正式敌人，因此这是有来源的真实伤害前置；当前证据不能称旧版伤害回执为伪造。问题是用缺血前置产生额外受伤声音，使仅比较拾取的一次动作混入非目标候选，不够直观。

主线已要求Lab显式以静默开发fixture初始化缺血，保留正式拾取Area/正式回血受付；此初始化不能被记录或播放为敌弹命中，必须单独guard。真实受伤仍由combat按钮走正式弹体。旧报告与轨迹保留，修改后需新源冻结与新Web对照，不能用旧12组合替新包签通过。

本轮完整docs Harness另有underworld专项超时，由主线保留/定位，不将前24项通过写成全套通过，也不为音频迭代扩大无关运行预算。

### V2-R6 · 派生DSP追踪字段可伪造 · REVISE（独立临时反例）

`validate`已核当前recipe/tool/source/output SHA，但尚未核render的processing、trim_filter、edge_filter、normalization_gain_db与实际源/配方相符。在完整临时ROOT中将首render的gain改999dB、edge_filter改volume=999dB、trim_filter改虚构方法及越界start_frame、processing改“synthesized sine wave”，保留全部真实WAV、config、tool与source字节。实际仍输出`AUDIO_CANDIDATES_V2_OK events=9 sets=3 rendered_files=54`。

当前真实trace不是此伪造值，反例不声称当前候选失真；缺口是未来加工追踪字段可以自相矛盾但守门通过，因此前述“语义校验关闭”只涵盖已实际验证的播放路径与源ID，不能扩大成所有派生DSP元数据均闭环。要求基于实际源与recipe推导或重建trace进行比对，拒绝伪filter/gain/trim，并补此反例；保持54个已冻WAV不变。

## 最终复审 · 限定工程范围 ACCEPT

审查实现冻结于`08df881cb3b84626f4c0fe638d86d2f86935cbe8`，Web build `1048defde2ef`；源自两次返工提交，旧340b249b报告不替代新包。实现者为主线与候选/场景/网页代理，本报告作者仍为独立`/root/v2_review`；本人只写本报告，独立运行Python隔离反例并核实物/截图，没有独立启动Godot或执行最终浏览器驱动。下列引擎/浏览器数据明确来自主线实际执行，本人审读原始报告/日志及其对应代码。

### R5、R6关闭

- **R5 CLOSED**：Lab复制HealthDefinition，仅为拾取样板设置4/5初始生命；`_fixture_setup`屏蔽初始化回执，演示不再先发敌弹。保留可选真实敌弹操作及战斗hurt演示；正式拾取Area、钱包、回血服务继续实际受付。新原生检查同时核hurt事件与原/新hurt played计数不增加。最终Web四profile拾取严格只有coin→heal→reward，health由4→5，没有前置hurt。
- **R6 CLOSED（独立重跑）**：在08df881c完整临时ROOT，未篡改control实际重渲染并验证54项通过；分别单改gain=999、edge=volume999dB、trim越界和processing=synth，均精确拒绝`DSP trace differs from recomputed source/recipe: <该字段>`。54个临时runtime WAV的SHA前后不变。当前validate从真实原文件与recipe临时重渲染，比较全部派生trace及输出SHA；不覆盖运行时文件。作者10项测试41.398秒通过、54文件与首轮V2字节一致，见`build/audio_director_v2/dsp-review-receipt.json`。没有把首次只校播放绑定的关闭扩大为当时已核DSP。

### 最终实物与运行证据

独立逐文件核`build/audio_director_v2/site-final/site-delivery.json`：535个文件bytes/SHA全部相符；index.html及manifest与当前生产源逐字节一致。独立按实际SW RESOURCE_MAP在内存解压355个chunk，各块size/SHA均正确；组合185858020字节，PCK SHA256为`1048defde2ef0797cf2b7ada204d3af7783cba4ac82252e0a19552aae4c75a2d`。这是只读重构核验，不落盘改包。页面明示首次约186MB；真实场景要求ServiceWorker与DecompressionStream，没有通用旧浏览器fallback承诺。

已实读最终真实Web报告`docs/evidence/audio_director_02/web-actual-final/report.json`（SHA256 `81fddfde57fc684997170fee6a0ef6e24999b26a563c4a6a18511224767300ec`）：

- 3情境×4profile为12组，另enemy_hurt、hurt各4profile为8组，合计20组。新包build/source均正确；各行实际payload的profile/candidate_id对应所选原版/A/B/C。
- UI各组严格click/confirm/denied且钱包购买后2；拾取各组严格coin/heal/reward、真实contact=true；enemy_hit和enemy_hurt均有实际敌HP2与actual_enemy_damage_receipt；主角hurt有HP4和actual_enemy_projectile_damage。
- 实际pointer后两个AudioContext为running、1910个采样、backend peak=0.103271484375、errors=[]。这是非零输出与实际消费者闭环，不能由总峰值推导每个候选悦耳或逐声波形质量。
- 已独立查看mobile.png和combat-desktop.png：手机宽度下有实际Godot画面、外部场景/方案/示范按钮，提供全屏与独立打开；内部小按钮与文字在竖屏很小，因此不签真实手机触控可用性。

最终冻结原生`build/audio_director_v2/native-frozen`：作者实际66 checks/0 failures、exit0、30.490秒，原90秒预算；已读日志未见ERROR/泄漏。包括四profile正式交易/Area/弹体/HP消费者、原Router跳跃、单层隔离、Stop/Pause取消telegraph、跨帧音乐选择和共享12voice释放。先前原运行时60/0、生命周期37/0作为受影响旧入口回归，不代替新专项。

完整docs wrapper `docs/evidence/audio_director_02/harness-docs/report.json`为同实现commit：33项全部passed、jobs1、396.628秒；underworld runner 152.882秒小于原180秒预算。此前源漂移、超时和旧Web混伤轨迹保留，没有改预算、删失败或把部分通过改写成整套通过。

### 已知非阻断提示偏差 · OPEN

最终实际事件含audio_unlocked=true、后端确有声音，但父页只在ready或独立audio_unlocked消息更新bridge.audioUnlocked；点击画布其他位置已触发Godot真实输入解锁时，截图仍可能提示“请在场景内开启声音”。这是已确认的状态显示假阴性，**不是实际无声**。点击场景内专门“点一下开启场景声音”按钮可同步父页。主线决定本轮保留冻结HTML以保证已测/上传包一致；后续可同步合法同源status的实际布尔值并补专项，不应靠请求意图自认解锁。

### 范围矩阵与结论限制

| 维度 | 本轮结论与界限 |
| --- | --- |
| 设计落实 | 3套独立CC0原take、9事件、可听单声和真实情境比较已接入；音色审美待用户。 |
| 玩法价值/公平/随机关卡 | 本轮不改变游戏规则或关卡，不作新玩法品质判定。 |
| 操作/画面 | 实际软件Chromium画面及手机宽度布局已核；内部按钮缩小和真机触控未验。 |
| 动画/美术 | 复用原正式表现；截图证明在场景中，不能据此代签风格品质。 |
| 特效音频 | 来源、许可、DSP、幅度、变体、播放绑定、生命周期与非零后端输出已核；好听、统一、辨识度待用户。 |
| 正式消费者 | 正式Shop/Health/钱包/弹体在显式开发fixture中运行；不称自然完整关卡通过。正式默认仍原版。 |
| 性能/状态/恢复 | 共享12voice、取消与drain有原生证据；不签手机帧率、Safari或硬件音频。 |
| 设备/主观认可 | UNVERIFIED；保留v1用户拒绝，V2全部awaiting-user。 |

**限定工程ACCEPT**覆盖上述冻结候选库、可复现加工、正式架构的Lab接入及实际软件Chromium情境试听。所有初审阻断项已返工验证；已知提示偏差明确保留。商业听感、完整自然战斗/钩索混音、真机与Safari仍为**UNVERIFIED**，内容G5不能由本报告代签。最终站点发布/在线可达由主线另记精确Sites source与部署收据；本审查未把尚在部署中的地址当成已实测上线。
