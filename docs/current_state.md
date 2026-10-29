# 当前状态

## 2026-10-29 MOBILE-WEB-AUDIO-FIX-03 · 修复候选已公开，合main等待完整CI

普通主页已是683cf2cce4d6（运行源fb5dc84b、官方threaded engine9c119194046e），Actions40931142506成功；公网10完整文件SHA及真实Home/Plains音频输出均通过，原UI/画质/工坊枪声保留，瞄准慢时额外cue关闭、机关使用清脆风铃原件。用户已授权合main。

6614e119完整CI的parallel因新验收卡格式/超范围PASS失败，已保原日志并修正记录；游戏源不变，未跳过165检查。冻结修正head后重新执行完整CI，通过再正常合PR117并从实际main导出。[证据](evidence/mobile_web_audio_fix_03/README.md)。


## 2026-10-29 MOBILE-WEB-AUDIO-FIX-03 · 线程供音正式修复，已授权合main

用户确认原独立线程测试页加载后声音正常，并要求修复后关闭空中瞄准/慢时附加声、机关清脆风铃，随后授权“完成后合入main”。生产fb5dc84b已导出683cf2cce4d6，正式threads=true，原UI/画质/工坊选择/五BGM不变；实际demo31/0和selected63/0已过。普通入口Web、缓存迁移、独审和精确head完整CI正在验证，通过后合PR117并导出实际main发布。[本轮证据](evidence/mobile_web_audio_fix_03/README.md)。


## 2026-10-29 MOBILE-WEB-AUDIO-02 · 新反馈明确属于普通主页

用户：“一开始进家园还不是很卡，慢慢越来越卡…后台声音正常，切到前台就卡…暂停也有点卡，没有关卡那么卡”，随后明确“普通试玩主页…画面和操作都不卡，只有声音卡”。本次当前公开1d主页仍threads=false，threaded独立入口同PCK；不能把普通版反馈记成线程版失败，也不能冒签其真机通过。手机具体缓存build未给出。

本轮仅只读静态复核和公开入口身份检查，未新增长时/后台/降频实测、未改生产、未重新部署。先请用户用现有audio-threaded链接连续运行数分钟并比较前后台、关卡暂停，获取记录；继续沿音频供给排队定位，不能先认定Shader、泄漏或热降频。见[原话与范围](evidence/mobile_web_audio_02/device-feedback-03.json)。


## 2026-10-29 MOBILE-WEB-AUDIO-02 · 工坊音色恢复，供音线程对照已公开

用户确认旧386仍卡且音色是旧版，旧两处Sample修复不能视为任务完成。已发现formal只装配环境选择，V3已选动作未启用；新SelectedSfxRuntime一次装配原14映射，原生63/0＋环境45/0，标准Web与公开真实Home/Plains实际PCM均确认已选pulse A。运行源b7406284，普通build1d3791a7c290／PCK208700940字节，四份官方nothreads引擎仍d209；不动已接受UI/美术/五BGM。

持续卡音的云端时序证据指向STREAM补给等待主线程：50ms Home请求等待P50/P95约473/769ms，混音0.3/1.7ms。同正式PCK/原画面/DPR2.5、真实RUN SEED输入mobile-audio-stream-01、同Manifest f3a63393...156a，单线程Home/Plains欠载88.24%/80.62%，官方threaded独立供音四个窗口均0且共享环实际read推进；主线程长RAF仍存在。不是手机FPS，也不证明shader/GPU/物理哪项是手机热点。Home普通菜单不暂停tree，关卡暂停另验。线程四窗之外仍有1408帧欠载，公网动作较宽窗口Home0.322%欠载保留；不能声称全会话无断供。

