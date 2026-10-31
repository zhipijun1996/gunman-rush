# Boss逐组合资料与素材

快照 310c0421e18829088a4d2208c5f1b6cba3db35dc。8场景／9Definition组合，Storm不是新物种。入口与历史回放分列；素材存在不表示该版本已获认可。见[原始审计JSON](boss-inventory.json)。

## 旧发条守卫 `clockwork_guardian`

设计资料：
- [docs/enemies_and_bosses.md](../../enemies_and_bosses.md) · §BossEncounter分层
- [assets/plains_v3/enemies/README.md](../../../assets/plains_v3/enemies/README.md) · Boss phase_1/phase_2/dead说明
- [docs/worklines/enemy_all_02/boss-production-cards.md](../enemy_all_02/boss-production-cards.md) · §场景制作卡 / §实际绑定与不变接口

当前身体：[assets/plains_v3/enemies/clockwork_atlas.png](../../../assets/plains_v3/enemies/clockwork_atlas.png)。独立atlas中的3个Boss静态键；与普通巡逻机同张总图集，但不是guardian.png的缩放版。

原始母版与来源：
- [assets/plains_v3/enemies/clockwork_atlas.png](../../../assets/plains_v3/enemies/clockwork_atlas.png) · 
- [assets/plains_v3/enemies/manifest.json](../../../assets/plains_v3/enemies/manifest.json) · 
- [assets/plains_v3/enemies/README.md](../../../assets/plains_v3/enemies/README.md) · 

准入与动作事实：

{"class": "legacy_fixed_demo_and_boss_lab", "evidence": ["docs/windkeeper_runtime.md:5", "scripts/demo/demo_app.gd:825"], "note": "固定demo/旧Boss Lab/旧回归场景；非当前平原两张正式地图Boss，未找到独立产品准入卡。"}

{"type": "three_static_state_keys_plus_code_motion", "static_keys": ["boss_phase_1", "boss_phase_2", "boss_dead"], "dedicated_attack_hurt_death_sequence_found": false, "fact": "manifest明确animation_complete=false；当前活体用共享网格，死体切独立dead静态键。"}

缺失／未知：
- 单Boss专用设计Sheet未在docs/design及顶层文档检索到；概念/动作细节只见泛用Boss契约和atlas说明。
- 没有找到专属移动、前摇、攻击、受伤、连续死亡帧序列；当前是3静态状态键+代码。

## 鸣铃巡游机 `bellstrider`

设计资料：
- [docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md) · §6.1鸣铃巡游机 / §9音频
- [docs/plains_pressure_boss.md](../../plains_pressure_boss.md) · §独立小Boss：鸣铃巡游机
- [docs/evidence/underworld_feedback_03/boss/preflight/design.md](../../evidence/underworld_feedback_03/boss/preflight/design.md) · 连续战斗/车底接触与完整fight来源
- [docs/design/story/boss_narratives.md](../../design/story/boss_narratives.md) · §16区主Boss与第一图定位
- [docs/worklines/enemy_all_02/boss-production-cards.md](../enemy_all_02/boss-production-cards.md) · §场景制作卡 / §实际绑定与不变接口

当前身体：[assets/underworld_plains/actors/bellstrider.png](../../../assets/underworld_plains/actors/bellstrider.png)。Bellstrider独立裁图；与Windkeeper同次双Boss原图生成，不是同图缩放。

原始母版与来源：
- [assets/underworld_plains/actors/source_bosses.png](../../../assets/underworld_plains/actors/source_bosses.png) · 
- [assets/underworld_plains/actors/generation_calls.json](../../../assets/underworld_plains/actors/generation_calls.json) · 
- [assets/underworld_plains/actors/actors_build.json](../../../assets/underworld_plains/actors/actors_build.json) · 
- [docs/quality/asset_records/underworld-production-actors.json](../../quality/asset_records/underworld-production-actors.json) · 
- [assets/plains_v4/bellstrider/manifest.json](../../../assets/plains_v4/bellstrider/manifest.json) · 
- [assets/plains_v4/spatial/manifest.json](../../../assets/plains_v4/spatial/manifest.json) · 

准入与动作事实：

