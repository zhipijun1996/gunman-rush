# 当前状态

2026-10-22，分支 `feature/region-bible-v2-forest`，草稿 [PR101](https://github.com/zhipijun1996/gunman-rush/pull/101)，未合 main。任务 FOREST-VARIETY-04 开发中；本轮是第一批探索场所原型，整森林未完成。

## 当前公开试玩

[恢复的旧森林 v15](https://zhipijun1996.github.io/gunman-rush/?v=12ac19e2ec02)，build `12ac19e2ec02`，运行源 `bbf5b24dc6a27374119f67f11fc2eed92a57ba00`。入口 DEVELOPMENT DEMOS → SELECT REGION → THORN_FOREST MAP 1/2。prepared Pages [39704078082](https://github.com/zhipijun1996/gunman-rush/actions/runs/39704078082) 已验证成功；[恢复原件](evidence/forest_variety_03/public_restore/report.json)。不能把这个旧包说成本轮扩容。

## 新候选 v18

保留用户肯定的 v15 核心、早段休整侧根、旧 HH／螺旋技巧线；默认入口仍 v15。新显式 FOREST PLACES MAP 1/2 接入双窗树腹、7型高枝回落、Z折根内外路、倒木上下路；图二另有固定果 H 后反向射击到背枝高奖励。Z／倒木次序由真正的 root seed 决定，两图取相反顺序，另有结构变体。Boss 完整 factory 随最终出口后移，无需清空宝箱才能开门。

奖励是实际金币或音符二选一：七型／倒木4或1、Z6或2、背枝5或2。不是更多短平台梯，不改物理／Motor／资源／能力／保存；活果渡口仍未实现。当前是多个分流汇流场所的链，尚非充分网状地图；没有把顺序／几何签名当作趣味性证明。

用户每图正常8–12分钟、充分探索15–20分钟为初步真人目标，未计时验证。实际路线证据只证明所列出生点／fixture旅程到 Boss 门前，不能换算真人游玩时长或 Boss 战验收。

## 质量与待办

[设计与范围](design/forest_exploration_v18.md)、[原件及失败索引](evidence/forest_variety_04/README.md)、[十一维记录](quality/records/FOREST-VARIETY-04.json)。33项原轮在600秒超时，保留原 FAIL；基础路线和新模块库已拆成可选开发检查，预算／守卫不变，原80/full/CI不变。

实际App04独审拒绝倒木直角L框；18.3已改真实外弯根腹，App05独审确认有实质轮廓改善，仅允许继续玩法验证，没有 ART 通过。Z细悬臂／倒L、背枝浮空平梁／通屏恢复层及森林材质仍需定稿。两条树皮材质尝试失败均保留、未接入。不能把原型当整区美术或用户认可再次覆盖旧公开包。

继续先完成森林含美术，再优化风铃平原。两份完整Bible、共享 Underworld16px/32wu 家族与自然覆生荆棘平台要求有效；BGM由用户后续引入，未生成或替换。整体难度曲线、更多有趣模块、充分网状探索、人类时长和实体设备／玩家认可仍未完成。

最新限定技术结果：新库16项fresh inner／outer通过（334.075秒）；倒木18.3之后两图正式出生点主路线fresh通过（135.791秒），全源稳定。不追认原33超时，不签全量回归、真人时长或ART。

首次Web构建真实失败：旧Foundry池的basis包含整个generation目录，新增区域脚本使其失配。已用原工具实际重新验证36短语／18连续路线与回放，只更新开发池JSON／export stamp；没有直接换SHA或改guard，森林几何／动作／参数字节未动。第一次失败保留，Web重试结果另记。
