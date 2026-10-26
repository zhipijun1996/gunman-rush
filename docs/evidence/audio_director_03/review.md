# AUDIO-DIRECTOR-03 独立审查

审查者`/root/v2_review`，与V3候选、场景、公共接口和网页实现作者分开；只写本报告，不修改生产或测试。任务输入630f3c52，实际冻结提交/录制源待主线后续提供。已读当前AGENTS、gameplay-reviewer、AUDIO-DIRECTOR-03 scope、用户feedback03、Style Bible V3，以及候选pipeline/manifest/recipe/rules、四个公共音频接口diff、reels/capture脚本、专项测试与reels HTML/验证器。没有启动Godot，没有完整重渲染42/54音效；场景代理独占引擎，素材登记仍在刷新，不把制作中状态判终态失败。

当前为早期**REVISE**，只针对下列已确定工程缺口；真实正式MP4、逐段原生音轨、审美、真机均待后续实物。Mario/动森/Hollow Knight为用户指定功能参考，不把商业原轨当可商用输入，不把本报告写成用户已接受新ABC。

## V3-R1 · 动作局部帧不能作为MP4时间轴 · REVISE

位置`AudioDirectorReels._physics_process/capture_reel`。当前_reel_clock仅_recording=true时累加，并在capture开始清零；Godot MovieMaker从进程启动连续写帧。boot/open_context中的process_frame、每profile重建以及mix中途重建继续产生影片画面，而局部动作时钟停计。因此segment.start_frame/end_frame不能直接除60当实际影片秒数；初始和转场偏移会累积。

这是静态确定路径，尚未声称已测到具体错位帧。已交场景作者修正：捕捉专属首draw前建立实际MovieWriter连续帧锚，segment及accepted_event记录movie_frame，动作trace独立保留。首次实片需实际抽取各段start前后±2帧核字幕和0/1基偏移，包含开场、第二profile与mix场景切换，再扩其余影片。

## V3-R2 · 捕捉成功守门未核本片目标事件 · REVISE

位置`tools/capture_audio_reels.py`及capture_reel。包装入口当前只核native退出/complete marker、媒体流、整体非静音与源稳定，未读取trace.json；capture_reel没有逐段成功断言，流程结束即返回true。实际MovieMaker中若Router TTL/接触/领取某次未成功，其他profile的声音或mix的BGM仍能令全片非静音并被标passed。

当前专项headless测试确实校目标事件/played，但它不能替本次实际录制的受付证据。要求实际影片入口或打包守门按reel核四profile、目标精确事件列表、正式结果、played_delta、有效时间窗口；weapons核三发射加实际bomb_explode，item/chest核build_count且不可重复领取。需临时删除某段target事件/played并保留有声视频的拒绝反例。此项不声称尚未完成的影片已经失败。

## V3-R3 · 捕捉源快照漏项目设置 · REVISE（独立实际反例）

位置capture.sources。独立在完整隔离的临时git ROOT建scripts/test.gd与project.godot，导入捕捉工具仅将ROOT改指临时目录。sources()实际只列scripts/test.gd。将project.godot音频mix_rate从48000改8000后，before与after仍完全相同，`project.godot_audio_config_drift_detected=False`。

真实生产配置没有被修改；这是source_stable对音频/渲染项目设置的遗漏，不是已录影片造假证据。要求至少把project.godot纳入；实际引擎启动脚本、版本/身份也应与录制来源绑定。临时参数漂移应拒绝，原始采集音轨不能仅凭完整commit字符串而忽略关键工作区文件变化。

## 当前静态边界与后续矩阵

