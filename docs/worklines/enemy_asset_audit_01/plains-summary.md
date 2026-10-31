# 平原7种资料与素材事实审计

源：`310c0421e18829088a4d2208c5f1b6cba3db35dc`。只读盘点；未运行Godot、未生成/改图、未改skills或仓库。已按HEAD全树核对，相关78文件均有本地原件，不把sparse缺失当不存在。最新用户已拒绝上一轮成品质量，本表不代签美术。

| 对象 | 设计资料 | 原scene实际L/H/D | Underworld实际L/H/D |
| --- | --- | --- | --- |
| patrol | 初代契约散在enemies_and_bosses/旧enemy_art；无独立现源单卡 | meadow beetle：idle_a网格 / 同图反馈 / death单格 | patrol.png静图网格 / 同图反馈 / 同图下沉淡出 |
| charger | 有plains_charger历史专卡；ENEMY-ALL-02共用卡 | legacy_charger：H3网格 / H0–3四姿态 / D4–7四姿态留尸 | underworld_charger：H3网格 / H0–3 / D4–7留尸 |
| diver | D070/反馈专线散落章节；无独立Enemy Sheet | legacy_diver：H3网格 / H0–3 / D4–7留尸 | underworld_diver：H3网格 / H0–3 / D4–7留尸 |
| hopper | D081跃扑守卫/共用卡；无独立Enemy Sheet | 共享meadow beetle：idle_a网格 / 同图反馈 / death单格 | hopper.png静图网格 / 同图反馈 / 同图下沉淡出 |
| sentry | D070草籽哨兵/共用卡；无独立Enemy Sheet | meadow sentry：idle_a网格 / 同图反馈 / death单格 | sentry.png静图网格 / 同图反馈 / 同图下沉淡出 |
| fan_sentry | D081船上扇射/共用卡；无独立Enemy Sheet | aerial=true：spatial/actors.png drone区，整体bob/tilt；H/D均同图，没有mesh绘制 | aerial=true：aerial.png，不是sentry.png；网格/同图反馈/下沉淡出 |
| root_bell | 有root_bell_design/encounter_v2专门合同；共用卡 | rawscene落plains_refresh/objects.png通用enemy_left/right；H/D同图，无root关节mesh | root_bell.png静图网格/同图反馈/下沉淡出 |

L=活体、H=受伤、D=死亡；“网格”是单母版程序关节，不是独立绘制运动序列。各源真实路径/行号/尺寸/SHA/分支/manifest裁切在同名JSON。

## 最需一起核对的资料断层

1. **有动作格却未消费。** `assets/plains_v3/enemies/meadow_actions/{beetle,sentry}.png`各6格，当前地面legacy只选idle_a/death；idle_b、telegraph、attack、recovery四格不播放。`EnemyPresentation._draw_action_frame`直接选两键，历史README与D070六姿态说明不能当当前播放事实。
2. **fan名和最终分支不同。** `plains_fan_sentry.tres`的aerial=true，正式generator也写aerial=true；原scene在`elif actor.definition.aerial`画`assets/plains_v4/spatial/actors.png`的[935,570,580,445]，绕开meadow与PlainsMotion02.draw_body。Underworld先判aerial用`assets/underworld_plains/actors/aerial.png`。本轮平原制作卡第20行“同sentry炮哨母版”与代码不一致。
3. **root三链不是一套身体。** rawscene通用旧甲虫图；GeneratedDemoStage会为root换`RootBellPresentation`；正式Underworld再统一替换`UnderworldEnemy`。独立root源为`assets/region_production_v3/enemies/root_bell/source/master.png`六格，只用idle/death，telegraph/attack/recovery/hurt四格未选；burst原6格只选5格，rise未用。
4. **当前只有charger/diver有独立4H+4D。** 两skin各一张v8 sheet，live又借H3作中性母版。原小charger/aerial PNG仍被读取用于身体尺寸与alpha锚测量，但已不是这两种live实际像素。不能把“读取了原图”称“还在画原图”。
5. **专卡覆盖不均。** HEAD的`docs/design/enemies/`只有plains_charger.md；root_bell另在quality/region_production_v3有完整设计/制作合同；其余是历史行为文档、地区生态和共用表。Bible四类生态没有明确映射到7个stable_id。旧charger专卡是历史冻结审计，并非现源规格。
6. **来源并非同等完整。** Underworld六种原图来自一张source_enemies.png的裁切/nearest缩小。v8 Underworld两张完整原prompt缺失、仅有重建brief；legacy两张有generation-result。model/许可多为unknown/not_exposed。RootBell provenance“project-original”不覆盖asset_record里license_status=unknown。
7. **历史图不能混入本轮产量。** 旧`assets/enemies/plains/*.svg`与`plains_v3/enemies/clockwork_atlas.png`保留；当前7种两链没有画这些SVG/旧无人机键。前者仍有预览/截图工具消费；`visual_development/p1_native/enemy_actions.png`另由candidate配置引用，不能凭名字算现源7种动作素材。

## 主要源码出处

- `scripts/enemies/enemy_presentation.gd:139` — `if feedback_body != null:`。
- `scripts/enemies/enemy_presentation.gd:142` — `elif actor.definition.aerial:`。
- `scripts/enemies/enemy_presentation.gd:163` — `func _draw_action_frame`。
- `scripts/underworld_plains/underworld_enemy.gd:143` — `var key := "aerial"`。
- `scripts/enemies/enemy_feedback_01_frames.gd:71` — `func canonical_live_texture()`。
- `scripts/enemies/root_bell_presentation.gd:84` — `_draw_pose("death"`。
- `scripts/demo/generated_demo_stage.gd:182` — `var presentation := RootBellPresentation.new()`。
- `scripts/demo/plains_region_stage.gd:145` — `UnderworldActors.install(self)`。
- `docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md:125` — `## 5. 怪物生态`。
