# 平原逐怪资料与素材

快照 310c0421e18829088a4d2208c5f1b6cba3db35dc。这是被拒候选的事实盘点，不是品质通过；当前=代码分支选择，未在本轮启动游戏复核。完整证据、行号、裁区、来源见[原始审计JSON](plains-inventory.json)。

## 巡逻怪 `patrol_drone`

未发现按该stable_id建立独立Enemy Sheet；设计散落共用/地区/行为章节

- [docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md) · 原Bible为四类生态外观/行为，未在原文映射这7个stable_id
- [docs/creative_direction/README.md](../../creative_direction/README.md) · 地区共同制作入口
- [docs/creative_direction/windchime_plains.json](../../creative_direction/windchime_plains.json) · creative-v21区域总谱
- [docs/enemies_and_bosses.md](../../enemies_and_bosses.md) · 共用Actor/伤害/表现所有权
- [docs/plains_enemy_behaviors.md](../../plains_enemy_behaviors.md) · D070三类行为历史设计
- [docs/worklines/enemy_all_02/plains-production-cards.md](../enemy_all_02/plains-production-cards.md) · 本轮共用表，非每物种完整单卡
- [docs/enemy_art.md](../../enemy_art.md) · 旧SVG素材说明，并非当前scene实际源

| 绘制链 | 活体实际素材 | 动作方式 | 受伤 | 死亡 |
| --- | --- | --- | --- | --- |
| scene | [assets/plains_v3/enemies/meadow_actions/beetle.png](../../../assets/plains_v3/enemies/meadow_actions/beetle.png) | 静态idle_a母版+PlainsMotion02连续UV关节；不播放原manifest的idle_b/telegraph/attack/recovery格 | 同idle_a母版，accepted tint/程序局部recoil | 单独death格+原整体压扁/alpha下限0.18，无独立多帧D序列 |
| underworld | [assets/underworld_plains/actors/patrol.png](../../../assets/underworld_plains/actors/patrol.png) | source_enemies原板裁切并nearest缩至33–40px上下的单张PNG；PlainsMotion02静图连续UV网格关节 | 同单张PNG+接受事件tint及局部recoil | 同PNG下沉+父PixelPlainsEnemy .65s淡出；无独立D图/持久尸体 |

资料／素材断层：
- 源图确有6格，但当前只选择idle_a/death两格；idle_b、telegraph、attack、recovery未消费。历史D070/README“六姿态播放”不能代表现源。

## 冲锋怪 `plains_charger`

有专卡但历史版本须分读

- [docs/design/enemies/plains_charger.md](../../design/enemies/plains_charger.md) · 历史ENEMY-CONTINUITY-01专卡，版本charger-audit-v1；不是现源运行规格
- [docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md) · 原Bible为四类生态外观/行为，未在原文映射这7个stable_id
- [docs/creative_direction/README.md](../../creative_direction/README.md) · 地区共同制作入口
- [docs/creative_direction/windchime_plains.json](../../creative_direction/windchime_plains.json) · creative-v21区域总谱
- [docs/enemies_and_bosses.md](../../enemies_and_bosses.md) · 共用Actor/伤害/表现所有权
- [docs/plains_enemy_behaviors.md](../../plains_enemy_behaviors.md) · D070三类行为历史设计
- [docs/worklines/enemy_all_02/plains-production-cards.md](../enemy_all_02/plains-production-cards.md) · 本轮共用表，非每物种完整单卡

| 绘制链 | 活体实际素材 | 动作方式 | 受伤 | 死亡 |
| --- | --- | --- | --- | --- |
| scene | [assets/enemy_feedback_01/frames_v8/legacy_charger.png](../../../assets/enemy_feedback_01/frames_v8/legacy_charger.png) | H3同一中性姿态作为live母版，PlainsMotion02连续UV网格关节变形；没有独立行走/攻击/转向绘制序列 | 0.32s绘制四个源姿态+同一网格关节/闪色；不是四张独立文件 | 原4死亡姿态，Stage兄弟Remains支撑/落地后D7持久尸体；非live网格死亡 |
| underworld | [assets/enemy_feedback_01/frames_v8/underworld_charger.png](../../../assets/enemy_feedback_01/frames_v8/underworld_charger.png) | H3同一中性姿态作为live母版，PlainsMotion02连续UV网格关节变形；没有独立行走/攻击/转向绘制序列 | 0.32s绘制四个源姿态+同一网格关节/闪色；不是四张独立文件 | 原4死亡姿态，Stage兄弟Remains支撑/落地后D7持久尸体；非live网格死亡 |

