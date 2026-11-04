# AUDIO-HOME-01 · 家园微风与生活声

- 继续Audio Director活跃工作线PR113；main仍45e98，音频前置7b28301f，分支feature/audio-ambience-01。不是另起平行音频引擎，不自动合main。
- 用户目标：家园有平原的平静，以及NPC的生活声音。沿已选quiet-02 plains_a的精确OGG字节，家园额外−2dB作为待听起点；五原BGM、MusicGain0.16、原session音量和已选A/A不改。
- 创作范围：既有安全风铃聚落，不创建地区/美术/玩法；完整原平原Bible、风格和真实Home消费者由authority.json绑定。NPC是静态Sprite，没有敲打/翻页动画帧事件；新声音称NPC所在地工坊内部生活拟音，不伪称动画同步。
- 来源假设：织时匠布料整理、维修工坊木件收放、武器工坊轻工具、档案员翻页。4家族各2真实录音变体，8短PCM候选；没有已开放NPC的预留地段无生活声，不加人群常驻loop。远处静音、近处轻微、每NPC12–22秒且全局至少6秒/至多1生活声，无远处积压/补播。
- 复用GameAudio/GameAmbience原2床2点能力；home独立manifest放assets/audio/ambience_v1/home/，不改原两区manifest、配方和选择SHA。formal HomeScene/DemoApp/Underworld/physics及81项style绑定原件不动。开发Lab装配真实HomeScene/Controller/Router；各正式keeper真实home_root作声源。
- 写集：素材作者tools/audio_home_design.py/config/audio_director/home/assets/audio/ambience_v1/home/加工测试/来源文档；运行作者scripts/audio/home_ambience_audition.gd/运行测试/运行规范；场景作者独立dev Lab、capture/packager/HTML/browser脚本。root独占Godot租约、共享接口、质量/资产登记、Sites和Git；独审不改生产。
- 生命周期：面板只停点声/禁新点声，风保持；pause暂停，恢复不补声；弱owner/listener、controller.died、离家、original、退出/重配清理；不读写伤害、物理、保存、资源或游戏RNG。
- 交付：正常BGM持续的original/bed/life三段真实26秒家园路线观看片（同输入/位置/镜头/每帧日志），不把走过上层NPC楼下说成已上楼交互；8单声可手机播放，来源许可/ID/版本可见。原环境工坊新增/home/子页，root已选两区和previous-v1逐字节保留。
- 验证：先窄parse/真实Home启动与最短路由，不改原预算；再相关加工/播放/面板/死亡/卸载/距离/防堆叠/静音/暂停专项。冻结全源/所有shader后原MovieMaker真实轨音，原900秒上限；独立后验实际音轨幅度/BGM未提高。2轮无改善停止声音方向并更换来源，工程失败单列。
- 用户听感、实体设备、完整CI/正式推广不由自动检查代签；新家园候选待听。
