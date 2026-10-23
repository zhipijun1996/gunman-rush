# 最终CI剩余44项：稀疏输入与实际消费者只读审计

基线：`54573a8e9400d790f58656efde2dd812cc00d8ba`，真实PR106 CI `39959074418`。原报告保持未改签：97 passed / 1 failed（plains-encounter-policy），expected142，因此44项尚未执行。本审计只写scratch；未运行Godot、完整CI、导出或历史媒体恢复，未改源、原断言或预算。已失败plains两文件由另一工作线修复，本审计不触碰。

## 结论与立即行动

1. 在下述有限实际调用链内，**未发现另一个确定会因缺少 docs/evidence 而失败的剩余check**。这不是完整静态依赖图证明，也不是44项运行通过。初始稀疏checkout本来保留assets/scripts/scenes/resources/tests/tools/config，仅排除docs/evidence；不能将这些源码/资源未出现在增量materialized列表误判为CI缺件。
2. 确认四项仍默认执行历史路径，违反本轮当前scope的意图或增加无关计算；它们读取的已证输入在源码/tests/assets中，**尚无本轮sparse缺件证据**。完整保留历史入口，不能把未运行记通过。
3. 若只修本轮已证CI失败，不需要据本审计新增宽泛docs/evidence输入或下载历史媒体；也不应为了“完整”另跑本地full历史套件。后续真实稀疏CI仍是未执行44项的运行证据。

## 真实收据

只从failure.zip选取五个JSON成员读取并保存，未全量解包：execution-plan.execution.json、execution-plan.json、inputs.json、pre-execution-inputs.json、pre-execution-plan.json。两个input收据都绑定54573，status ready、tests_executed false；初始实际materialized3079件，执行前第二次为0。ready是已枚举输入可用性，不证明所有动态消费者已枚举。具体原始收据位于本目录，原ZIP与report.json未改。

## 默认历史执行：具体范围与最小处理

- `forest-h-slice`：tools/run_forest_h_slice_tests.py:1、115–116明确标为 frozen historical H-only，使用tests/fixtures/forest_h_legacy_traversal.tres；137–139启动tests/forest_h_slice_runner.gd的positive/missing-anchor/no-hook。没有--current分流，当前short-hook另由forest-traversal覆盖。适合将完整本检查留在显式legacy-compat，不删其反例。需总控确认当前能力守门保留后再调整profile。
- `terrain-family-tests`：tools/run_plains_terrain_family_tests.py:19–20、106强制--legacy-presentation-fixture=terrain_family；131明确historical presentation compatibility。原all-maps及负例可完整保留为手动legacy-compat；不可宣称它代表新默认细粒度表现已获认可。
- `forest-hazard-records`：tests/forest_hazard_records_runner.gd:19–24遍历registry.recorded_variants()；生成器:77–82包括legacy/v7–v18。若收缩必须Python→GD→输出reader/case身份全贯穿，只当前两图仍保全部危险区域数量/顺序/damage role断言，旧全集保手动入口。不是只在顶层添flag。
- `forest-bible-versions`：tools/run_forest_bible_versions.py:135–151跑versions和JSON replay；GD:45–51、69–101真实重建v13/v14旧App，Python validate/negative_controls仍锁旧56检查及4historical cases。若分流须保当前public/candidate/JSON拒绝守门、精确区分case schema和负例；不能整个删掉当前部分，亦不能沿用旧计数伪通过。

详情与源码行见bible-sparse-audit.md。fruit/world-contract中旧版本类是当前生成继承/算法对比，并不因类名较旧就自动属于可删除历史兼容；本审计未把它们列为上述同类。

## 单check inputs合同缺口（非本轮确定CI缺件）

- `forest-bible-ambience`漏`assets/audio/kenney/warning.ogg`：真实GameAudio按CUES动态加载，建议精确补此项或声明实际kenney目录。
- `forest-bible-discoveries-tests`漏直接fixture `tests/combat_tests.gd`、`tests/audio_teardown.gd`，动态baseline items `resources/items/field_medic.tres`和`region_damage_purple.tres`，以及combat实际实例化`scenes/player/player.tscn`；后续仍须沿玩家资源闭包，不把这些当完整清单。
- `forest-camera-stability`的玩家场景8个直接ext_resource未在局部inputs里覆盖：scripts/combat/{action_resources,recoil_ability,shoot_ability}.gd，scripts/actors/actor_resources.gd，resources/actors/prototype_health.tres，assets/characters/courier/courier_visual.tscn，scripts/art/{player_visual_adapter,player_feedback}.gd。同样需递归资源/类，不能声称8件即完整闭包。
- camera/hazard/fruit共享run_engine实际调用tools/godot.sh，局部inputs可显式补tools/godot.sh与project.godot。