{"class": "current_plains_map1_runtime_consumer", "evidence": ["scripts/demo/plains_region_stage.gd:53"], "note": "当前App平原图1实例化该scene；其资产登记仍有limited_preview/unverified字段，不能把运行入口等同用户美术准入。"}

{"type": "single_static_body_plus_code_wheels_suspension_mesh", "primary_condition": "UnderworldActors.enabled(metadata underworld_formal_style)", "alternate_branches": ["pixel_style: PixelFormalActors.draw_bellstrider程序绘制", "else: spatial/chassis.png + actors.png wheel + Windkeeper parts.png braces/core"], "dedicated_attack_hurt_death_sequence_found": false}

缺失／未知：
- 没有找到当前128×114身体的独有状态动作序列或转面表。
- 原Bible外观/招式描述、D077轮式铜木SVG和当前Underworld车体是不同层资料，不能视作同一已批准原画包。

## 牧风者（默认） `windkeeper`

设计资料：
- [docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md) · §6.2牧风者 / §9.3牧风者战斗
- [docs/windkeeper_plains_iteration.md](../../windkeeper_plains_iteration.md) · §牧风者：用户确认内容 / §实现边界
- [docs/windkeeper_runtime.md](../../windkeeper_runtime.md) · §分离契约 / §实际验证范围
- [docs/plains_pressure_boss.md](../../plains_pressure_boss.md) · §大Boss：强化牧风者
- [docs/evidence/underworld_feedback_03/boss/preflight/design.md](../../evidence/underworld_feedback_03/boss/preflight/design.md) · 连续战斗与三平台策略
- [docs/design/story/boss_narratives.md](../../design/story/boss_narratives.md) · §16区主Boss与第一图定位
- [docs/worklines/enemy_all_02/boss-production-cards.md](../enemy_all_02/boss-production-cards.md) · §场景制作卡 / §实际绑定与不变接口

当前身体：[assets/underworld_plains/actors/windkeeper.png](../../../assets/underworld_plains/actors/windkeeper.png)。默认与storm均精确复用同一windkeeper.png；storm没有独立原画母版，只在代码中的阶段尺寸/行为和资源不同。

原始母版与来源：
- [assets/underworld_plains/actors/source_bosses.png](../../../assets/underworld_plains/actors/source_bosses.png) · 
- [assets/underworld_plains/actors/source_windkeeper_edit.png](../../../assets/underworld_plains/actors/source_windkeeper_edit.png) · 
- [assets/plains_v4/windkeeper/body_actions.png](../../../assets/plains_v4/windkeeper/body_actions.png) · 
- [assets/plains_v4/windkeeper/parts.png](../../../assets/plains_v4/windkeeper/parts.png) · 
- [assets/underworld_plains/actors/generation_calls.json](../../../assets/underworld_plains/actors/generation_calls.json) · 
- [assets/underworld_plains/actors/actors_build.json](../../../assets/underworld_plains/actors/actors_build.json) · 
- [assets/plains_v4/windkeeper/manifest.json](../../../assets/plains_v4/windkeeper/manifest.json) · 
- [assets/plains_v4/windkeeper/README.md](../../../assets/plains_v4/windkeeper/README.md) · 
- [docs/quality/asset_records/underworld-production-actors.json](../../quality/asset_records/underworld-production-actors.json) · 

准入与动作事实：

{"class": "legacy_aperture_scene_default", "evidence": ["scenes/bosses/windkeeper.tscn", "scripts/demo/plains_region_stage.gd:53-55"], "note": "同一scene的两种Definition/机制组合，非两个独立Boss物种。默认scene为旧12HP窗口配置；当前平原map2覆写storm资源36HP/continuous，不能只按scene默认判断正式版本。"}

{"type": "single_static_underworld_body_plus_code_mesh_rotor", "primary_condition": "underworld_formal_style祖先metadata", "alternate_branches": ["pixel_style: PixelFormalActors程序身体", "else: 六关键姿态body_actions或interactive_atlas三form，再由代码过渡/腿切片/rotor旋转"], "dedicated_full_sequence_in_primary_branch_found": false, "alternate_six_keys_are_not_full_animation": true}

