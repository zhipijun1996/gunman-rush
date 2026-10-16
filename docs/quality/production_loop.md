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

## 本轮实际调用结果

2026-10-13 已实际执行 `skill-routing-smoke.json --execute`，并非只运行 fake-worker。第一次 `codex exec` 因本机 ChatGPT 登录 token 过期/失效返回 1，执行器保留提示词、事件和退出码并转为 blocked（calls=1）。见 [真实失败状态](../evidence/quality_review/rework/actual_loop_blocked.json)。目前不能声称已经实证自动连续完成森林任务；恢复 Codex 登录后需要新 evidence-dir 重试真实烟测，再执行经设计确认的内容任务。CLI 的“logged in”标签不能替代一次实际调用成功。

## 有界宿主 Codex worker（V2）

现有执行循环支持两个传输入口，任务依赖、Skills、预算、Harness、独立审查和停止规则共用：

```sh
# 默认真实 CLI，需要该 CLI 的有效账户认证
python3 tools/harness.py --mission build/mission.json --execute --worker-mode codex --evidence-dir build/verification/mission-cli
# 当前 Codex 宿主处理实际子代理请求；不是无人值守的独立 shell 模型服务
python3 tools/harness.py --mission build/mission.json --execute --worker-mode host --evidence-dir build/verification/mission-host
```

`host` 模式逐次在 `<evidence>/<task>/<round>/<implement|review>/host_request.json` 发布有期限的请求。当前宿主 Codex 读取请求后，使用真实 collaboration 工具创建对应专业代理，并等待它完成；不是让用户逐步手工选择技能。请求含 task/attempt/role、完整 Skill 来源及 SHA256、提示词、前置任务产出、此前返工记录、允许路径、源码摘要、nonce、request_hash 和 expires_at。

宿主必须把该请求的完整 prompt 与角色/路径边界交给子代理。实现代理与审查代理是不同的实际 agent，审查只读。子代理的原始完成消息应保留为宿主执行证据，不得由宿主编造 ACCEPT。宿主原子写入同目录 `host_response.json`：

```json
{
  "schema_version": 1,
  "request_hash": "原请求值",
  "task_id": "原请求值",
  "attempt": "原请求值",
  "role": "implement",
  "agent_id": "/root/实际子代理规范名称",
  "result": {"status": "ready_for_review", "summary": "真实执行结论", "findings": []}
}
```

使用临时文件后 rename 提交 response。实现只可 ready_for_review/reject/blocked/awaiting_acceptance；只有独立审查可 accept。返回结构、request hash、任务、轮次、角色、期限及 agent ID 都检查，旧 response 不得复用。同一 agent/session 的实现与审查被拒绝。`invocation.json` 标记 `actual_host_codex_agent`，CLI 则为 `actual_codex_exec`；两者不能互相冒充，文件里的 agent 名称本身也不是身份的密码学证明，交付需关联真实宿主调用记录。

宿主需监看 lease 和执行器状态；超时/终止后立即中断仍运行的子代理，不得再提交响应或继续写代码。Python runner 可以拒绝过期响应，不能直接调用宿主 collaboration 中断工具。没有活跃宿主分发请求时，host 模式会在预算内超时并保持 blocked，不能假装模型已执行。

## 阶段完成、反馈和恢复

每次调用把前置任务的完整结果及证据路径传给下游；返工携带上轮 implementation/review 结果和真实 Harness checks。Harness 失败不调用审查，修复后重跑；检查期间源文件发生变化也拒绝 fresh。worker 不能自启动嵌套 agent 或循环绕过 max_calls。CLI 强制非交互 approval_policy=never，保留既有 sandbox，不使用 bypass。

地区 route 从注册表解析名称/alias，生成 `mission.preparation.region_context` 和 `lessons` 并传入每个实际 worker 的 prompt。前者由 `build_region_context` 提取权威设计和代码现状，后者由 `load_lessons` 校验来源、地区/能力范围与证据；computed_proxy/design_review 不会升级为玩家认可。多地区请求冲突或经验来源校验失败会停止；未知地区保留 unregistered/runtime_available=null、经验为空，要求先建立权威来源，不继承平原默认能力或伪造已实现状态。

