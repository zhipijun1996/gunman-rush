# R3 Boss：可纳入现有Harness/Skills的有边界经验

适用：本轮正式Bellstrider / Windkeeper continuous_combat，以及其历史窗口fixture。不是全Boss的固定尺寸/时间/风格要求。

1. **“随时可攻击”与“低风险恢复期”是两个状态合同。** `core_open`保留为恢复动作/节奏提示，不能再决定唯一受击权限。R3每阶段用真实Router弹分别打observe、telegraph、attack、recovery、phase_transition，intro/inactive/dead仍拒绝。见`continuous_combat_final.log`100/0及对应JSON。建议boss-creator G0/G1明确“资格”和“风险”分离，不统一加大HP或只缩等待。
2. **开放过渡受击后，要反证无风险DPS木桩。** 旧3.2s+返岸+无限等玩家上台的桥切换，在新合同下能站桩打完后两阶段。正式改为1.4s有界预告、最近桥墩真实移动，历史资源原样保留。完整Main实际801帧、36HP、三阶段、5HP存活证明一种基础构筑策略，不签所有策略/玩家趣味。
3. **可射击体与接触危险可分离，但都必须有真实shape和唯一Definition来源。** Bell完整躯干140×144可射击，底盘接触128×110；悬铃/留白不增加接触危险。整个hurt体充接触体的失败、起跳稍晚0.69wu擦边的失败都保留。最终真实Motor满跳+横移越过roll无伤，站桩受伤。不能仅凭几何算峰高或单静图签“可避”。
4. **身体不会随恢复窗消失。** 持续保留shootable body collision layer；body_contact_enabled独立控制intro/phase保护。身体是hit/contact形状而非堵路的墙，Boss自身仍使用Motor实际移动，接触由真实相对扫掠与actor shape验证。
5. **奖励验证需要实际入口token。** 最初fixture直接调`_advance_region_map`跳过真实门确认被正确拒绝，不是生产bug。最终完整战斗后真实门确认+12币一次→第二图，Gold真门/claim/repeat拒绝→Home完成一次；原失败保留。不能为了fixture方便放开`_reward_token`。
6. **同帧死亡以真实碰撞/弹体反序做强验。** 实际Router弹+Boss encounter地波，同一FrameDamagePolicy队列内两顺序×两Boss，双方HP1是明示初始边界fixture，非完整战斗。此前在不变出生保护期间造命中被拒，待实际保护结束再验证。最终44/0，包含段回退旧弹/取消阶段波/JSON不复发；不能以直接改Health代替新战斗命中证据。
7. **历史合同显式冻结。** Legacy两个tres从精确0fab13f原字节保存，旧四脚本所有check原行保留；仅安装真实旧窗口资源/PixelThreePlane消费者、仍驱动当前实际Manifest/Camera。pressure489、platform18、interactive109、energy528均0失败。原正式新旧不匹配失败保存，新formal消费者另以100/44/两完整App强验，不让legacy默认反推正式规则。
8. **严格wrapper必须实际执行生命周期脚本。** `tools/run_underworld_r3_boss_tests.py`无条件组件100+生命周期44；`--full-fights`额外两完整App，所有原engine/script/error/leak/timeout/marker守门保持。GPU影片、音轨/独审、用户手感与实体设备单列；headless计数不签声音/画面/性能。Root在源码冻结后重采完整guard，dirty preflight不改标签冒称新commit。
