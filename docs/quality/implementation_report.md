# QUALITY-SYSTEM-01 实施报告

日期 2026-10-12；任务类型 process；质量规范版本 1。本任务交付可执行流程与约束，不新增游戏内容，不发布版本，不自动合并。完整文件清单见文末。

## A. 真实基线与项目现状

已 fetch 全部远端 refs，检查所有开发分支、提交时间和未合并 PR，原始清单见 [remote_refs](../evidence/quality_system/remote_refs.txt)、[open_prs](../evidence/quality_system/open_prs.jsonl)。main=6568e9a41e6268001ae7d132017f409ea83ac475 已包含 PR54/924a8d1 最新玩法。其后最新有效累积基线是未合并 PR55 的 chore/project-harness-skills@da76b0aa65f257f5208cde23e98aa8d9b3098ad1；它引入 harness v1 与四个技能。此次分支 chore/game-quality-system 从该提交创建。

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

实施后的命令、退出码、结果与完整日志将记录于 docs/evidence/quality_system/；以最终质量记录引用的 reviewed_commit 为验收代码版本。阶段中发现的失败、修复与最终回归分别保留，不把计划命令写成执行。

## F. 三个反向测试

[enemy](drills/A_enemy.json)：追踪+接触伤害+单图，无独特决策/预警/动画受击/遭遇，规则预期 4 项拒绝。
[boss](drills/B_boss.json)：三阶段仅 HP/速度变化，无决策变化/机制/反冲/时序，规则预期 4 项拒绝。
[region](drills/C_region.json)：坐标/顺序/Seed 变化，缺动作差异/真实 Motor/节奏/风险奖励/完整路线，规则预期 5 项拒绝。

`python3 tools/quality_drills.py` 对预先标明观察事实的隔离样本执行 rubric；三者必须 REJECT。即使把所有观察改成 true，结果也只 UNVERIFIED，不会自动宣布内容通过。这是模板演练和拒绝逻辑测试；不是自然语言模型独立判断，不是实际 Codex Skill 调用，不改变正式游戏。

## G. Git 交付

分支 chore/game-quality-system；基线 da76b0a；以 PR55 分支为 base 创建可审阅堆叠 PR，避免混淆前轮改动。最终提交/PR 地址由 handoff 与 Git 日志记录；不自动合并，不发新游戏版本。

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

最终 Git 差异对应文件及职责在交付前填写。
