# Underworld / sample styles / cloud-preview：只读 sparse 闭包审计

审计目标 HEAD：`54573a8e9400d790f58656efde2dd812cc00d8ba`。结论：**限定范围内未发现确定的 CI sparse 输入阻塞，也未发现需要给默认入口补传 `--current` 才能切断的历史回放链。** 这不是 Godot/运行时通过声明。未运行 Godot、完整 CI、历史媒体下载；未修改仓库任何文件。

## 实际 CI 输入证据

- `inputs.json` 与 `pre-execution-inputs.json` 都绑定上述 SHA，状态 `ready`，两份收据 `resolved_checks.checks` 都包含下表全部21个check，其 argv 与本次 HEAD manifest 一致。
- 前者 `materialized` 实际记录3079个路径；后者为0，表示第二次检查无需新增物化，不能把0解释为全部输入不存在。
- `.github/workflows/production.yml:50–53` 初始非cone sparse规则是 `/*` 加 `!/docs/evidence/`。因此 tracked `assets/`、`scripts/`、`tools/`、`tests/`、`resources/`、`scenes/`、`shaders/`、`config/` 本就被初始checkout纳入；不能要求它们也出现在增量 `materialized` 里。本报告没有用本地full-checkout的 `exists()` 代签CI获取。
- 只读调用 `underworld_pipeline.audit()`，用 `io.open` 记录实际 Python 文件读取，得到 **1022 checks / 0 failures；513个读取路径，全部为 HEAD tracked 文件，全部在 assets/scripts/tools**。路径清单另存 `underworld-pipeline-read-paths.json`。该实验仅证明 source audit 消费链，不能替代Godot或整个 `test_underworld_pipeline.py` 执行，也不声称覆盖Pillow内部open及纯 `exists` 分支。

## wrapper→真实消费者核查

| check | 已追到的默认下游及输入结论 |
| --- | --- |
| windchime-plains | `tools/run_windchime_tests.py:5–7` → `build_windchime_art.py --check` → `tests/test_windchime_layout.gd`、`test_windchime_lab.gd`。builder只读 `assets/windchime_plains` 产物及源码规则；Godot指向现有lab/Player场景，无docs/evidence读取。 |
| pixel-plains | `tools/run_pixel_plains_tests.py:6–7` → `build_pixel_plains_art.py --check` → `tests/test_pixel_plains.gd`。builder `:279–282`读取自身、blob47规则；默认不是历史媒体生成/回放。 |
| pixel-formal | `tools/run_pixel_formal_tests.py:4–7` 仅执行 `tests/test_pixel_formal_terrain.gd`；真实 `PlatformingModule` / ferry / one-way消费者在该runner `:57`后执行。未再执行painted历史fixture。 |
| style-exploration | `tools/run_style_exploration_tests.py:44–51` → import、style runtime、biomes、3个CLI实例。`scripts/style_exploration/style_scenery.gd:74–87,223–227,290–294`的动态拼接根均为 `assets/style_exploration/`，包含原始资源及region变体；不拼docs/evidence。 |
| underworld-pipeline | `tests/test_underworld_pipeline.py:22–33`先对实际production manifest做baseline audit，负例重用当前真实片段。`tools/underworld_pipeline.py:796–820`会审terrain/scenery/hazards/player/mechanisms/home/ui/objects全部域；动态外置prompt分别在 `:185–200`解析到assets同目录。UI `:767–770`扫描全部scripts；这些均有初始checkout保证。 |
| underworld-scenery / underworld-hazards | `tools/underworld_pipeline.py:831–850` runtime分支直接调用对应GD runner；scenery还执行identity_population。**runtime分支未先执行整个source audit**。`test_underworld_hazards.gd:55–62`的legacy断言只是构造Node当前行为，不读历史快照。 |
| underworld-terrain | `tools/run_underworld_terrain_tests.py:5–10` → terrain + border-equivalence。后者 `tests/underworld_plains/test_terrain_border_equivalence.gd:3,6,10–11`用仓库内frozen oracle比较当前几何，默认 `worlds=false`，wrapper不传 `--world`。无需历史媒体/旧64图回放。 |
| underworld-formal-terrain / underworld-formal | 各同名wrapper直达 `tests/underworld_plains/test_underworld_formal_terrain.gd` / `test_underworld_formal.gd`；当前Stage/App、Boss-break、audio_teardown与资源来自初始checkout。未见docs/evidence读。 |
| underworld-raw-export | `tests/test_underworld_raw_export.py:26–88`检查preset、manifest绑定、7个raw路径及内存RawPack负例；`tools/underworld_delivery.py:22–29`枚举的7个PNG全部在assets；不启动delivery导出/浏览器main。 |
| underworld-player-animation / underworld-mechanisms / underworld-ui | 各wrapper直达同名GD runner；mechanisms还做editor import。当前动画/物理/正式UI资源在assets、resources、scripts；无历史文件回放分支被默认额外开启。 |
| underworld-home | `tools/run_underworld_home_terrace_tests.py:24–44`的immutable R2 fixture确实默认进入OWNED，`:113`对其做SHA，但 `:116,125`只执行当前terraces runner；旧 `.source` 不被替换进生产源码或执行。`tests/underworld_plains/test_underworld_home_terraces.gd:172`的legacy_replay仅写入收据字段。整个tests/fixtures在初始checkout中，无sparse缺口。 |
| underworld-home-guard-tests | `tests/test_underworld_home_terrace_wrapper.py:36–38`调用当前wrapper.verify，`:154–157`调用真实当前provenance preflight；其余generation负例用临时目录。没有执行旧fixture。 |
| underworld-damage-feedback | `tools/run_underworld_damage_r3_tests.py:5` → R3 runner；其 `:310–312`还加载 `tests/damage_tests.gd`、enemy edge及response ownership cases。全部属于初始纳入的tests，未漏docs evidence。 |
| underworld-projectile-vfx | `tools/run_underworld_projectile_tests.py:5,10` → projectiles + weapon_consumers；后者在 `tests/underworld_plains/test_underworld_weapon_consumers.gd:1` 继承 `tests/all_weapons_runner.gd`，前者加载 `tests/combat_tests.gd:21`。全部已由初始checkout纳入。 |
| underworld-world-objects | `tools/run_underworld_r3_object_tests.py:11–19,31`动态glob/hashes对象资产及builder，GD `test_underworld_r3_objects.gd:13,173`还加载shot_latch_tests。路径均在初始纳入的assets/tools/tests。 |
| underworld-continuous-bosses | `tools/run_underworld_r3_boss_tests.py:15–43` → import、连续战斗、方向、lifecycle；CI明确传 `--full-fights`，故还执行map1/map2实际App战斗。不是仅顶层标记current却暗含旧版本回放。 |
| cloud-preview-runtime | `tools/run_audio_lifecycle_tests.py:24–26`只下传指定脚本与可选prove-skip-drain；该check未传可选flag。`tests/cloud_preview_runner.gd:16–41`执行actions/scene/demo真实入口，再返回菜单并drain；场景及audio_teardown均由初始checkout纳入。 |