资料／素材断层：
- 有4H+4D，不等于待机/走动/转向/预警/攻击/恢复各有独立帧序列；live实际借用受伤末姿态H3。
- 专卡charger-audit-v1仍描述旧charger.png live及H→旧PNG回接；当前代码已改H3 live。应作为历史审计原件保留，不能直接视为现源制作规格。

## 俯冲怪 `plains_diver`

未发现按该stable_id建立独立Enemy Sheet；设计散落共用/地区/行为章节

- [docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md) · 原Bible为四类生态外观/行为，未在原文映射这7个stable_id
- [docs/creative_direction/README.md](../../creative_direction/README.md) · 地区共同制作入口
- [docs/creative_direction/windchime_plains.json](../../creative_direction/windchime_plains.json) · creative-v21区域总谱
- [docs/enemies_and_bosses.md](../../enemies_and_bosses.md) · 共用Actor/伤害/表现所有权
- [docs/plains_enemy_behaviors.md](../../plains_enemy_behaviors.md) · D070三类行为历史设计
- [docs/worklines/enemy_all_02/plains-production-cards.md](../enemy_all_02/plains-production-cards.md) · 本轮共用表，非每物种完整单卡

| 绘制链 | 活体实际素材 | 动作方式 | 受伤 | 死亡 |
| --- | --- | --- | --- | --- |
| scene | [assets/enemy_feedback_01/frames_v8/legacy_diver.png](../../../assets/enemy_feedback_01/frames_v8/legacy_diver.png) | H3同一中性姿态作为live母版，PlainsMotion02连续UV网格关节变形；没有独立行走/攻击/转向绘制序列 | 0.32s绘制四个源姿态+同一网格关节/闪色；不是四张独立文件 | 原4死亡姿态，Stage兄弟Remains支撑/落地后D7持久尸体；非live网格死亡 |
| underworld | [assets/enemy_feedback_01/frames_v8/underworld_diver.png](../../../assets/enemy_feedback_01/frames_v8/underworld_diver.png) | H3同一中性姿态作为live母版，PlainsMotion02连续UV网格关节变形；没有独立行走/攻击/转向绘制序列 | 0.32s绘制四个源姿态+同一网格关节/闪色；不是四张独立文件 | 原4死亡姿态，Stage兄弟Remains支撑/落地后D7持久尸体；非live网格死亡 |

资料／素材断层：
- 有4H+4D，不等于待机/走动/转向/预警/攻击/恢复各有独立帧序列；live实际借用受伤末姿态H3。

## 跃击怪 `plains_hopper`

未发现按该stable_id建立独立Enemy Sheet；设计散落共用/地区/行为章节

- [docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md) · 原Bible为四类生态外观/行为，未在原文映射这7个stable_id
- [docs/creative_direction/README.md](../../creative_direction/README.md) · 地区共同制作入口
- [docs/creative_direction/windchime_plains.json](../../creative_direction/windchime_plains.json) · creative-v21区域总谱
- [docs/enemies_and_bosses.md](../../enemies_and_bosses.md) · 共用Actor/伤害/表现所有权
- [docs/plains_enemy_behaviors.md](../../plains_enemy_behaviors.md) · D070三类行为历史设计
- [docs/worklines/enemy_all_02/plains-production-cards.md](../enemy_all_02/plains-production-cards.md) · 本轮共用表，非每物种完整单卡
- [docs/plains_interactive_platforms.md](../../plains_interactive_platforms.md) · 玩法按人类标签描述；没有stable_id专卡

