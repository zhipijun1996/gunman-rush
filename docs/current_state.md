# 当前项目状态

本页是现行规则导航，覆盖历史说明中冲突的入口/范围。数值仍由实际配置和 Definition 提供。新需求变更时同步本页与所属契约，不在每个 skill 复制玩法默认值。

## 当前运行

- 入口：scenes/demo/demo.tscn，标题 → 可操控家园 → 正式平原两张非线性随机连通地图；第一图铃行者，第二图牧风者，Boss 完成后显示后续开发边界并安全回家。
- 仅平原开放；六地区长期计划和 world_regions.json 的十六候选地区不等于已实现。三关/八关、Module Lab 和 RANDOM STAGE 为开发/回归消费者。
- 平原默认一跳，未命中基础两发；射击精力按 ShotEnergyDefinition 扣除，接受的真实命中回能并返还一发空中弹药。移动/跳跃不耗精力，慢时实验预算独立。
- 家园与关卡共享控制；存活环境伤害段回退，零血结束本局。同帧死亡优先，回退不重抽地图/刷新机关/奖励。金币与永久音符、局内与 Meta 状态分离。
- Boss 实体门封场、合法高跳不丢射击资格，击败动画完成后原保证奖励结算；视觉宝箱不新增支付。参数、碰撞、随机流与账本不由表现决定。

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
