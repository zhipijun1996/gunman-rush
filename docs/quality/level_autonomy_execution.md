# 自主关卡生产：同一个 mission 的真实执行

本轮任务 LEVEL-AUTONOMY-01 / PLAINS-AUTONOMY-01。继承 [Q1–Q8](level_quality_dimensions.md)、[production loop](production_loop.md)、原 G0–G5/十一维。用户已授权一个有界正式平原切片；其余地区只做权威输入与制作流程演练。

入口从仓库根目录调用：

```sh
python3 tools/level_design.py route --request '优化风铃平原' --output build/level_autonomy/mission.json
python3 tools/harness.py --mission build/level_autonomy/mission.json --execute --worker-mode host --evidence-dir build/verification/level-autonomy-run
```

`route` 自动读取地区注册表对应的 regions_v0.3、weapons_v0.8、最新覆盖合同、实际源码消费者及有来源的经验；不是重新编一套能力规则。宿主按目标将通用五阶段计划缩成授权切片，保留依赖、Skills、允许路径、检查、阶段与预算。请求森林时明确 H 硬锁、S2 仅一项核心能力，未实现的正式授予与地区消费者是制作依赖，不当成已开放。

两种 worker 使用同一个执行器：已正常登录的机器可用默认 `codex exec`；当前环境实际 CLI 调用返回401/token刷新失败，失败原件保留，不能称成功。`host` 通过同一 loop 的有界租约接入当前 Codex 宿主真实子代理；它不是假 worker，也不是另一个生产系统。裸 shell 没有 Codex 宿主处理租约时会明确超时停止，不自称后台无人值守。

宿主 Codex 的执行步骤（用户无需手动挑技能或逐步批准）：

1. 启动 execute，读取唯一当前 `host_request.json`，核对任务/轮次/角色、request hash、来源和有效期。
2. 将完整 prompt、Skills、依赖产出、原始检查与前轮拒绝交给实际专业子代理；实施者只改 allowed_paths，审查者只读且使用不同 agent。
3. 子代理执行并写同目录 `host_response.json`，标明真实 canonical agent_id。宿主保留工具调用记录，不用预写结果或假执行日志替代。
4. 原 loop 验证响应绑定与角色、检查文件越界、实际执行原 Harness 检查，然后请求独立审查。失败不会消耗无意义审查调用。
5. 被拒绝后下一轮拿到原检查/原审查，针对具体内容返工；零进展、越界、租约中断、规格变化或预算耗尽停止并保存原因。中断的未知 worker 不会被悄悄重放。
6. 阶段验收只推进本阶段；G5、设备、主观趣味等继续保持未验。完成工程范围不把整个地区伪标 done。

正式观测工具与新诊断消费原工程体系：

```sh
python3 tools/level_formal.py --seed-count 10 --maps 1 2 --strategies fast growth deep return --jobs 3 --output build/level_formal/before
python3 tools/level_design.py experience analyze --batch build/level_formal/before/batch.json --output build/level_autonomy/before-report.json
python3 tools/level_visual_capture.py --strategy deep --map-index 1 --output build/level_autonomy/visible-before
python3 tools/level_design.py experience compare --before build/level_autonomy/before-report.json --after build/level_autonomy/after-report.json --output build/level_autonomy/comparison.json
```

80份真实观测完整保留死亡与策略失败；命令退出0表示采集一致，不表示80路线通关。map2 是合法独立测试入口，不冒称已打赢map1 Boss；奖励通过正式 modal callback，未当作鼠标/触屏验收。正常画面使用1280×720正式镜头、真实软件GPU和60FPS/48kHz音画，仍非实体设备认可。输入请求、接受事件、角色资源、敌人状态、相位、奖励、镜头和失败逐帧定位。

比较要求同 Seed/图/策略/相位、能力、物理、观测器及consumer scope；源码可不同且必须保留原归属。历史 receipt 按其原始快照校验，不改标为当前版本。事实、代理指标、AI审查和用户反馈分开；Q1–Q8 没有虚构趣味分数。

动作事件必须与所属帧 tick 一致，且完整对应 journal 的实际次数，不能复用一个事件清除空白候选。比较会检查原件/receipt 存在及哈希，再从原始轨迹重算整份报告；重算摘要不能赦免被修改的统计、边界或虚构验收。

新正式 receipt 使用 schema2：启动时 running，结束后保存 source_before/source_after、错误及 accepted/rejected 终态。历史分析不能重新接纳 rejected、未完成或前后源码变化的捕获。旧 schema1 默认拒绝；需要用 `level_formal.migrate_legacy_batch(batch_path, frozen_commit)` 显式迁移完整原 batch：原 captured/errors、命令、日志、原件SHA、观测器与全部源码必须匹配冻结 Git 树。迁移只加独立 `batch.migration.json`，不改旧 receipt，也不冒称重新运行引擎。此次80份基线匹配冻结 `e56c29d`，原始运行提交仍保留 `7c981ee`。

本轮实际第一次执行在三次调用后因工具依赖 R-A1–R-A3 正规 blocked。修复后采用新证据目录重验设计依赖，剩余 max_calls=9，加原三次总预算12；原状态、请求、响应与拒绝原因全部保留。跨目录总预算由本次宿主账本核对，执行器本身的硬预算限于单个 mission，不能声称有全局预算服务。

资产优先复用已验证母版和源资产；新素材沿 art-director 的来源、版本、锚点、拼接、合屏和动态检查。没有实际图像模型/产物时只记录待制作规格。当前切片先看真实黄金画面再决定改动，不靠加敌人或放宽观察阈值追数值。
