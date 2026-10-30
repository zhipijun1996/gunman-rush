# AUDIO-FEEDBACK-06 · 标题自动音乐与主角受伤再选材

用户原话：“进入标题页面直接开启bgm；弹丸碰墙新版变体1试试；主角受伤感觉都不太对，参考空洞骑士受伤的声音”。这是PR121同一音频工作线的新一轮反馈，最新main仍5f55716a，续接已交付f0778c4c；不重新合入或重建旧候选。

Fast Iteration／Creative Exploration，采用Audio Director、Game Quality、Animation VFX、Project Integration。标题进入即调用原引擎播放，允许自动播放的浏览器立即有声；冷浏览器策略拦截时依官方后端真实手势恢复，不声称能绕过平台授权。去掉单独开启音乐的标题提示；同曲进Home不重启。墙地仅固定feedback05/wall_1，保60ms／最多2声／12共享池／原混音。旧选择与其他两条原件保留。

受伤旧C和feedback05两条已被用户否决。换原材质做三个真正可比较的短受击方向：明确起音、身体重量、短气息/空腔余韵；不是仅把旧声增响。空洞骑士仅作用户指定功能/情绪参考，不能把其商业音轨作为生产输入。每条原件CC0来源／许可／下载日期／SHA与处理参数留存，五首原BGM和原jump/land/其他事件不改。新hurt仅此开发分支默认候选，未获用户认可。

root拥有新feedback06配方/manifest/处理器/受伤候选、SelectedSfxRuntime候选装配、Audio Director上下文、捕获/工坊/导出来源、任务/质量/证据与必要技术版本重绑。ambience_runtime仅GameMusic、DemoMenu、WeaponFeelAudioV2及原反馈/BGM测试中相关标题和墙声预期；ambience_sources只读选材/忽略缓存研究。ambience_review只读最终差异、许可和证据审查。所有Godot/导出/浏览器WASM由root持单租约；冻结采证期间不改源。

相关最小原Harness、实际浏览器自动播放允许/拦截两种条件、同源正常速度真实Godot音轨及当前包指纹分别记录。原门禁不删不减，不把自动检查签成听感/真机/商业品质。继续提供独立试听入口，原main与feedback05入口来源保留，PR121更新，不自动合main。
