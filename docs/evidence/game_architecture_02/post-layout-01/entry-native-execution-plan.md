# 35 入口有限原生验收计划

读取主树 `6584d48bca916de100eed3801af6f0973ae49767`；4 处测试路径由 root 机械修正，均未在本次只读审查中复跑。复用已有审计和 wrapper；本文件不是入口注册表或新的测试框架。

目前准确可说：已有 6 条 native Harness gate 通过。其中 owners 84/0 实际加载 11 个 Cloud 托管场景，lifecycle 65/0 实际加载 4 个独立 study 并执行 Home→Plains→Home。共 15 个精确 PackedScene 被运行，不能称 35 个完整用户流程通过。正式 item-v5 的 191/0 仍因退出 57 ObjectDB /25 resources 泄漏失败。

## 推荐执行批次（均由 root 独占引擎执行）

- **existing-passed — ALREADY_PASSED_DO_NOT_REPEAT_WITHOUT_CHANGED_INPUTS**：Exact 4 study scenes and 11 Cloud-hosted scenes; limited semantics below.
  ```bash
  python3 tools/harness.py --jobs 1 --release --check entry-audio-lifecycle --check entry-audio-owners
  ```
- **entry-frontier — PENDING_AFTER_FOUR_MECHANICAL_PATH_FIXES**：Adds 5 exact scene roots and real practice interactions; style tests parameter-switch only style_lab root.
  ```bash
  python3 tools/harness.py --jobs 1 --release --check cloud-preview-runtime --check blob47-foundation --check windchime-plains --check pixel-plains --check style-exploration
  ```
- **formal-studio-interactions — PENDING**：Real formal Home appearance, movement, regional stages, pause/death/retry; Action training controls and actual patrols. Existing formal exit leak is independent blocker.
  ```bash
  python3 tools/harness.py --jobs 1 --release --check player-default-integration --check studio-input
  ```
- **module-random-consumers — PENDING**：Existing menu/dynamic/boss-approach/Random consumer suites; packed Random plus Module created from real App. Does not load PlainsPolishReview despite runner name.
  ```bash
  python3 tools/run_audio_lifecycle_tests.py --script tests/polish_regression_runner.gd --marker '^POLISH REGRESSION: [1-9][0-9]* assertions, 0 failures$' --timeout 180 --output build/entry-matrix/polish-regression
  ```
- **foundry-consumer — PENDING_CONDITIONAL_ON_EXISTING_CURRENT_BASIS_BATCH**：Real App._open_foundry, 6 accepted replay routes, pause, profile switch, feedback, leave; class instance rather than Foundry PackedScene. Existing feedback action writes its normal local feedback file.
  ```bash
  python3 tools/run_audio_lifecycle_tests.py --script tests/foundry_lab_runner.gd --marker '^FOUNDRY LAB: [1-9][0-9]* assertions, 0 failures$' --timeout 180 --output build/entry-matrix/foundry-lab
  ```
- **forest-golden-consumer — PENDING**：Existing frozen arch golden real Motor positive/negative routes; source script.new rather than PackedScene. Unique output directory required; wrapper holds existing engine.lock; 45s per variant.
  ```bash
  python3 tools/run_forest_directional_golden.py --output-dir build/entry-matrix/forest-directional-arch --layout arch --variant all
  ```

优先执行 entry-frontier；只修路径后的原断言才可能证明新目录实际可加载。player-default 与 studio-input 补实际交互。polish-regression 一次复用 Module 动态消费者及 Random 已有测试；它不是 PlainsPolishReview 的测试。Foundry 需现有 current-basis batch，不能为过关伪造/再生成记录。Forest golden 的 source-hash闭包仍含明确保留的历史物理文件，不能当全部正式森林通关。

## 每个入口的实际范围