| 绘制链 | 活体实际素材 | 动作方式 | 受伤 | 死亡 |
| --- | --- | --- | --- | --- |
| scene | [assets/plains_v3/enemies/meadow_actions/beetle.png](../../../assets/plains_v3/enemies/meadow_actions/beetle.png) | 静态idle_a母版+PlainsMotion02连续UV关节；不播放原manifest的idle_b/telegraph/attack/recovery格 | 同idle_a母版，accepted tint/程序局部recoil | 单独death格+原整体压扁/alpha下限0.18，无独立多帧D序列 |
| underworld | [assets/underworld_plains/actors/hopper.png](../../../assets/underworld_plains/actors/hopper.png) | source_enemies原板裁切并nearest缩至33–40px上下的单张PNG；PlainsMotion02静图连续UV网格关节 | 同单张PNG+接受事件tint及局部recoil | 同PNG下沉+父PixelPlainsEnemy .65s淡出；无独立D图/持久尸体 |

资料／素材断层：
- 源图确有6格，但当前只选择idle_a/death两格；idle_b、telegraph、attack、recovery未消费。历史D070/README“六姿态播放”不能代表现源。

## 炮哨 `plains_sentry`

未发现按该stable_id建立独立Enemy Sheet；设计散落共用/地区/行为章节

- [docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md) · 原Bible为四类生态外观/行为，未在原文映射这7个stable_id
- [docs/creative_direction/README.md](../../creative_direction/README.md) · 地区共同制作入口
- [docs/creative_direction/windchime_plains.json](../../creative_direction/windchime_plains.json) · creative-v21区域总谱
- [docs/enemies_and_bosses.md](../../enemies_and_bosses.md) · 共用Actor/伤害/表现所有权
- [docs/plains_enemy_behaviors.md](../../plains_enemy_behaviors.md) · D070三类行为历史设计
- [docs/worklines/enemy_all_02/plains-production-cards.md](../enemy_all_02/plains-production-cards.md) · 本轮共用表，非每物种完整单卡

| 绘制链 | 活体实际素材 | 动作方式 | 受伤 | 死亡 |
| --- | --- | --- | --- | --- |
| scene | [assets/plains_v3/enemies/meadow_actions/sentry.png](../../../assets/plains_v3/enemies/meadow_actions/sentry.png) | 静态idle_a母版+PlainsMotion02连续UV关节；不播放原manifest的idle_b/telegraph/attack/recovery格 | 同idle_a母版，accepted tint/程序局部recoil | 单独death格+原整体压扁/alpha下限0.18，无独立多帧D序列 |
| underworld | [assets/underworld_plains/actors/sentry.png](../../../assets/underworld_plains/actors/sentry.png) | source_enemies原板裁切并nearest缩至33–40px上下的单张PNG；PlainsMotion02静图连续UV网格关节 | 同单张PNG+接受事件tint及局部recoil | 同PNG下沉+父PixelPlainsEnemy .65s淡出；无独立D图/持久尸体 |

资料／素材断层：
- 源图确有6格，但当前只选择idle_a/death两格；idle_b、telegraph、attack、recovery未消费。历史D070/README“六姿态播放”不能代表现源。

## 扇形炮哨 `plains_fan_sentry`

未发现按该stable_id建立独立Enemy Sheet；设计散落共用/地区/行为章节

- [docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md) · 原Bible为四类生态外观/行为，未在原文映射这7个stable_id
- [docs/creative_direction/README.md](../../creative_direction/README.md) · 地区共同制作入口
- [docs/creative_direction/windchime_plains.json](../../creative_direction/windchime_plains.json) · creative-v21区域总谱
- [docs/enemies_and_bosses.md](../../enemies_and_bosses.md) · 共用Actor/伤害/表现所有权
- [docs/plains_enemy_behaviors.md](../../plains_enemy_behaviors.md) · D070三类行为历史设计
- [docs/worklines/enemy_all_02/plains-production-cards.md](../enemy_all_02/plains-production-cards.md) · 本轮共用表，非每物种完整单卡
- [docs/plains_interactive_platforms.md](../../plains_interactive_platforms.md) · 玩法按人类标签描述；没有stable_id专卡

