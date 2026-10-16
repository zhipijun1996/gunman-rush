# V3最终57日志终态审计（只读）

57/57原始log，171185B；先本地2个、一次仅抓55个精确小log blob。未物化工作区、未抓PNG/ZIP、未重跑Godot。

**实际可见泄漏：3个check、14个子suite。** region互动平台另有CanvasItem/Area2D/Shape2D RID错误；旧log未verbose，不能都归为Ogg或同owner。

| check | suite | 原始终态诊断 |
|---|---|---|
| generated-consumers | tests/plains_camera_trace_runner.gd | L122: WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L124: ERROR: 2 resources still in use at exit (run with --verbose for details). |
| generated-consumers | tests/generated_latch_trajectory_runner.gd | L223: WARNING: 6 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L225: ERROR: 2 resources still in use at exit (run with --verbose for details). |
| generated-consumers | tests/plains_branch_runner.gd | L464: WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L466: ERROR: 2 resources still in use at exit (run with --verbose for details). |
| generated-consumers | tests/home_app_runner.gd | L661: WARNING: 10 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L663: ERROR: 4 resources still in use at exit (run with --verbose for details). |
| region | tests/plains_cohesion_drops_runner.gd | L26: WARNING: 26 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L28: ERROR: 10 resources still in use at exit (run with --verbose for details). |
| region | tests/plains_cohesion_lifecycle_runner.gd | L40: WARNING: 10 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L42: ERROR: 4 resources still in use at exit (run with --verbose for details). |
| region | tests/plains_interactive_platforms_runner.gd | L52: WARNING: 3 RIDs of type "CanvasItem" were leaked.; L54: WARNING: 18 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L56: ERROR: 7 resources still in use at exit (run with --verbose for details).; L58: ERROR: 1 RID allocations of type 'P11GodotArea2D' were leaked at exit.; L59: ERROR: 1 RID allocations of type 'P12GodotShape2D' were leaked at exit. |
| region | tests/plains_exploration_module_runner.gd | L108: WARNING: 6 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L110: ERROR: 2 resources still in use at exit (run with --verbose for details). |
| region | tests/plains_exploration_expansion_runner.gd | L154: WARNING: 12 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L156: ERROR: 6 resources still in use at exit (run with --verbose for details). |
| region | tests/plains_pressure_boss_runner.gd | L170: WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L172: ERROR: 2 resources still in use at exit (run with --verbose for details). |
| region | tests/plains_campaign_map_runner.gd | L184: WARNING: 10 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L186: ERROR: 4 resources still in use at exit (run with --verbose for details). |
| region | tests/plains_region_runner.gd | L225: WARNING: 19 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L227: ERROR: 16 resources still in use at exit (run with --verbose for details). |
| region | tests/plains_region_lifecycle_runner.gd | L239: WARNING: 28 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L241: ERROR: 12 resources still in use at exit (run with --verbose for details). |
| terrain-production | tests/terrain_production_runner.gd (explicit wrapper script; import also shares outer log) | L27: WARNING: 12 ObjectDB instances were leaked at exit (run with `--verbose` for details).; L29: ERROR: 4 resources still in use at exit (run with --verbose for details). |

action-budget5946、actor-actions2929、all-weapons2381、weapon-feel1224都有实际Godot stdout及0fail标记，所暴露日志没有匹配终态诊断。**RootBell、terrain-family、visual-director-space只有summary/路径，内部native终态不可见，不能签clean。**

优先只读代码风险：RootBell formal runtime/admission和VisualDirector space等有内层重定向+narrow SCRIPT错误守门，外层Harness无法看见被留在inner log中的resource ERROR。native165自身ERROR拒绝已存在，不混同其后的admission audit。每路径精确hash/守门行在JSON；这不是新native失败的复现。

## 全57 check概览

| check | native stdout banner可见 | 实际匹配诊断行 | 判断 |
|---|---|---:|---|
| action-budget | True | 0 | no_matching_diagnostic_in_exposed_native_output |
| actor-actions | True | 0 | no_matching_diagnostic_in_exposed_native_output |
| all-weapons | True | 0 | no_matching_diagnostic_in_exposed_native_output |
| art-art | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| art-meadow_enemy_art | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| art-painterly_pack | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| art-plains_ground_art | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| art-plains_item_art | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| art-plains_spatial_art | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| art-plains_v3 | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| art-windkeeper_art | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| capture-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| consumer-coverage-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| core | True | 0 | no_matching_diagnostic_in_exposed_native_output |
| directed-space-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| docs | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| environment | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| forest-h-slice | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| generated-consumers | True | 8 | terminal_error_observed |
| harness-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| level-design-analysis | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| level-design-contracts | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| level-design-golden-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| level-design-golden | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| level-design-routing | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| level-design-runtime | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| level-experience | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| level-formal-receipts | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| level-formal-runtime | True | 0 | no_matching_diagnostic_in_exposed_native_output |
| level-region-context | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| plains-action-golden | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| plains-autonomy-golden | True | 0 | no_matching_diagnostic_in_exposed_native_output |
| plains-encounter-policy | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| plains-experience-golden | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| plains-redesign-golden | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| plains-redesign-scene | True | 0 | no_matching_diagnostic_in_exposed_native_output |
| plains-redesign-spatial | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| production-loop-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| quality-drills | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| quality-review-engine | True | 0 | no_matching_diagnostic_in_exposed_native_output |
| quality-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| quality | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| region | True | 21 | terminal_error_observed |
| root-bell-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| runtime-raw-export-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| structure | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| studio-input | True | 0 | no_matching_diagnostic_in_exposed_native_output |
| terrain-family-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| terrain-production | True | 2 | terminal_error_observed |
| terrain-tile-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| visual-director-space | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| visual-director-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| weapon-feel | True | 0 | no_matching_diagnostic_in_exposed_native_output |
| web-resource-contract-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| wood-platforms | True | 0 | no_matching_diagnostic_in_exposed_native_output |
| world-design-tests | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |
| world | False | 0 | outer_log_no_matching_diagnostic; nested_native_visibility_unknown_or_not_applicable |

原始log、blob OID、SHA、逐suite上下文及完整机读报告在同build目录。旧远端terrain原生stderr缺失仍unknown；这里不冲销旧失败或推定同因。
