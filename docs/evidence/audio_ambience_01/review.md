# AUDIO-AMBIENCE-01 · 独立审查

审查者：`/root/ambience_review`，与素材、运行、场景实现作者不同。审查者没有修改所审生产实现；主控独占Godot，本审查不另启动引擎。基线main `45e98dbbf38d906dc5eae9686dc9ee5ee6a99acc`。当前为制作中间态审查，最终冻结源码/真实录屏/网页收据待主控提供。

## 首轮结果：REVISE（可局部返工）

以下范围仅为实际源码和独立Python反例；未播放音轨、未完整观看视频、无实体手机，不签音色、自然度、商业品质或设备认可。

| ID | 严重度/事实 | 证据与最小修复 | 当前状态 |
| --- | --- | --- | --- |
| R1 | 中：build渲染后仅核recipe/source-registry/pipeline字节，不重核真实录音cache字节，可能把渲染中漂移的录音标成旧输入SHA | `tools/audio_ambience_design.py`的build/check_sources；manifest写前再次check_sources(require_originals=True)，构造原件中途修改负例 | 修后独立Python复验通过，见下文 |
| R2 | 高：manifest仅候选ID变更为`forged-candidate-id`，原验证器仍通过，可能使用户选择身份与运行配方不一致 | 独立临时manifest反例实际通过，日志`build/audio_ambience_01/review/catalog-id-counterexample.log`；校验candidate ID/profile/source/loop/duration与配方以及point_events引用 | 修后独立Python复验通过，见下文 |
| R3 | 中：真实lab传PlayerMotor作listener，它无died信号；自造Listener.died测试不能证明真实PlayerController死亡即清理 | `scripts/demo/demo_app.gd`player:PlayerMotor与`player_controller.gd`signal died；lab连接实际controller.died，并对真实宿主路径复验 | 实际Controller.die专项6/0通过；完整自然战斗死亡未验 |
| R4 | 中：单声试听旧play Promise迟到后无条件single.pause，会暂停共享audio元素的新请求 | `ambience_index.html`renderSingles；应按播放owner token保护，延迟A→B独立反例验证 | 已发场景作者，待最终复验 |
| R5 | 中：打包验证movie/trace，直接复制未绑定的chapters.json；可调换A/B章节起止而仍打包，从而按钮错听 | `tools/audio_ambience_lab.py`；由已验证trace重算章节并严格比较生成原件，保篡改拒绝反例 | 已发场景作者，待最终复验 |
| R6 | 低/效率与分发范围：cache中出现Godot生成*.import，说明大录音缓存被编辑器导入 | `build/audio_ambience_01/source-cache`；添加.gdignore，并在fetch建立时保证该标志。Gitignore本身不是Godot导入/导出排除证据 | fetch与现cache均已加.gdignore；本轮未做Godot Web导出 |

实际第一次独立Python加工测试：`python3 -m unittest discover -s tests -p test_audio_ambience_design.py -v`，9项，1失败/1错误，均中间态pipeline SHA漂移；原log/json保`build/audio_ambience_01/review/design-tests-01.*`。作者正在修改并重建，不能把此中间态失败写最终通过，也不据此添加降标或放宽指纹。

## 已核查事实与审查范围

- GameAudio的diff仅增加显式创建/委托、会话音量、区域清理、shutdown；未修改原voice数、原cue选择、玩法物理/伤害/输入/RNG/save。只有显式configure才创建2床+2细节，正式默认仍original；不把它写成沿用12短voice或默认接入。
- GameAmbience使用原Ambience总线，床Vorbis副本loop，细节资源副本非loop。距离为手动线性衰减，没有声像/遮挡/混响声明。弱owner/listener、旧listener signal断开、暂停冻结淡变与时钟、mute、region clear和有界shutdown都有实际代码路径；真实运行结论待主控原生日志。
- 7条输入source_page SHA已独立逐一核对，原HTML均包含对应CC0许可字段；作者/原件/URL/下载日/商业/署名条件齐全。HaelDB页面为多许可选择CC0，未把Sonniss或CC-BY冒称CC0。完整原件留build cache且可URL/SHA恢复，处理产物与许可才入Git。
- 4床为不同录音片段/层次：平原A风、B风+稀薄鸟，森林A树冠鸟录音、B另一段树冠+低风；有语义差异，不只总响度变化。线性tail/head交叠、Vorbis解码接缝指标为技术守门，不能证明无感接缝或自然愉悦。
- Capture直接Godot MovieMaker native.avi，再编码MP4；原生音轨无另行拼接。每profile新DemoApp同Seed，真实router输入、Motor状态/HP和接受jump/land/shot对照，并记录真实床路径。最终后验需要实际录屏和完整源稳定收据，制作计划不算执行。
- 原声与候选均保森林原9秒短风，属于增量床声对照，非已替换旧风；应在交付准确说明。新点声当前未在真实地标布置，不能把原料/接口已具备写成全地图机械/树体空间音完成。

