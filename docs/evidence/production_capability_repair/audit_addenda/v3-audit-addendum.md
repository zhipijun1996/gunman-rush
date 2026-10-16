# V3 原始调用可见性补充复核

只读复核者 `/root/v3_evidence_audit`；在冻结源码完整交付等待窗口，仅检索已存在本地证据，不联网抓档案、不改源码/原账本/旧审计、不看像素。

结论：**11个旧审计缺raw response的nonce仍未获得新增原始response；17个缺耗时nonce亦未获得新增原invocation耗时。维持33/44 raw response可见、27/44 invocation耗时可见。** 未找到不等于原执行没有发生，也不把unknown改签成功或失败。

对 `docs/` 与 `build/` 的JSON/JSONL/Markdown做精确request_hash搜索，共检查1513个≤8MiB本地文本文件；原host response须完整信封、request_hash、task/attempt/role严格匹配，审计副本、state摘要或引用不当作原响应。命中的11缺失hash只来自原budget审计与两份派生审计副本。

检查当前本地7个V3 ZIP的目录，并只读其中≤1MiB的host/invocation/checkpoint/state JSON；没有提取媒体或拉取未物化大ZIP。唯一命中缺失请求的容器 `docs/evidence/region_production_v3/shared_environment/resume/actual_checks_and_old_partial.zip` 只含旧implement request，不含该nonce的response或invocation。容器、成员和原budget SHA均在JSON。

当前Git记录有211条原host request/response/invocation路径，本地实际物化21条；selected quality/knowledge依赖物化不代表全部原host元数据已物化，因此明确保持可见性边界。

| 审计序 | task / role / round | nonce | 新raw / 新耗时 |
|---|---|---|---|
| 6 | V3-ASSET-01 / review / 1 | `945f83d0fef148e58913614015287fb5` | 未暴露 / 未暴露 |
| 15 | V3-ENCOUNTER-V2-01 / implement / 1 | `5d43d28154d340809f0f3c775d4c6cbc` | 未暴露 / 未暴露 |
| 22 | V3-ENEMY-EVIDENCE-REPAIR-01 / implement / 1 | `43bca68ad1564db984b8a51abec67bd3` | 未暴露 / 未暴露 |
| 23 | V3-ENEMY-FORMAL-01 / implement / 1 | `288b275b89fc430a8309e8687bd5db7e` | 未暴露 / 未暴露 |
| 24 | V3-FOREST-STARTUP-01 / implement / 1 | `cd2a3f3c85234ef08019f52ad379c3ea` | 未暴露 / 未暴露 |
| 26 | V3-FOREST-STARTUP-01 / implement / 2 | `e28bf88714134e2fba8d9fbf3056f94a` | 未暴露 / 未暴露 |
| 32 | V3-REAL-RECOVERY-DRILL / implement / 1 | `b58fdf0533a9492e862471ca5aea5637` | 未暴露 / 未暴露 |
| 33 | V3-REAL-RECOVERY-DRILL / review / 1 | `2413c86b7fed4b8ab362859a1a9ee21f` | 未暴露 / 未暴露 |
| 34 | V3-REAL-RECOVERY-DRILL / review / 1 | `54dd34a03d8245c7975fb68bc08f622e` | 未暴露 / 未暴露 |
| 39 | V3-SHARED-ENVIRONMENT-01 / implement / 1 | `bcea8bc185f347399887f56fbacc5419` | 未暴露 / 未暴露 |
| 40 | V3-TERRAIN-BINDING-02 / implement / 1 | `e08d05b2b0e74a69bab27e05dafea85c` | 未暴露 / 未暴露 |

本结论仅为本地有界证据可见性补充；不改变原44调用消耗、14次图生计数、原失败分类、内容/商业美术/用户/设备状态。精确原件路径/SHA及检查成员索引见相邻 `v3-audit-addendum.json`。