- 新pipeline对path/variants、source IDs、WAV摘要、recipe/tool/source指纹与重渲染派生DSP逐字段比对，比V2最初守门完整；待作者刷新结束再做当前版本的隔离篡改反例，不把V2旧测试升级为V3通过。
- 当前coin源为收集符号/钟亮点；heal有bubble/splash/water主体；chest锁扣/木盖与item长乐句独立。当前item_get非静音尾约1.69–1.76秒，非简单拖静音。仅核材料/时间事实，未听音轨，不签Mario清脆、液体感或动森式获得感是否成立。
- 公共weapon_cue新增末尾可选weapon_id，旧调用默认空身份；精确pulse_gun/shadow_shuriken/recoil_bomb才选择新shot/bomb事件，缺bank沿原路。shot_bomb仅Lab监听真实shot_fired后触发；正式原版bomb launch仍静音，不把场景候选称全游戏默认接入。
- chest/item走正式RewardService实际claim；角色近距Router交互或Area接触后才发声。明确开发固定样板与原版confirm/note通用映射，不称正式所有宝箱已有Chest节点或新声音。
- 影片未交付前，不签正常速度画面、帧同步、原生音频真实性、BGM混音或手机视频循环操作。最终需分别审媒体流/时间锚、实际受付、浏览器seek/loop/stop与用户音色偏好。

## 4d724a73 录屏实物复审

当前影片producer冻结于`4d724a73293aa6f9b94fe51e4884ff5102802ccc`。首版取景/JSON数值失败保留；同源最终原生作者126/0通过、docs33项独占通过。本人未启动这些Godot/完整Harness，不把作者运行记为独立执行。10片实际MP4/report/trace位于`build/audio_director_v3/reels-final`，各有原生AVI与单输入转码命令；状态全部passed/source_stable，60fps、48k立体声，每片约0.8–2.84MB，9片无BGM、mix片录入原Home音乐。实际10个movie和trace SHA已由本人独立逐一核对producer报告。

### R1 CLOSED · 实际帧锚及像素

捕捉专属SceneTree在首draw前安装RenderingServer.frame_post_draw连续计数，Lab明确区分action_frame与movie_frame，片段/接受事件均用实际movie_frame。独立查看`pilot-second-analysis/A-start.png`：182/183仍是原版字幕，184/185/186为A；original-start的0为空栏、1/2/3为原版，支持receipt的0基界限。原始开场空帧没有被藏成内容。mix实际550→552之间551为重建帧，绝对movie时钟继续计数，不再用暂停动作时钟当视频时间。

独立查看实际缓存PNG：coin的230/250帧有角色靠近→物件消失/钱包1；chest_open前闭盖、后开盖且原Toast/道具1；item_get acquired/long-tail保留角色/Toast；UI accepted-purchase有真实钱包2/道具1；三武器有枪弹、手里剑、反冲爆破；mix-before/after确有开发fixture重建。具体文件为`build/audio_director_v3/reels-final-inspection`内chest_open-before/after、item_get-acquired/long-tail、ui-accepted-purchase、weapons四相及mix-rebuild前后，帧号/媒体SHA在其summary.json。只签实际看过的帧与技术关联，没有声称完整聆听或视频逐帧全审。

### R2 CLOSED · 当前实际trace守门（独立反例）

当前capture读取实际trace、四profile精确事件列表、真实钱包/HP/RewardService结果、director路径/played及片段时段。独立以真实coin trace作通过control，分别删除target、删除played、错WAV路径、错candidate ID、钱包0、事件移出时段、重复target、分数帧、movie锚漂移、原版混新候选，10个隔离副本均明确拒绝。实际trace/MP4不改。波形守门另见R4，不能由本项关闭代签其数值可靠。

### R3 CLOSED · 项目配置指纹（独立反例）

sources现在包括project.godot及tools/godot.sh，report绑定实际4.7.2 Standard版本/二进制SHA。独立临时git ROOT重复48000→8000项目音频设置修改，sources前后现在不相等，原遗漏关闭。

配方入口附加实证：在内存副本分别只改coin第二候选为coin_unroutable或把profile B重复标A，当前inputs分别以不可路由ID或A/B/C不完整拒绝。临时完整ROOT内再独立篡改首候选播放路径、DSP gain、DSP filter与subjective_status，均按对应原因拒绝；当前真实42文件未改，不将旧V2测试代签V3。

