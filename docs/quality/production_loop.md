# 大任务生产循环

`tools/harness.py` 保留原有检查模式，并通过 `--mission` 调用 [production_loop.py](../../tools/production_loop.py)。Skills 是工作指令；harness 是负责顺序、检查、证据和停止条件的执行器。Codex 可以根据 AGENTS 和 Skill description 自动选择技能；用户无需每次命名，但 `$weapon-creator` 等显式调用可固定主导职责。

任务先由 game-quality-gate 拆成有依赖的 G0–G5 工作包；同一内容共享一份质量记录。新主角→player-creator，武器/升级→weapon-creator，新能力及能力锁→ability-creator。一次武器改造同时覆盖持枪、瞄准、松手开火、弹体、反冲、空中、命中、落地及换装/暂停/撤销，不能只改伤害数值。

```sh
# 只查看计划，不会调用模型
python3 tools/harness.py --mission docs/quality/missions/forest.example.json
# 实际执行已填写并审阅的任务（需要本机 codex 登录）
python3 tools/harness.py --mission build/forest-mission.json --execute --evidence-dir build/verification/forest-01
# 中断后使用相同命令续做；已完成依赖不重复调用
```

每包执行：专业 Skill 实现 → 既有 harness 检查 → 新的只读 Codex 会话独立审查 → 携失败报告修复。检查失败不消耗一次无意义的审查调用。原始 prompt、JSONL、退出码、耗时、结构化结果、每轮检查日志和状态全部保存；这是真实 `codex exec`，单元测试的假 worker 另有明确标注。脚本的独立会话不能保证审查结论正确，仍须核对证据；GUI/设备/用户认可不能靠会话数量代替。

任务按拓扑排序，循环检查依赖、max_rounds、max_calls、单次超时。失败无文件进展、超预算、异常写入、创意/玩家验收缺失都会停止，不会无限自修复。`complete` 只表示该任务声明范围完成；读档/暂停/G5等适用要求仍由质量记录约束。生产记录必须通过 quality.validate_record，task_id 一致，且 production_snapshot 是当前仓库（排除 docs/quality/records/）的文件哈希字典摘要；可用 `production_loop.digest({... production_loop.snapshot() ...})` 计算。旧 done 记录不能替新修改放行。

只读审查启动 `codex exec -s read-only`；实现使用 workspace-write。执行器检测越界文件变更后停止并保留现场，不偷偷撤销。路径检查是误改检测，不是安全隔离；在独立工作树运行已授权任务，不给不可信任务授予工具/凭证。循环不执行 push、merge 或发布，任务提示也禁止这些操作。

外部改动或任务规格变化会让旧恢复状态失效。先审查现有修改，再用新 evidence-dir 重新验证；不能修改旧证据冒充连续通过。awaiting_acceptance/blocked/budget_exhausted 是明确停止点，确认或修订后新建一轮保留前轮证据。暂不实现后台无人值守服务、跨任务并发写同一工作树或无限自动扩张需求。

森林任务的 goal 必须写明用户批准的体验、内容数量/范围、约束和消费者；示例只是依赖拆分，不代表用户已批准森林机制。大任务涉及多关卡/敌人/Boss时，先做一个完整黄金样板，审查后再扩展，最后做连续区域集成和完整路线体验审查。
