# 当前项目状态

## 最新：已认可平原美术正式接入（2026-10-13）

PR59 已合入 main a9a9cd2。用户随后明确认可水粉石灰岩合屏并要求完全接入，本轮 PLAINS-TERRAIN-02 将其设为正式两图默认表现，包含实体空中平台与移动平台；可穿透木桥保持原语义。Skills 已加入可复用制作经验。范围、证据、当前验收见 [接入报告](quality/terrain_production.md) 与 [handoff](handoff.md)。下文旧候选/未合并说明仅为历史，不能覆盖本修订。用户认可该美术不等于其余游戏内容、设备和独立审查已通过。

本页是现行规则导航，覆盖历史说明中冲突的入口/范围。数值仍由实际配置和 Definition 提供。新需求变更时同步本页与所属契约，不在每个 skill 复制玩法默认值。

## 当前运行

- 入口：scenes/demo/demo.tscn，标题 → 可操控家园 → 正式平原两张非线性随机连通地图；第一图鸣铃巡游机（Bellstrider，早期称铃行者），第二图牧风者，Boss 完成后显示后续开发边界并安全回家。
- 仅平原开放；六地区长期计划和 world_regions.json 的十六候选地区不等于已实现。三关/八关、Module Lab 和 RANDOM STAGE 为开发/回归消费者。
- 平原默认一跳，未命中基础两发；射击精力按 ShotEnergyDefinition 扣除，接受的真实命中回能并返还一发空中弹药。移动/跳跃不耗精力，慢时实验预算独立。
- 家园与关卡共享控制；存活环境伤害段回退，零血结束本局。同帧死亡优先，回退不重抽地图/刷新机关/奖励。金币与永久音符、局内与 Meta 状态分离。
- Boss 实体门封场、合法高跳不丢射击资格，击败动画完成后原保证奖励结算；视觉宝箱不新增支付。参数、碰撞、随机流与账本不由表现决定。

## 本轮候选修订（2026-10-13）

[当前质量审查与修复](quality/current_review_spec.md) 覆盖平原空间/表现/参考系/战斗生命周期契约；正式路线和数值来源不变。新敌人仅为开发样板，视觉与玩家验收未通过。Skills自动路由；大任务执行见 [生产循环](quality/production_loop.md)。

## 最新修订入口

| 主题 | 当前优先依据 |
| --- | --- |
| 两图探索、迷雾与流程 | [D076](plains_two_maps_fog.md)、[运行契约](run_and_routes.md)、design_contract.json |
| 精力、道具与反馈 | [D079](plains_experience_energy.md)、[资源契约](combat_and_recharge.md) |
| 路线压力与奖励 | [D080](plains_exploration_expansion.md) |
| 表面机关与平台 Boss | [D081](plains_interactive_platforms.md) |
| 共用控制、封场、地形与掉落 | [D082](plains_cohesion.md) |
| Web 分块、校验、恢复与部署 | [D083](web_loading_resilience.md) |

旧规格中一张图/八关、第八 Boss、正式精力未定等描述保留历史用途；不能按旧段落改回正式入口。D083 没有改变 D082 的玩法。

## 整合基线与未验范围

最新 fix/web-loading-resilience 的 924a8d1 已于 2026-10-12 经 [PR54](https://github.com/zhipijun1996/gunman-rush/pull/54) 合入 main（6568e9a）。运行代码与成功 [CI38232680571](https://github.com/zhipijun1996/gunman-rush/actions/runs/38232680571) 的 26906a4 一致，后续为文档证据。历史发布与失败证据见 [D083归档](archive/handoff_d083.md)。

技术测试和浏览器 GUI 有既有证据；完整真人探索趣味性、Android/iPhone、实体手柄、手机内存/CPU、大陆运营商直连继续待验。国内镜像未部署。本轮整理不把这些任务标完成。

## 项目级质量体系（2026-10-12）

本页兼任 project_status，不另建同义副本。质量体系基于最新未合并 [PR55](https://github.com/zhipijun1996/gunman-rush/pull/55) 的 da76b0aa65f257f5208cde23e98aa8d9b3098ad1，运行目录与 main 6568e9a 相同。分支 chore/game-quality-system 只建设流程、文档和检查，不改游戏版本。统一入口见 [quality](quality/README.md)。

多武器分支升级树、完成地区获得新大能力和后续区域能力锁是未来目标，不能算当前已实现；demo_app 明确在第二图完成后提示开发边界，不授予不存在能力。当前生成事实见 [generation_current](generation_current.md)。

PR55 的严格 harness 已在干净工作树暴露 Web 导出 `Parse Error: Busy`（windkeeper.tscn:13）；导出进程返回 0 仍不应通过。此前宽松导出记录不能覆盖该失败。详见 [本次审计](quality/implementation_report.md)。不修改核心 Boss 或放宽错误签名来掩盖它。

交付前复查：本任务执行期间新增 [PR56](https://github.com/zhipijun1996/gunman-rush/pull/56) / feature/ai-platforming-foundry@4ed7ba6，与 PR55 从 main 分叉，是开发工坊消费者，未并入本质量分支或 main。不能把它的二跳/四发开发配置当正式能力发放；后续整合保留其真实回放、来源指纹和 CI。详见 [并行审计](evidence/quality_system/concurrent_pr56.json)。

## 当前质量返工（2026-10-13）

新 player/weapon/ability Skills 和有界生产循环已实现；真实 Codex 子调用因登录失效 blocked，不能称自动大任务已实证成功。平原镜头/暂停/接触规则修复与新登场仍在 review。第一次地形边框和敌人缩放已被拒绝并撤回；原问题保持未解决，新47邻接材质仅在开发gallery。最新证据与范围见 [迭代报告](quality/iteration_report.md)，不得用此前候选描述覆盖新的 REJECT。

## 最新手绘返工与区域对照（2026-10-13，覆盖同主题旧描述）

分支 feature/quality-review-and-production-loop；运行提交 aa40f9071575325884ed523dc66f92145d41913e，PR59保持draft，不合并不发布。现有11核心Skills自动路由；真实多Skill生产循环仍因Codex认证失败blocked。非整格/薄体候选已接入真实区域开发对照，普通正式入口保持基线。v7褐土及v4密集花草均保留拒绝记录，v5水粉石灰岩继续待用户认可。不要把旧“仅整格gallery”当最新实现，也不要把技术通过当美术完成。

完整范围、实际命令、截图录像、独立审查与剩余缺陷见[迭代报告](quality/iteration_report.md)。下一步是针对实际黄金合屏继续美术反馈；原敌人身体/hurtbox、新敌人正式遭遇、Boss视听和真人/设备仍未完成。常用 `python3 tools/harness.py --profile docs`、`python3 tools/run_quality_review_tests.py`。
