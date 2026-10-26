# 独立审查证据索引

绑定源 `91ea8850f308cc3c955bcece2c35cd66f75e7bda`。原件均从实际执行产物复制；gzip 解压后按 original_sha256 对照。完整哈希和来源见上级 [review.json](../review.json)。

- 最终15项： [report](harness/report.json)、[command](harness/command.json)、[receipt](harness/receipt.json)，15份原日志在 `harness/logs/*.gz`。
- 独立GL67/0与原menu44/0：[GUI report](gui/ui-report.json)、[receipt](gui/receipt.json)、原日志及三个PNG在 `gui/`。
- 实际跨区：[cross_region_equipment](consumers/cross_region_equipment.json)、[Manifest](consumers/cross_region_manifest.json)、[native pointer事件](consumers/campaign_pointer_events.json)。
- 实际森林App92/0：[摘要](consumers/forest-app-summary.json)、完整native/capture/report gzip在 `consumers/`，保留原fixture scope与注入标志。
- `history/`保留原失败/部分批次报告、关键失败native、排序窄反例、旧F10图及旧95收据；历史失败没有改写为通过。

本目录不含最终操作录屏；root/capture另交付。所有设备、G5、听审及full profile边界见上级独审文档。