这些全在本CI初始checkout覆盖域；它们影响独立check输入合同/缓存身份准确性，不能冒称已经造成此次docs稀疏失败。此轮不据此扩大历史下载。

## 其余实际消费链的有限结果

- plains-redesign-scene：原native shards及同文件mutation反例；未发现额外Python unittest child。legacy_ui是当前UI/camera的兼容断言，未见读取冻结历史文档。
- forest-traversal：run_forest_region_tests.py→tests/test_forest_vine_gate.gd严格错误probe→tests/forest_region_runner.gd实际current short-H；未见docs/evidence读或子Python selftest。
- forest-depth-region：默认--corpus、layout空，逐case执行tests/forest_depth_region_runner.gd；历史layout须显式--layout。inventory根为project+scripts/scenes/resources/config/shaders/assets/tests/tools，没读历史evidence。
- forest-ecology/progression/campaign/debug：直接对应GD。生态动态enemy/boss路径位于scenes；campaign cross_region_manifest.json与campaign_pointer_events.json是本轮build输出而非历史输入；debug与campaign实例化当前正式layout。未找到额外历史文件读。
- Bible/世界motor/practice/ambience/fruit/camera：详见bible-sparse-audit.md。版本runner preload旧version runner仅取常量，不等于执行其全旧run；weaver覆盖父run，未调用父整套历史测试。没有据此扩大历史闭包。
- Underworld/风铃样式/cloud-preview：详见underworld-sparse-audit.md，实际wrapper→GD及有限只读source audit读取513 tracked路径，全部assets/scripts/tools。旧Home fixture仅哈希并未运行替换；terrain oracle默认world=false；元数据中的docs provenance字符串未被当前consumer解引用时不当作必需输入。该source audit不是Godot结果。

## 可直接选定的计划/复验命令（本审计未执行）

只看必需输入计划，不物化、不启动测试：

```sh
python3 tools/cloud_inputs.py --commit HEAD --check forest-hazard-records --check forest-bible-versions --check forest-bible-ambience
```

已有scope变更后，实际运行必须选中变更对应的同一check并保持原marker/负例；例如：

```sh
python3 tools/harness.py --check forest-hazard-records --check forest-bible-versions
```

这两个命令都是具体工具现有接口；前者只证明availability，后者是定向开发检查，不能当完整profile批准。不要用本地full-checkout运行结果替代真实sparse CI。下表提供剩余44项的精确原argv，便于总控只选择必要范围；本审计未运行它们。

