# AUDIO-DIRECTOR-02 · 现成音色与真实情境试听

用户明确：“重新给我几套音效。工坊试听音效增加游戏场景，更能感受和联想”。本轮继续PR109工作线，最新main仍26e7f2a，输入为第一轮4f230705及其明确用户否决；旧v1原件/失败保留，不重新包装旧A/B。

- 目标：3套少加工CC0现成原料，重点UI点击/确认/拒绝、金币/生命/普通奖励、敌人命中/受伤与主角受伤。保留用户认可的原起跳/落地，其余枪/钩索/音乐维持原版。
- 完成条件：单声与真实Godot UI/拾取/战斗场景能直接比较、重复触发、同场景换套装与BGM；手机工坊首屏能进入场景，无需游玩整张地图。用户审美与设备仍独立。
- 模式：Creative Exploration＋System Engineering；只改表现及明确development fixture，不改正式伤害/物理/资源/随机/存档规则。
- 写集：候选代理独占tools/audio_candidates_v2.py、config/audio_director/v2、assets/audio/director_v2、候选测试与AUDIO-DIRECTOR-02素材登记；scene代理独占GameAudio和motion/weapon最小兼容、scripts/dev/audio_director_lab_v2.gd与scene/test/UID；web代理独占tools/sound_lab/v2_index.html和verify_v2.mjs；主线负责tools/audio_lab_v2.py、精确导出配置、文档/任务/质量/精选证据、构建及已有Sites部署。
- 接口：新manifest versionaudio-director-v2，profiles A/B/C，9事件，保旧bank；显式configure新bank后仅映射存在的事件，未映射沿原声音。same-origin parent/iframe只支持明确context/profile/demo/pause命令，不能任意脚本。所有音效复用原12voice。
- 场景：正式角色/敌人/损伤服务与真实Area碰撞的开发样板；物件摆放、训练目标重置显式fixture。单事件焦点可仅比较命中或敌伤的一层，避免双重瞬态；真实HP/拾取受付链仍发生，不把直接play()冒充动作。
- 验证：新样本重建/许可/峰值及漂移拒绝、最小音频/场景正式消费者、手机HTML与真实Godot冷启动/桥接/事件追踪、原docs一次、跨基线质量守门、独立只读审查。不因试听迭代重跑无关完整Release。
- 发布：复用已部署的owner-private Sites项目appgprj_6adeafa19ac881919f6f51362eef3c11及原Web导出/分块哈希；先本地核精确源与PCK，保存/部署同一源版本后给真实地址。旧站未替换前不声称V2已上线。
- 新主观状态：全部awaiting-user；v1维持用户拒绝，不以新技术通过改签旧审美。