## V3-R4 · 短声相关性数值假峰 · REVISE

本审查实际解码10片为mono48k、对63次候选和42个冻结WAV复算原算法。旧capture用累计能量相减估算短窗能量，在短声后静音窗发生浮点消减误差；FFT舍入残差除近零分母得到不可能大于1的相关值，例如ui click_a约79.57、denied_a约17396.88、weapons shot_pulse_b约3443.63。由这些假峰读出的71–130ms不是已证实音画延迟；原.12守门在这类窗口不能作严格存在/时点证明。

独立修正测量采用短ref直接滑动能量、长ref有效能量mask，并在最终峰窗直接dot复核，得到全部相关≤1。排除三个同tick shot_bomb独立时点歧义后，60次实际音轨onset最佳匹配相对接受事件为+2.7083至+11.375ms；UI修正为+3.375至+11.375ms，相关约.9889–.9996。该结果是文件内信号对齐，不是人类听感或实体音频延迟测量。

BOMB为正式Lv1反冲炸弹：shot_bomb与bomb_explode真实同tick发生，不能虚构投掷飞行或按时间单独试听两层。单层launch的全窗最大相关可能被同源/相似波形和同时爆破混淆（B仍可能匹配到-75ms），该独立时点保持UNVERIFIED。以实际爆破共起点联合拟合launch/blast，三profile两系数均为正，R²分别约.998210/.981901/.994682；共起点约+8.0417/+11.375/+4.0417ms。这支持混合轨与两个已接受事件一致，不是分离音轨，不据低阈值或高R²签审美。

实际可复现独立脚本`/workspace/scratch/v3_review_offsets.py`、JSON`/workspace/scratch/v3_review_offsets.json`，由主线要求保留供其只读参考，含影片/trace/manifest/script SHA和63项数据。主线拟新增独立包装后验证器修数值问题，保4d捕捉源、原媒体和原capture报告字节不变；修后实际QA与负例尚待复核，当前不签全体工程ACCEPT。

## 最终复审 · 限定工程范围 ACCEPT

最终身份分开绑定：影片/游戏producer `4d724a73293aa6f9b94fe51e4884ff5102802ccc`；数值修复与包装源 `df22e3763484f86b892e16b7cf3e5e9952b847db`；最终网页UI源 `c9795f5c3f4223a5dea1a640a37a2a922cddf5f3`。UI SHA256=`ea1ec829727b35fb6a5297c5aa6c53eca1d881f85b38a376ba05a8276f2803ab`；稳定验证器SHA256=`8b395d5da9cf3bc8c800eec81ec5a38bd51e7df7cc259dbec256ac002fac8144`。最终核验目录`build/audio_director_v3/listen-publish`，原始失败和录制报告均保留。本人只编写本审查文件与受主线要求保留的scratch隔离测量/反例脚本；生产修复由主线编写。修复采纳了本审查的数值方法建议，不伪称与建议无关，也不冒称独立运行Godot或浏览器驱动。

### R4 CLOSED · 保留媒体，升级真实后验验证

新工具对静音/极低能量窗口屏蔽，最终候选峰以直接点积复核Cauchy界；报告相关不会再大于1。联合BOMB初版只要求正系数，本人实际调用该helper，以真实CC0参考在内存构造`.4*blast+1e-6*launch`，曾被误签joint_mix_verified/R²1。这不是实片缺陷；该算法反例现已修复：联合模型对两个单层模型各要求至少.01的独立R²增益，不能用浮点正数冒充实际层存在。

独立重跑8个数值专项全部通过，另以相同完整helper/真实参考WAV重复上述近零launch反例，现准确拒绝`Combined recording does not independently support both components`。纯blast、缺blast、近零launch负例与真正两层正例均保留。实际3组联合增益最低.039784，修复未提高声音、改游戏规则或为了测试重录。

