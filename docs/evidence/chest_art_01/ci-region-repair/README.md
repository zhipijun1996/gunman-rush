本目录保留 PR111 精确提交 `b2f92dcede97ac3a0f0a2075bcd01a552c9bf1d6` 的真实并行 CI 失败，不代表修复后通过。GitHub [原任务](https://github.com/zhipijun1996/gunman-rush/actions/runs/40670325927/job/122761172421) 的 `region` 检查以退出码1失败；原生扩展测试为2900项断言、2处失败。

`eligible_item_cache` 仍从旧 `chest.items` 期待 `stability_blue`，正式流程已使用 V5 道具池。独立根因记录见 [independent-failure-review.json](independent-failure-review.json)，当前失败检查的原对象见 [region-check.json](region-check.json)。这不是宝箱美术、版本绑定或运行超时失败。

完整原任务日志、原 Harness 报告、原失败 runner 日志按原始字节 gzip 归档；原 ledger 直接保存。解压后的长度和SHA、压缩文件SHA及原始下载ZIP摘要见 [manifest.json](manifest.json)。没有复制无关ZIP、修改失败状态、删断言、放宽预算或在此重跑引擎。后续修复及其运行结果需另存，不能回写这些历史原件。
