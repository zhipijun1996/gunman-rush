# ENEMY-FEEDBACK-01 M0 原件

运行源 `0ee0e79197f40e898283440d4af2d956f91f1c64`；生产merge基线 `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`。所有命令在专用worktree执行并source `/workspace/worklines/enemy-feedback-01-env.sh`。本目录是原有消费者baseline；不是新反馈样板或用户认可。

- `input-plan.json`：原cloud_inputs preflight，exit0、ready、0缺件，未跑测试。
- `baseline-receipt.json` / `baseline.log`：原Harness完整回执和stdout；fresh `underworld-damage-feedback`，exit0，317断言/0失败，Godot4.7.2。
- `baseline-runtime.json`：原生消费者完整轨迹原字节，含原巡逻怪Underworldhurt、旧链地面/空中弹体边界；不能外推两新代表death/正式地图/画面。
- `source-inventory.json`：实际消费者、配置、Bible和工具完整SHA；用于恢复与baseline归因，不代签视觉。

命令：`python3 tools/harness.py --check underworld-damage-feedback --release --jobs 1`。原目录 `build/verification/harness/20261022T125012.811711Z/`；inner `tools/run_underworld_damage_r3_tests.py` 原120秒与outer180秒不变。原生baseline没有失败；没有媒体或独审原件，均保持未验。

`quality-record-check.json`为修正元数据后的单卡实际结果；初版缺原schema字段导致REJECT，checkpoint保留原因。`global-quality-sparse.log`为全局静态检查实际exit1，因本线稀疏缺历史证据，不代表原生317检查失败，也不补签全局通过。
