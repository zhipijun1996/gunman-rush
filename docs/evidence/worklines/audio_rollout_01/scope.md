# AUDIO-ROLLOUT-01 · 已选环境音正式采用与快速试玩

用户明确“快速合入main，并部署试玩”，覆盖本工作线此前“不自动合main/正式默认original”的候选阶段边界。按已选quiet-02平原A/森林A、home-quiet-01家园life接入真正主场景；不重问选择或发布授权。基线main45e98、PR113现前置3e6bf692，继续活跃feature/audio-ambience-01，普通merge不强推/不绕门禁。

仅scenes/demo/demo.tscn新增SelectedAmbienceRuntime子Node与新装配脚本/专项，借用原GameAudio/GameAmbience/HomeAmbienceAudition，不改正式DemoApp/HomeScene、81style绑定、选音字节/旧manifest/五原BGM、物理/输入/伤害/资源/RNG/存档，也不顺带推广13项SFX候选。所有三个正式preset精确追加4份必需manifest/选择JSON与16个原始音频；复用现有raw exporter以add_file(..., false)同时保留精确指纹原件及正常导入派生，不放宽目录通配。新增导出正负例、实际PCK逐项读回SHA/长度，原PNG导出逻辑不变。

装配deferred等待实际父App自有GameAudio，真实Home可见才life；stage实际Generated.manifest.region、stage类型与app.active_region一致才选对应A；未知/标题/旧开发Lab静音，无随意fallback平原。同context不重启，死亡直接绑Controller.died且闩锁防下帧复活；暂停/菜单沿原语义，离场/重配/场景切换清理。Web新建组件继承已经接受的真实用户gesture解锁，不能无条件auto-unlock。

验证先加载真实demo.tscn的title→Home→plains→forest→Home/死亡/暂停/幂等/多App隔离专项；原小测试与已冻结素材证明不重做长片。独审新增装配，门禁失败修具体原因不改断言预算。合入核精确最终head的完整Production impact双通道/affected，通过后普通merge。

试玩按既有快速路线：优先复用目标source已验证包；当前公开source45e98无本轮声，须只重建Web。Foundry仅真实stamp过期才原工具重建；原check_release_evidence/导出/包闭包守门保留。最终真实main source导出Web Playtest→prepared仅构建分支→原deploy-prepared-playtest；核公开build-info完整PCK字节/SHA及真实GUI。不会以旧电影、旧Sites或排队状态冒充新可操作试玩。

运行与审查：runtime作者只新helper/专项；root只main scene/精确export白名单与raw exporter增量/导出专项、质量/源码守门/所有Godot/构建与发布；scene只读快速链路与隔离browser脚本；reviewer只读独审，不改生产/不跑Godot。新主站试听交付不代签实体设备、全游戏平衡或未听的其他音效。

远端前置3e6bf692的parallel实际quality失败：旧AUDIO-DIRECTOR-01的audio-style-v1证据仍指向后来追加环境反馈的活规范。逐字恢复3cc6c620原文件为本轮frozen/style_bible_candidate_v1.md.txt并核原08371f6 SHA，仅迁移旧evidence.path，原source/hash/结论不变；当前风格与quiet-02反馈保留。未刷新旧SHA或追认旧失败。