| Check | 原真实命令 |
| --- | --- |
| plains-redesign-scene | `python3 tools/run_plains_redesign_scene_tests.py` |
| terrain-family-tests | `python3 tools/run_plains_terrain_family_tests.py --all-maps` |
| forest-h-slice | `python3 tools/run_forest_h_slice_tests.py` |
| forest-ecology | `bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/forest_ecology_runner.gd` |
| forest-progression | `bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/forest_progression_runner.gd` |
| forest-campaign | `bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/forest_campaign_runner.gd` |
| forest-debug | `bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/forest_progression_debug_runner.gd` |
| forest-traversal | `python3 tools/run_forest_region_tests.py --skip-import` |
| forest-depth-region | `python3 tools/run_forest_depth_region.py --corpus --output 'build/forest_depth/region/harness-matrix/harness-{check_token}'` |
| windchime-plains | `python3 tools/run_windchime_tests.py` |
| pixel-plains | `python3 tools/run_pixel_plains_tests.py` |
| pixel-formal | `python3 tools/run_pixel_formal_tests.py` |
| style-exploration | `python3 tools/run_style_exploration_tests.py` |
| underworld-scenery | `python3 tools/underworld_pipeline.py runtime --suite scenery` |
| underworld-hazards | `python3 tools/underworld_pipeline.py runtime --suite hazards` |
| underworld-terrain | `python3 tools/run_underworld_terrain_tests.py` |
| underworld-formal-terrain | `python3 tools/run_underworld_formal_terrain_tests.py` |
| underworld-formal | `python3 tools/run_underworld_formal_tests.py` |
| underworld-raw-export | `python3 tests/test_underworld_raw_export.py` |
| underworld-player-animation | `python3 tools/run_underworld_player_animation_tests.py` |
| underworld-mechanisms | `python3 tools/run_underworld_mechanism_tests.py` |
| underworld-home | `python3 tools/run_underworld_home_terrace_tests.py` |
| underworld-ui | `python3 tools/run_underworld_ui_tests.py` |
| underworld-damage-feedback | `python3 tools/run_underworld_damage_r3_tests.py` |
| underworld-projectile-vfx | `python3 tools/run_underworld_projectile_tests.py` |
| underworld-world-objects | `python3 tools/run_underworld_r3_object_tests.py` |
| underworld-continuous-bosses | `python3 tools/run_underworld_r3_boss_tests.py --full-fights` |
| forest-camera-stability | `python3 tools/run_forest_camera_stability.py` |
| forest-hazard-records | `python3 tools/run_forest_hazard_records_tests.py` |
| forest-fruit-contract | `python3 tools/run_forest_fruit_contract.py --output 'build/forest_fruit_routes04/harness-{check_token}'` |
| forest-bible-weaver-tests | `python3 tools/run_forest_bible_weaver.py` |
| forest-bible-discoveries-tests | `python3 tools/run_forest_bible_discoveries.py` |
| forest-bible-integration-tests | `python3 tools/run_forest_bible_integration.py` |
| forest-bible-world-contract | `python3 tools/run_forest_bible_world_contract.py --output 'build/region_bible_v2/world-contract/{check_token}'` |
| forest-bible-world-connection | `python3 tools/run_forest_bible_world_motor.py --output 'build/region_bible_v2/forest-bible-world-connection/{check_token}' --route bible_connection_journey --seed forest-depth-hollow-00 --map 2` |
| forest-bible-world-backbranch | `python3 tools/run_forest_bible_world_motor.py --output 'build/region_bible_v2/forest-bible-world-backbranch/{check_token}' --route bible_backbranch_journey --seed forest-depth-hollow-00 --map 2` |
| forest-bible-ambience | `python3 tools/run_forest_bible_ambience.py --output-dir 'build/region_bible_v2/ambience/harness/{check_token}'` |
| forest-bible-app-discoveries | `python3 tools/run_forest_bible_app_discoveries.py` |
| forest-practice-bell-restore | `python3 tools/run_forest_practice_bell_restore.py --output-dir 'build/region_bible_v2/practice-bell/harness/{check_token}'` |
| forest-bible-world-connection-map1 | `python3 tools/run_forest_bible_world_motor.py --output 'build/region_bible_v2/forest-bible-world-connection-map1/{check_token}' --route bible_connection_journey --seed forest-depth-hollow-00 --map 1` |
| forest-bible-world-backbranch-map1 | `python3 tools/run_forest_bible_world_motor.py --output 'build/region_bible_v2/forest-bible-world-backbranch-map1/{check_token}' --route bible_backbranch_journey --seed forest-depth-hollow-00 --map 1` |
| forest-bible-world-spiral | `python3 tools/run_forest_bible_spiral_motor.py --output 'build/region_bible_v2/forest-bible-world-spiral/{check_token}' --mode full --seed forest-depth-hollow-00` |
| forest-bible-versions | `python3 tools/run_forest_bible_versions.py --output-dir 'build/region_bible_v2/forest-bible-versions/{check_token}'` |
| cloud-preview-runtime | `python3 tools/run_audio_lifecycle_tests.py --script tests/cloud_preview_runner.gd --marker '^CLOUD PREVIEW TESTS: [1-9][0-9]* assertions, 0 failures$' --timeout 90 --output 'build/cloud_preview/{check_token}'` |

## 未知边界

静态实际调用追踪覆盖上述已知wrapper/主要GD/动态资源分支；未执行Godot或模拟全部状态，因此不覆盖任意运行时字符串/条件分支、导入缓存及class_name解析。原required_input_preflight自述不是完整依赖证明，ready不替代消费者执行。原97pass/1fail仍是真实状态；44项未执行仍为未验证。未做源修改建议清单之外的实现、未改预算、未签发布或玩家认可。
