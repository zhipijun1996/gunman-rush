# Bible / forest remaining-check sparse audit

审计基线：`/workspace/integration-four` HEAD `54573a8e9400d790f58656efde2dd812cc00d8ba`。只读源码审查，唯一写入为本 scratch 报告；未执行 Godot、全 CI、历史下载或媒体下载。未触碰 plains encounter 文件。

结论：发现两个默认历史回放范围问题，以及几个可复核的独立 check.inputs 缺口。**未发现本组额外动态 docs/evidence 文件的确定缺件；不能据此签完整 sparse 闭包或真实运行通过。** `inputs.json`/`pre-execution-inputs.json` 自述 `input_availability_only`、`tests_executed:false`、`limits: ... not a complete static dependency graph`；ready 只证明其已枚举输入。全 CI union 已有 scripts/scenes/resources/assets/tests/tools，因此下面多数独立检查缺口可能被其他检查覆盖；它们不是该 CI 工作区必然缺文件的证据。

## A. 确定默认历史执行（需决定 current/legacy 分流）

### A1. forest-hazard-records

调用：`tools/run_forest_hazard_records_tests.py:10-13` → `tests/forest_hazard_records_runner.gd`。

- runner `:19-24` 无条件遍历 `registry.recorded_variants()`，生成所有版本、两张地图。
- `scripts/generation/thorn_forest_region_generator.gd:77-82` 返回 legacy、DEPTH_LAYOUT_SCRIPTS 的全部 v7–v18，加 v9 north_return=false。
- wrapper 和 Godot runner 都没有 `--current` 参数；当前 `CURRENT_DEPTH_LAYOUT` 为 Bible v15（注册表 `:18`）。只给 Python argv 添参数不足以停止历史路径。

最小正确贯穿方案：Python 接收/转发 `--current`；Godot 在 current scope 只用明确 `{version: DEPTH_VERSION, layout: CURRENT_DEPTH_LAYOUT}` 两图，保留每张图所有现有危险矩形/记录数量、顺序、damage role 断言；非 current 的完整原检查留给显式 legacy-compat。报告 scope 与 wrapper 的 case identity 验证应区分两种范围，避免只检查“非空 cases”就让 current 被静默缩空。原全部变体断言不能删除。此问题增加历史计算，但本 runner 未读历史 docs/evidence fixture。

### A2. forest-bible-versions

调用：`tools/run_forest_bible_versions.py:135-138` → `tests/forest_bible_versions_runner.gd`；其后 `:145-151` 另跑 `tests/forest_bible_json_replay_runner.gd`。

- Godot runner `:45-46` 每图执行当前 public_app 后，无条件 `recorded_app_case` v13/v14。
- `:47-51` 又建 `""/v13/v14/v15` 四种 trace；`:69-101` 对旧 App 真正保存、强制请求 v15、重建，并核对旧 manifest/claim/mechanism/actor-health。
- Python `:119-122` 只有 output-dir；没有 current 选择。`validate():28-35` 锁定 56 checks + 4 historical cases，`negative_controls():76-90` 索引直接指旧 case；不能仅给入口加 flag 或从 runner 跳过两行。
- `tools/harness/profiles.json:2948` 注册此检查；它仍被普通 profile 列表引用（`:3711`, `:4000`），而 `legacy-compat` `:4108` 未列它。

最小方案两选一：若它确为独立 additional compatibility，就将完整现检查留在显式 legacy-compat，并确认其当前 candidate/public/JSON replay 断言已有当前入口承担；否则做端到端 `--current`：保留两图 candidate、公有 App、current strategy 与完整 JSON replay 当前拒绝验证，精确重算该 scope 的 checks/cases/marker，Python reader/negative_controls 随 scope 选择断言，旧 56/旧 cases 全部保留手动路径。不能把兼容检查整体删掉却丢失当前 producer/JSON 拒绝守门。

## B. 确定 check.inputs 漏声明

这些是合同缺口；实际全 CI union 是否已经覆盖必须分开判断。

### B1. forest-bible-ambience：动态 warning 音效

- `tests/forest_bible_ambience_runner.gd:32-33` 新建并加入真实 GameAudio。
- `scripts/audio/game_audio.gd:7` 的 CUES 含 `warning`；`:52-53` 对每个 id 动态 load `res://assets/audio/kenney/%s.ogg`。
- remaining44 的 ambience inputs 枚举 24 个 Kenney OGG，**遗漏 Git 跟踪的 `assets/audio/kenney/warning.ogg`**。Python `source_hashes()` `tools/run_forest_bible_ambience.py:38` glob 却会包含它；独立 sparse 缺它会使 inventory/运行行为随工作区不同。
- 最小补充：`assets/audio/kenney/warning.ogg`（更稳健合同为 `assets/audio/kenney`，因为实际 consumer 会加载整个 CUES）。不要因本地文件存在就宣告闭包。
- `historical_disabled` `tests/forest_bible_ambience_runner.gd:147-153` 只是给同一当前 ambience 节点传一个 v14 标识，验证拒绝；没有创建历史 App/加载历史 evidence，不能等同 A1/A2 的历史回放。

