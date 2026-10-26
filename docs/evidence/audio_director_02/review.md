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