缺失／未知：
- 当前Underworld主身体仅单张128×119静图；未找到其专属走动/攻击/受伤/终结逐帧序列。
- v4六姿态确实存在，但不能记成当前Underworld正式body已消费的逐帧动作。
- Bible终结演出风叶坠落/铜铃依次失声的独立分镜与对应专素材未在本次范围找到。

## 牧风者（Storm） `windkeeper_storm`

设计资料：
- [docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md) · §6.2牧风者 / §9.3牧风者战斗
- [docs/windkeeper_plains_iteration.md](../../windkeeper_plains_iteration.md) · §牧风者：用户确认内容 / §实现边界
- [docs/windkeeper_runtime.md](../../windkeeper_runtime.md) · §分离契约 / §实际验证范围
- [docs/plains_pressure_boss.md](../../plains_pressure_boss.md) · §大Boss：强化牧风者
- [docs/evidence/underworld_feedback_03/boss/preflight/design.md](../../evidence/underworld_feedback_03/boss/preflight/design.md) · 连续战斗与三平台策略
- [docs/design/story/boss_narratives.md](../../design/story/boss_narratives.md) · §16区主Boss与第一图定位
- [docs/worklines/enemy_all_02/boss-production-cards.md](../enemy_all_02/boss-production-cards.md) · §场景制作卡 / §实际绑定与不变接口

当前身体：[assets/underworld_plains/actors/windkeeper.png](../../../assets/underworld_plains/actors/windkeeper.png)。默认与storm均精确复用同一windkeeper.png；storm没有独立原画母版，只在代码中的阶段尺寸/行为和资源不同。

原始母版与来源：
- [assets/underworld_plains/actors/source_bosses.png](../../../assets/underworld_plains/actors/source_bosses.png) · 
- [assets/underworld_plains/actors/source_windkeeper_edit.png](../../../assets/underworld_plains/actors/source_windkeeper_edit.png) · 
- [assets/plains_v4/windkeeper/body_actions.png](../../../assets/plains_v4/windkeeper/body_actions.png) · 
- [assets/plains_v4/windkeeper/parts.png](../../../assets/plains_v4/windkeeper/parts.png) · 
- [assets/underworld_plains/actors/generation_calls.json](../../../assets/underworld_plains/actors/generation_calls.json) · 
- [assets/underworld_plains/actors/actors_build.json](../../../assets/underworld_plains/actors/actors_build.json) · 
- [assets/plains_v4/windkeeper/manifest.json](../../../assets/plains_v4/windkeeper/manifest.json) · 
- [assets/plains_v4/windkeeper/README.md](../../../assets/plains_v4/windkeeper/README.md) · 
- [docs/quality/asset_records/underworld-production-actors.json](../../quality/asset_records/underworld-production-actors.json) · 

准入与动作事实：

{"class": "current_plains_map2_definition_override", "evidence": ["scenes/bosses/windkeeper.tscn", "scripts/demo/plains_region_stage.gd:53-55"], "note": "同一scene的两种Definition/机制组合，非两个独立Boss物种。默认scene为旧12HP窗口配置；当前平原map2覆写storm资源36HP/continuous，不能只按scene默认判断正式版本。"}

{"type": "single_static_underworld_body_plus_code_mesh_rotor", "primary_condition": "underworld_formal_style祖先metadata", "alternate_branches": ["pixel_style: PixelFormalActors程序身体", "else: 六关键姿态body_actions或interactive_atlas三form，再由代码过渡/腿切片/rotor旋转"], "dedicated_full_sequence_in_primary_branch_found": false, "alternate_six_keys_are_not_full_animation": true}

缺失／未知：
- 当前Underworld主身体仅单张128×119静图；未找到其专属走动/攻击/受伤/终结逐帧序列。
- v4六姿态确实存在，但不能记成当前Underworld正式body已消费的逐帧动作。
- Bible终结演出风叶坠落/铜铃依次失声的独立分镜与对应专素材未在本次范围找到。

## 旧森林守卫 `thorn_guardian`

设计资料：
- [docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md](../../creative_direction/bibles/2-thorn_forest_region_bible_v2.md) · §8根铃守卫
- [docs/enemies_and_bosses.md](../../enemies_and_bosses.md) · Boss契约
- [docs/design/story/boss_narratives.md](../../design/story/boss_narratives.md) · §16区主Boss与第一图定位
- [docs/worklines/enemy_all_02/boss-production-cards.md](../enemy_all_02/boss-production-cards.md) · §场景制作卡 / §实际绑定与不变接口