## 最终复验

待最终冻结源码与主控真实原生/影片/网页收据。整体内容保持UNVERIFIED；即便局部工程随后ACCEPT，用户听感、原录音可能的现代背景/近鸟、疲劳、BGM遮盖与实体设备仍须单列未验证。

## 第二轮：素材与真实生命周期限定复验

素材源码 `a073f9cf08a45753326977b232c641c76ab2032116cb5df9a5cbf4d89b29a568`；manifest `619fbca8b7999c791c010692ad9a61f2027260c49a06ec47a4b49f009b68f8f4`。

- 独立实际运行同一9项加工Python测试：全部通过，13.634秒；`build/audio_ambience_01/review/design-tests-02.{log,json}`。渲染中原件真实字节漂移负例要求拒绝且不覆盖原manifest；并检查许可/配方/加工器/输出漂移、完整cache可缺但已有坏cache不可接受。
- 原候选ID篡改反例修后实际重跑，收到`Catalog identity/reference changed`拒绝；`catalog-id-counterexample-fixed.log`，首轮误接受log保留。events/regions/point_events现由配方与实际take完整构造再比较。
- 主控实际原生日志`lifecycle-03/native.log`与JSON为6项/0失败、退出0、严格日志清理通过，真实正式平原Controller.die()即时取消床声及真实幂等绑定；这不是自然敌伤死亡或森林死亡全覆盖。首次父类成员/函数名冲突parse失败、次轮退出cleanup失败分别保`lifecycle-01/02`，未追签。
- 另读主控严格wrapper的`runtime-01`、`old-selected-01`与`old-forest-01`通过收据，分别支持显式组件、本项目旧已选SFX、原森林短风/果/网消费者的局部回归；审查者未另开Godot进程，不冒称独立执行引擎。
- 独立逐字节比较main基线：五原MP3、Kenney跳落fallback、实际正式PlayerMotionAudio脚本与全部9个jump/land/heavy WAV共17件均不变，`review/preserved-audio.json`。不由这些字节证明新混音悦耳或动作没有被遮盖。

R1/R2源身份与R3真实死亡绑定已在上述范围解决；R4网页异步、R5章节身份实际打包/浏览器反例、正常速度连续片/原生音轨和发布身份仍待主控最终收据。整体仍UNVERIFIED，允许继续制作和工程验证，不是商业品质或全游戏正式推广接受。

## 有限资源适配器与录屏尺寸配置增量独审

适配器 `tools/check_quality_diff.py` SHA `6ff7ad4a0b0d739a71f7e57e87323fbc3eda6b9c0fc7dd9cb05f09e44dfafc17`，绑定唯一GameAmbience loader SHA `344eee9381b7ac653cdcc94f4f32fc484864796fc87a275bba5c6b76745ed4c3`。原scanner把目录prefix当文件拒绝的失败保留，新增条件只对该精确loader的该精确prefix生效，并先核有限适配器；没有跳过其他caller或整个assets目录。

独立实际执行：

