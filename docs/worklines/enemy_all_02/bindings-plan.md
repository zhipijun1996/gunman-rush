# ENEMY-ALL-02：局部素材绑定与原守门计划

本文是只读源码核对后的制作计划，不是执行报告。基线为 `20e67867b272a7e461eddce169a0cdb83353f4b6`，工作分支 `feature/enemy-completion-02`。本次没有改 registry、Bible、风格 SHA、测试或运行实现，没有执行 Godot 或签署 PASS。实现与录制由 root 持单引擎租约组织；源码未冻结前不生产最终收据。

## 结论与适用方向

保留 **style-v18 / creative-v21** 的原字节与现有 **81** 个 role/path/SHA 引用。逐项核对发现，这 81 条没有 `UnderworldEnemy`、`EnemyPresentation`、`EnemyFeedback01*`、森林 enemy presentation 或 Boss presentation。仅改这些表现叶和它们的新图，不会触发旧引用漂移，**本轮不新增全局风格版本**。用本任务局部实际消费者／素材合同及当前截图、连续实机视频补足追溯。

局部合同应引用既定方向，而不重新选择方向：共享 32px/32wu 地形、角色世界 1wu/nearest、Underworld 轮廓／材质家族；平原按原 Bible 第5–6章生态和旧黄铜机械识别，森林按原 Bible 第7–9章有机根枝／苔藓／荆棘及活锚识别。两份原 Bible 不修改。本轮内容仍须独立看合屏，旧方向认可不签新怪物审美、完整动画或设备认可。五首原 BGM 与当前正式音效选择沿 AGENTS 当前条款保留。

当前参考：

- style-v18：`docs/creative_direction/bibles/style-continuity-20261028-v18-chest-art.json`，SHA `22c2afbb1a298bfbb5f72315b4f60aefc9ae377a6c93bc47780ef6ae4f0a7510`。
- registry：`docs/creative_direction/bibles/registry.json`，SHA `de601eecbbae88f1b426fa76f7c596723db676c6dd5e2585fbc1df2fb62ef44d`。
- 平原原 Bible SHA `02c9dd3299d12c91a426cf40b2a5885e526b51f467b955539b4b5ff99e1aca35`；森林原 Bible SHA `a7bad8323af64a7be0577132e5d988a6e1b781d9e1ac1639d37f9d65935194e3`。
- 两区 creative-v21 的 region_bible 同时绑定原 Bible、registry、style-v18。其 authority_sources 没有本轮上述怪物表现叶。

若实际实现扩大到 `plains_region_stage.gd`、`demo_app.gd`、`thorn_forest_region_stage.gd`、`forest_bible_presentation.gd`、`underworld_presentation.gd` 或任一既有81路径，必须先重新列差异与影响，不能直接刷新 SHA。`forest_bible_actor_presentation.gd` 和 `forest_bible_presentation.gd` 是不同文件；前者当前不在81引用中。

## 新素材的最小正确绑定