## 容易误报为漏输入的引用

1. `assets/underworld_plains/decor/provenance.json:10`记载 `docs/evidence/style_exploration/generation.json`；它在CI `inputs.json.materialized`中确实有物化记录，但当前 `audit_extended_decor` (`tools/underworld_pipeline.py:315–355`)并不解引用这个嵌套generation_record，而读取该assets provenance中的native grass字段及单独identity_generation_record。baseline实际读路径也无docs。不能把这个元数据字符串直接当必需未声明输入。
2. `assets/underworld_plains/backgrounds/depth_frame_06/provenance.json:25`有旧home.png引用。实际source audit读取的是该目录landmark_ridge_r2.png，未读该provenance，更未读其docs图片；当前选中的sky/meadow外置prompt均在assets内部。
3. resources中还存在旧art catalog的master / admission_proof文档字符串。未发现本组实际runner链把这些字符串传给FileAccess或ResourceLoader；不能因JSON含docs路径就扩大下载历史媒体。

## 修复建议与边界

本组没有已证实的缺失输入，故不建议为了本次sparse CI新增宽泛 `docs/evidence/**`，也没有有依据的最小 `check.inputs` / `--current`修补项。各check的局部inputs有些未枚举全部间接源码（例如pipeline UI会rglob全部scripts、Home会hash旧fixtures）；当前生产workflow通过初始源码checkout覆盖，且pipeline非cacheable，不能把这种声明不完整等同本轮已缺文件。

有限保证：静态追踪覆盖上述21个入口与显式/动态主要消费者；source audit仅执行一次，未执行pipeline完整152个测试方法、不启动引擎，也不签导入/动态类解析、全部场景运行或完整CI。若未来sparse进一步排除assets/tests/scripts，必须重新审查这些动态扫描与fixture哈希域。本报告不能据此宣称全部CI已通过。