- 新适配器17项测试全部通过，0.174秒，`review/adapter-tests-01.{log,json}`；原57项quality测试全部通过，4.398秒，`review/quality-tests-01.{log,json}`。这些是资产身份测试（部分夹具为明确synthetic bytes），不证明可解码/听感。
- 对真实工作区实际调用有限适配器，closure恰9件：四床OGG、四点声WAV、一个manifest；同目录未引用sibling不被登记。
- 独立5例：source配置字节漂移拒绝，loader prefix改双斜线先被SHA拒绝，未知动态caller仍被原scanner拒绝，森林runtime别名指向平原被closure拒绝，未引用sibling保持精确9件；全部符合预期。`review/adapter-independent-counterexamples.json`记录精确adapter/loader SHA与真实closure。
- 原recorded source/recipe/pipeline、输出文件普通路径/祖先symlink、字节/SHA、固定四床/四点、事件与运行映射和typed bool/number边界均有对应拒绝路径；不按目录glob自动承认任何新资产。

该有限适配器在上述范围工程ACCEPT，需随真实loader或实际家族扩展另作审查；不能替代音频解码/声音生产验证，也不批准全游戏正式音效推广。

录屏尺寸原失败保持：capture-01的1280×720软件渲染按实际速率不足原900秒预算，由主控有界停止；capture-02仅CLI尺寸未改变MovieMaker实际1280头，也停止并保raw/stop-reason。未把这两轮签通过。新版通过临时`override.cfg`设置物理960×540，逻辑1280×720、同Seed/输入、6×26秒和原900秒预算保留；真实smoke/完整媒体尚待主控执行，不由源码推断成功。

独立4个配置生命周期反例已实际运行（真实临时文件系统，mock runner，不启动Godot）：已有普通override原样拒绝；已有symlink原样拒绝；受控runner失败仅删除本调用同字节普通override；处理中出现foreign字节则保留文件并报失败。全部通过，`review/capture-override-counterexamples.json`绑定该capture脚本SHA。真实MovieMaker尺寸、持续逻辑视窗、源码稳定、音轨与像素仍须实际捕获后验；FS/mock测试不升级为引擎测试。

### R7：渲染源码守门闭包（增量）

`frozen_sources()`原prefix列scripts/scenes/resources/assets/config，漏独立`shaders/`。两区真实渲染使用该目录，故不能把原source_stable描述为完整渲染源闭包。已通知主控完整采集前补入shaders；若某轮已采只能保其实际列出源范围，不能事后补造录前快照。原source范围及旧媒体身份保留，修后新采再验。

## R8：实际合屏遮挡 · REJECT该轮媒体

独立审查者实际打开`build/audio_ambience_01/first-scene-observation.png`（capture-04原MovieMaker第600帧，960×540）。可见环境工坊PanelContainer从约物理x190–790、y60延伸到画面底部，形成巨大实心面板，中央角色与主要动作区域被完全遮住。画面边缘仍有真实平原、正式HUD，但这不能支持用户观察动作与环境的关系；坐标落在屏幕范围内不等于实际可见，原validate_trace的screen坐标断言不足以判此遮挡。

主控已停止capture-04并保留raw/native.log/report/stop-reason.json；该轮不可签真实场景试听已验，也不得截取几秒有背景的部分冒称合屏合格。修复方向为capture_mode使用小字幕、两区各120帧真实scene-smoke先看实际像素，再执行原6×26秒/900秒完整媒体。审查者不改所审生产代码、不启动Godot；修后pilot像素与完整连续媒体尚待实际执行和审查。

此发现为真实画面事实与必需可见性失败，独立于音色是否悦耳；既有声波、源闭包、有限适配器通过均不能冲销它。

### R8 修后：两区真实pilot像素限定接受

独立审查者实际打开`scene-smoke-01/plains.png`与`forest.png`两张960×540原图。平原角色在约(410,310)完整可见，起跳平台/右侧缺口与远景风车未被面板遮挡；森林角色在约(455,340)完整可见，根台/右侧枝路与纵深树林清楚。两行小字幕位于左上HUD下方，未覆盖角色与主要动作区域；先前中央巨大实心Panel已不存在。该两张画面的R8故障已在限定静态合屏范围解决。

独立核对原pilot收据：261输出帧，各区120物理样本/120帧、`interactive_panel_present=false`，caption逻辑rect分别(28,94,432,25)、(28,122,392,21)，物理960×540/逻辑1280×720，严格日志与source_stable通过。`report.seconds=30.951568...`为采集/编码/清理包络，不与主控单列native约25秒混用。

