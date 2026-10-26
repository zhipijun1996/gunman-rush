# AUDIO-DIRECTOR-01 · 第一阶段

- 目标：让高频动作的原音效与一组统一童话机械候选可实际比较；建立可复用审计、许可原料、加工及试听入口。
- 基线：origin/main `26e7f2a4459623f35613a857da8a75e89daa3e62`；分支 `feature/audio-director-01`；独立工作区 `/workspace/gunman-audio`。
- 模式：Creative Exploration → System Engineering；声音方向仍 awaiting-user，不标商业品质完成。
- 完成条件：可听的16事件 A/B 候选、原版对照、原五曲混音、真实Godot动作入口、来源与参数可追溯、最小专项及独审、独立PR；发布阻塞须交可下载比较包。
- 写集：主线负责 tools/audio_director.py、tools/sound_lab/*、docs/audio_director/style_bible.md与README、.agents/skills/audio-director、任务/质量/交接、Lab生成物及独立host；audit代理独占 tools/audio_inventory.py及inventory/event_catalog；candidate代理独占 tools/audio_design.py、config/audio_director/recipes.json/sources.json、assets/audio/director_candidates、source_library/pipeline；runtime代理独占GameAudio、motion/weapon音频链、scripts/art/player_feedback.gd、GameMusic、runtime配置/测试/文档；Lab代理独占scripts/dev/audio_director_lab.gd、scenes/dev/audio_director_lab.tscn及UID。
- 接口：保留12voice、cue/motion/weapon接口；profile original默认，A/B仅显式启用；表现只消费accepted事件，不改伤害/资源/物理/输入/RNG/save。
- 原五首BGM逐字节保留；不生成/替换音乐。候选原料只留选用CC0；未用包在本机缓存，Sonniss未核验不引入。
- 验证：production_plan development，docs一次；音频文件重建/峰值/资源/许可、Godot解析与实际消费者/生命周期、手机尺寸浏览器GUI和公开字节；相关旧audio lifecycle。Integration由PR原守门执行，不跑无关完整CI。用户听感和实体设备独立未验。
- 交付：需要实际聆听与操作，HTML移动试听 + 同源真实Godot Preview；主站和旧Preview保留。固定种子 audio-director-01；离线Dummy不证明实际听感。
- 当前检查点：G0/G1，基线已取、审计/加工并行；机器4.6.3与锁定4.7.2不符，原setup尝试中。独立审查在代码冻结后进行。
