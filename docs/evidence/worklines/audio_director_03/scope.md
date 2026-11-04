# AUDIO-DIRECTOR-03 · 功能选材与真实有声对比录屏

继续PR109的用户反馈迭代；最新main仍26e7f2a，输入为630f3c52。用户要求快速组合各场景不同声音的试听录屏，并明确Mario式清脆金币、液体回血、宝箱开启、动森式长道具获得、Hollow Knight式动作打击、逐武器射击及符合当前美术的UI。不是直接采用商业游戏原轨。[原反馈](../../evidence/audio_director_03/feedback.md)、[功能风格规范](../../audio_director/style_bible_v3.md)。

目标：先交14事件×3方案=42个可听新候选，9个原版/A/B/C真实Godot短片＋1个原BGM连续混音片，手机直接看/听/按事件选择，不下载185MB互动游戏。保原jump/land与五MP3、物理/伤害/资源/RNG/存档规则。完整互动V2入口保留，新录像入口独立；V3非正式默认。

所有权：候选代理仅tools/audio_candidates_v3.py、config/audio_director/v3、assets/audio/director_v3、专属Python测试、candidates_v3文档与AUDIO-DIRECTOR-03资产登记；scene代理仅reels场景/脚本/UID、capture_audio_reels工具与专项测试；web代理仅reels_index.html/verify_reels.mjs；root负责GameAudio/weapon_audio/weapon_audio_v2/weapon_feel最小参数与事件路由、brief路由、风格/任务/质量/证据、静态打包与原owner-private Sites发布；独审只写review.md。

接口：新manifest/rules沿V2bank结构，profiles A/B/C。事件coin/heal/chest_open/item_get/click/confirm/denied/enemy_hit/enemy_hurt/hurt/shot_pulse/shot_shuriken/shot_bomb/bomb_explode。weapon_cue末尾可选真实weapon_id隔离同材质不同武器，缺bank不改旧路由；bomb launch仅Lab订阅真实accepted shot后播放，原版保原静音launch。新weapon family复用12voice与owner生命周期，不造第二音频服务。

宝箱目前无独立Chest Node，正式区域使用reward offer/claim流程；本轮明确Home开发fixture，角色真实靠近、可见开盖、RewardService接受、原奖励UI/Toast。原版只有confirm/note通用音，字幕标旧映射；新chest_open与item_get分开时点，不冒充正式所有宝箱接入。

捕捉：真实Godot MovieMaker固定60fps，原生48k立体声音轨直接AAC编码，不能静图或后配声音。字幕/候选ID、Seed、实际事件tick与段起止、源/输出SHA可追。原版/ABC尽量同场景同输入；未变的玩法资源不注入假结果，明确开发初始化。正常速度不等于实体FPS。

验证：原生消费者/3武器映射反例/暂停释放、原audio60及生命周期37的相关回归、42输出/来源/参数/指纹与重建、真实影片流/非静音/音画事件、手机视频播放/seek/loop/停止/偏好保存。先冻结运行源码与输入，docs独占完成后串行影片采集，避免CPU竞争造成Router TTL。最小相关检查，不升级无关完整CI或185MB新Web导出。

发布：复用既有Sites项目及owner-private受众，旧dist游戏与单声保留，新增reels/视频页。每MP4<25MiB，直接可播/下载，源与metadata绑定真实冻结commit。审美、手感、设备和全局正式混音保持待用户。后续事件由简短Audio Director指令读取本轮功能风格与素材，而不是重新写长提示。