当前身体：[assets/forest_bible_v2/native/fine_32/guardian.png](../../../assets/forest_bible_v2/native/fine_32/guardian.png)。与rootbell_guardian_v2精确同guardian.png，1×同基准。

原始母版与来源：
- [assets/forest_bible_v2/native/fine_32/boss_beetle_master_original.png](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_master_original.png) · 
- [assets/forest_bible_v2/native/fine_32/boss_beetle_generation.json](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_generation.json) · 
- [assets/forest_bible_v2/native/fine_32/boss_beetle_build.json](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_build.json) · 
- [docs/quality/asset_records/fine-space-05-forest-boss-beetle.json](../../quality/asset_records/fine-space-05-forest-boss-beetle.json) · 

准入与动作事实：

{"class": "legacy_forest_v1_explicit_replay", "evidence": ["scripts/generation/thorn_forest_region_generator.gd:_boss_paths LEGACY_VERSION"], "note": "仍受支持的旧森林v1 scene；不是默认v2/v15地图的Boss，不因本轮换图获得新版本准入。"}

{"type": "one_reused_static_fine_body_plus_shared_code_mesh", "dedicated_attack_hurt_death_sequence_found": false, "replacement_fact": "本轮两叶从程序树干/枝冠改为复用fine32母版；此前程序形体是历史代码，不是另一份原画。"}

缺失／未知：
- 未找到仅针对该旧scene的独立设计Sheet、独有母版或逐帧动作资产。
- 与V2/Canopy不同的旧窗口/弱侧/seed机制，不能只因图相同混作同一准入版本。

## 旧森林女王 `thorn_queen`

设计资料：
- [docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md](../../creative_direction/bibles/2-thorn_forest_region_bible_v2.md) · §9棘冠女王
- [docs/enemies_and_bosses.md](../../enemies_and_bosses.md) · Boss契约
- [docs/design/story/boss_narratives.md](../../design/story/boss_narratives.md) · §16区主Boss与第一图定位
- [docs/worklines/enemy_all_02/boss-production-cards.md](../enemy_all_02/boss-production-cards.md) · §场景制作卡 / §实际绑定与不变接口

当前身体：[assets/forest_bible_v2/native/fine_32/queen.png](../../../assets/forest_bible_v2/native/fine_32/queen.png)。与Weave/Canopy精确同queen.png；旧Queen仅2×整数显示与接地基准不同，没有独立旧Queen专画。

原始母版与来源：
- [assets/forest_bible_v2/native/fine_32/boss_beetle_master_original.png](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_master_original.png) · 
- [assets/forest_bible_v2/native/fine_32/boss_beetle_generation.json](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_generation.json) · 
- [assets/forest_bible_v2/native/fine_32/boss_beetle_build.json](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_build.json) · 
- [docs/quality/asset_records/fine-space-05-forest-boss-beetle.json](../../quality/asset_records/fine-space-05-forest-boss-beetle.json) · 

准入与动作事实：

{"class": "legacy_forest_v1_explicit_replay", "evidence": ["scripts/generation/thorn_forest_region_generator.gd:_boss_paths LEGACY_VERSION"], "note": "仍受支持的旧森林v1 scene；不是默认v2/v15地图的Boss，不因本轮换图获得新版本准入。"}

{"type": "one_reused_static_fine_body_plus_shared_code_mesh", "dedicated_attack_hurt_death_sequence_found": false, "replacement_fact": "本轮两叶从程序树干/枝冠改为复用fine32母版；此前程序形体是历史代码，不是另一份原画。"}

缺失／未知：
- 未找到仅针对该旧scene的独立设计Sheet、独有母版或逐帧动作资产。
- 与V2/Canopy不同的旧窗口/弱侧/seed机制，不能只因图相同混作同一准入版本。

## 根铃守卫V2 `rootbell_guardian_v2`

