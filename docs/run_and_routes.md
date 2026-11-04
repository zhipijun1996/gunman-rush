# 运行、路线与内容复现

## 正式流程

`DemoApp`装配`RunSession`与`RunComposition`，由`DemoRunDirector`管理局生命周期，`RunCampaignProgression`管理能力权益与地区推进。

标题 → 家园 → 新局平原地图1／小Boss → 平原地图2／牧风者 → 能力选择H → 森林地图1 → 森林地图2 → 能力权益与开发边界。平原目前只开放H；W／U1对应的后续地区入口未开放。森林结束权益与下一地区可用性按`RunCampaignProgression`返回结果显示。

每地区是两张连通探索图，普通路线不要求全清怪。Boss合法胜利、保证金奖励及地区推进依次提交，玩家同帧死亡先结束本局。家园是独立安全上下文。

## 状态与提交

| 所有者 | 职责 |
| --- | --- |
| RunSession／DemoRunDirector | 本局服务、运行状态、跨图状态与终局 |
| RunCampaignProgression | 能力权益、已完成地区、地区准入及选择收据 |
| Stage及区域状态 | 本图实例、敌人生命、机关相位、拾取和恢复 |
| DemoLifetime／DemoToken | Run、Stage、Actor epoch；拒绝迟到请求 |
| RunManifest | 内容版本、能力／构筑快照、实际地图、奖励与决策记录 |

转场校验当前token、玩家存活、候选与选择ID，一次锁定目标。相同请求只读返回已提交收据；新图推进stage／actor epoch，保留本局背包、装备、钱包与账本。存活回退只换actor epoch并保留世界状态。

## 随机与Manifest

地图、路线、奖励、商店和Boss攻击使用独立随机流。规范化root seed、命名空间、稳定实例ID、内容与派生算法版本共同决定流；增加奖励抽样不改变地图。

Manifest保存实际输出、算法／内容／物理配置身份、能力快照、稳定对象ID、奖励和交易收据。相同版本与相同决策可复现内容；缺失或不支持的版本明确拒绝。JSON往返须验证身份数值与完整结构。

Manifest用于内容复现，不提供完整中途续局。永久进度另由 [SaveService](home_and_save.md) 提交。

## 开发入口与新来源

三关开发Profile仅用于开发消费者；动作练习、Foundry及mapgen切片有各自明确入口。正式出发使用Plains／Forest Provider；mapgen开发入口通过RuntimeMapV2Provider产出LevelPlan并交给公共Runtime装配。

长期S1–S6／16地区与H/W/D/U1/U2门槛见 [地区设计](design/player_actions/regions_v0.3.md)。新来源必须接真实身体、能力、稳定实例、取消和恢复，再决定是否替换正式入口。相关代码和验证见 [模块导航](module_map.md)。