原report.commit保`9721f677ef6cf434fdbc2365cbcf8f7dd41ebc39`（修复源码尚未提交时采集），实际完整source_before与之后提交`de6b36c62f0640d9322973fffb687472755d25b7`的当前frozen_sources逐件完全相同，独立比对为true。关联依据为该完整实际快照等价，不篡改旧report或宣称其commit字段原本de6。`review/scene-smoke-observation.json`保两原图SHA、实际源/帧/尺寸观察。

该pilot不包含完整连续动作/26秒循环/BGM混音试听，也未验证非capture互动Lab工具条；这些不由小字幕原图继承通过。完整影片后续须实际媒体后验和至少动作窗口像素审查。

## 完整 capture-05：限定工程 ACCEPT

实际producer `de6b36c62f0640d9322973fffb687472755d25b7`，MP4 SHA256 `69da1d4d924d79010be30468ba3f23a0831c469212f45cc38929a3b09de5fc8e`，14,049,972字节、9943帧、60FPS，物理960×540／逻辑1280×720。完整6×26秒章节、起始/转场和退出帧保留。原生日志记录约8分42秒，report采集/编码/清理包络577.629秒；两者口径不同，均在原900秒native界内，没有增加原超时。

审查者实际读取`capture/{report,trace,chapters}.json`与native.log，并独立重跑原trace、override生命周期、章节重建一致性及MP4/trace SHA检查，全部通过。3808件完整源快照before/after一致，且独立复核时仍与当前工作区实际源相同；完整shader与project/export守门保留。`review/final-trace-check.json`保各区/方案真实动作和loop观察。

- 6段各1560个连续物理样本；同区original/A/B的Manifest、每帧位置/HP/落地状态与接受jump/land/shot相对帧完全一致。平原2次jump/3次land/1次shot，森林另有真实移动后落下一层的1次land；六段生命保持5。不是自然完整探索路线或完整敌伤/死亡测试。
- 4个新床声实际backend playback_position各观察到1次24秒循环wrap；original无新床。BGM前15秒按正式地区选择，+16秒后清空track并已淡出；旧森林短风保留，未宣称完全替换。
- 审查者独立重跑native AVI声音窗口验证：平原A/B direct normalized dot分别0.953134/0.904764，森林A/B分别0.932991/0.915408，证实候选样本存在于真实BGM-off原生录音。独立静音样本反例被拒绝；把平原A错误指向森林B的实际候选反例dot0.052118被拒绝。`review/final-native-audio-check.json`保原值与限定范围。此为波形身份，不是人耳听音或悦耳判断。
- 审查者实际打开最终`capture/plains_A.png`和`forest_B.png`完整960×540图，空中角色轮廓、接收平台和主要空间清楚，小字幕未遮动作区；结合先前两区pilot，R8故障在这些实测窗口解决。未完整播放165.7秒影片，不能把抽帧审查写成完整连续视觉/听觉验收。

因此，当前实际范围可判**工程 ACCEPT**：获许可的四床/四点候选身份、显式有界运行、已验生命周期、真实两区同输入原生录音、循环/波形证据、采集来源闭包与代表动作像素成立。actions-01的90秒诊断超时仍为失败，不被本轮通过追签；原capture01–04和parse/cleanup失败链保持。非capture互动Lab GUI、全地图细节布点、完整自然路线、手机/Safari/实体扬声器、用户音色/疲劳/混音认可与商业品质保持UNVERIFIED；完整内容G5未完成。网页实际播放/异步反例与发布身份另待收据，不从本节继承通过。

## 手机尺寸网页与打包身份：收据交叉核对通过

审查者只读核对`build/audio_ambience_01/browser-01/report.json`与`package-counterexamples-01/report.json`；真实浏览器/打包动作由场景实现者与主控执行，审查者未另启浏览器，也未进行人耳听音。独立核对记录为`review/final-browser-package-receipt-check.json`。

