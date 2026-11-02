# R3 单次既存低台应对诊断候选

状态：外部候选，尚未运行 Godot；不修改主树、CI 或生产。R3 原 278/1、精准接触绑定后仍 278/1、正式 cautious2 1608 帧死亡都继续有效。首组假说即使成功，也不能证明旧地面 68/78 输入无伤、后续全战斗、完整 CI、公平性或人工认可。

## 唯一假说与实际来源

保原实际 App map1、`underworld-r3-continuous-boss` seed、原开战前一次摆位与正常初始资源。只有首个真实已冻结 phase1 roll_warning 出现后才改变输入；不是提前登台改变自主选招。以实际 Stage.assembler.modules 的 plains_bellstrider_arena 为唯一平台来源：定义 one_way_platform_indices 对应已安装 PlatformN/CollisionShape2D，检查原生矩形、one_way 标志/组以及 authored 与 installed world rect 一致。选择最低层现有单向台中离当前玩家最近的中心；当前资源该层比地面高 130wu，候选未复制 130 或任何推导世界坐标。

通过原 Router 轴和原 27-frame jump hold 登台。真实 PlayerMotor 滑动碰撞的朝上法线、body instance ID 和 path 与已安装平台匹配，且 grounded，才承认落台；必须在该真实 warning 内发生。原跳跃能力负责落地恢复，不写 used_jumps/位置/速度/生命/弹药/时钟。降落后停止水平输入，由原摩擦停下；实际 `Encounter.body_contact_rect()` 的来袭水平前缘进入所选平台跨度，且真实水平速度已停时，才请求原 grounded held jump。真正碰撞继续由原 body_contact_sweep/FrameDamagePolicy 判定。没有 SAT、新碰撞代理、轨迹预测、帧搜索或参数扫描。

当前支持假说的离线约 92wu 估计只在 structure 的 platform_boundary.py/JSON 中，候选不读取或移植该计算。能否在 warning 内真实落台、按下第二跳、无伤穿越和两枪反击尚未证明。

## 写集与行为边界

仅两既有测试工具，见 candidate.json 的精确 before/candidate SHA：

- tools/bellstrider_01/legal_input_pilot.gd：显式默认 false 的 platform_counterplay，首组有界输入决策与观察状态。原两枪收招算法逐字不变，后续回到原 cautious2；不尝试不同目标/时机。
- tests/underworld_plains/capture_underworld_r3_boss_fight.gd：解析 `--platform-counterplay`，从实际装配/物理读取窄数据，追加逐帧记录和 opt-in 收口判据。原全部 25 条 failure.append 源行逐字保留（包含原 21 条胜利判据及已整合的 4 条真实 fixture/lifecycle 守门）；所有原循环和摆位原句保留。

观察同时核 tuning.max_jumps==1、实际 JumpAbility.maximum_jumps()==1（含 capacity_floor）和 hook_enabled==false。默认不加开关时，不启用新策略或诊断判据。新代码无生产写入、资源变更、解锁、更换武器、重置或额外射击。

## 必须实际成立的判据

每帧 trace 追加平台路径/instance ID、安装矩形数值、真实朝上接触点与法线、当前 rig 矩形、有效跳数、已用跳数、真实速度/轴、原 player HP；原 trace 继续记录实际位置、state、clock、stamina、shots。input_rows 记录真实离地/落台/空中换边/第二次落地以及请求输入事件；请求和标签不当物理成功。

原正常与 arena-released 两个 receipt 写出前都会执行独立 opt-in 收口：

1. 首组真实完成，且真实登台离地、第二次离地、空中换边和落地都有观察；failed/waiting/incomplete 一律失败。
2. 首 warning 到该组完成的 HP 最小值等于起始值。
3. 最终读取原 FrameDamagePolicy.batch_resolved 的 damage_events，首 tick 到 complete tick **含尾 tick** 没有 player 已提交伤害；不是只依赖 policy 前采样 HP。
4. 原 input_rows 第一组恰好两次提交射击；原 combat_metrics.events 第一组恰好两次真实 base-one bell_hit。仍保所有原完整战斗/40HP/奖励/生命周期判据。

任何新判据失败都会加入原 failure 数组，不能以平台 metadata failed 配最终 0 failures marker。新额外 verdict 明确仅第一组；后续死亡、奖励失败等保持原失败。若局部成功但完整战斗失败，旧 R3 CI 仍 blocked，不能迁移旧正断言。

## 原预算内一次运行（仅由租约持有人）

先核 candidate.json 两原件 SHA 仍匹配，独审接受后才应用 platform-counterplay.patch。原件与正逆 whole-file 验证在 originals/、candidate/、static-proof.json。回退用 `git apply -R platform-counterplay.patch`，不更改生产。

在已有固定修复版引擎/原环境中，通过原 run_tests.run_engine 一次调用（不要本 agent 执行）：

```python
from tools.run_tests import run_engine
output = run_engine([
    '--headless', '--fixed-fps', '60', '--audio-driver', 'Dummy', '--path', '.',
    '--script', 'tests/underworld_plains/capture_underworld_r3_boss_fight.gd',
    '--', '--map=1', '--platform-counterplay',
], 180)
```

保原 7200 战斗物理帧、180s native 上限，原后续 300 帧金币/其余收尾不变。不串行试多个参数、不提高超时。先归档旧 build/underworld_r3/boss/full_fight_map1.json，再保存这次原日志、完整 receipt、引擎 SHA、精确 source bindings 和严格退出结果到新目录。正式 wrapper/旧 roll assertion不改。

原 `UNDERWORLD R3 FULL BOSS MAP1` 0 failures marker、receipt failure 空、40HP 实际击杀/存活/金币与所有原胜利判据仍必要；还必须检查 platform_trial_receipt_verdict 每项 true、真实事件链及源稳定。仅动作局部成立不能代替原完整胜利。此处只列运行计划，没有宣称 native passed。
