# case编号语义勘误

S2选定CI39200142616的forest80首失败是zero-based case index33，即按人类从1计数的第34条；前33条通过。seed forest-depth-hollow-04/map1/growth。此前正文/PR中“第33例”若指该失败，属于编号措辞错误，不能改解释为仅前32条通过。

本说明只更正编号语义，不改变原ZIP、raw、日志、receipt或旧正文历史字节，不把索引33失败修成通过。

本地后续原80/600整体FAIL(timeout)：59条完整通过，zero-based index59（第60条）中断，合计21条未完成；这与S2远端index33失败分属两次实际运行，不相互替代。最终S3 CI仍待终态，未额外轮询API。