| # | 精确入口 | 已有证据 | 下一已有命令 | 剩余区别 |
|---|---|---|---|---|
| 1 | `experiments/motion/entries/action_studio.tscn` | 已过Cloud托管音频/释放；直接启动待验 | formal-studio-interactions | 按已有测试有限断言，不扩张为完整通关 |
| 2 | `experiments/terrain/entries/blob47_lab.tscn` | 本候选未跑 | entry-frontier | 按已有测试有限断言，不扩张为完整通关 |
| 3 | `game/application/demo.tscn` | 已过Cloud托管音频/释放；直接启动待验 | formal-studio-interactions | 按已有测试有限断言，不扩张为完整通关 |
| 4 | `experiments/generation/entries/forest_directional_golden.tscn` | 本候选未跑 | forest-golden-consumer | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 5 | `experiments/generation/entries/foundry_lab.tscn` | 本候选未跑 | foundry-consumer | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 6 | `experiments/generation/entries/module_lab.tscn` | 本候选未跑 | module-random-consumers | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 7 | `experiments/terrain/entries/pixel_plains_preview.tscn` | 本候选未跑 | entry-frontier | 按已有测试有限断言，不扩张为完整通关 |
| 8 | `experiments/terrain/entries/plains_polish_review.tscn` | 本候选未跑 | 已过范围保留；缺口见JSON | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 9 | `experiments/generation/entries/random_stage_preview.tscn` | 本候选未跑 | module-random-consumers | 按已有测试有限断言，不扩张为完整通关 |
| 10 | `experiments/terrain/entries/windchime_lab.tscn` | 本候选未跑 | entry-frontier | 按已有测试有限断言，不扩张为完整通关 |
| 11 | `experiments/audio/entries/audio_ambience_lab.tscn` | 已过Cloud托管音频/释放；直接启动待验 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 12 | `experiments/audio/entries/audio_director_lab.tscn` | 已过Cloud托管音频/释放；直接启动待验 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 13 | `experiments/audio/entries/audio_director_lab_v2.tscn` | 已过Cloud托管音频/释放；直接启动待验 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 14 | `experiments/audio/entries/audio_director_reels.tscn` | 已过Cloud托管音频/释放；直接启动待验 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 15 | `experiments/audio/entries/audio_home_lab.tscn` | 已过Cloud托管音频/释放；直接启动待验 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 16 | `experiments/terrain/entries/authored_terrain_study.tscn` | 已过独立study就绪/切场景/释放 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 17 | `experiments/platform/entries/cloud_preview.tscn` | 本候选未跑 | entry-frontier | 按已有测试有限断言，不扩张为完整通关 |
| 18 | `experiments/terrain/entries/high_density_terrain_study.tscn` | 已过独立study就绪/切场景/释放 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 19 | `experiments/terrain/entries/light_study.tscn` | 已过独立study就绪/切场景/释放 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 20 | `experiments/terrain/entries/pixel_light_study.tscn` | 已过独立study就绪/切场景/释放 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 21 | `experiments/motion/entries/landing_feel.tscn` | 已过Cloud托管音频/释放；直接启动待验 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 22 | `experiments/motion/entries/motion_candidate.tscn` | 已过Cloud托管音频/释放；直接启动待验 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 23 | `experiments/motion/entries/weapon_feel.tscn` | 已过Cloud托管音频/释放；直接启动待验 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 24 | `experiments/motion/entries/weapon_feel_v2.tscn` | 已过Cloud托管音频/释放；直接启动待验 | 已过范围保留；缺口见JSON | 按已有测试有限断言，不扩张为完整通关 |
| 25 | `experiments/terrain/entries/basic.tscn` | 本候选未跑 | entry-frontier | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 26 | `experiments/terrain/entries/cavern.tscn` | 本候选未跑 | entry-frontier | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 27 | `experiments/terrain/entries/cavern_forest.tscn` | 本候选未跑 | entry-frontier | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 28 | `experiments/terrain/entries/cavern_gear.tscn` | 本候选未跑 | entry-frontier | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 29 | `experiments/terrain/entries/retro.tscn` | 本候选未跑 | entry-frontier | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 30 | `experiments/terrain/entries/scribble.tscn` | 本候选未跑 | entry-frontier | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 31 | `experiments/terrain/entries/style_lab.tscn` | 本候选未跑 | entry-frontier | 按已有测试有限断言，不扩张为完整通关 |
| 32 | `experiments/terrain/entries/underworld.tscn` | 本候选未跑 | entry-frontier | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 33 | `experiments/terrain/entries/underworld_forest.tscn` | 本候选未跑 | entry-frontier | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 34 | `experiments/terrain/entries/underworld_gear.tscn` | 本候选未跑 | entry-frontier | 命名PackedScene仍需启动探针；同class/参数不替代场景 |
| 35 | `experiments/motion/entries/graybox.tscn` | 本候选未跑 | 已过范围保留；缺口见JSON | 命名PackedScene仍需启动探针；同class/参数不替代场景 |