1. 原始生成 PNG 保存完整原字节；保存真实 prompt、工具与可见 model 字段、生成结果路径和 SHA。未暴露的字段写 `not_exposed`。保留原生成与失败记录，不把旧图重登记为新生成，也不把程序性旧 SVG 当新成品图。
2. 新家族使用独立版本目录／明确 manifest，逐 species/skin 写真实整数裁切、固定家族比例、接地点／身体轴锚点和状态映射；同一角色所有姿态引用同一母版。局部动作可引用现有素材而不修改其旧 provenance。局部合同须记录实际 presenter → loader → manifest → 每张真实 PNG → material/shader 的边；只写图目录或源清单不等于消费者闭包。
3. **优先 literal finite references**：loader 中每张图用明确 `preload("res://assets/…/actual.png")`，manifest 用明确完整文件路径。现有 `EnemyFeedback01Frames.TEXTURES` 四条 preload 和 `MANIFEST_PATH` 已是正确范例；scanner 能识别，无需更新全局有限 adapter。
4. 为每张新增／改动运行 PNG 新建 `docs/quality/asset_records/enemy-all-02-*.json`，包含实际 `source_path/source_sha256/runtime_paths`、`task_id=ENEMY-ALL-02`、新 `content_version`、工具／prompt／processing／usage_scope／license_source。实际被运行代码读取的 manifest 也要运行登记；只把它放 `associated_files` 的 source_contract 角色不能覆盖真实 runtime provenance。纯 provenance、原prompt或未读取的审计 JSON 可做带 SHA 的 associated_files。未采用生成图用 `production_record_only` 或 `rejected_evidence_only`、空 runtime_paths 和明确原因。
5. `consumer_scripts` 要写真实 loader，另由局部合同和实际场景证据证明真正被画出。**当前 validate_asset 不校验 consumer_scripts 的可达性**；该字段填好不是实际消费证明。`runtime_candidate` + `visual_status=unverified` 可诚实登记新候选；`visual_status=passed` 需要 verified license 和实际 user_acceptance_evidence，不能靠 AI 自评签署。
6. 任何改变了已登记 source 或 associated_file 的字节，都使旧 asset_record 失效；推荐新增家族版本与记录，保留旧记录和原图，而非覆盖旧文件导致历史来源失真。全部改动 assets（除 .import/.uid）需被有效 provenance 覆盖。
7. 若坚持新动态 `%s`／目录／manifest拼接加载，先补真正的有限 adapter：校验精确 loader 身份、有限 manifest 结构及逐文件安全路径、存在性／SHA、atlas尺寸／裁切界限／锚点和预算，并保留原 consumer tests／拒绝负例。仅新增 asset_record 不能解决 scanner 的 `Unresolved asset reference needs finite consumer adapter`。当前 `EnemyPresentation` 的 meadow_actions 目录已有特定旧适配，这不授权任意新目录。新作建议用第3步，避免增加全局 adapter维护。

## 局部源合同与制作卡的证据字段

在素材和实现冻结后生成本任务实际 source-contract（本计划不代生成最终 SHA）：精确实现 commit、当前已选style/Bible引用、逐 renderer 的 scene／definition／presenter／helper／素材／shader、当前SHA及状态适用范围。任何源码变更后重新录制受影响片段；不要重用旧 commit 的通过作为新源通过。

制作卡按每个实际 renderer 链分别记录移动→前摇／攻击→受伤→恢复当前相位→死亡→留尸或原死亡政策。针对冲锋与俯冲，重点核对 H退出时轮廓／背部齿轮／肢体身份、相同 contact anchor、面对方向、当前脑状态，以及移动／攻击中受伤而非仅 idle fixture。全体 Boss 保留原死亡政策并显式写适用／不适用理由，不能因普通怪留尸要求覆写奖励、阶段或卸载行为。

每段视频注明正式安装器／显式fixture、真实 AI 与输入／真实发射物或直接 Damageable case、seed/manifest、影片时长/fps/帧数、trace行数、真实 accepted 事件及 terminal 次数、恢复状态、尸体观察尾段；导演静态比较应看真实截图和连续关键帧。不得把调试fixture称自然路线或以单个renderer代表全部物种；未覆盖的 attack、台面、暂停、恢复、设备和自然遭遇分别记未验证。

## 原检查集合与预算

以下是原入口核对，不代表已执行。最终选集以 `tools/production_plan.py --stage development|integration --base 20e67867b272a7e461eddce169a0cdb83353f4b6` 的实际依赖计划为起点，保留 AGENTS 当前素材变动的 art/gameplay 以及 docs 守门。阶段检查可以选择受影响集合；不删原断言、不提高预算。full profile 原165项保持不变。

