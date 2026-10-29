# Plains revision · forest charger support-consumer repair

**限定ACCEPT：本处charger精确支撑位置从旧16wu常量改为真实Definition半高，修复当前森林装配断言；不签森林视觉或完整163回归。** 独立审查者 `/root/revision_r3_review`，只读，没有编辑Game，没有运行Godot/Harness。

实际修复已冻结在HEAD `b479775383c46527096ebc6e4e284924f66ccf48`。对比修复前6a55c5e8，唯一生产delta为 `forest_vertical_expedition.gd` 的一行Definition半高读取和一行row.y表达式替换。独立字节控制把新增行移除、表达式还原后，整个文件与原版本完整字节一致。因此其余row、随机流／抽签、地形、角色数量、id、支撑宽度／巡逻半径边界、原assert与掉落调用均没有顺便变化。

## 实际失败与修复原因

原163检查attempt02执行35项：34passed，generated-consumers失败，后128未执行。失败日志实际到 `tests/avatar_presentation_ownership_runner.gd` 创建forest_v14，原 `_ecology` 脚底assert失败；原始backtrace与归档report已读，不称163全部执行或通过。root_catch_charger行用support.y−16，当前charger实际collision28wu高、half14，脚底差2wu；原assert正确拒绝，不能降低其<.1阈值。

修复只读取 `resources/enemies/plains_charger.tres` 的实际collision_size.y*.5，使该行按support顶减半高装配；后续仍用同Definition计算half并执行原脚底／横向巡逻边界assert。没有为assert造临时碰撞盒或改平台。旧loop本来就加载同Definition，不新增第二套几何权威。

实际调用链：v14基于v13，v13基于原ThornForestRegionV2，原BASE._candidate调用ForestVerticalExpedition.install；v15基于v14，因此当前v15也继承此生成位置修复。旧冻结历史Manifest不据此追签回放兼容；当前用户授权当前Demo优先。

root随后实际单跑原avatar消费者（定位时fixedfps60），日志 `build/plains-revision-forest-support-01.log`：v14与current_v15两次实际App装配事件均出现，AVATAR OWNERSHIP37／0，音频正常drain，完整日志无script/shader/ObjectDB/resource/RID失败。此为真实局部实现者运行、独审读原日志，**不是原generated-consumers wrapper完整重跑，更不是完整163通过**。原wrapper命令、预算和assert未改。

## 其他charger放置消费者检索

- Forest v7/v9/v10真实_install_encounters均用 `row.floor-definition.collision_size.y*.5` 算ground at，用实际半宽／半高构造sweep与准入边界，原文件未改。
- 当前exploration生态_ground从实际Def推support半高，_row从Def构造体积；ForestExplorationWorld实际调用该生态。模块源虽有旧lower_root_patrol charger槽[624,46]，但生态先清空enemies，槽迭代只接受指定borrow_pod，ground charger另走实际Definition候选，因此不能将该离线模块槽误报为另一个当前old16消费者。
- PlainsWorldRebuild正式spawns已读取实际chargerDef半高；共享创建者用实际Definition配置碰撞。
- 全仓仍有旧通用Plains lane／encounter的−18参考坐标及明示测试／Lab起始位置。它们不是本次charger专用−16精确支撑合同，不能声称“全仓每个charger坐标都由Def脚底推导”，也不应无实际失败就批量改其旧布局语义。本次检索未找到第二处charger专用old16精确支撑常量；其余完整消费者继续由原回归验证。

当前style19/creative Bible JSON检索没有此文件的consumer引用，本次又无美术／shader／原图变化，不需要为物理放置修复重签画风或更新Bible hash。它仍是实际森林生产文件修改，须纳入最终affected_paths／消费者覆盖，不能伪装成纯文档修复。

## 范围

有限delta有正确原assert、真实失败及当前App局部复验，可继续原完整wrapper与163适用检查。未放宽阈值、预算、原生退出守门或地形边界。最终完整回归、森林正常游玩／美术、实体性能与用户认可保持各自证据状态；本报告不扩展本轮美术范围、不要求新生成或重录无依赖的旧影片。

