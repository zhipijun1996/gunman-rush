# AUDIO-DIRECTOR-03 · 功能声音与真实录屏交付

[打开手机录屏试听](https://clock-audio-director-lab.silkyball18.chatgpt.site/reels-v3/) · [下载全部MP4/候选/许可](https://clock-audio-director-lab.silkyball18.chatgpt.site/reels-v3/audio-scene-reels.zip) · [PR109](https://github.com/zhipijun1996/gunman-rush/pull/109)

10支真实Godot有声短片，共9445帧/157.4167秒、12475449B；每片0.80–2.71MiB。网页提供12个场景/武器章节、48个原版/A/B/C可点播片段，无需下载185MB游戏。武器三个入口从同一原片的真实接受事件帧跳转，无重配音或音画重排。前9片无BGM，第10片现场混入用户原Home BGM，页面不再叠音乐。

[原反馈](feedback.md)已落实为[功能风格V3](../../audio_director/style_bible_v3.md)、[增量事件目录/代码位置](../../audio_director/event_catalog_v3.md)和[实际候选/来源](../../audio_director/candidates_v3.md)。14事件×3方案=42个CC0声音：清脆收集币、液体回血、木扣开箱、约1.7秒实际有声的道具获得、UI、命中/敌伤/主角伤，以及脉冲枪/手里剑/反冲炸弹。58个原件、101条登记，所有新声音待用户；原jump/land、五MP3和正式original默认不改。成熟作品只作功能/节奏参考，未用其原轨生产。

## 怎么选择

选类别与事件→点原版/A/B/C直接跳段→可循环当前段→逐事件选择或全部否决→备注/导出JSON。可直接回复“金币B、回血C、道具A”；组片也保存每事件真正sound_candidate_id、profile与版本。选择仅存当前浏览器，不声称远程同步。下载链接可直接用原MP4看完整对照；ZIP不含互动游戏，会禁用不存在的离线互动入口。旧V2互动入口单独标明，未拿旧包冒充V3。

## 精确来源与工程验证

- 原生影片运行源 `4d724a73293aa6f9b94fe51e4884ff5102802ccc`，Godot4.7.2；后验证/媒体打包源 `df22e3763484f86b892e16b7cf3e5e9952b847db`，页面修订源 `c3f4fdf4a41eaa32dad170804fc9f221f84f0d2a`。各身份分别记录，不把后修工具追认原拍摄源码。
- Sites版本5，网站源`86ddc8aa712bcb7a9331e0fbef22340e91cc9d3f`，原owner-private受众保持；发布后[实际站点浏览器验证](remote-browser.json)通过金币C/回血B真实点击、Blob播放与非零时段跳转，无autoplay豁免。首次发布完成前启动的超时保留，未推定其原因。[原生发布成功收据](deployment.json)；旧V2根页面/游戏/单声文件保留。
- [同源原生126/0](native-final/report.json)，严格runner退出0、33.54秒、无ERROR/资源泄漏；包括新事件/真实HP钱包道具/3武器身份与非目标回退/owner清理。原共享audio60/0与生命周期37/0同阶段通过，未签全量Integration。
- 10片均实际接受事件、精确候选路径/实际播放、四profile相同物理/HP序列、可见行动区、MovieWriter0基帧锚及片段时长通过。[原始结构摘要](recordings-summary.json)与[完整原报告/trace/log ZIP](capture-proofs.zip)、[逐成员SHA与真实读回验证](capture-proof-index.json)。原报告中的旧数值相关性已被下条取代，不能单独当音轨证明。
- [9项加工反例](route-guard-tests.log)：42WAV真实原件重建/DSP trace/SHA、ABC唯一且ID可路由、路径/来源/工具/配方漂移拒绝；[结果](route-guard-receipt.json)。[12项真实影片trace反例](capture-counterexamples.log)拒绝删事件/假结果/缺播放/错源/分数帧/帧基漂移/工程音频设置漂移。
- [稳定后验数值8项](numeric-tests.log)拒绝静音窗FFT假峰、缺层/极小正系数冒充存在。全部原媒体不变，新增[10份后验证](post-validation/coin-audio.json)；63次候选播放覆盖42WAV，以57次独立波形匹配和3个同帧双层联合拟合验证。独立量测的60个非launch项偏移+2.7083～11.375ms，属于软件录屏/编码链事实，非设备延迟预算。
- BOMB是原Lv1即时反冲爆破，发射和爆破信号同tick。两个声层共同拟合R²约.982–.998，且相对每个单层解释都有显著能量增益；单独launch时点不可分离，保留unverified，不能把错误单层峰当时分试听。[独立原音轨脚本](independent-audio-audit.py)/[实际结果](independent-audio-audit.json)。
- [手机网页48段实际检查](browser-final/report.json)：真实指针、无autoplay豁免，MP4视频/AAC音轨解码、seek/loop/Stop/后台取消、媒体互斥、逐事件ID选择/导出/持久化通过。软件Chromium390px不代替实体手机或Safari。最终QA在不支持Range的普通HTTP服务通过；以fetch缓冲单支小MP4后用Blob URL跳段，[延迟下载取消反例](browser-deferred/report.json)通过。实际私有托管[读取探针](remote-http-probe.json)确认不支持Range，原Range前提已被修订覆盖。首次Python普通静态服务的失败保留[原始记录](browser-failures/browser-pointer-final.json)，未靠放宽或强开自动播放通过。
- [冻结docs33项](harness-docs/report.json)通过；后续新增数值后验与UI缓冲修复分别执行相关8/12/63/48验证，最终文档/质量/跨base守门另核，不冒充完整Release。[独立工程ACCEPT](review.md)关闭R1–R4，审美、玩家、真机仍未批准。

## 样板与剩余范围

角色行走、Area接触、ShopService交易、RewardService领取、原敌我弹体/FrameDamagePolicy均为真实消费者；初始条件明确是Home开发fixture。宝箱/道具原版只有confirm/note通用映射，片上注明。混音片中途明确重建战斗fixture，BGM继续，不能当自然无重置关卡或钱包保持证明。取景/Toast位置只影响样板视觉，没改规则。

制作中原mix因枪反冲把角色移出旧敌弹射程而缺hurt，真实126/7失败后改为Router走回原范围；没有改伤害/射程/TTL。早pilot保留JSON整数float适配失败及偏边构图，0基A=184帧实读证明后才采最终版。数值旧算法在安静尾部可产>1假相关，R4保留原报告并以稳定能量/直接dot和缺层反例重验，未重录掩盖事实。网页还修复了非Range/未缓冲seek时静默取消的问题，现fetch所选小片并使用Blob URL在本地已缓冲媒体跳段，最多缓存4片，并拒绝Stop/换片后的迟到下载触发播放；提供直接下载。

没有V3互动Web导出，也未自动接入全部正式宝箱/地区/敌人。用户选定后再做所选声音的组合混音与高频变体，并按授权推广。更多钩索/装填/机关/Boss/环境需求已列目录，不能以音效数签完成。音色悦耳、获得感、打击手感、长听疲劳、实体手机/Safari/扬声器/耳机与全局正式混音仍待用户；PR保持review，不合main。
