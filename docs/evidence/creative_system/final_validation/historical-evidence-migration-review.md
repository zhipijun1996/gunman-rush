# 历史design-spec证据迁移独立只读审查

结论：**ACCEPT_SCOPED**。这是将历史证据定位到同字节冻结副本的可逆路径迁移，没有重签历史内容或放宽原SHA守门。

审查基线为当前Git HEAD `e8ee34446aa82b4e64f5cdc414a22f5b6e2a6ca7`。实际递归比较修改前后完整JSON，唯一差异是 `docs/quality/records/LEVEL-HARNESS-V2-01.json:/evidence/0/path`：

- 原 `docs/level_design_harness_v2.md`
- 新 `docs/archive/creative_system_baseline/level_design_harness_v2.md.source`

`id=design-spec`、原sha256、source_commit、全部断言/状态/其他证据及字段均未改变；不是把新文档重新hash后写成历史通过。当前文档仅增加当前入口说明，与冻结证据内容分开。

逐字/指纹独立验证：

| 归档 | 与Git HEAD原件逐字相同 | SHA256 | 字节 |
| --- | --- | --- | ---: |
| `LEVEL-HARNESS-V2-01.json.source` | 是 | `cdc377eabaf0edacdc128bd3d7e227fc3b07f9fc238bebc7d820b8aabdb9bbf8` | 26768 |
| `level_design_harness_v2.md.source` | 是 | `570b1eaba6924e846f4bc12b486cc33bfc14a6196e76c17586c617b0466bfdcc` | 19764 |

两者均匹配 `docs/archive/creative_system_baseline/manifest.json` SHA及字节量；新path目标hash精确等于历史record原先要求的570b1...。原record原件保存，可直接按manifest恢复；旧历史记录仍可追溯其当时路径和内容。

机器复算记录：`scratch/historical-migration-review-verification.json`。本次未修改代码、证据或文档，未重跑全Harness，也不签完整CI。尝试额外读取record的原source_commit `11827baaf259f5fc91061f5358f2621ed00e958c` 时，本地Git对象不存在（exit128），故不声称已在该commit重新构建；本结论基于Git本轮基线原件逐字一致及既有历史SHA完全一致。父任务所述首次SHA守门失败应继续保留；本次未找到其原日志，不代签该失败的实际执行细节。