诊断工具源f21b221f，prepared84ddcb0，Actions40911443229成功。普通入口与已选音效保留；[独立线程50ms](https://zhipijun1996.github.io/gunman-rush/audio-threaded/?latency=50&audio_probe=1)和[主线程50ms](https://zhipijun1996.github.io/gunman-rush/audio-stream-test.html?latency=50&audio_probe=1&diag=timing-v1)为同包对照。公网完整PCK/threaded WASM与11HTML/JS/worklet SHA匹配，真实COI/SAB/threads三项及Home→Plains触屏动作成功；两段各8秒原BGM逐半秒匹配连续无跳/重启，已选pulse A胜旧pulse/B/C负控。首个本地安装竞争、首个公网redundant安装失败及官方blocking-on-main警告保留；后者失败当时原因未抓到，后续同字节通过，不追签旧失败。

f21b定向docs/web-cache/web-bundle三项fresh通过，非full CI。[证据与完整边界](evidence/mobile_web_audio_02/README.md)。任务in_progress/awaiting-device，PR117仍draft未合main；荣耀60Pro Chrome真机连续性、长时BGM/玩家认可未验。页面手动记录游戏/菜单10秒后下载JSON，下一步读取真机记录及反馈；若线程仍卡，按实际thread ring/PCM/主线程长任务继续定位，不降画质或改全Stream。恢复勿重导PCK/重跑既有native，先核公开身份与最新手机反馈。


## 2026-10-29 MOBILE-WEB-PERF-01 · 两处音频修复已部署，待真机

最新真机反馈为“声音卡，动作几乎不卡；暂停页面声音正常”。以main1b29932c/Godot4.7.2核验，公开UI包2caa/source4707与原main618的四份音频/正式场景源相同，JS/WASM是同一官方4.7.2导出模板，不混称同一个PCK。

最小Web真实PCM确认：默认add_bus()的-1路径会破坏Sample总线路由，单Master正常、多总线Sample静音但Stream正常；一段play每帧stream_paused=false会创建/启动/结束27个native Source，声音不断重启。正式demo.tscn原版/bus_only/pause_only/环境音真正停用四组已独立启动对照；bus_only的家园/平原跳跃射击均有真实混合波形匹配。首轮录音窗口错误、补录家园环境音关闭组未跳跃等边界完整保留，云端慢帧不代表手机画面卡顿。

生产只改GameAudio用bus_count增长保同序创建、GameAmbience仅实际状态变化写pause，原生160／0及源码独审限定通过。保留用户已认可UI/画质/素材/音量/五BGM/玩法。标准Web源ccc11e1a，build3866985a1e8b，PCK208691528字节／SHA3866985a1e8b5db39e3400b452b2b46339073e010659c9b367b71e385b3afd21；已导出及cache/bundle通过。标准Web真实触屏进入家园/关卡，四声实际混音确认并经独立负控复核；Actions40896322142已成功，公开两PCK与8份engine文件完整HTTP字节一致。

[根因证据](evidence/mobile_web_perf_01/README.md) · [范围](worklines/mobile_web_perf_01/scope.md)。分支fix/mobile-web-performance-20261029，不自动合main。[声音修复版](https://zhipijun1996.github.io/gunman-rush/?v=3866985a1e8b)与[前后对照](https://zhipijun1996.github.io/gunman-rush/audio-compare.html)已公开；两个独立目录的线上真实触屏GUI均已通过（设置/返回/家园/菜单/resize），page/script/shader错误0。定向docs/web-cache/web-bundle三项fresh通过（非full CI）；[PR117](https://github.com/zhipijun1996/gunman-rush/pull/117)保持draft未合main。手机BGM长时间连续性与最终听感awaiting-device，动作几乎流畅按最新用户反馈，不继续无依据删光照/降画质。

## 2026-10-29 MOBILE-UI-CLARITY-01 · 已部署，待真机

运行源 `4707b9ef15fa7e89b09d3e33ef8206c0b12f64af`，分支 `fix/mobile-ui-clarity-20261029`；[新试玩](https://zhipijun1996.github.io/gunman-rush/?v=2caa023125bd) 为 `2caa023125bd`（角标2caa0231），已通过既有prepared流程发布，公网完整208,691,576字节PCK及SHA256一致。[PR115](https://github.com/zhipijun1996/gunman-rush/pull/115)保持draft，没有合main。

手机与电脑统一1280×720逻辑UI/世界比例；Web使用完整1280×720内部RT与真实DPR backing store/nearest呈现，原生保留canvas_items。标题/HUD/模态框去掉逆CSS放大，家园提示避开摇杆且仅保留一个菜单入口。原shader/PNG不改，前景保护矩形改用RT局部stretch坐标，避免黑边偏移。

原生专项37／0、原UI合同149／0、Web密度8／0，最终源图鉴UI72／0、R2菜单输入208／0；这些检查执行后UI生产字节保持一致，后续导出守门要求原Foundry重建（36短语／18行程、0失败）并刷新验证basis，生成数据单独提交。实际桌面与模拟手机Web截图/指针通过，按钮逻辑边界最大差0.6wu；隔离GPU探针实测原生产mask函数与shader在黑边/DPR下透明位置正确。独审限定ACCEPT，最终定向Harness docs/web-cache/web-bundle三项全fresh通过，公网模拟手机实际设定/家园/菜单/resize通过。真实荣耀60Pro、帧率、金币音效、完整两区动态和玩家认可仍未验，质量awaiting-device。所有旧失败和验收边界见[本轮证据](evidence/mobile_ui_clarity_01/README.md)。

恢复先核当前公开build-info及完整PCK；不要重做已通过UI修复或擅自合main。后续先收用户真机UI/清晰度反馈，再继续单独定位家园/关卡卡顿及拾取音效。

## 2026-10-29 AUDIO-ROLLOUT-01 · 已授权快速合入并部署

用户明确“快速合入main，并部署试玩”，覆盖下方候选“不合main/正式默认original”阶段限制。root正补正式demo.tscn的最小装配：平原A/森林A与家园life，原声/五BGM/规则/既有DemoApp与HomeScene不改。实际生产源06a76d18：正式场景45／0、导出26／0与原PNG30／0严格通过，限定工程独审ACCEPT；已保留旧测试/CI失败，按[新范围](worklines/audio_rollout_01/scope.md)验证，原精确head完整CI门禁后普通合PR113，现有快速prepared Web路径交真实main试玩，不重复问已授权merge/publish。当前main45e98、先前头3e6bf692，旧公开Web尚无本次声，不可报新已上线。


## 2026-10-29 AUDIO-HOME-01 · 已选择底声＋生活音

用户在家园三模式交付后明确“底音+生活音”，选定当前home-quiet-01的life整体方案。config/audio_director/home/user-selected.json绑定manifest9da878...、床与8条生活素材SHA、原话与影片源a4b／UI745；brief自动读取并拒绝版本/文件漂移。保床额外−2dB、原BGM与每NPC12–22秒/全局6秒/最多1点声。区域A/A选择保持。

本轮只记录当前整体声音选择、上下文与质量证据，不重制音频/重录/部署，不修改正式默认或main。同步PR113；正式接入时直接消费已选两区A/A＋家园life，不重问已确定方案。单素材独立排名、全自然路线、实体设备与完成推广未推导。下方“家园待选择”是此前交付状态，现由本条覆盖。


## 2026-10-29 AUDIO-HOME-01 · 家园微风与生活声试听已发布

[家园手机试听](https://clock-ambience-lab.zhipijun1996.chatgpt.site/home/)已由原Site v3部署（仍仅拥有者）；只加/home/，原root/previous-v1共54文件及hosting配置逐字节保持。托管源`1bfc4d6bb36807d78108a084d6803c3f798f9f7c`，原生影片producer`a4b2113aa786193a1d653080365f6067dd020880`，严格HTML身份/后包装源`745097b8c390502257a55c727444104c4f64cecf`分别记录。

借用已选quiet-02 plains_a原字节再−2dB，新布料/木件/工具/册页各两条CC0生活拟音，4真实keeper脚底定位；12–22秒/全局6秒/至多1点声，静态NPC无假动作同步。原BGM与规则/正式HomeScene/DemoApp/共享音频/区域选择不改，显式开发候选，家园混音仍待用户试听。

真实3×26秒/4969帧/7,900,638B（SHA d56076d...）原生轨音、3838源闭包与同路状态通过；家园60/0、原regional55/0、加工8项根/作者/独审均过。正常短片只听到1次近处cloth1，8条素材可单听。修后手机3章/9单听/11身份篡改反例通过；远端/home MP4全SHA、真实life指针/AAC45827字节/Stop及旧root元数据均实测。

[实际证据与失败](evidence/audio_home_01/README.md)。原processor/两个runtime/typedArray scene/64像素headless/UID登记及HTML身份缺项全部保留，不改预算或伪签；新源技术/审查与用户、实体设备、完整CI/正式推广分开。继续PR113，不合main；下一步消费home-quiet-01真实选择JSON/听感，再按明确范围接入，不重做已选两区A/A。

## 2026-10-29 AUDIO-AMBIENCE-01 · 两区quiet-02均已选A

用户在轻微环境版交付后明确“两者都选A”：平原`plains_a`、森林`forest_a`，保当前−14dB床声／原BGM混音。精确记录`config/audio_director/ambience/user-selected.json`绑定quiet-02、manifest与两OGG SHA、原话和原生producer e55910ec；brief自动读取并拒绝指纹漂移。原B方案与较响首版不删，不推导四点声或真机认可。

本次仅记录明确选择与后续上下文；运行默认original和main未改，无新录屏/重导出。沿PR113同步；下一步正式集成时使用此精确A/A选择，保原音乐和生命周期规则，不重问已确定的两区方案。下方“待选择”属于当时历史交接，现由本条覆盖。


## 2026-10-29 AUDIO-AMBIENCE-01 · quiet-02轻微环境音已发布

用户明确首版环境音过响盖住BGM；同PR113／`feature/audio-ambience-01`已迭代为quiet-02：保原归一/控峰后四床−14dB、四点−10dB，实际解码降幅已核。五MP3、MusicGain 0.16与玩法/动作保持。原生/影片源`e55910ec7d5be218735fb7cade4ebdd4f662552a`，6×26秒／9943帧、14,065,613B，714.952秒内完成原900秒预算，source/loop/轨迹/音轨均通过；不是后期配音。

[原手机工坊](https://clock-ambience-lab.zhipijun1996.chatgpt.site/)已更新Sites v2（仍仅拥有者）；托管源`060788289a4d04dd96b51904317beaa04c174320`。默认BGM混音，旧版27件原样保留[previous-v1/](https://clock-ambience-lab.zhipijun1996.chatgpt.site/previous-v1/)。新选择KEY与mix_revision隔离旧选择/旧包。真实本地12章节/4点声和4身份反例通过；远端全MP4 SHA、两指针/AAC解码/Stop通过。

[新增证据与失败](evidence/audio_ambience_01/quiet-02/README.md)：加工9／适配17／旧quality57／原生55通过。新混音限定独立工程审查ACCEPT；原首轮工程审查与失败不改签，旧听感被拒绝；quiet-02用户听感、实体设备、完整CI和正式推广仍未验，默认original、不自动合main。下一步直接消费新试听反馈/选择JSON，不重做素材，不将工程检查当审美批准。

## 2026-10-28 AUDIO-AMBIENCE-01 · 两区环境音候选已交付

从main `45e98dbb` 独立创建 `feature/audio-ambience-01`。4个24秒CC0实录床声＋4个细节声、可追溯加工/许可、显式GameAudio环境组件和两区同Seed原音轨对照已实作。运行/影片源 `de6b36c6`，9943帧，原生音画14,049,972B；[本轮证据](evidence/audio_ambience_01/README.md)、[音效入口](audio_director/ambience.md)。

[手机环境音工坊](https://clock-ambience-lab.zhipijun1996.chatgpt.site/)由Sites v1成功发布（仅拥有者账号）；12章节、单声/循环、BGM混音、4点声与选择JSON，原动作工坊和主站保留。托管源 `8d29d154` 与原生producer分记。无新可操作完整Web包，不把主站称本候选。正式默认仍original，点声未全图布设；用户听感/实体设备/完整CI不代签。技术记录review，不自动合main。

恢复：`python3 tools/audio_director.py brief '优化森林环境音'`；来源与精确配方见manifest。四床source/loop/原音轨/同区物理时序已实际验证；独立工程审查通过，原导入/遮挡/未完成片/诊断超时全部保留。后续先消费用户环境音选择，再做组合混音或明确授权的正式推广。

## 2026-10-28 PR111合入与试玩发布授权（最新）

用户已明确“合并到main，并且导出试玩网站”，覆盖此前PR111不自动合main的开发阶段限制。先修精确91545e4完整CI的两处旧消费者测试（旧shared chest icon、旧forest_heart_gold）；原run40684591543实际90项／2失败／75未执行，不能称全量跑完。保原165与两lane/affected门禁、预算和失败原件，精确新head全绿后正常merge，再导出实际main并核公开metadata／完整PCK及真实GUI。不要再次询问已授权的合并或发布，不跳过红灯，不重生成美术。详见[本轮范围](worklines/main_merge_web_111/scope.md)。

## 2026-10-28 三档宝箱已进入正式两区（当前）

蓝平盖、紫拱盖、金紧凑钟箱的闭／开六态已接平原和森林。原PNG与两区脚底、奖励／金币／claimed账本及RNG不变；成功提交才开盖，取消或拒绝不提前开盖。修复连续领奖后首个W被吞：只复用原输入恢复函数，不削弱按住保护。

实际生产源为`0f7a5d1c401556b38f89d403ce781eda9798f0e6`：原生210／0、平原连续26.066667秒105／0、森林10.1秒41／0。两区1280与960六态对照32／0及26／0；后续仅gallery producer修订、生产字节不变，所有原来源与失败保留。实际Web Playtest PCK隔离15／0。独审已看24张真实PNG及逐帧收据，限定V8技术／视觉接受；旧几何规格失败、实体设备／完整G5和森林小屏旧教程HUD重叠未代签。

冻结测试源／媒体提交`6d02fe70`的10项相关Harness已全部fresh通过（0复用／0失败，非full165／最新远端CI）。Core5686、region原15套、R387＋宝箱210、pure161及Home/V5formal均通过；两份过期单报价fixture已按正式V5三槽迁移，原失败与预算保留。公开两影片与两小屏截图均实际HTTP200、完整SHA一致。后续仅文档／收据收口，PR111保持OPEN，不自动合main。详见[宝箱证据](evidence/chest_art_01/README.md)。

## 2026-10-28 宝箱source04已按用户v8采用接入两区（当前）

用户明确“宝箱接入游戏，继续工作”，已采用source04现图及此前披露的细微尺寸／姿态差异。三档蓝／紫／金的闭／开六态现已注册production资产并接入正式平原与森林消费者；[v8合同](worklines/chest_art_01/spec.md)固定原PNG、完整ROI、每tier共同factor／脚底，交易／Manifest／RNG、平原＋21与森林＋18支撑及1wu采样不变。此为用户采用后的新合同，旧≤1wu配对与金箱44／58规格失败仍保留，不能追签旧PASS；4／4生成用尽，无新图。

原生专项 `build/chest_art_01/native-02.log` 实跑192项／0失败，未见脚本或原生ERROR；未知tier负例的预期warning保留。首次native01的真实场景未就绪／Nil访问失败原件不删，不以其147／0 marker称通过。当前production两区capture／正式开箱媒体仍待root执行与核验；不把原隔离GL或旧影片当新主游戏证据，实体设备与完整G5仍未验。[宝箱证据与边界](evidence/chest_art_01/README.md)。

当前分支feature/item-v5-catalog／PR111，不自动合main。最终commit、当前源正式两区截图／媒体与公开入口由root收口后补实际收据；恢复先核git状态与单Godot租约，不重复生成美术。

> 下方原文为本条之前的阶段交接，保留来源；其中“宝箱待取舍／仅离线／未注册”已被上述实际用户采用与两区实现覆盖，其历史失败仍有效。其余工作线按各自证据判断。


## 2026-10-28 家园图鉴候选与宝箱美术取舍（当前）

HOME-CODEX-01已接原relics建筑：共享ItemCatalogV5目录，存档独立记录发现／音符永久解锁／出发单选。配置管理价格、家园准入与先发现开关；每局一个Lv1实例先入背包，仍需装备。保存失败、旧报价、切档、失焦和关闭输入守门已实现；下架／移除条目始终可取消选择。冻结运行源8b83e22b的16项相关Harness全部fresh通过（0复用／0失败，非full165），Core5686、Meta92／UI72／App91；实际PCK隔离79、家园GPU198、商店11及27.133333秒／59断言连续影片均通过且clean。公开下载与PR状态以[交付证据](evidence/home_codex_01/README.md)实际收据为准，不追签开发旧失败影片。

style17／creative20 R2为73真实引用，公开16／19原件不改，旧68仅两个旧Home入口变更；原250输入前缀追加至267。原32＋10及四项绑定fresh通过；实体安卓／手柄、平衡、用户认可未验。

CHEST-ART-01已按用户拒绝长扁金箱重画紧凑蓝／紫／金六态，但仍超冻结几何要求，4／4生成预算耗尽。原图／独审／失败与75项clean单相位GL诊断均[离线归档](evidence/chest_art_01/README.md)，不注册为live、不替换默认主游戏箱体；用户对当前差异的取舍待答。正式接入方案只作离线准备，不伪称完成。PR111保持独立分支，不自动合main。

[图鉴范围](worklines/home_codex_01/scope.md) · [权威规则](rewards_and_builds.md) · [开发证据](evidence/home_codex_01/development/index.json)。恢复先核git状态、最终源/媒体收据和单Godot租约，避免重复生产美术。


## 2026-10-28 PR111与公开录屏已交付（最新）

PR111已推送并保持OPEN，不自动合main。运行源56e639d712cab0604807992cce0e6eaeaf56ac08；三段媒体固定在提交00264dbb9120916eb2a979abdf2de43320ea335b，后续仅文档证据。54秒主片及两区各12秒公网均实际HTTP200，完整SHA与本地一致，见[公开核验](evidence/item_art_01/public-download-check/receipt.json)。33项受影响Harness fresh、222主片、19／18两区和导出包隔离加载均通过；完整远端CI已启动，精确head结果以[PR111](https://github.com/zhipijun1996/gunman-rush/pull/111)实际Actions为准，未签full164通过。工作树最后只归档下载证明及交接，不重跑原生或生成美术。

恢复先核PR最新head／checks。若CI具体失败，只修真实失败并保旧报告；通过后等待用户／实体设备／平衡反馈，不自动合并。源码、已实现和未验边界见下方本次候选及[证据索引](evidence/item_art_01/README.md)，不得把旧网页当新候选。


## 2026-10-28 道具V5／独立美术候选交付（最新）

分支feature/item-v5-catalog／PR111，运行源56e639d712cab0604807992cce0e6eaeaf56ac08，已同步最新main11e359的音频工作线。72有效道具、16同实例成长与9启用联动沿既有正式宝箱／Boss／商店／暂停背包接入；03H参数按用户确认。新增配置覆写／下架／已支持静态效果的数据新增与原子CLI，常规维护不改装备核心。

72独立图标、32单帧语义资源与三套八帧家族采用现有细像素／旧黄铜／冷钢／克制青光。10原PNG不改像素、1wu世界采样、64MiB预算不提高；原全局shader／音符／物理与主线音频选择不改。R13只技术重绑实际WeaponFeel单叶，其他67引用保留；原32＋10和四绑定检查通过，有限历史输入原239前缀保留至250。新增finite资产适配原51测试完整保留，追加6例纯stdlib通过，不把离线manifest冒充运行资源。

同运行源最终33项受影响Harness全部fresh通过（0复用／0失败，非full164／远端CI），core5686、ART1185、catalog1553、authoring451、森林74、gearUI158。主游戏真实连续54.066667秒／222断言；平原／森林各12秒／19与18断言，三段source_stable且clean。主片完整入包／装备生效／卸装撤销／B11生命上限5→6→5／8→10扩容扣35；已知奖励、靶场、站位、共鸣与扩容金币fixture各自可见明示，不称自然全流程。来源、失败与原件见[当前证据](evidence/item_art_01/README.md)。

正在更新同一PR111与公网下载核验，不自动合main。质量保持review；实体安卓／手柄、低端性能、听感、平衡、用户审美与G5未签；21删除道具不投放，3待重设计／4删除依赖联动禁用。P17基线解释与G19 Boss计精英候选仍保留原设计边界。最新阶段优先于下方历史待验描述，恢复先核git状态、实际PR头与证据，不重复美术生成。


## 2026-10-28 同步最新main音频工作线

本分支保留本次道具／美术实现，同步main `11e35968323bbc3d3e95a0b0c0c4fc9378e702cd`（PR109音频）。两份交接文档冲突保留双方原文；武器音效传入真实武器ID、敌人受击语义音效及导出资源条目均保留主线更新。正式音效默认与用户选择记录遵循音频工作线，不由道具美术更改。R13已对实际weapon_feel单叶重新绑定，另67引用不变；原32＋10和四项Harness fresh通过，历史缺件失败保留，有限输入原239前缀追加至250。新影片与最终33项受影响Harness仍待合入后干净源集中执行。PR111不自动合main。


## 2026-10-28 道具美术与配置候选收口（最新）

72独立图标、32单帧语义资源及P24／P14／G16三套八帧家族已接入实际目录、暂停背包与世界表现。沿现有细像素、旧黄铜／冷钢／克制青光，世界1wu采样；原全局shader不变。10张源PNG保持原字节，RGBA上界62,908,904字节，原64MiB预算不提高。

当前原生ART1185／0，实际全72菜单534／0，世界shader独立GL11／0，最新完整节点／非零alpha边界83／0。修复施放回调换装后的旧视觉来源与重复通用效果；不改HP、能量和技能结果。G05／P20／陷阱边界已用原brief与全alpha实测修正；旧“下排消失”观察经原PNG和字节相同重播反证，独审已撤回，未改生产代码掩盖假设。所有失败保留。

style16／creative19 R11绑定68实际引用，本轮只更新View／Defense两叶，另66不变；原32＋10与四项纯检查尚待最终冻结执行，不能沿用R10通过。原72基表400与实际配置目录1553、维护479分源保留。最终集中Harness、当前源正式连续影片、PR111推送与公网下载核验仍待执行；旧7afe影片不签新shader。不自动合main。实体安卓／手柄、低端性能、听感、平衡与用户G5仍未验。

[当前证据](evidence/item_art_01/README.md)。恢复先核git状态与实际PR头；native／GL单租约由root协调。


## 2026-10-28 ITEM-AUTHOR-01／ITEM-ART-01（当前）

用户继续要求实现表格道具、方便调参与增删，并强调新图标／特效必须与整体美术风格一致。当前本地候选已接入72独立图标、32单帧语义美术资源与P24／P14／G16三套8帧动画家族；10张原始PNG未改像素，实际注册纹理RGBA上界62,908,904字节，保留64MiB上限。UI资源由数据映射，世界沿现有1wu顶点／光照语义，新道具专用采样只补浮点稳定及真实REGION_RECT边界钳制，原全局shader不改。

实际专项：原nativeART924／0；新世界采样GL11／0；完整G19节点／原回退对照GL35／0；真实暂停菜单534／0，两尺寸均完整显示72图标，包含G01／P16修正ROI的52／90px详情。G19真实光学中心偏差0.167wu，正式variant不再重复画旧进化圆点。所有源图留白／原生64请求失败及原生、切片、UV、高比例串图和采证失败链均保留；这些是局部技术证据，不签用户、实体设备、听感或完整玩法平衡。

style16／creative19的R09已绑定68个实际引用，旧61只更新6项、追加6PNG及专用shader；原32＋10及四项绑定检查通过，原202输入保留追加至213。历史15／18、预美术16及R08原件不回写。配置维护的冻结72基表与实际覆写／新增已分离；原维护479／目录1553为先前阶段，最终受影响Harness尚待当前源码集中运行。

当前仍在收口：独审要求明确解决G05／P20／陷阱完整alpha边界与候选brief差异，并补不可用护卫的实际画面（旧探针状态切换后隐藏了下排对象，不能拿数值当画面）。随后冻结源码、补本次材质的正式连续录屏、受影响Harness、权威设计／质量记录、同一PR111推送与公开媒体核验。旧7afe193断言49秒影片只证明前一美术源；不签最新材质。当前分支feature/item-v5-catalog，main879b39e未变，远端PR111仍d9445c0e；本地修改尚未交付，不自动合main。

[维护说明](item_authoring.md) · [美术范围](worklines/item_art_01/spec.md) · [证据](evidence/item_art_01/)。恢复先读build/item_art_01/checkpoint.json和git状态，native／GL单租约由root协调。


## 2026-10-27 ITEM-V5-01：正式道具候选

分支`feature/item-v5-catalog`，基线main879b39e，冻结运行源`979dbb9ab5f04c82f9c605c775a5e92ee14f7141`。72 件有效道具、16 件同实例成长与9组有效联动已接入正式宝箱／Boss／商店、暂停背包与六个效果家族；21件删除道具不投放。03表H当前建议参数已由用户确认；原表与冲突完整保留。 原件与十表快照见[来源](evidence/item_v5_01/source/)，唯一规则见[权威文档](rewards_and_builds.md)。

冻结运行源的选定 30 项原 Harness 全部 fresh 通过（0 复用、0 失败）；这是受影响专项，不是 full161 或远端 CI 全通过。 最终正式Manifest专项覆盖等级／破损／容量与严格伪造拒绝；森林四图、实际V5金色奖励、35金币扩容及跨区持有／装备保留均有原检查。K2整合曾26通过／1失败／2未运行的REJECT及其地图记录遗漏保留，不能回写为通过。

同运行源连续主游戏影片 93 断言／0 失败，实际退出0且源码稳定；准确时长与媒体参数见捕获收据。 [实际证据与录屏](evidence/item_v5_01/README.md)区分本轮源、K2历史影片和FBC触控代理；位置、已知奖励与训练靶fixture均明示，不是自然全路线或72件逐件实战验收。独立Preview原容量仅余约1.36MB，未删除旧入口或把旧网页冒充新V5；公网下载可用性以实际发布核对为准。

style-v15／creative-v18仅技术绑定实际消费者、保留原Bible和旧版本；无新terrain或图生。P17保留未装备的原全速蓄力基线，装备后按表40%／55%／70%运行，基础规则冲突仍待用户选择；G19的Boss计精英为可调候选，未冒称用户确认。S05／S08／S14待重设计，S03／S04／S11／S16因删除道具禁用。实体安卓／手柄、低端性能、平衡、听感、趣味与玩家G5未验。 质量review，不自动合main；PR与完整CI见实际交付链接，不由本地专项代签。


## 2026-10-28 用户选声组合

AUDIO-DIRECTOR-04继续PR109并同步最新main879b39ea。用户回传13项选择：金币/回血/宝箱/脉冲枪A，道具/UI三项/主角伤C，命中/敌伤B，手里剑/炸弹原版；爆炸项仅复合推导。原件与归一映射已入库，brief会读取。78.4秒真实Godot原音轨，10组原/所选20章；108新原生/126旧原生与20章网页验证通过，来源及原failed后验修正见[本轮证据](evidence/audio_director_04/README.md)。网页实际发布状态见该页收据，不以旧V3冒充。正式默认仍original，整体混音/自然战斗/真机未批准，不合main。

## 2026-10-26 音效第三轮：功能音色与对比录屏

AUDIO-DIRECTOR-03继续PR109：按用户最新反馈重选42个CC0候选，覆盖清脆金币、液体回血、宝箱、长道具获得、打击/受伤、3武器及UI；已交10支真实有声短片/12章节/48可选段，约157秒；[直接点播](https://clock-audio-director-lab.silkyball18.chatgpt.site/reels-v3/)，不必先下载完整游戏。原jump/land与五BGM保持。V2未取得本轮采用认可，旧素材/反馈保留；Sites版本5已发布新录屏入口；旧V2保留。[V3精确状态](evidence/audio_director_03/README.md)、[声音功能规范](audio_director/style_bible_v3.md)。

## 2026-10-26 音效第二轮：3套现成CC0与真实情境

AUDIO-DIRECTOR-02从用户拒绝v1 A/B的反馈继续：只重选UI、拾取、命中/受伤，3套×9事件×2实际take共54 WAV，原起跳/落地、未要求动作及五首原BGM保留。工坊加入正式Home/ShopService/拾取Area/真实弹体伤害的开发情境，原版与A/B/C同场切换；这是试听样板，不冒充自然完整流程。[新版手机工坊](https://clock-audio-director-lab.silkyball18.chatgpt.site/?v=2&build=1048defde2ef)、[第二轮入口与状态](audio_director/listening_v2.md)、[精确验证与最终部署](evidence/audio_director_02/README.md)。听感与实体手机待用户；PR109独立工作线不默认合main。下方第一阶段是原历史交付，不能用旧v1包替代本轮场景。

## 2026-10-26 独立音效导演第一阶段

AUDIO-DIRECTOR-01保持review，基线main26e7f2a，分支feature/audio-director-01；16事件A/B各2变体共64个CC0素材加工候选、来源/许可库、可重现pipeline、固定基线审计和真实Godot/手机Sound Lab已实现。正式默认original，保五首用户MP3原字节；工程验证不签用户听感或商业品质。[交付入口](audio_director/README.md)、[最终版本与证据](evidence/audio_director_01/README.md)、[交接](handoff.md)。不合main，旧主站和预览入口保留。

## 2026-10-26 PR110：最后的测试／输入契约修订

用户明确合入main，授权持续有效。原CI40324535594在head05200fc的serial55全部成功、parallel73通过后因style精确期望13／实际14失败，剩余15未执行；完整CI仍失败。随后本地逐项补跑尾部，识别持有统计接口迁移的旧源码指纹断言，余14项全通过。

最终实现／测试源`56f74fb0918d1cfbd1487a9734403975caf2e85f`仅修测试与已有Harness输入声明，游戏／资源／录片工具保持原运行源：style14断言与v13拒绝、11个冻结style文件显式输入、ecology1处／lift3处持有统计的精确归一化并保原SHA。原32＋10＋55共97测试fresh通过，不同作者再独立97／0及7个源守门反例拒绝；真实隔离稀疏缺v12被原CLI在worker前阻断。见[完整失败和分源证据](evidence/run_gear_merge_05/README.md)。

下一步只核[PR110](https://github.com/zhipijun1996/gunman-rush/pull/110)最新head完整CI：全部成功后正常merge；若已经merged，核main树及自动Godot构建，不重复合并。当前记录为合入前快照，最终实际状态以PR及main为准；技术合入不签玩家／实体设备G5，网页发布单独核实际构建。

## 2026-10-26 PR110：用户已授权合入main

用户本轮明确“合入到main”。[PR110](https://github.com/zhipijun1996/gunman-rush/pull/110)在完整CI通过后正常merge；旧“不合main”段落是此前开发阶段快照。若已merged，直接核main合并提交与自动Godot构建，不重复合并或把构建排队称网页发布。

原CI40316936625在parallel已通过66项后，因`tests/test_region_creative_direction.py`期望creative-v16而正式记录为v17失败；serial55项全部通过，parallel66通过／1失败／22未执行；整轮仍失败，不能记完整通过。唯一代码修复`fae1799c869feb891f01afd5a912ab1b0fde3594`只更新精确测试版本期望，游戏／录片／资源字节不变。原10测试重现1失败，修复后原Harness及不同作者独立10／0，历史v16及v2拒绝、G2/content/未正式开放断言保留；详见[合入守门记录](evidence/run_gear_merge_04/README.md)。原失败未追签，最终同head完整CI及main实际状态以PR为准。用户／实体设备与复杂效果边界保持。

## 2026-10-26 RUN-GEAR-UI-02：暂停直达背包与参考图分页

用户要求暂停直接背包、左右切页、图标网格与右侧详情，补充负荷槽必须是齿轮形状。已更新同一[PR110](https://github.com/zhipijun1996/gunman-rush/pull/110)，运行源`bb4bf464a639af6c20828b84a5ac1df3785f393b`，分支`feature/run-gear-inventory`，不合main。新入口与布局覆盖下方RUN-GEAR-01旧暂停构筑入口，所有权／装备／交易合同保持。

实际软件GL独立原wrapper159检查／0失败，1280与960、8／10／14齿轮、点击选择详情、装卸／替换、左右键／肩键／触屏分页、滚动和失效请求已验证。原生主游戏标题→可操作Home行走→正式出发→平原暂停及新UI已试录34断言／0失败；靠近宝箱的一次位置fixture始终明示，不冒充自然挑战通关。最终同源收据见[本轮证据](evidence/run_gear_ui_02/README.md)。

前轮CI两个失败分别是canopy旧自动生效假设和plains动态调用的未类型化Array；已迁移测试并保原实际效果／严格退出守门，原失败保留。原Harness10项fresh全部通过，最终正式主游戏片27.47秒／34断言／0失败、源码稳定；UI contract149与R2入口修复后208通过。独立Preview站仅余1,358,399字节，无法加入当前完整游戏包；保留旧入口，不把旧站签成本轮。用户／实体安卓／实体手柄仍未验，任务保持review。

恢复：`git switch feature/run-gear-inventory`，按本轮证据执行原选定Harness／正式影片采集。下一步只处理真实门禁／反馈并更新同PR；不要重新生产美术、删旧Preview或自动合并。

## 2026-10-26 RUN-GEAR-01：局内背包与齿轮装备候选

实现分支`feature/run-gear-inventory`，基线main`26e7f2a`，冻结运行源`91ea8850f308cc3c955bcece2c35cd66f75e7bda`。后续只追加证据／文档，PR面向main且不自动合并。[交付与可下载完整操作录屏](evidence/run_gear_01/README.md) · [独审](evidence/run_gear_01/independent-review.md) · [权威规则](rewards_and_builds.md)。

当前道具先入无齿轮上限背包，暂停构筑装卸／原子替换后才生效；8→10→12→14容量与价格唯一来自config/gear_capacity.json。保持武器、核心能力和永久音符独立；保留收据幂等、死亡优先、跨图／地区／存活环境回退，真结束清理。新增常规道具走Definition／效果组件，复杂主动／武器／钩索技能本轮未开发。

同源独立15项原Harness fresh全部通过，core5685、gear107、正式UI64、campaign67、森林App92、地区当前15组及40图回放等零失败；另实际GL67／原触控44通过。最终原生操作片20.47秒、20断言／0失败、源码稳定且退出clean：固定开发关卡自然射击／行走／领取→入包→装备／生效→卸下／撤销→扩容；正式区域消费者另有实际App验证，不能冒称正式自然全路线。

所有真实失败和F1–F14修复链保留。当前技术ACCEPT／质量review，未做实体安卓／实体手柄、数百道具低端性能及玩家G5；扩容价格为试验值。27条旧独立路线及legacy-compat未跑，不记通过。当前style-v14／creative-v17仅重绑DemoApp，另35引用、原Bible和旧档字节保留，不继承美术／设备认可。

恢复命令：`git switch feature/run-gear-inventory`；相关检查见证据的原Harness命令与收据；`python3 tools/check_quality_diff.py --base 26e7f2a4459623f35613a857da8a75e89daa3e62`。完整PR CI以实际Actions为准；下一步只处理具体审查／用户设备反馈，不重启旧PR108合入或无关美术生产，不自动合main。


当前仅校验器收尾：f2CI实际Home184/0被旧181／四服务外层拒绝；现精确184/194／五runtime服务、39校验器测试、真实headless/GL及剩余22原serial全部通过，原门禁/预算保留。[准确分源收据](evidence/playtest_feedback_20261024/home-wrapper-contract/README.md)。f657只改三Python验证/录像工具，游戏仍b761/5ce，无需重导Web；最终head、CI和main状态继续核PR108，旧失败不改签。

## PR108 合入入口（当前）

[当前真实试玩](https://zhipijun1996.github.io/gunman-rush/?build=5cebbdc37404)，源码b7610b8a，build5cebbdc37404，Pages40061834215成功，完整公网184493060B PCK已核。修复五项反馈及集成发现的实际遮挡／小屏MENU冲突；左状态固定，其余导航／Toast保留保护，原UI139触屏断言未放宽。最终原Harness8/10/15 fresh126.817s与独立UI270/139/HUD61/GL通过，当前style13/creative16。

用户已授权合main。下一动作先核[PR108](https://github.com/zhipijun1996/gunman-rush/pull/108)实际状态与最终head：若未合且affected完整通过，执行普通合并；若已merged，核main树／运行源与自动Release，不重复合并或重启已通过检查。此页为预合入证据快照，最终CI及合并SHA以PR实际收据为准；准备产物分支不并源码。实际来源、失败保留和新公网GUI见[精选证据](evidence/playtest_feedback_20261024/hud-integration/README.md)。

仅Web像素密度与软件GPU观测已验，正常world保护扫描恢复；首次下载仍186MB，完整自然战斗／听感、用户和实体设备未签。原main旧Foundry音频Release失败保持其旧身份。

小屏集成修订：保留本帧响应式地图／暂停位置作为避障候选，避免桌面缓存fallback覆盖真实触屏MENU。原960×540失败与4fc独审REVISE保留；两行修复后原UIcontract139/0，最终同源专项／独审和新Web以实际结果为准。

PR108当前集成纠正：固定左侧状态，恢复地图／暂停／钱包／位置／Toast保护，真实绘制leaf代替透明VBox包围盒；原平原场景8/10/15全部通过，HUD61/0。先前1b25 CI实际遮挡失败保留，不靠删断言放行；正常world扫描恢复，旧e525无扫描CPU结论不继承。style-v13/creative-v16仅DemoApp再重绑，35项与原Bible/旧版本保留。用户已授权合main，当前新独审、最终Integration及Web实际身份见[跟进证据](evidence/playtest_feedback_20261024/hud-integration/README.md)。

## 2026-10-24 五项试玩反馈候选已交付

[最新候选试玩](https://zhipijun1996.github.io/gunman-rush/?build=2ed80c618b79)：实际producer `e5254559b38f9593f03fa2fd7847b107d5d04402`、build `2ed80c618b79`，公网完整PCK及真实Home/固定Seed平原/工坊三武器已验证；main源码仍cd4989，候选不冒充main完整Release。

Web-only HighDPI按CSS像素渲染且nearest合成；正常HUD固定边缘；14普通物种/22渲染链与8Boss普通受击共用模板、死亡和弱点等保各自；原arms工坊提供3个真实Lv1会话选择、实际出发/返回携带；标题Start进入可操作Home。源码与证据见[本轮交付](evidence/playtest_feedback_20261024/README.md)。

独立冻结e525原native270/139/56/597全部clean，scope限定ACCEPT；作者原all-weapons2381/0等前阶段证据保原身份。公网DPR2同CSS/Seed/Manifest观测7.78→23.68FPS，物理buffer有意2560×1440→1280×720，SwiftShader不签玩家设备。首次加载仍约186MB，完整CI/设备/玩家G5仍未验。

当前style-v11/creative-v14只技术重绑DemoApp/HomeScene，另34引用/原画风/Bible/旧v10v13原字节保留。下面旧四线记录仅保原来源；main/CI以真实PR状态为准，不重新执行已完成的旧集成。

## 四线集成与当前验证（2026-10-23）

人物b106976、怪物080ac505、UI ea2d6fd及美术02031d7已接入集成分支；黄金切片68bd037暂停，不在本轮合入范围。
正式默认新版Courier；家园“织时匠”保留服务id和位置，可在当前会话切换新／经典外观，刷新后默认新版。
家园、平原／Boss、森林／Boss已接入用户提供的五首原MP3；功能接入不等于听感、手感、审美或设备认可。

当前共享画风为style-v10，区域方向为creative-v13；原Bible、像素规范和历史版本保持原件。
当前性能修复源码为`421eacc19a838723aabe898af4565435958735b6`，第二阶段仅改UnderworldForeground；它不在36项style引用中，无需再改画风版本。
保留真实每帧渲染、保护与准入；诊断惰性生成的等价性按实际helper／shader／原GPU结果记录，不推断其他生命周期或玩法通过。

原森林80项结果：精确421eacc1原Harness fresh通过，80/80、source_stable=true；Harness总461.667秒，原检查451.045/600秒，实际CPU亲和[0,1]。
后续原35项结果：精确421eacc1的原35项fresh全部通过，Harness总644.359秒，jobs=1；使用本机原允许CPU集合，不能与双核80混为同一性能条件。
最终源码／CI身份与状态：运行源421eacc1；本次收口仅追加证据和文档，精确head、CI、main及发布状态以PR106／Actions为准。

a2f7远端run40011980788真实失败：106项通过，森林原600秒预算耗尽时68/80，35项未执行；parallel89仅证明该通道。
本地单例耗时和旧精确80收据保持各自源码，不签当前完整CI、GitHub耗时或品质认可；原断言、场景和预算不变。
最终Integration、main Release与新公开版本以[PR106](https://github.com/zhipijun1996/gunman-rush/pull/106)及其Actions实际收据为准；本地通过不代表已合main或已发布。

## 当前公开试玩

[四线开发Preview](https://zhipijun1996.github.io/gunman-rush-previews/previews/FOUR-LINE-INTEGRATION-01/a074a709ffa64c1382d73d2dab6dcff673222728/d38c8a407473/)
producer为`a074a709ffa64c1382d73d2dab6dcff673222728`，build为`d38c8a407473`，包含原工具生成并逐项核实的56项Foundry输出。
它不含本轮CPU修复，也不是main正式发布；[准确构建、公开验证与恢复证据](evidence/four_line_integration_20261023/final-synchronization/preview-a074-delivered.md)保留原身份。
主站本轮未复核；开发Preview不证明主站当前源码／内容。

## 范围与后续入口

当前任务为[FOUR-LINE-INTEGRATION-01质量记录](quality/records/FOUR-LINE-INTEGRATION-01.json)；作者卡的review／未验结论继续有效。
用户已授权普通合入PR106；先核PR/head状态，原142 CI完整通过才普通合main；若已合入则核原Release，不重复合并或重启已有检查。
审美、趣味、真人时长、完整浏览器旅程、五曲听感与实体设备仍按原证据边界，不能由AI代签G5。
用户已明确暂不考虑旧存档／旧特性兼容；当前保存、物理、能力、随机Manifest与资源引用守门保留，手动历史未跑不记通过。

[集成范围与来源](integration/four_lines_20261023.md) · [原始／失败／独审证据](evidence/four_line_integration_20261023/README.md) · [前景CPU证据](evidence/four_line_integration_20261023/foreground-cpu/README.md)
[生产入口](cloud_production.md) · [Harness](harness.md) · [任务](tasks.md) · [下一步交接](handoff.md)

历史正文完整原字节见[本页旧快照](archive/integration_closeout_20261023/current_state.before-second-cpu.source)及[旧交接快照](archive/integration_closeout_20261023/handoff.before-second-cpu.source)。
这些快照与各原证据保留旧源码／SHA及失败；旧“最新”、排期和下一命令不作为当前指令。