最终包装重新审计10片实际音轨：57个非联合waveform记录及3个同tick联合记录（共覆盖63次新候选播放）。57项独立offset与3个blast锚合计60项为+2.7083至+11.375ms，与独立全轨测量一致；联合R²/系数/增益相符。3个launch各自独立时点仍明确UNVERIFIED，实际Lv1发射与爆破同tick，不虚构可听的飞行间隔。低阈值、R²和短音色的谱匹配不是打击感、悦耳度或BGM掩蔽合格分数。

保留4d原电影、原AVI、原trace/report，旧不稳定数值结果没有回填成新通过。后验证升级仅对白名单`tools/capture_audio_reels.py`与`tools/audio_reels_validation.py`作区别：原捕捉工具先对4d历史Git blob/SHA核实，其他脚本/场景/资源/资产/config/项目设置/引擎入口仍逐字相同。本人独立核`git diff 4d724a73`上述游戏范围为空；当前capture工具的差异为验证输入及后验函数委托，未改实际采集动作或转码输入。

### 最终网页及不可混淆的服务条件

实际`build/audio_director_v3/browser-range-final/report.json`（SHA256=`a234c4d81d6eaab097e94906cf51ee31c0d427b8eb58dfb700856ab1b158a2bc`）由主线运行，本人实读：12章节、48个原版/ABC候选段，390px viewport/scroll均390，video top约363.7px。真正pointer开始、unmuted/volume1、userActivation有效，没有autoplay豁免；MP4画面/AAC轨解码、seek、候选循环、Stop、延迟播放取消、媒体互斥、后台暂停、选择导出/本地恢复通过，errors=[]。本人另查看其手机PNG，实际选择/循环/下载/记录偏好与旧V2明确标签可见；没有独立执行这套浏览器驱动，不据此签真实手机。

此前普通Python http.server的200/无Range导致seekable只有0、候选seek被clamp，失败/诊断保留。当前网页preload auto、等待实际seekable、内部seek token及目标复核，并对缓冲失败给出提示；使用标准Range服务的48段实际通过。**已签范围是该标准点播条件**；未承诺所有无Range本地服务器可正常跳段。直接MP4/下载始终另有入口；线上部署的Range/在线可达由主线另做发布核验，不能用本地结果代签。

### 交付字节与选择语义

独立核最终listen-publish收据100个文件的bytes/SHA全部匹配；10个MP4、42个WAV、10个新后验验证JSON与已核listen-release逐字节相同，10片MP4均与4d原producer SHA一致。只更新网页及其UI身份：比较reels.json，去除新增UI SHA/commit后，所有候选时段、事件、来源、许可和选择语义完全相同。页面源码与已测模板逐字节相同。

离线ZIP实测14653577字节，包含10个真实MP4及同一HTML，禁用不存在的旧互动入口；在线旧V2链接明确标为“上一版互动工坊（V2）”。每片约11.68–28.33秒、均小于25MiB。宝箱/长道具为正式RewardService接受的明确Home开发fixture，不冒称所有正式区域已有独立Chest节点或新声；mix一次真实连续采集内有明确上下文重建，BGM原生混入，不能称自然完整关卡或钱包状态连续保持。

实际伴随音源按segment.director_events、非零played_delta登记，包含命中片同时发生的shot_pulse、旧武器/移动/预警以及mix的原BGM，不再只把目标event_ids当全部音轨来源。新素材CC0、旧Freedoom派生BSD3和用户BGM项目授权分开；许可三态不会把未知署名条件写成无需署名。本人在本轮再次逐首比对五MP3与main26e7f2a，字节全部一致。

### 验收范围