- 本地390px Chromium软件浏览器布局宽度/scroll均390，无横溢；12个真实指针章节行的ID/region/profile/context/start/end与最终native chapters逐项一致，实际播放时间在各章节内，解码视频/音频计数均为正，muted=false且已有真实激活。该证据证明12入口调用真实媒体并解码，不证明实体手机音频输出或主观听感。
- 原报告实际记录片段边界停止/循环、单声与视频互斥、4个独立点声试听、旧single.play Promise延迟不会暂停新候选、localStorage与选择JSON、可见性暂停、自然结束、真实fetch延迟取消均通过，errors=[]。选择文件为自动测试数据，不是用户环境音选择。
- 四个复制元数据包反例实际被拒绝，且没有意外交付目录：调换章节且保原SHA、调换章节再伪造SHA、未清理override生命周期、篡改native correlation。两原始report/chapters SHA与Git证据区保留capture原件完全一致，未改写媒体/trace。
- R4共享audio异步暂停竞态与R5章节错听风险在这些源码/反例范围已解决；原误实现与历史失败记录仍保留。点声是素材单听，不外推已在正式地图布点；录屏为真实场景播放，非新Godot Web包或完整互动Lab导出。

当前工坊本地工程范围可接受，线上发布与完整字节仍待主控远端核验。独立owner-private Site与旧动作工坊并存，不由静态页面链接证明新发布成功；实体设备、Safari/旧移动浏览器与用户审美继续UNVERIFIED。

## 线上发布身份与最终冻结结论

审查者只读核对`deployment.json`和主控的`remote-browser-03/report.json`，没有亲自执行浏览器/发布/听音。独立交叉核对记录`review/final-remote-receipt-check.json`。

- 独立owner-private Site：`https://clock-ambience-lab.zhipijun1996.chatgpt.site/`。原生发布状态succeeded，版本1，deployment `appgdep_6ae2352c0a8881919dbfbf723a2c68f2`，saved version `appgprj_6ae228bff25c8191a704958f043b1ee0~appgver_6bf2e109649c8191a1c328464e598799`。
- 网站源码仓库提交 `8d29d15465fab8cd3e2856d130373fb35a2dd8ad`与游戏/媒体producer `de6b36c62f0640d9322973fffb687472755d25b7`分列，没有把网站提交冒称Godot运行源。线上完整MP4响应200，14,049,972字节及SHA `69da1d4d924d79010be30468ba3f23a0831c469212f45cc38929a3b09de5fc8e`与实际capture原件完全一致，线上delivery producer一致。
- 远端390px Chromium两真实指针入口：平原A混音、森林B环境段，实际active/currentTime/playing状态正确，视频尺寸960×540；Stop后video与单声均暂停、active=null，errors=[]。这些是网页实际播放与身份收据，非实体手机/扬声器或用户听感。
- 远端03的脚本与report没有保存/断言音频解码计数；其scope写`actualAACdecode`不能单独提升为该次直接AAC计数观察。本审查对此采用更窄且充分的范围：远端同一完整MP4字节、实际媒体入口播放/Stop；AAC解码直接计数证据引用本地12行软件浏览器报告。不会以措辞把未记录事实补造为远端直接观察。
- 远端01用错误通用Authorization头导致等待超时、远端02 Node API直连IPv6不可达的失败保留；主控按文档OAI-Sites-Authorization及同源Chromium访问完成03，没有更改Site权限或追签旧失败为成功。它们不是已经证实的游戏或Site应用故障。

**最终限定结论：工程 ACCEPT／整体内容 review。** 实际获许可候选、有限运行、身份与反例、真实场景录音及代表像素、本地手机尺寸工坊与远端发布身份/播放已形成可审查交付。4个点声仅为单独候选，正式默认original不变；本轮不含完整地图声学布点、全互动Godot Web包替换或自动全游戏推广。未完整连续观看影片、未人耳试听；用户审美、疲劳、自然录音污染、BGM主观遮盖、实体手机/Safari/扬声器与商业品质保持UNVERIFIED。技术/发布通过不代签这些维度。

此审查由独立review代理冻结到本节；之后交付提交/PR状态及新增实证由主控另存实际收据，不改写本文件、旧媒体或旧失败。