## 最少剩余 14 个精确入口启动

执行以上待跑 wrapper 后，以下 14 个仍没有精确 PackedScene 装配证明；复用原 `/workspace/audit-evidence/entry_probe.gd`，每条明确传新路径，禁止使用其旧默认路径。JSON 每行已有完整 `existing_probe_command`，通过既有 `tools/run_tests.py::run_engine` 做 90 秒上限和严格错误/退出检查，再检查两个 receipt。只读 probe 只启动/等帧/打印装配/释放；不检查就绪和交互。若最终验收要求每个入口独立直接启动，应对全部35条逐条运行同一原probe；已过11个托管入口不等于其直接启动已过。

- `experiments/generation/entries/forest_directional_golden.tscn`
- `experiments/generation/entries/foundry_lab.tscn`
- `experiments/generation/entries/module_lab.tscn`
- `experiments/terrain/entries/plains_polish_review.tscn`
- `experiments/terrain/entries/basic.tscn`
- `experiments/terrain/entries/cavern.tscn`
- `experiments/terrain/entries/cavern_forest.tscn`
- `experiments/terrain/entries/cavern_gear.tscn`
- `experiments/terrain/entries/retro.tscn`
- `experiments/terrain/entries/scribble.tscn`
- `experiments/terrain/entries/underworld.tscn`
- `experiments/terrain/entries/underworld_forest.tscn`
- `experiments/terrain/entries/underworld_gear.tscn`
- `experiments/motion/entries/graybox.tscn`

Graybox 的 RESET/接触/menu，以及 PlainsPolishReview 的旧 Boss8 fixture，仍无现成精确入口交互验收。后者源码还按8房stage_index驱动当前region运行，需要单独旧缺陷定性；不能用名字相近的 formal Boss 测试替代。

## 迁移缺陷与原有历史引用

- `tests/cloud_preview_runner.gd:17`：`experiments/terrain/entries/cloud_preview.tscn` → `experiments/platform/entries/cloud_preview.tscn`；root已修，当前字面核实=True，原native待跑。
- `tests/demo_ui_01/contract_runner.gd:192`：`experiments/terrain/entries/cloud_preview.tscn` → `experiments/platform/entries/cloud_preview.tscn`；root已修，当前字面核实=True，原native待跑。
- `tests/test_blob47_layout.gd:4`：`game/presentation/world/art_foundation/blob47_layout.gd` → `experiments/terrain/art_foundation/blob47_layout.gd`；root已修，当前字面核实=True，原native待跑。
- `tests/test_windchime_layout.gd:4`：`game/presentation/world/art_foundation/windchime_layout.gd` → `experiments/terrain/art_foundation/windchime_layout.gd`；root已修，当前字面核实=True，原native待跑。

`eight_demo_runner`/`eight_run_runner` 在2ce基线已引用不存在的 ten_* 测试；旧8房淘汰遗留，无可直接机械替换目标。`run_loop_tests.gd` 中 `formal_eight.tres` 必须不存在，是正确负断言。

**118 个动态加载表达式仍是清单，不是运行通过证明。** 以上仅有限消费者和原native wrapper；PCK导出、公开站点、浏览器输入、实际图声和设备性能均不由这些 headless 结果证明。