### B2. forest-bible-discoveries-tests：真实 fixture / 动态 ItemDefinition

- `tools/run_forest_bible_discoveries.py:25-29` 直接运行 `tests/forest_bible_discoveries_tests.gd`。
- runner `:65-67` preload 并调用 **`tests/combat_tests.gd`**；`:216` preload **`tests/audio_teardown.gd`**。两者不在该 check.inputs 中。
- `:92-94` 动态加载 **`resources/items/field_medic.tres`、`resources/items/region_damage_purple.tres`** 作数值/效果基准；inputs 只有两个 forest 新物品，未覆盖这两个现有基准资源。
- `tests/combat_tests.gd:3` preload 玩家场景，`:20-22` 实际实例化；**`scenes/player/player.tscn`** 不在该 check.inputs。其资源/脚本继续有真实依赖，应继续核实，不能只加 combat fixture 就签完整。
- 最小已证实补充：上述两个 tests、两个 baseline items、玩家场景；然后沿玩家场景 ext_resource 和 class_name 解析补全真实闭包。当前未完整枚举它的所有 class_name/资源传递依赖。

### B3. forest-camera-stability：玩家场景的确定 ext_resource 未覆盖

- `tests/forest_camera_stability_runner.gd:3` preload 玩家，`:40-42` 实际实例化。
- `scenes/player/player.tscn:8-16` 直接依赖：`scripts/combat/action_resources.gd`、`scripts/combat/recoil_ability.gd`、`scripts/combat/shoot_ability.gd`、`scripts/actors/actor_resources.gd`、`resources/actors/prototype_health.tres`、`assets/characters/courier/courier_visual.tscn`、`scripts/art/player_visual_adapter.gd`、`scripts/art/player_feedback.gd`。
- remaining44 的 camera inputs 只有 scripts/player、scripts/input、scenes/player、config 及少数文件，未覆盖这八个路径。最小先补这八项，再递归这些资源/类；不能称这八项就是全部闭包。
- `tools/run_tests.py:16` 真正启动 `tools/godot.sh`；camera/hazard/fruit 的 inputs 均没列此脚本（Harness 全部 runner argv 的共享扫描不等于检查 input_digest 覆盖它）。建议这三个检查补 `tools/godot.sh` 与 `project.godot`，并核实环境工具链共享合同。

## C. 已追踪但未发现额外历史 docs/evidence 输入的路径

- camera/hazard/fruit wrapper 只调用 run_engine，没有 unittest discover 或 Python 自测入口。
- fruit `tests/forest_fruit_contract_runner.gd:3-4,31-38` 对比旧 v13 与 v14；world-contract `tests/forest_bible_world_contract_runner.gd:23-25` 用 v14 作为 v15 前身比较。它们的当前生产算法本来继承这些源码（v15→v14→v13→v12）；不能把出现旧版本类名当作可直接删除的历史文件。没有看到它们读取历史 evidence。
- Bible weaver wrapper → `tests/forest_bible_weaver_runner.gd`（继承 forest_depth_enemy_runner，但覆盖 `run():251`），没有调用父级整套 historical run。其精细 inputs 不足以覆盖所有真实玩家/表现依赖，不能签独立闭包；本次重点证据见 B3 的同一真实玩家场景。
- Bible integration / app-discoveries / world Motor（两 route、两 map）/ spiral Motor / practice-bell wrappers：直接 run_engine 对应 runner；`forest_bible_world_sources.inventory()` 的 roots 为 scripts/scenes/resources/config/shaders/assets/tests/tools + project.godot，这些检查 inputs 已列同组目录。未见从这些 wrapper 发起 Python unittest。`run_engine` 本身只是 subprocess 执行 godot.sh，不会调用 run_tests.main 的全套游戏测试。
- `tools/run_forest_bible_reader_tests.py` 的确 discover `test_forest_bible*.py`，但不在本次剩余本组 argv 中，也未在上述 wrapper 中被调用；不能把它误判为这些 native wrappers 的子测试。
- `forest-bible-ambience` Python BASE_SOURCES 明确读取并已在 inputs 声明 `docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md`。
- scripts/generation/forest_exploration_world.gd 与 forest_varied_bible_layout.gd 的 BIBLE_PATH 只是字符串写入 manifest（并有固定 BIBLE_SHA），在所读代码中没有对该路径 FileAccess 读/散列；这不是额外缺件证据。
- versions preload `tests/forest_depth_version_runner.gd` 用于 EXPECTED_PUBLIC_LAYOUT 常量，不等于执行其原始 327 全 run；该文件虽含历史 fixture 读取函数，但本组调用路径未调用那些函数。

## 界限与后续验证

未伪造 sparse 缺件、未据本地 exists 认定 CI 闭包；没有运行 scope 所以不签通过。B 类修复只能完善输入合同，不能解决 A 类默认历史范围。若做 current 收缩，必须让 Python→Godot→实际 audit reader/marker/case schema 贯穿，并真实执行同一 scope 后再更新状态。当前全 CI 可用性小收据不能替代这个验证。