```json
{
  "reviewed_head": "b479775383c46527096ebc6e4e284924f66ccf48",
  "before_commit": "6a55c5e8",
  "original_file_sha256": "8c7b6d4a5ecc9df89d9bb0743be80cfe78b734d187cfd47e3d1277e6a19108e8",
  "current_file_sha256": "3dba0ecaa0f4d1037e6560c5653857de0d0058a15dda16d8a642907c76dacd54",
  "two_line_control_restores_original_bytes": true,
  "sources": {
    "scripts/generation/forest_vertical_expedition.gd": "3dba0ecaa0f4d1037e6560c5653857de0d0058a15dda16d8a642907c76dacd54",
    "scripts/generation/thorn_forest_region_v2_v7.gd": "84f6b1cf29186cfeb90c4139e8d9d305eb6b6c022358d532c25f4bacef26d314",
    "scripts/generation/thorn_forest_region_v2_v9.gd": "5c5acbd73dcbda1f9ccd3a2452b56cff70d53f4518b6de01530913c9f960ff13",
    "scripts/generation/thorn_forest_region_v2_v10.gd": "eb03a34d24079ae22c5b87e635b16ee5d33de05cb496dcbc839e663c2da12acd",
    "scripts/generation/forest_exploration_ecology.gd": "cd9d8b0837a33358bca3bc1e3ec3b18355004e1e27660d9edf275ad25d663897",
    "scripts/generation/forest_exploration_modules.gd": "951123639e721c5f5f422b9c3b1c06bbcd04d9fcb46b4dc82e39cecefc372641",
    "scripts/generation/forest_exploration_world.gd": "28f2a8f3752347268b8d3107a5c5752c8d874134d94267e363d4682b145441ea",
    "scripts/generation/thorn_forest_region_v2.gd": "c449be2883d8590d2db01483889522f5f9b0a1e62e8421733ff71aeeac6185f8",
    "scripts/generation/thorn_forest_region_v2_v13.gd": "890b6ff6fd290f171bce6da7be077f0e1b73d815fab78a358e0ea8384301b088",
    "scripts/generation/thorn_forest_region_v2_v14.gd": "cedc089b4fbb0ac7e31de4bbe545264a9f933c4a90dd3910d4c070f0563cf86f",
    "scripts/generation/thorn_forest_region_v2_v15.gd": "8fbe2f3684dc66c27422819cec873588f82853ecaaa4f9a6bdf2024b39fa01f7",
    "scripts/generation/plains_encounter_planner.gd": "e5ae4edfdd377c63d8632c08acc3fb61898bb644660702b65d64e28d65fa2b30",
    "scripts/generation/plains_region_generator.gd": "3bcece711a322269dbb99e4f6a10e48349da2e5f6eac0f0dae18caf50db154ab",
    "scripts/generation/plains_world_rebuild.gd": "cead8b829ee02461fc281eb9cb2f81e1b1ff8687e8cb5ff34bee93bfb4ea61f9",
    "scripts/demo/generated_demo_stage.gd": "06c0dd58d030cdce64682f0978f969b657b1f8abd4d54de79c8d0b9d84f9fcd3",
    "resources/enemies/plains_charger.tres": "39513bce9f2d604514a88838d733db24b723ce965402ce5579e8260f5a83a232",
    "build/plains-revision-forest-support-01.log": "52a74bc5940fb65d6cc899dfb8f1616f344740c6ed4d76c0bca0f20a94532548",
    "docs/evidence/plains_monster_revision_01/integration/attempt-02/report.json": "f0c281dd7c491f738255d69f6b9c41057abcecf788269ae9c810596f7ada4031",
    "docs/evidence/plains_monster_revision_01/integration/attempt-02/generated-consumers.log": "22ba398fc4c15811d157b09853c0ec3c05c9ad2a49f9ea48394d20f3f5fddfb8"
  }
}
```