| 项目 | 结论 |
| --- | --- |
| 14事件/42候选与配方 | 输入、输出、trace与路由守门及独立篡改反例成立；候选材料/长度事实可审，音色功能是否悦耳待用户。 |
| 实际消费者/规则 | 正式角色、Router、交易/Reward/Health、弹体和三武器接受信号在显式fixture中成立；不改物理/伤害/资源，正式默认仍原版。 |
| 原生/项目检查 | 作者同源126/0、33项docs通过（`20261026T050304.045801Z`）；独立数值8项及隔离反例通过。原早期126/7与失败试片保留。 |
| 录制与网页 | 真实MovieMaker画面/原生音轨、实际帧锚及标准Range下48段软件Chromium成立；正常60fps影片不等于实体FPS。 |
| 艺术/触感/设备 | 没有完整聆听、实体手机、Safari或自然全局战斗验证；商业品质、Mario式清脆、液体恢复感、动森式获得感、Hollow Knight式打击感均不由本审查代签。 |

**限定工程ACCEPT**覆盖以上精确字节的候选生产、真实录屏、稳定后验验证和标准Range网页选择流程。R1–R4已返工复核，无已知未关闭工程阻断。V2用户原否决保留，V3全部awaiting-user；整体美学与设备G5为UNVERIFIED。最终Sites发布source/在线可达由主线另留收据，本报告不提前把旧站或尚在上传的地址写成已上线。

## 最终播放器补充复审 · Blob 点播 · 限定工程 ACCEPT

本节覆盖此前“需标准Range服务”的播放器条件结论，保留前次测试/失败作为历史。主线实际私有Sites探测`remote-http-probe-final.json`返回manifest 200/application/json、12章节、producer仍4d724a73；MP4返回200/video/mp4且无Accept-Ranges/Content-Range，文件头为实际isom MP4。因而不能把本地Range服务通过自动等同于该私有部署可跳段。

已只读审查最新HTML（SHA256 `cfcc512dc3bb3933b6e28fba33cd9315a22278a31b8e62169851fa44cd67e85d`）：使用同源、携当前会话凭据的fetch获取所选MP4，校HTTP成功及video MIME，再以Blob URL提供本地可seek媒体；无需服务端Range。只取当前选择短片，缓存Map最多4项；切换版本时递增mediaGeneration，过期下载结果不挂载，旧Object URL在替换前撤销。Stop通过候选epoch取消后续播放，下载可完成但不会迟发autoplay；此处不声称HTTP请求本身被AbortController终止。实际录屏、音轨、候选及时间轴均不因播放器修订改变。

已实读作者实际QA：

- `browser-blob-final/report.json`（SHA256 `bb532e229d4e86742bc84594a5ccb719270d6caa7fa109c2bed46f2c9f8c779e`）：真实无Range HTTP、软件Chromium390px，真正手势启动且unmuted/volume1，无autoplay豁免；12章节48段全部解码/跳转，currentSrc均为Blob媒体。循环/Stop/互斥/延迟播放取消/后台暂停/选择导出和恢复通过，errors=[]。
- `browser-deferred/report.json`（SHA256 `40b42b8d249856dd5a685332c6138e39015030e163adb237f6794d506b09c7b9`）：故意延迟真实MP4下载，Stop后不迟发播放；随后真实手势可播放；旧片下载完成不能替换已选新片，全部passed。
- `remote-http-probe-final.json`（SHA256 `2042d8d88e18d036044ef468813109d78854140ad280caf5ac9b7c9805ca4d9f`）仅证明上述真实私有站HTTP行为和媒体类型，不把尚未发布的v5播放器说成已上线实测。

本人本次未启动引擎、未修改生产/测试、未独立重跑浏览器驱动；结论来自当前代码审查及实际QA原始结果核对。限定工程ACCEPT现包括**无Range服务下的所选短片Blob点播及异步取消**，前述Range限制不再是新版前提。v5精确source发布及线上冒烟仍由主线另留收据；音色审美、实体手机、Safari、硬件性能及完整自然玩法混音仍未验，原4d影片与既有主观待审状态不变。
