# 最终回归的真实失败保留

`actual_failed_releases.zip` 逐字节归集原报告及日志，索引 `manifest.json` 列出原路径、大小与SHA。不是新的执行或最终通过证明。

- 235003：临时PR正文放在build下，其相对链接被原文档检查真实拒绝；改为绝对GitHub链接后重跑。
- 235132：历史pipeline spec的原SHA与被更新的当前说明不一致；恢复历史Git原字节到不可变档案，保留原SHA/审批结论。
- 235620：core5676与generated31已过，但旧pressure背景消费者47断言有1项失败，总发布失败；其后完整region15还揭示原campaign3705有3项版本绑定失败，分别有独立修复证据。
- 7e5远端CI：Web构建通过，包闭包失败；本地实际导出重现缺工作坊raw PNG，现有include声明不能代替实际包字节。保留导出前Foundry刷新及56JSON差异，所有replay frames原样。

不复制包含短时签名URL的artifact下载错误日志。原失败及原生证据仍留在对应build目录。后续新的成功必须有独立的新输出与确切源指纹，不能改写这些失败。
