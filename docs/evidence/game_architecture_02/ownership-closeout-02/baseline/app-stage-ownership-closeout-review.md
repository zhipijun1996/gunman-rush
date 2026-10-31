# App / 两区 Stage 所有权收口审查

源：`ed95d67d8c19988ab6af3b720aa07a17fd1f59cf`。只读源码与原 Git 对照；未改 main、未运行 Godot。以下是本轮所有权目标尚未彻底收口的 3 项，均在 `2ce4ffa64ef65dd5fba892776eea019c9e2841d4` 存在，不是已证实的新行为回归。优先级按边界暴露和变更风险，不能把静态发现解释为玩家路径已失败。

## 1. ShotLatch 恢复仍由地图逐字段执行

实际调用：`PlainsRegionStage.capture_state()`（260；机制字段写入286）→读取 `ShotLatch._clock/_opened_at/is_open/sequence_step/open_count` 与 `motion_target.motion_clock/motion_running` → `region_state.mechanisms`；`setup_shot_latches()`（298–319）反向逐字段赋值、调用 `restore_sequence_gate()`，再操作平台与 `gate_shape.set_deferred("disabled",true)`。

已存在的所有者：`ShotLatch` 管理待提交射击、序列门与开门时钟；`ModuleMovingPlatform.restore_motion()` 已同时恢复 clock/running/实际位置与 sync_to_physics。Stage 在调用该方法前又直写平台两字段，是明确越过已有边界；其余 latch 私有字段也是地图掌握对象内部恢复步骤。

最小写集：`game/world/components/shot_latch.gd`、`game/world/levels/providers/plains_region_stage.gd`；如已有公开平台读值足够，无需改平台。增加具体 `region_snapshot()` 和 `restore_region_state(data, persistently_open)`，搬入原逐字段顺序、原缺省值、原 deferred gate 操作；Stage 只按原 ID 存取快照并传递 `region_state.opened.has(id)`。平台恢复直接复用唯一 `restore_motion(clock,running)`。不新建通用存档框架。

必须保持：原 String 字典键、8 个字段、JSON 内容、先 sequence 再门/平台的顺序、motion_mode 差异、定时门剩余时间、永久开门覆盖、暂态请求不重放。不要顺带增加旧存档拒绝条件、修重复恢复/重复 deferred 行为。

验证：原 `tools/run_plains_region_tests.py`（含实际生命周期重载）、`core`；在现有 `tests/shot_latch_tests.gd` / 地图生命周期 runner 增加同一真实实例的 capture→卸载→重建比较：序列一步/完全开门、timed 半程、永久门、移动平台运行/停止以及 region.opened 覆盖。比较状态/位置、开门剩余帧与无新增奖励/声音/射击请求；保原断言。不能只测新函数返回字典。

旧证据：2ce 的 `scripts/demo/plains_region_stage.gd:319` 已直接写 `_clock`，并有相同恢复块。

## 2. App 越过 Director 修改完成状态

实际调用：`DemoApp._load_stage():626–627` 在 connected region 且保存 Boss HP ≤0 时直接 `director.stage_complete=false`；当前 `DemoRunDirector.complete_stage(token)`（53）和 `_enter_stage`（185）才是流程自身的完成状态写者。`_damage_resolved():929–963` 依赖 `was_complete` 的 false→true 来重新准备当前地图奖励/门，这个赋值不能简单删除。

最小写集：`game/application/demo_app.gd`、`game/application/demo_run_director.gd`、`tests/run_session_runner.gd`。在原 flow owner 内增加明确的地图重入完成重算操作；App 保留原 terminal reload 触发条件与相同调用位置。若方法带 token，仅采用既有 IN_STAGE/lifetime 接受语义，别扩大到每次 reload 置 false，也不操作 stage/run epoch、收据或 manifest。

验证：原 `run-session`、`tools/run_plains_region_tests.py`、`forest-depth-restore`、Bell/Pressure 实际重载用例。补 terminal Boss 同图重载后第一次批次重新完成/重新显示合法门、物理币不再生成、已领宝箱不重开、钱包/库存/epoch 保留；并测 live Boss 重载不误触发 terminal 恢复逻辑。原死亡优先与 queued actions 顺序不动。

旧证据：2ce `scripts/demo/demo_app.gd:656` 是相同直接赋值。

## 3. Windkeeper 恢复从 App 调私有 phase 回调