设计资料：
- [docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md](../../creative_direction/bibles/2-thorn_forest_region_bible_v2.md) · §8.1外观 / §8.2借铃返击 / §12音频
- [docs/design/rootbell_guardian_v2.md](../../design/rootbell_guardian_v2.md) · §状态承诺阶段 / §灰盒表现与接受范围 / §历史索引
- [docs/evidence/forest_guardian26_delta/prior_design_chronology.md.txt](../../evidence/forest_guardian26_delta/prior_design_chronology.md.txt) · 历史全记录
- [docs/design/story/boss_narratives.md](../../design/story/boss_narratives.md) · §16区主Boss与第一图定位
- [docs/worklines/enemy_all_02/boss-production-cards.md](../enemy_all_02/boss-production-cards.md) · §场景制作卡 / §实际绑定与不变接口

当前身体：[assets/forest_bible_v2/native/fine_32/guardian.png](../../../assets/forest_bible_v2/native/fine_32/guardian.png)。与旧thorn_guardian同一guardian.png、相同72×96绘制bounds；独有机制在独立Bell Node，未找到单独V2身体动作页。

原始母版与来源：
- [assets/forest_bible_v2/native/fine_32/boss_beetle_master_original.png](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_master_original.png) · 
- [assets/forest_bible_v2/native/fine_32/boss_beetle_generation.json](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_generation.json) · 
- [assets/forest_bible_v2/native/fine_32/boss_beetle_build.json](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_build.json) · 
- [docs/quality/asset_records/fine-space-05-forest-boss-beetle.json](../../quality/asset_records/fine-space-05-forest-boss-beetle.json) · 
- [assets/forest_bible_v2/source/native_guardian_v1/provenance.json](../../../assets/forest_bible_v2/source/native_guardian_v1/provenance.json) · 
- [docs/quality/asset_records/forest-bible-v2-rootbell-guardian-v1.json](../../quality/asset_records/forest-bible-v2-rootbell-guardian-v1.json) · 

准入与动作事实：

{"class": "current_forest_v2_map1_candidate_default", "evidence": ["scripts/generation/thorn_forest_region_generator.gd:VERSION/_boss_paths", "docs/design/rootbell_guardian_v2.md:3/58"], "note": "当前森林v2/v15 map1运行入口；设计页明确局部限定接受及非商业/全Boss/设备准入，不能抹平为8个同等成品。"}

{"type": "single_static_fine_body_plus_shared_code_mesh", "primary_condition": "forest_bible_actor_art + RootbellGuardianV2 + stable_id=rootbell_guardian_v2 + collision72×96", "fallback": "条件不满足时仍为程序矩形/树臂，不把fallback当独立素材", "dedicated_attack_hurt_death_sequence_found": false}

缺失／未知：
- 专卡与机制历史存在；独立身体原画/逐动作分镜/专属动作序列未找到。
- 绘制Bell共享机关素材，不能由可抛掷/可返击行为推导有独立VFX素材包。

## 织网女王V2 `thorn_queen_v2`

设计资料：
- [docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md](../../creative_direction/bibles/2-thorn_forest_region_bible_v2.md) · §9棘冠女王
- [docs/design/thorn_queen_v2.md](../../design/thorn_queen_v2.md) · §历史/核心交互/几何/持续网络/入口保存
- [docs/evidence/forest_depth_v2/queen_design_history/design-through30.md.txt](../../evidence/forest_depth_v2/queen_design_history/design-through30.md.txt) · 历史设计归档
- [docs/design/story/boss_narratives.md](../../design/story/boss_narratives.md) · §16区主Boss与第一图定位
- [docs/worklines/enemy_all_02/boss-production-cards.md](../enemy_all_02/boss-production-cards.md) · §场景制作卡 / §实际绑定与不变接口

当前身体：[assets/forest_bible_v2/native/fine_32/queen.png](../../../assets/forest_bible_v2/native/fine_32/queen.png)。与Canopy使用完全同一queen.png与相同(-36,-39,72,68)bounds；无Weave独有当前身体母版。

原始母版与来源：
- [assets/forest_bible_v2/native/fine_32/boss_beetle_master_original.png](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_master_original.png) · 
- [assets/forest_bible_v2/native/fine_32/boss_beetle_generation.json](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_generation.json) · 
- [assets/forest_bible_v2/native/fine_32/boss_beetle_build.json](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_build.json) · 
- [docs/quality/asset_records/fine-space-05-forest-boss-beetle.json](../../quality/asset_records/fine-space-05-forest-boss-beetle.json) · 
- [assets/forest_bible_v2/source/native_queen_v1/provenance.json](../../../assets/forest_bible_v2/source/native_queen_v1/provenance.json) · 

