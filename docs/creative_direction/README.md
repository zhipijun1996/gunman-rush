# 当前创作入口：从区域主题到真实游戏

本目录是当前区域创作的唯一入口；游戏规则仍由 [AGENTS](../../AGENTS.md) 列出的实际配置、Definition 和设计契约负责，质量仍使用原 [policy](../quality/policy.json)、G0–G5 和十一维。总谱不是另一个质量框架，也不是运行时配置。历史状态、失败原件和冻结Manifest按需追溯，不自动加载为当前设计。

## 三阶段执行

**Pre-production** 由 [region-creative-director](../../.agents/skills/region-creative-director/SKILL.md) 主导：核实当前源码和地区阶段/能力，提出2–3个在玩家行为、空间、生态/Boss、艺术情绪上不同的方向，比较原创性、可行性、吸引力与成本。先设计完整游戏画面的大形、负空间、围合、层深、统一角色/敌人/地形语言和动态音画，再选一个方向。专业推荐可用于已授权的可逆实验；用户最终认可另列，不能伪造。

**Production** 共同引用选定JSON的 `path/sha256/region_id/version`。region-generator、challenge-choreographer与encounter-director共同安排路线/动作/落点/敌区/相位/资源/返回；enemy-creator和boss-creator负责行为实体；visual-director统筹完整游戏画面，art-director制作家族，scene-composer实现实际空间，animation-vfx统一已接受事件的动作音画。先完整可玩艺术样板，通过相关工程和专业审查才拆可复用模块并推广。候选先隔离，失败资产不接正式消费者或导出。旧资产有消费者不代表创意必须继承。

每份专业交付必须回答五项：对总谱的具体贡献；要与谁协作及接口；带来什么新玩家行为或视觉体验；存在什么主题冲突；如何在真实游戏中证伪。不能各专业独立完成后才拼接。总谱变更必须升级版本与绑定，旧下游不再作为当前通过；先RETHINK受影响设计，再重跑受影响工程验证，未变化且证据依赖严格一致的结果可按原缓存规则复用。

**Validation** 同时检查整体主题一致性和工程正确性。ACCEPT仅接受所声明范围、实际证据与当前源码；REWORK复用原有界返工预算；RETHINK停止后继并回预制作；DISCARD停止继续投入，记录隔离要求，另做可逆撤出，不擅删原件。旧reject仍兼容局部返工。独审须实际看完整屏幕/正常速度音画与路线，不以AI评分签市场、用户或真机。审美判断不能豁免物理公平、输入/HP、真实消费者、性能、严格退出与发布CI。

## 当前总谱和短指令

- [风铃平原总谱](windchime_plains.json)：三方向比较、用户已选择“逆风送钟的草海”，样板/整区最终审美未确认；只验证正式RootBell空间，不批量重画全区。
- [荆棘森林总谱](thorn_forest.json)：S2仅H，比较后推荐“听风棘廊”；只作有限真实技术演练，不开放森林，不冒签完整地图、生态或艺术。

```sh
# 短Prompt先启动创意预制作，不再默认把G0/G1小原型当完整生产
python3 tools/level_design.py route --request '制作荆棘森林' --output build/creative_system/start.json
# 活跃宿主按原租约处理专业工作和独审，裸shell不是无人值守模型服务
python3 tools/harness.py --mission build/creative_system/start.json --execute --worker-mode host --evidence-dir build/verification/creative-start
# 方向形成、校验和独审后，使用相同短指令+检查点绑定继续完整分解
python3 tools/level_design.py route --request '制作荆棘森林' --direction docs/creative_direction/thorn_forest.json --output build/creative_system/production.json
# 显式工程原型用于有限真实演练，不能称完整地区
python3 tools/level_design.py route --request '制作荆棘森林' --phase prototype --direction docs/creative_direction/thorn_forest.json --output build/creative_system/prototype.json
```

route只规划。实际执行必须有真实worker/源码修改或设计产出、Godot进程、独立审查和质量记录；`continuation`保存下一命令，当前活跃宿主继续，尚非脱离宿主的后台全自动服务。完整分解保留不同专业任务与依赖；原production_loop同一工作树仍顺序写入，不冒称实现了跨专业安全并发。原Harness的隔离并行检查继续可用。

## 共用工程与证据契约

最新用户授权优先于历史窗口/仅平原/仅工具描述。每任务有完整基线SHA、任务ID、内容版、允许路径、正式消费者、合法能力与来源。LOCKED设计、PROPOSED候选、实际实现、正式授予分开。PlayerMotor唯一求解；单一当前武器、真实资源、RNG、保存、死亡/奖励优先级不为画面让步。

沿原质量记录的design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance十一维，分别用passed/failed/unverified/not_applicable，N/A要理由。证据包含路径、SHA256、版本、退出码和实际观察范围，真实失败原件不删不改、断言不降。技术通过不签完整内容；独审不同实际代理，审查者不改生产代码。缺工程依赖blocked、缺审查review、缺设备awaiting-device；用户/趣味/审美与设备不由AI代签。

开发反馈使用受影响的短专项；局部验收用原消费者正反例；冻结后完整适用回归；发布使用fresh `--release`与同源构建/同包GUI/公开指纹。新创作mission先执行原Godot导入预检，只有合法新UID sidecar可纳入首次源基线，已有源码改变仍calls0拒绝。实际宿主演练的原sidecar漂移失败保留。

`creative-prototype`只执行当前能力技术样板（含严格退出），不把未准入森林样板加入正式地区默认生产。`creative-feedback`是明确工具快查，不是art/gameplay/full替代。`history`是冻结复现索引，当前full仍保留原全部检查；不因新增索引删历史测试。缓存依赖/产物改变即失效，旧绿不冲销新红。

实际阶段成本沿原 `tools/production_timing.py`，分别记录实施/图生/集成/验证/独审/返工/等待/发布。区间求和与并集分开；未知token、价格与纯模型计算不补造。每方向最多两次无实质改善即停，保留原失败和恢复检查点，不能换任务名退款。

## 本轮预算与检查点

2026-10-16本轮预算：审计与架构45分钟目标、observer独立诊断25分钟/最多两候选、艺术样板45分钟/最多两次图生或编辑、短Prompt与冻结回归45分钟目标。阶段可并行，包络不能相加当纯模型工时；超出目标只为收口证据/必要修复显式记录，不重新开启失败美术方向。检查点为baseline→direction-selected→slice-captured→frozen-validation；源码或总谱变化则保留旧证据、重新验证受影响范围。

历史Skill原件及恢复SHA见 [归档](../archive/skill_history/README.md)。历史PR失败与成本审计见本轮交付报告；不再要求每个专业默认读取所有修订记录。