| 入口／检查 | 原预算与边界 |
| --- | --- |
| `creative-direction` | 30s，`tools/region_creative_direction.py --directory docs/creative_direction` |
| `creative-direction-tests` | 60s，原10 unittest方法 |
| `region-bible-contract` | 30s，`--check-bibles`；24有限输入 |
| `region-bible-tests` | 30s，原32 unittest方法；294有限输入前缀保持 |
| `enemy-feedback-native` / `enemy-feedback-formal` / `enemy-corpse-save` | 各Harness360s；原wrapper每次90s import + 对应240s runner |
| `enemy-feedback-support` / `enemy-corpse-snapshot` | 各Harness300s；原wrapper90s import + 对应180s runner |
| `forest-depth-enemies` | Harness300s，默认golden包含实际森林反馈35断言完成标记和意外error/warning拒绝 |
| `forest-depth-guardian` | Harness300s，现有rootbell局部实际机制 |
| `forest-depth-queen` / `forest-depth-queen-canopy` | 各Harness240s，原Queen/canopy验证与源码／验证器before-after guard |
| `underworld-continuous-bosses` | Harness360s，`run_underworld_r3_boss_tests.py --full-fights`，实际App两Boss完整战斗 |
| `art-meadow_enemy_art` | 120s；仅旧meadow_actions素材的原SHA／alpha／整数crop／锚脚／distinct姿态，不自动验证新atlas |
| `tools/run_tests.py` | 90s import + 540s原core runner，包含原enemy_tests与boss_tests；不能将单独加载文件误称完整core通过 |
| `tests/enemy_hit_template_tests.gd` / `tests/enemy_hit_template_pixels.gd` | 现有独立runner，未发现专用Harness check注册；应由root按现有包装／真实退出码和完整标记执行，记录实际独立范围，不能伪称已在docs或五feedback中执行 |
| `capture_enemy_feedback_01_remains.py` | 原捕获300s、编码90s、ffprobe30s；source_stable要求git_metadata before/after一致，单引擎／冻结源码后录制 |
| `python3 tools/harness.py --profile docs --release --jobs 1` | 原33项文档与纯工具守门；不等于画面／运行验收 |
| `python3 tools/check_quality_diff.py --base <base>` | 覆盖全部changed生产、有效asset provenance、finite consumer、已完成记录 reviewed_commit字节及原测试guard变化 |

五feedback checks目前仅严格验证 charger/diver 两种、legacy/underworld两链与原H0–3/D4–7语义：8个实际不同pixel payload、source/bounds对应、accepted事件、暂停、epoch、终态、支持面与静态保存恢复。不要为新动画方便抹掉原框架断言、放宽8帧独特性或把新增species自动纳入原sample supports导致旧fixture覆盖含义变更。新的全怪物运动／转场覆盖用新driver和额外验证。

## 冻结历史与防止错误归因

style-v18当前81引用不含上述叶，所以这次保持它们不变时，原32＋10不需要迁移冻结断言。若未来扩大引用范围，原测试包含明确 version18/count81、旧73+8关系、旧Home／首版18／input修复源原件比较及旧creative版本拒绝；必须保留历史阶段的原SHA、原负例和预算，新增当前局部契约不回写旧历史证明。

`forest-depth-crossbranch-lifecycle` 虽在当前Harness中保留（300s），wrapper明确把 lifecycle／root_entry／expedition视作**历史v10坐标fixture**；可作为原策略的局部回归，不能称当前v15自然路线证明。其他已移入 `legacy-compat` 的历史回放按AGENTS当前授权延期，未跑记deferred/unverified；当前保存、资源、物理、manifest和实际消费者仍须守门。不得把历史fixture不匹配通过改旧源hash“修成通过”。

捕获及森林／Boss wrappers的 source before/after 是防止**录制期间变源**，不是让新怪物继承旧视觉通过。任何新录制应在团队停止写实现后进行，收据保持真实；现有失败原件保留。`check_quality_diff` 对旧测试guard被删改还会要求 `independent_review=passed` 及 `test_change_justification`；本轮尽量不改旧测试而追加独立当前覆盖。

当前状态：计划完成，实际素材／实现／新source-contract／各项验证与影片待冻结源后由root执行。本文件不能用作G3/G4/G5或用户／设备PASS。
