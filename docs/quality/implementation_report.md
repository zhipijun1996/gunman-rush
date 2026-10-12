# QUALITY-SYSTEM-01 实施报告

日期 2026-10-12；任务类型 process；质量规范版本 1。本任务交付可执行流程与约束，不新增游戏内容，不发布版本，不自动合并。完整文件清单见文末。

## A. 真实基线与项目现状

已 fetch 全部远端 refs，检查所有开发分支、提交时间和未合并 PR，原始清单见 [remote_refs](../evidence/quality_system/remote_refs.txt)、[open_prs](../evidence/quality_system/open_prs.jsonl)。main=6568e9a41e6268001ae7d132017f409ea83ac475 已包含 PR54/924a8d1 最新玩法。开工审计时最新有效累积基线是未合并 PR55 的 chore/project-harness-skills@da76b0aa65f257f5208cde23e98aa8d9b3098ad1；它引入 harness v1 与四个技能。此次分支 chore/game-quality-system 从该提交创建。

交付前第二次 fetch 发现执行期间新增 [PR56](https://github.com/zhipijun1996/gunman-rush/pull/56)（17:13，4ed7ba6）。它是从 main 分出的并行开发工坊，不包含 PR55；已核对其流程和导出审查，本任务不混入它的 112 个运行/数据文件。后续整合保留其消费者与测试，详情见 [并行审计](../evidence/quality_system/concurrent_pr56.json)。因此 da76b0a 是本任务冻结的流程基线，不声称交付时远端没有更新分支。

Godot 4.7.2 Standard / GDScript；scripts 放玩家/敌人/Boss/生成/Run 服务，scenes 与 resources 是正式消费者/Definition，config 是参数来源，assets 保留运行资源及谱系；tools/tests 为既有验证。当前入口 scenes/demo/demo.tscn：标题→可控家园→平原两张非线性连通图，第一图鸣铃巡游机，第二图牧风者。三关/八关、Module Lab 是历史回归，不替代正式流程。平原一跳、基础两发未命中空中射击，真实命中返能/弹；多武器分支树和区域末新大能力尚未实现，不将用户长期目标写成当前事实。

审计复用 AGENTS、README、handoff、tasks、acceptance、architecture/module_map、各机制/美术/生成文档与真实实现。[current_state](../current_state.md) 继续承担 project_status，不另造重复页面；新 generation_current 区分算法事实与质量设计要求。旧同义技能由新技能接替；历史玩法文档加当前权威导航，保留回归/来源，不删除运行素材或游戏逻辑。

基线缺陷：PR55 严格 Web CI 失败，在干净 detached da76b0a 工作树运行 `python3 tools/harness.py --profile web` 同样失败（harness 退出 1）。[原始报告](../evidence/quality_system/baseline_web/report.json) 和 [导出日志](../evidence/quality_system/baseline_web/web-build.log) 保留：Godot 报 windkeeper.tscn:13 `Parse Error: Busy`，导出子进程却返回 0。严格 harness 拒绝正确；未降标，也未借流程任务改 Boss。HARNESS-WEB-01 跟踪后续修复。此前完整导出记录不能证明严格检查已通过。

## B. 八个核心 Skills

每个文件都有官方 name/description 元数据、触发边界、输入、G0–G5 阶段/交付物、详细设计、自动/人工验收、准入退出、返工和证据状态。官方规范与核验来源见 [skill_source](../evidence/quality_system/skill_source.json)。项目目录 .agents/skills，显式 `$skill-name`；没有伪称实际宿主调用成功。

| Skill | 触发及主责 | 调用关系 | 交付与关键验收 |
| --- | --- | --- | --- |
| game-quality-gate | 重大内容全流程、小修按适用性 | 路由专业技能，统一一份记录 | 设计/任务/质量记录，拒绝无证据 done；process 不要求未来游戏试玩 |
| enemy-creator | 新敌人/行为改造 | gate + art/animation/reviewer | 敌人卡、状态机、可玩场景、遭遇矩阵、连续录像；独特操作价值/真实弹体/正式池 |
| boss-creator | 新 Boss/核心阶段机制 | gate + art/animation/reviewer | 设计、竞技场、各阶段样板及整战；阶段决策变化、真实弱点、反冲空间、公平与记忆点 |
| level-module-creator | 跳跃挑战/模块接口 | gate + art/animation（适用）/reviewer | 模块卡、端口相位/邻接矩阵、输入轨迹；真实 Motor、资源/扫掠/接缝/恢复/镜头 |
| region-generator | 大地图与探索编排 | gate + level/art/reviewer | 五层设计、Manifest/种子、结构/动作统计、三种路线；A–G 分开验收 |
| art-director | 资产/母版/风格精修 | gate + animation/reviewer | 黄金合屏、母版谱系、连接件矩阵、来源账本；实际画面及用户认可 |
| animation-vfx | 动作/过渡/视听反馈 | gate + art/reviewer | 状态/锚点/时间轴、带音轨正常速度录像；枪口/脚底/事件同步/取消与预算 |
| gameplay-reviewer | 独立严格审查 | 接同任务规格/冻结版本，不改被审生产代码 | 发现/反例/REJECT/复审链；独立性、正式操作、十类质量及用户/设备分离 |

project-integration 保留辅助 Git/清理/发布范围。game-iteration、level-generation、game-art 删除并记录迁移，不再有并行竞争规范。

## D. 工作机制与状态

G0 设计→G1 真实灰盒→G2 正式合屏/连续视听→G3 正式消费者→G4 自动检查/独立严格审查→G5 玩家/设备。总流程 [development_quality](../development_quality.md)，机器最小合同 [policy](policy.json)。重要内容不能删掉相关门槛；纯流程及普通修复只做适用项。

十一维 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance，分别 passed/failed/unverified/not_applicable（原因）。planned/ready/in_progress/review/done/blocked/awaiting-device 继续使用；done 被检查器约束。内容未获用户认可不能完整完成；本流程建设的完成与未来游戏内容验收无关。

检查器要求场景/方法/观察/失败条件、版本和原始证据，核对文件哈希及证据类型，拦截自审冒充独立审查、AI 反馈冒充用户、无物理设备的验收。新增 PR 差异守卫要求生产变更有非 process 任务、素材有来源、新 done 有完成记录，并对删除/改动既有断言和删套件报警。它不能认证真人身份、解读录像质量或证明任意代码没有绕过断言；仍需实际审查。

## E. 实际检查

固定实现提交 **8bac191769c4d0e94ef4ae0fa5c07919048b1dd4** 的实际 [命令/退出码](../evidence/quality_system/implementation/commands.json) 和 [harness 报告](../evidence/quality_system/implementation/core/report.json) 已归档。

| 实际命令（仓库根目录） | 退出码 | 结果 |
| --- | --- | --- |
| python3 tools/harness.py --profile core | 0 | 9 检查通过：docs/world/structure、11 harness 单测、25 quality 单测、3 演练、环境、Godot Core5942/0 |
| python3 tools/check_quality_diff.py --base da76b0aa65f257f5208cde23e98aa8d9b3098ad1 | 0 | 生产归属、新 done、测试/套件保留与源码新鲜度检查 |
| python3 tools/quality_drills.py | 0 | 三样本全部 REJECT，4/4/5 项发现 |
| python3 tools/quality.py check docs/quality/records/QUALITY-SYSTEM-01.json --require-complete（记录未完成时） | 1 | 预期拒绝，原始失败保留；不能自动变 PASS |
| git diff --exit-code da76b0a -- scripts scenes resources config assets shaders project.godot export_presets.cfg | 0 | 无生产差异 |
| git diff --check | 0 | 无空白错误 |

最终状态/交接/报告归档后的 docs、完成记录与 diff 再检见 final_checks.json。43 套历史/15 套地区没有在本地重复全部跑，本轮没有运行变更；PR 既有 CI 仍保留它们。模板演练和自检限制见 [self_review](../evidence/quality_system/self_review.md)。

## F. 三个反向测试

[enemy](drills/A_enemy.json)：追踪+接触伤害+单图，无独特决策/预警/动画受击/遭遇，规则预期 4 项拒绝。
[boss](drills/B_boss.json)：三阶段仅 HP/速度变化，无决策变化/机制/反冲/时序，规则预期 4 项拒绝。
[region](drills/C_region.json)：坐标/顺序/Seed 变化，缺动作差异/真实 Motor/节奏/风险奖励/完整路线，规则预期 5 项拒绝。

`python3 tools/quality_drills.py` 对预先标明观察事实的隔离样本执行 rubric；三者必须 REJECT。即使把所有观察改成 true，结果也只 UNVERIFIED，不会自动宣布内容通过。这是模板演练和拒绝逻辑测试；不是自然语言模型独立判断，不是实际 Codex Skill 调用，不改变正式游戏。

## G. Git 交付

分支 chore/game-quality-system；基线 da76b0a；以 PR55 分支为 base 创建可审阅堆叠 PR，避免混淆前轮改动。实现提交 8bac191；最终证据归档提交/PR 地址由 handoff 与 Git 日志记录；不自动合并，不发新游戏版本。

## H. 未验证与边界

实际 Codex 宿主发现/显式调用和真正独立审查未执行，记录 unverified。静态 Skill 格式有效不等于 AI 每次都会遵循；后续用一个真实小切片验证。未来游戏美术/趣味/动作认可、Android/iPhone/实体手柄性能、大陆运营商体验均未在本轮验收。没有新素材，旧许可未知项不倒填。基线严格 Web 导出失败独立保留；不是本轮流程测试通过就自动解决。

## I. 可复制 Codex 任务

以下均在仓库根目录调用，先查最新基线；重大创意先标 proposed，独立可逆工作继续，未确认不伪称最终批准。

1. `$game-quality-gate $enemy-creator`：建立 ENEMY-NEXT-01，先对照已有平原敌人提出一个能改变落点/反冲决策的新敌人。使用 Enemy Sheet，按 G0–G5 制作真实弹体灰盒、区域母版、动作与遭遇矩阵、正式池接入和失败反例。共用 art-director/animation-vfx/reviewer；重大新机制先供我确认，缺玩家/设备证据保持 review。
2. `$game-quality-gate $boss-creator`：建立 BOSS-NEXT-01，为未来新 Boss 提出三阶段原创机制；逐阶段必须改变策略并利用反冲空间。先交设计和竞技场，再各阶段可玩样板及完整战斗、预警/判定/恢复时间轴、死亡/奖励/取消测试。不修改牧风者或鸣铃巡游机现有设计，不把增加 HP/速度当阶段创新。
3. `$level-module-creator`：建立 MODULE-NEXT-01，制作依赖当前真实能力的反冲跳跃挑战。记录入口速度/资源/冷却、端口和相位，真实输入验证正反向、身体扫掠、失败恢复、相邻拼接及镜头可见性；不改 PlayerMotor 基础物理，完整验收前不入正式池。
4. `$region-generator`：建立 REGION-NEXT-01，复用现有 PlainsRegionGenerator/Topology/Recipes/Assembler/RNG 扩展探索编排。先写五层设计，保持 Manifest/保底；分别验证结构、真实操作、能力、复现、拓扑/动作多样性与三种真实路线。新能力尚未实现就不把它作为可用前提。
5. `$art-director`：建立 ART-NEXT-01，为拟议地区制作原创童话手绘黄金合屏候选。先读 Visual Bible，给母版/角色比例/材质光照/功能色与地形连接件方案；在真实镜头检视并留来源元数据，等我认可母版再批量扩展，不改碰撞适配图片。
6. `$animation-vfx`：建立 ANIM-NEXT-01，优化现有角色“瞄准→松手→弹体→反冲→空中→命中/落空→落地”连续动作。记录锚点和事件时间轴，验证朝向/连续操作/受伤/暂停/慢时，交带音轨正常速度录像和必要逐帧诊断。表现只订阅玩法，不改变射击与物理。
7. `$gameplay-reviewer`：独立审查任务 TASK-ID 的具体实现 SHA，读取其设计/证据，自己从正式入口验证并构造失败反例；检查设计、操作、美术动画视听、公平、多样性、正式接入、状态保存和性能。只出含复现与严重性的 ACCEPT/REJECT/UNVERIFIED 报告，不修改被审生产代码；无法实际独立则明确标记 unverified。

## C. 文件清单

以下均为仓库根目录相对完整路径；工作区前缀为 /workspace/gunman-rush/。仅删除三项已被替代的旧 Skill，其余文件新增或完善；不删除运行资产或游戏测试。

| 路径 | 作用 |
| --- | --- |
| `.agents/skills/animation-vfx/SKILL.md` | 项目技能：animation-vfx 的触发、工作流、交付与验收 |
| `.agents/skills/art-director/SKILL.md` | 项目技能：art-director 的触发、工作流、交付与验收 |
| `.agents/skills/boss-creator/SKILL.md` | 项目技能：boss-creator 的触发、工作流、交付与验收 |
| `.agents/skills/enemy-creator/SKILL.md` | 项目技能：enemy-creator 的触发、工作流、交付与验收 |
| `.agents/skills/game-art/SKILL.md` | 删除：被八个专用 Skill 接替，迁移映射见使用说明 |
| `.agents/skills/game-iteration/SKILL.md` | 删除：被八个专用 Skill 接替，迁移映射见使用说明 |
| `.agents/skills/game-quality-gate/SKILL.md` | 项目技能：game-quality-gate 的触发、工作流、交付与验收 |
| `.agents/skills/gameplay-reviewer/SKILL.md` | 项目技能：gameplay-reviewer 的触发、工作流、交付与验收 |
| `.agents/skills/level-generation/SKILL.md` | 删除：被八个专用 Skill 接替，迁移映射见使用说明 |
| `.agents/skills/level-module-creator/SKILL.md` | 项目技能：level-module-creator 的触发、工作流、交付与验收 |
| `.agents/skills/project-integration/SKILL.md` | 项目技能：project-integration 的触发、工作流、交付与验收 |
| `.agents/skills/region-generator/SKILL.md` | 项目技能：region-generator 的触发、工作流、交付与验收 |
| `.github/pull_request_template.md` | PR 质量声明和证据模板 |
| `.github/workflows/docs.yml` | CI 添加 PR 差异守卫、保留所有旧检查 |
| `AGENTS.md` | 现行权威、八技能路由与底线 |
| `README.md` | 质量体系使用入口 |
| `docs/acceptance_tests.md` | 流程体系场景/方法/预期/失败验收 |
| `docs/animation_vfx_standards.md` | 核心动作、锚点、时间轴与视听/生命周期规范 |
| `docs/archive/handoff_harness_v1.md` | 保存 v1 交接，防止历史覆盖当前结论 |
| `docs/content_pipeline.md` | 合屏优先、母版变体与素材谱系管线 |
| `docs/current_state.md` | project_status 职责、正式玩法/未来能力/并行分支 |
| `docs/development_quality.md` | G0–G5、十一维、状态映射和反捷径权威 |
| `docs/enemies_and_bosses.md` | 已有敌人/Boss 契约与新流程导航 |
| `docs/evidence/quality_system/baseline_web/docs.log` | 保留 da76b0a 干净 Web 失败原始报告/日志：docs.log |
| `docs/evidence/quality_system/baseline_web/harness-tests.log` | 保留 da76b0a 干净 Web 失败原始报告/日志：harness-tests.log |
| `docs/evidence/quality_system/baseline_web/report.json` | 保留 da76b0a 干净 Web 失败原始报告/日志：report.json |
| `docs/evidence/quality_system/baseline_web/structure.log` | 保留 da76b0a 干净 Web 失败原始报告/日志：structure.log |
| `docs/evidence/quality_system/baseline_web/web-build.log` | 保留 da76b0a 干净 Web 失败原始报告/日志：web-build.log |
| `docs/evidence/quality_system/baseline_web/web-cache.log` | 保留 da76b0a 干净 Web 失败原始报告/日志：web-cache.log |
| `docs/evidence/quality_system/baseline_web/world.log` | 保留 da76b0a 干净 Web 失败原始报告/日志：world.log |
| `docs/evidence/quality_system/concurrent_pr56.json` | 审计、来源、自检、并行分支或最终验证证据：concurrent_pr56.json |
| `docs/evidence/quality_system/final-diff.log` | 审计、来源、自检、并行分支或最终验证证据：final-diff.log |
| `docs/evidence/quality_system/final-docs.log` | 审计、来源、自检、并行分支或最终验证证据：final-docs.log |
| `docs/evidence/quality_system/final-record.log` | 审计、来源、自检、并行分支或最终验证证据：final-record.log |
| `docs/evidence/quality_system/final-whitespace.log` | 审计、来源、自检、并行分支或最终验证证据：final-whitespace.log |
| `docs/evidence/quality_system/final_checks.json` | 审计、来源、自检、并行分支或最终验证证据：final_checks.json |
| `docs/evidence/quality_system/implementation/commands.json` | 固定 8bac191 实现的真实检查结果/日志：commands.json |
| `docs/evidence/quality_system/implementation/core.log` | 固定 8bac191 实现的真实检查结果/日志：core.log |
| `docs/evidence/quality_system/implementation/core/core.log` | 固定 8bac191 实现的真实检查结果/日志：core.log |
| `docs/evidence/quality_system/implementation/core/docs.log` | 固定 8bac191 实现的真实检查结果/日志：docs.log |
| `docs/evidence/quality_system/implementation/core/environment.log` | 固定 8bac191 实现的真实检查结果/日志：environment.log |
| `docs/evidence/quality_system/implementation/core/harness-tests.log` | 固定 8bac191 实现的真实检查结果/日志：harness-tests.log |
| `docs/evidence/quality_system/implementation/core/quality-drills.log` | 固定 8bac191 实现的真实检查结果/日志：quality-drills.log |
| `docs/evidence/quality_system/implementation/core/quality-tests.log` | 固定 8bac191 实现的真实检查结果/日志：quality-tests.log |
| `docs/evidence/quality_system/implementation/core/quality.log` | 固定 8bac191 实现的真实检查结果/日志：quality.log |
| `docs/evidence/quality_system/implementation/core/report.json` | 固定 8bac191 实现的真实检查结果/日志：report.json |
| `docs/evidence/quality_system/implementation/core/structure.log` | 固定 8bac191 实现的真实检查结果/日志：structure.log |
| `docs/evidence/quality_system/implementation/core/world.log` | 固定 8bac191 实现的真实检查结果/日志：world.log |
| `docs/evidence/quality_system/implementation/diff.log` | 固定 8bac191 实现的真实检查结果/日志：diff.log |
| `docs/evidence/quality_system/implementation/drills.log` | 固定 8bac191 实现的真实检查结果/日志：drills.log |
| `docs/evidence/quality_system/implementation/production-unchanged.log` | 固定 8bac191 实现的真实检查结果/日志：production-unchanged.log |
| `docs/evidence/quality_system/implementation/unfinished-rejection.log` | 固定 8bac191 实现的真实检查结果/日志：unfinished-rejection.log |
| `docs/evidence/quality_system/implementation/whitespace.log` | 固定 8bac191 实现的真实检查结果/日志：whitespace.log |
| `docs/evidence/quality_system/open_prs.jsonl` | 审计、来源、自检、并行分支或最终验证证据：open_prs.jsonl |
| `docs/evidence/quality_system/remote_refs.txt` | 审计、来源、自检、并行分支或最终验证证据：remote_refs.txt |
| `docs/evidence/quality_system/self_review.md` | 审计、来源、自检、并行分支或最终验证证据：self_review.md |
| `docs/evidence/quality_system/skill_source.json` | 审计、来源、自检、并行分支或最终验证证据：skill_source.json |
| `docs/generation_current.md` | 实际生成架构/版本和五层七项分验 |
| `docs/handoff.md` | 当前成果、准确验证、失败、并行工作与后续入口 |
| `docs/harness.md` | 新增质量检查、CI 与语义限制 |
| `docs/procedural_generation.md` | 历史规范用途与当前权威导航 |
| `docs/quality/README.md` | 实际命令、技能迁移、官方规范和证据限制 |
| `docs/quality/drills/A_enemy.json` | 隔离低质量设计反例：A_enemy |
| `docs/quality/drills/B_boss.json` | 隔离低质量设计反例：B_boss |
| `docs/quality/drills/C_region.json` | 隔离低质量设计反例：C_region |
| `docs/quality/implementation_report.md` | A–I 交付报告、完整文件路径和七条任务示例 |
| `docs/quality/policy.json` | 单一机器门槛/维度/任务类型/证据策略 |
| `docs/quality/records/QUALITY-SYSTEM-01.json` | 本流程任务实例及实际证据，不冒充内容完成 |
| `docs/tasks.md` | 流程 done 与 Web 独立阻塞任务 |
| `docs/templates/animation_vfx_specification.md` | 可复用设计/任务/审查/质量或资产元数据模板：animation_vfx_specification |
| `docs/templates/art_asset_metadata.json` | 可复用设计/任务/审查/质量或资产元数据模板：art_asset_metadata |
| `docs/templates/art_asset_specification.md` | 可复用设计/任务/审查/质量或资产元数据模板：art_asset_specification |
| `docs/templates/boss_design.md` | 可复用设计/任务/审查/质量或资产元数据模板：boss_design |
| `docs/templates/enemy_design.md` | 可复用设计/任务/审查/质量或资产元数据模板：enemy_design |
| `docs/templates/gameplay_review_report.md` | 可复用设计/任务/审查/质量或资产元数据模板：gameplay_review_report |
| `docs/templates/iteration.md` | 可复用设计/任务/审查/质量或资产元数据模板：iteration |
| `docs/templates/level_module_design.md` | 可复用设计/任务/审查/质量或资产元数据模板：level_module_design |
| `docs/templates/quality_gate_acceptance.md` | 可复用设计/任务/审查/质量或资产元数据模板：quality_gate_acceptance |
| `docs/templates/region_generation_design.md` | 可复用设计/任务/审查/质量或资产元数据模板：region_generation_design |
| `docs/visual_bible.md` | 统一视觉语言和黄金合屏准入 |
| `tests/test_quality.py` | 25 个防伪、完成、差异、来源和反例单元测试 |
| `tools/check_project.py` | 项目入口检查改为从统一 policy 发现八核心技能 |
| `tools/check_quality.py` | 技能/元数据/模板/引用/任务与资产静态检查 |
| `tools/check_quality_diff.py` | 生产归属/素材/新增完成/旧断言与受审版本差异保护 |
| `tools/harness/profiles.json` | 所有 profile 添加质量检查，原套件不减 |
| `tools/quality.py` | 记录生成、状态/证据/版本/完成和资产元数据校验 |
| `tools/quality_drills.py` | 三个可重复模板拒绝演练；不冒充真实 Skill 调用 |
