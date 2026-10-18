# Queen canopy-v3：便携原件与有限独审

此目录只证明复制与归档一致性。没有启动引擎、重跑原生测试、修改生产或提交；不新增趣味、正式 App、保存、电影、音频或玩家验收。电影由其他作者另行归档。

- [01 完整紧凑原件](canopy-v3-01.tar.gz)：原索引40个成员全部保留，另含原 index。purpose **15/0，但末 HP1**，有466/508/550/592四次真实网伤；ordinary_cut **15/0、HP5/E100、626击杀/637稳岸**。ordinary_keep **实际 FAIL（15断言、2失败、native exit1，488死亡）**；随后 lure 未运行。技术通过不等于目的策略安全或优越。
- [02 完整紧凑原件](canopy-v3-02.tar.gz)：原索引39个成员全部保留，另含原 index。同冻结01内容，只改驾驶理解；purpose **17/0、614击杀/625稳岸、HP4/E80**；ordinary_keep **18/0、500/511、HP4/E65.5**；lure **19/0、876/887、HP3/E100**。三个完整成功不代表全指标优越。01 的 ordinary_cut **没有在02复采**，只保其原source/结果，不能倒签到02。结束时刻不同的能量值不是净消耗比较。
- [独立评审](REVIEW.md) 与 [实际审计](independent-audit.json)：原字节复制并绑定。结论是允许有限 App/保存/正常整战片后续整合；整体高品质/H核心仍 REVISE，未看该版正常电影、未真人操作。本次推广不重新签署其结论。
- [07 独立历史原件](air-motion-07-double-root.tar.gz)：36个原索引成员及原 index 全部保留（压包小于3MB）。仅是旧 dual-root 三个有限 selector 技术结果；因安全普通站位反例，整体核心仍 REVISE。不是最终三阶段、不是01/02新增覆盖；旧05失败和06未执行身份按原索引保留。

每个 tar 保留原相对文件名，包括原报告、selected-source、完整source inventory、copy/outer/native receipts、日志及全部索引所列 gzip raw；没有派生导入或shader缓存。历史 Markdown 保留在 tar 中，不将缺少相对上下文的历史正文当成新活动文档展开。

[manifest.json](manifest.json) 逐项记录全部118个归档成员的原字节长度/SHA256、三个原索引SHA、压包SHA、原source路径、压包读回核验和打包后source不变守卫。两个当前批次没有被索引遗漏的额外文件；07亦无遗漏。所有 gzip JSON 已解压验证完整；独审所列02 capture原始SHA已与解压raw核对。三个原 index 也单独复制，便于无需解包查看成员清单。

使用 `python docs/evidence/forest_depth_v2/queen_canopy_v3/verify.py` 可离线重核压包、全部成员、直接独审文件及所有解压raw，不需要引擎或原 build 路径。最终目录文件校验表见 [SHA256SUMS](SHA256SUMS)。