| 绘制链 | 活体实际素材 | 动作方式 | 受伤 | 死亡 |
| --- | --- | --- | --- | --- |
| scene | [assets/plains_v4/spatial/actors.png](../../../assets/plains_v4/spatial/actors.png) | 先命中actor.definition.aerial分支：完整单图整体bob/倾斜/_weight缩放；绕开_draw_action_frame及PlainsMotion02.draw_body | 原图+EnemyHitTemplate染色/反馈姿态；没有独立H图 | 同一aerial区域，整体压扁/变色，alpha下限0.18；无独立D图或Remains。aerial tilt仍有sin(_clock*2)项 |
| underworld | [assets/underworld_plains/actors/aerial.png](../../../assets/underworld_plains/actors/aerial.png) | source_enemies原板裁切并nearest缩至33–40px上下的单张PNG；PlainsMotion02静图连续UV网格关节 | 同单张PNG+接受事件tint及局部recoil | 同PNG下沉+父PixelPlainsEnemy .65s淡出；无独立D图/持久尸体 |

资料／素材断层：
- fan_sentry默认及正式生成aerial=true，原scene实际飞行机静图分支，不消费meadow_actions/sentry姿态；PlainsMotion02虽advance、虽有fan分支，该scene绘制绕开它。本轮共用卡“与sentry同炮哨母版”描述不符实际。

## 根铃怪 `plains_root_bell`

有专卡但历史版本须分读

- [docs/quality/region_production_v3/root_bell_design.md](../../quality/region_production_v3/root_bell_design.md) · 独立敌人设计、外观、状态、玩家策略、资产请求
- [docs/quality/region_production_v3/root_bell_encounter_v2_card.md](../../quality/region_production_v3/root_bell_encounter_v2_card.md) · 遭遇制作/修复合同
- [docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md) · 原Bible为四类生态外观/行为，未在原文映射这7个stable_id
- [docs/creative_direction/README.md](../../creative_direction/README.md) · 地区共同制作入口
- [docs/creative_direction/windchime_plains.json](../../creative_direction/windchime_plains.json) · creative-v21区域总谱
- [docs/enemies_and_bosses.md](../../enemies_and_bosses.md) · 共用Actor/伤害/表现所有权
- [docs/plains_enemy_behaviors.md](../../plains_enemy_behaviors.md) · D070三类行为历史设计
- [docs/worklines/enemy_all_02/plains-production-cards.md](../enemy_all_02/plains-production-cards.md) · 本轮共用表，非每物种完整单卡

| 绘制链 | 活体实际素材 | 动作方式 | 受伤 | 死亡 |
| --- | --- | --- | --- | --- |
| scene_raw_fallback | [assets/plains_refresh/objects.png](../../../assets/plains_refresh/objects.png) | 行为不在_draw_action_frame白名单，落通用enemy_left/enemy_right；整体bob/_weight缩放，不调用PlainsMotion02.draw_body | 通用图染色/变形 | 同通用活图压扁/变色，alpha下限0.18，无独立D格 |
| underworld | [assets/underworld_plains/actors/root_bell.png](../../../assets/underworld_plains/actors/root_bell.png) | source_enemies原板裁切并nearest缩至33–40px上下的单张PNG；PlainsMotion02静图连续UV网格关节 | 同单张PNG+接受事件tint及局部recoil | 同PNG下沉+父PixelPlainsEnemy .65s淡出；无独立D图/持久尸体 |
| root_bell_independent | [assets/region_production_v3/enemies/root_bell/source/master.png](../../../assets/region_production_v3/enemies/root_bell/source/master.png) | 固定idle母版+根枝程序关节 | 同idle格+tint/局部recoil；manifest的hurt格未选择 | death格+0.8s淡出，无持久尸体 |

资料／素材断层：
- 原始scene raw链显示通用旧甲虫图，不是独立芦铃设计，也不调用root关节mesh。正常GeneratedDemoStage会先换独立RootBellPresentation，正式Underworld又会替换为UnderworldEnemy，三条不可混称同素材。