任务 `completion` 默认只读为 `scope`、生产为 `content`。可显式使用 `stage` 并声明 `required_gates`，只通过原 policy 对应门槛及其证据/场景/当前 production_snapshot 才推进；其他门槛仍保留未验，不把阶段完成当整个内容完成。stage 不能跳过既有门槛依赖、无证据 PASS 或重大创意批准。`content` 仍要求 quality.validate_record 的完整 task_complete；只读最终审查也不能豁免，可用 `quality_task_id` 绑定直接依赖的整合记录。所有状态额外区分 `content_complete`。

地区 route 当前 audit 为 scope、design 为 G0 stage、golden 为 G0/G1 技术 stage、integration 为 G0–G3 stage，最终只读 review 为完整 content 检查。黄金技术通过不授予 G2 美术/正式集成准入；整合必须先满足 G2。缺 G4/G5、玩家或设备证据时仍 awaiting_acceptance，不能靠多次模型会话代签。

每次调用前持久化 active_call 与已消耗预算。异常或被中断的 lease 不静默重放；保留现场并 blocked，用新 evidence-dir 重新验证。相同规格、相同源码和相同 worker transport 下，已完整完成的任务可恢复并跳过；换 transport、外部改动、修改规格均不复用旧完成声明。

2026-10-14 已运行一次真实 CLI 只读探针：CLI 0.159.2 的 `login status` 显示登录，但实际请求因 401/access-token refresh 失败退出 1；MCP 另有 451。原证据在 `build/level_autonomy/probe/initial/`。没有重新登录、切换身份或绕过认证；裸 CLI 成功仍未验证。host 的成功声明必须使用实际宿主子代理证据；单元测试明确采用模拟 worker/response，不能算真实自主执行。

## V3 真实失败后的定向执行与计时

任务的 `checks` 是有顺序的依赖链：先实际消费者清单/资产接口等短专项，再集成与昂贵回归。首个失败保存原日志和检查前缀，停止本任务后续检查及审查；恢复也不越过失败前缀。其他无依赖任务仍继续。缺件预检保留 calls=0；断言通过但进程退出失败依然失败，不把代码/资源生命周期错误称作网络偶发。

每个任务可选 `max_calls`（至少2，不超过mission总额）；失败、重试和中断创建的目录仍计入该方向预算。新一轮同时预留实施与独审的两次调用。用具体未准入家族/消费者分配额度和依赖，不通过换task名重开已停止方向；最终发布与玩家/设备认可继续独立。单任务额度不构成跨mission全局预算服务。

开发 `harness --reuse` 另外验证缓存内的输入摘要和实际产物文件清单/SHA256；目录仍在但产物被删改、加文件、变成链接，均重新运行。旧的目录存在性缓存也不再复用。完整最终发布仍使用 `--release` 强制fresh。

`tools/production_timing.py` 只记录实际命令包络，不执行模型调度或替代原生产循环：

```sh
python3 tools/production_timing.py run --ledger build/production_repair/harness/stages.jsonl --stage game_integration --label actual-family-calibration --log-file build/family-command.log --output build/family/calibration.json -- python3 tools/asset_family.py --source ACTUAL_SOURCE --spec FROZEN_SPEC --output build/family
python3 tools/production_timing.py report --ledger build/production_repair/harness/stages.jsonl --production-dir build/verification/actual-mission --harness-report build/verification/harness/ACTUAL_RUN/report.json --output build/production_repair/harness/timing-report.json
```

`--output`（也可写`--artifact`）只记录命令结束后实际存在的产物与SHA，不重定向stdout/stderr；缺文件明确记missing。需要原生输出时使用`--log-file`写一个新文件，捕获真实合流stdout/stderr并绑定SHA；已存在文件拒绝覆盖。wrapper原样返回命令退出码，不把exit0里的resource ERROR判为成功或代替专项守门。只有elapsed原件没有起止时可用`report --reported-duration STAGE=JSON_FILE`保留seconds/duration_seconds，时间区间仍unknown。

stage包括 `model_implementation/image_generation/game_integration/verification/independent_review/rework/network_wait/release`。实际工具调用不能包在shell时，只导入真实已见证起止时间与原件；缺数据留unknown。新worker invocation与Harness check原件自动记起止及实际耗时；宿主worker包络包含调度/工具/等待，不能称纯模型compute。并行/嵌套的包络分别报告求和、区间并集和重叠，不相加冒充总墙钟；阶段间未记录空隙也单独列出。历史只有seconds的记录保留其原值但不从租约expires或mtime猜起止/阶段；tokens和价格未暴露时记录not_exposed。