准入与动作事实：

{"class": "historical_weave_candidate_pin_not_current_map2", "evidence": ["docs/design/thorn_queen_v2.md:1-9/86", "scripts/generation/thorn_forest_region_generator.gd:_boss_paths"], "note": "旧迁巢织场/Def6/schema13；整体设计页写未通过，保留历史pin/旧layout replay；当前v15 map2用Canopy，不能当新增第9物种或同等正式准入。"}

{"type": "single_reused_static_fine_body_plus_shared_code_mesh", "dedicated_attack_hurt_death_sequence_found": false, "replacement_fact": "此前菱形/枝臂为代码；现复用Canopy同族静态图，非新增动作序列。"}

缺失／未知：
- 有机制设计专卡和大量历史版本，但未找到Weave独有身体原画/完整动作资产或声效套件。
- 共享Knot/Band的3网机制与Canopy两网机制不同；共用实现或图不能代替独立内容资料。

## 棘冠女王V3 `thorn_queen_canopy`

设计资料：
- [docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md](../../creative_direction/bibles/2-thorn_forest_region_bible_v2.md) · §9.1视觉角色 / §9.2三阶段 / §12音频
- [docs/design/thorn_queen_canopy_v3.md](../../design/thorn_queen_canopy_v3.md) · §身份 / §身体四段闭环 / §受伤恢复 / §证据边界
- [docs/evidence/forest_depth_v2/queen_canopy_movies/README.md](../../evidence/forest_depth_v2/queen_canopy_movies/README.md) · 历史两影片
- [docs/design/story/boss_narratives.md](../../design/story/boss_narratives.md) · §16区主Boss与第一图定位
- [docs/worklines/enemy_all_02/boss-production-cards.md](../enemy_all_02/boss-production-cards.md) · §场景制作卡 / §实际绑定与不变接口

当前身体：[assets/forest_bible_v2/native/fine_32/queen.png](../../../assets/forest_bible_v2/native/fine_32/queen.png)。与旧Queen、Weave共享queen.png；与Weave同尺寸基准，旧Queen仅2×/接地基准不同。

原始母版与来源：
- [assets/forest_bible_v2/native/fine_32/boss_beetle_master_original.png](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_master_original.png) · 
- [assets/forest_bible_v2/native/fine_32/boss_beetle_generation.json](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_generation.json) · 
- [assets/forest_bible_v2/native/fine_32/boss_beetle_build.json](../../../assets/forest_bible_v2/native/fine_32/boss_beetle_build.json) · 
- [docs/quality/asset_records/fine-space-05-forest-boss-beetle.json](../../quality/asset_records/fine-space-05-forest-boss-beetle.json) · 
- [assets/forest_bible_v2/source/native_queen_v1/provenance.json](../../../assets/forest_bible_v2/source/native_queen_v1/provenance.json) · 
- [docs/quality/asset_records/forest-bible-v2-thorn-queen-v1.json](../../quality/asset_records/forest-bible-v2-thorn-queen-v1.json) · 

准入与动作事实：

{"class": "current_forest_v2_v15_map2_candidate_default", "evidence": ["scripts/generation/thorn_forest_region_generator.gd:CURRENT_DEPTH_LAYOUT/_boss_paths", "docs/design/thorn_queen_canopy_v3.md:3-5"], "note": "当前森林v2/v15 map2运行入口；专卡允许有限产品整合并明确整体品质/H核心仍REVISE，不能等同用户制作质量认可。"}

{"type": "single_static_fine_body_plus_shared_code_mesh", "primary_condition": "forest_bible_actor_art + stable_id=thorn_queen_canopy_v3 + collision48×54", "fallback": "非正式metadata/identity时仍为程序冠形身体", "dedicated_attack_hurt_death_sequence_found": false}

缺失／未知：
- 设计有视觉文字/机制专卡；当前72×68身体无独立巡游/蓄势/受伤/冠刺终结逐帧页。
- 未找到终结冠刺缓落/林间和声的独立制作分镜与专属完整素材包；不据文字设计推定实现。