实际调用：`DemoApp._load_stage():740–747` 装配 Boss 平台后，普通 Windkeeper phase3 时直接 `arena_consumer._phase_changed(3)`；Pressure terminal 分支先 `restore_combat_state()` 再 `_restore_windkeeper_pressure_bridge()`；后者（2909–2914）判断 `bridge_break_ready()` 后遍历 Encounter 子节点并直接调用同一私有回调。另一个调用点是 `_start_generated_boss()` 在激活后恢复 Pressure 状态，再调同一 bridge helper，必须一并迁移。

已存在的所有者：`WindkeeperEncounter.bind_stage_geometry()` 创建并绑定 `WindkeeperArena`；Arena 自身监听 `phase_changed` 并 deferred `_break_ground()`。App 已不应知道 Arena 的私有信号处理函数/子节点枚举。Pressure 的真实 `_bridge_released` 与 phase3 不等价，不能把两个恢复条件统一为 phase3。

最小写集：`game/application/demo_app.gd`、`game/bosses/windkeeper/windkeeper_encounter.gd`、`windkeeper_pressure_encounter.gd`，必要时 `windkeeper_arena.gd` 提供明确的恢复入口。把现有 phase3/真实 break flag 的具体恢复策略放回各 Encounter，复用原 Arena `_phase_changed` → `_break_ground` 实现；不要复制桥算法。App 在原 binding/terminal restore/activation restore 后调用该语义入口。保现有子节点遍历目标与 deferred 次数，不借此加幂等化改变同帧行为。

验证：原 `windkeeper-pressure-01` 六消费者与 `tools/run_plains_region_tests.py`；原 phase3 Windkeeper、Pressure 已进入 phase3 但尚未真实断桥、真实断桥后重载、terminal 空中落地/死亡时钟重载四类。比较实际碰撞体/support、段回退锚点、coin drop 次数和 release 时刻。不要把 entry startup 当断桥交互通过。

旧证据：2ce `scripts/demo/demo_app.gd:783` 与2976已有相同两种私有回调调用。

## 不作为本轮新增拆分要求

- 森林 `ThornForestRegionStage._ready():73–96` 的 authored actor shape 验证以及 App `_load_stage():647–699` 的 shore/strand/line 配置仍偏宽，但当前恢复真实调用 `actor.restore_instance_health()` 和 `attack_behavior.restore_region_state(saved)`；后者在 `enemy_attack_behavior.gd:39` 内写 state/time/serial/direction，并让 Crossbranch 专属 override 保有 depth 权威。现有 `enemy_region_state_runner.gd:95,134` 明确约束 Stage 的 health/position 装配与 App 必填拒绝责任。可以以后按行为家族把 placement 验证归回已有 Registry/behavior，但不是“仍直接写 attack 私有状态”的证据，不能为压行数合并 schema 或改变 health→position→bind→geometry→restore 顺序。
- 两区重复 LevelRuntime.assemble、boss/actor 创建、map UI 装配是接入相同协议；两区 capture 使用180/160访问半径、不同 actor 字段、专属 terrain/remains/fruit 状态。不能强调一个父 capture 造成政策变化；不建议为几行实例化增加 Factory。
- App `_commit_pickup` / `_claim_region_chest` 均调用 RunWallet/SupplyHealEffect/MetaProgression/RewardService，没有另写余额/库存账本。拾取满血拒绝、REPLAY 音频与宝箱 committed 音频、失败文案等有原差异；不把两段 kind 分支强合成新奖账本。Stage pickups/chests 字典仍由 App 执行跨域领奖后标记，是可后续收束的场景完成用例，不是当前钱包所有者被绕过。
- App `_commit_room_reward():2131` 与 `_enter_generated_exit():2370` 的 simple_reward.claim→accepted→audio→reward_available→manifest 是真实重复，可在现有 App 内提取小提交方法；必须保两入口不同 gate、claim ID、失败清理与 status。这是低风险去重，不是必须追加模块/阻塞整轮的理由。
- `RunSession` 持有原 Director/钱包/装备实例，App 的引用别名/构造注入不是第二份状态；未在这三文件发现本轮重新绕过 Inventory/Equipment 的私有 mutation。

## 有限验证命令与风险

以下仅建议，未执行：

```bash
python3 tools/harness.py --jobs 1 --release --check run-session --check enemy-region-state --check forest-depth-restore --check windkeeper-pressure-01 --check core
python3 tools/run_plains_region_tests.py
```

每项独立小提交，父提交作为回退；本只读建议的统一比较基线是 ed95d67d，不伪造未来修复提交。最终引擎仍须按 root 审核的工具链身份运行。三项均牵涉重入时序，故不能以静态路径通过代替原真实重载测试；118 动态加载、全部入口和完整 CI 也不由本审查签 PASS。
