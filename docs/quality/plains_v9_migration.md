# 正式平原 v9：兼容与历史重演边界

2026-10-14；`PLAINS-ACTION-GOLDEN-01`。本轮正式内容由 `plains-region-v8` 升级为 `plains-region-v9`，随机派生版本仍 `plains-region-v4`。这次版本升级承认实际配方/几何变化，不把旧v8原件改标为新运行。完整交付范围见 [报告](../level_autonomy_delivery.md)。

## 实际变化

仅既有 `thorn_gap` recipe改为 `plains_thorn_bridge`340→`plains_low_arch`640，既有selector/随机抽样规则/其他recipe不改。1000连接中的20尾缝只在该组合、同高端点扩大为40宽collar，左叠入arch20，右端和接收侧one-way不变。该节点geometry显式序列化 `standing_margin=16`，`PlainsRegionGenerator`实际hydration消费者重建distinct ports；其他节点默认20。不能推广成通用thin-join容差或改基础物理。

内容VERSION进入新Manifest/encounter plan/校验；RNG_VERSION不变使同Seed的拓扑、派生流及其他内容抽样按原规则运行。版本变化与manifest hash变化不能当随机性、玩法丰富度或用户认可证据。

## 消费者兼容矩阵

| 原件/消费者 | 当前行为 | 可以声明的范围 |
| --- | --- | --- |
| 当前真实DemoApp v9 Manifest/RunManifest | 实际roundtrip和regenerate通过 | 当前内容版本可重建；完整游戏/设备另验 |
| 冻结真实旧v8 generated Manifest | 当前v9 generator明确拒绝 | 没有静默升级；不能在当前源重演成原地图 |
| 冻结真实旧v8 RunManifest | 当前regenerator明确拒绝 | 不承诺旧运行版本跨内容继续 |
| 历史v8 capture分析 | analysis显式支持v8/v9，并校验原receipt/源/配置/观测器 | 可以读旧事实，不能称当前源重新执行 |
| unknown Plains版本 | analysis/运行校验拒绝 | 未实现迁移，不自动猜测 |
| 冻结旧源码归档＋其原配置/素材/工具 | 可恢复旧消费者重演 | 须核对逐文件SHA与旧版本；不是现行v9消费者 |
| MetaSave、Motor、武器、资源服务 | 本轮未改变 | 不把RunManifest拒绝写成永久存档格式已迁移 |

旧v8原件和当前v9 actual roundtrip均在真实Godot黄金中验证，非fixture手工拼造版本字符串。原冻结正例171/0保留，最终当前黄金增加真实方向顺序/连续衔接断言为187/0；实际坏岸29/4 exit1。独立 `/root/action_versioned_reviewer` 在不同只读代理核对源码/原件、重跑正负例后接受G0/G1范围。最终框架独立复审 `ACCEPT_SCOPED`，47项回归由full2的41通过与fresh targeted release12/12合并覆盖，不是单次full47PASS；Foundry36短语/18路线真实重验证，56JSON/326值仅basis/hash/manifest_hash更新，不改变几何/能力/输入/轨迹。实际浏览器Home购买/fixture持久化/正式departure/地图/跳跃8checks通过，未证实earned-note保存、完整遍历或实体设备；不会扩展版本兼容承诺。`content_complete=false`，新模块池全面准入仍未完成；一行既有正式recipe已实际替换，不能写成纯离线提案。

## 归档与重新执行

保留baseline615、navigation616、action617源归档、source manifest、tracked-worktree diff、原Manifest/RunManifest、receipt和日志。来源标签相同不意味着源码相同；逐文件SHA和补丁才界定实际运行源。原基线schema1 receipt不重写；显式migration sidecar只绑定旧冻结树并验证原batch，不代表重跑引擎。

当前源不提供自动v8→v9 RunManifest转换。需要历史重演时从原归档恢复独立项目、核对配置/资产/工具SHA，再使用旧消费者；不要给旧JSON改version或manifest hash使其通过当前检查。新局使用v9，并单独保存新receipt/源。

分析中的历史v8 scenery projection只能在匹配旧生产源码的scope适用，不得由v8标签单独推断，也不得套到v9。修复观测器后保留历史80/phase冻结语义，通过源约束与失败反例重验；后续新采集与旧采集若观测器不同，不能直接冒称同条件对照。

仍未承诺全历史Save兼容、跨版本运行续局、完整Boss战役/后续地区、设备性能与最终手感。对这些保持unverified；如未来需要自动迁移，须另立真实消费者/版本合同、原件正反例与独立审查，不能由本次内容升级顺带签收。
