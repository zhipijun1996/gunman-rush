## 2026-10-31 模块边界与责任CI已实施

森林地方装配归Stage，怪物地方几何／恢复归EnemyActor；App保流程协调。实际95／54／61／61／69专项及source guard通过。CI沿原planner按12模块和实际下游选择，普通文档3门禁，未知／共享／构建full171；选择器46和Harness91通过。完整集成、内容源码权威技术绑定与历史Bible30秒仍待，不宣称全绿或发布。具体调用、责任、证据与回退见[本批说明](module_boundaries_and_ci.md)。下方为历史节点。

# 当前重构节点：优先解决真实阻断

用户最新要求 token 有限，集中高收益重构；不再展开全仓审计、旧地图计时或资源清理。本页优先于旧暂停指导。工作树 `/workspace/gunman-rush-refactor`，分支 `refactor/game-architecture-02`；原 `/workspace/gunman-rush` 用户改动不碰。

## 已保存的三批

| 提交 | 实际变化 | 回退基点 |
| --- | --- | --- |
| `a97d11f1ce61a5d973a257d53a7cf598b3a8de64` | P10：App 原事务成功后由 Generated/Plains Stage 统一写本地领取状态，Forest 只负责后置机关；静态真实消费者同步迁移 | `c59c24fb76762a0f66033e0f79d7b2cba7a84444` |
| `9c48310be10adfbd1eed956b3745139c7edf1f6e` | P11：App 与 Generator 共用 `CacheRewardPolicy`，保 offer 注册／结算所有权 | P10 提交 |
| `1abb0b5cccc2d5a7b1388fe1b910de7df1c0b65a` | 14 项旧布局／路线检查退出默认，原注册／预算保留在 legacy-compat；通用鼠标／暂停／重复领取转入原宝箱测试 | P11 提交 |

按依赖逆序撤回，不直接覆盖工作树。只有元数据／文档保存可能位于后继提交，实际 HEAD 用 Git 核。

P10 原 run-session 61/0、world-objects、audio 四case、item formal 通过；静态守门177/0（134.879/原180秒），三项真实误接受均拒绝。新增森林测试夹具首次60/1失败保留，修的是测试准备，生产四文件与独审候选相同。

P11 实际原 expansion 2989/0（原150秒native），原 item formal、random-context、audio 四case 全部通过；精确五文件 SHA 前后相同。原候选注册／重复note ID缺陷只表征，未修规则。见[职责和消费者](stage_claim_and_cache_policy.md)。

默认 full 现为 **171＝92 parallel＋79 serial**；注册仍218，legacy原16前缀后追加14。原 planner37／Harness91通过，主树planner37通过。原对象87/0＋chest225/0证明五帧冻结、真实Control鼠标、原App队列结算和首W／重复领取；不冒称旧80路线通过或浏览器触屏认可。见[精确范围](map_ci_scope.md)。

## 下一步只处理两项 CI 阻断

1. **现有资源权威的技术源码绑定。** current style27还绑定C59的四个所有者源码；已真实执行 `region_creative_direction.py --check-bibles`，首先拒绝PlainsStage SHA。完整差异见[四文件指纹](../../evidence/game_architecture_02/p10-p11-checkpoint/current-authority-source-drift.json)。使用现有版本／技术迁移机制记录本次职责变化，保旧style/source/失败原件，不直接刷新旧历史SHA，不冒称新艺术认可，不新增平行版本注册表。App新SHA47c3158f、其余三Stage为P10候选精确SHA。所有图声原件未改。
2. **region-bible-tests历史读取与执行成本。** C59浅克隆缺8个历史commit的20个叶；外部V2已按原Git字节做有限归档，保旧72方法及所有SHA，针对方法4/0、独立68小probe及12攻击接受。但完整原30秒仍超时（V2有66点，未完成不是PASS）。候选**尚未应用生产工具**；[完整补丁与失败](../../evidence/game_architecture_02/p10-p11-checkpoint/bible-history-blocked/candidate.patch.gz)已随本节点保存。其输入追加与当前171 profile需有限合并。不要反复宽跑、提高预算或删通用资源反例。先确定默认当前资源守门与手动历史审计的合理边界，再最小修复；混合旧地图check暂保，不按名字整项删。

P11新生产叶已登记非process质量记录 `STAGE-CLAIM-CACHE-OWNER-01`，状态in_progress；不是已验收。原缺记录失败及后继结果在checkpoint原件保留。

两项闭合后才冻结最终源码，运行一次现有完整双通道和最终交付；不为每笔元数据提交重复dispatch。C59 run41216348163是失败：parallel73pass后Bible30秒超时，serial17pass后旧路线600秒超时；Windows成功，Web／Android／部署跳过。没有后继全量CI、合main或发布，公开上次核验仍55b07609。此前成功不可拼成当前full171。

最终交付仍用固定Godot修复版和原环境workflow；实际CI ZIP／三浏览器／PCK隔离、同源连续影片及公开完整SHA须按原指导完成。C59影片与Windows不追签P10/P11新源。无需重建引擎、重生美术／音效或重跑旧地图80矩阵。main仍2ce4ffa6，PR122/124已含、PR123关闭排除。

## 资源与后续地图

正式Underworld fine32、当前普通怪修订、diver v8、森林fine32／weaver及已选音效保持；不以目录数字大小擅换版本。[资源短报告](asset_version_retirement/SUMMARY.md)和[具体版本／清理批次](asset_version_retirement/report.md)绑定C59视觉链，本次未改图声。尚无足够证据全删旧文件；先处理正式选择与精确导出排除，保仍活实验／经典角色／来源许可。新地图统一模块库和算法尚未实现，现接口先适配旧生成器。

三份全仓索引仍明确为2fa2源快照，非新增policy后的最终依赖图；仅在最终生产源码收口后刷新一次，保人工报告。当前无本地Godot或新增CI租约；恢复先核Git状态和进程。小范围验证已完成，除新变更影响外直接复用精确源证据，不重做审计。
