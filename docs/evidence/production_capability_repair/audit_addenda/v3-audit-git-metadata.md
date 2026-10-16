# V3 精确 Git 小元数据补充复核

只读审计 `/root/v3_evidence_audit`。冻结源 HEAD `b675515fc43805ef8b31604a19d939c1b96b52cd`；未改源码、旧账本或旧报告，未抓ZIP/PNG、未看像素。

**结论仍为33/44原response、27/44原invocation耗时已独立读取；不能声称全部44原response/耗时已补齐。** 本次不再将这些缺失笼统称为“工具不可见”：9项原审计明确曾存在response/invocation，但当前HEAD命名小元数据未取得原字节；另2项原审计response=false，分别为撤销的recovery review和断连的shared-environment implement，不能伪造完成回执。

需纠正上一补充措辞：211是以host_request.json、host_response.json或invocation.json结尾的Git候选路径，**包含native及模拟测试，不是211份原生产host证据**。按精确HEAD tree读取路径/OID，再以禁lazy-fetch的cat-file批量查询190唯一对象：162对象已经在Git缓存，共5,268,692字节，无需网络逐blob读取；解析后严格绑定44个request_hash及task/attempt/role，33 response与27带seconds的原invocation全部与旧审计一致，新增0。其余28未缓存路径都是native/专项invocation，不含缺少的host_request/host_response。

另从相关任务目录精确挑选11份小JSON（archive/artifact索引、原checkpoint/state、terrain request与verification等），7个OID未缓存；按授权只做一次批量git fetch，7.947秒exit1：`fatal: bad revision '87f0e0829e72caecdc29a5b37006d4b88b314cbe'`，随后`origin did not send all necessary objects`。未重试。该运输失败不能证明原对象不存在或原调用没有发生；详细命令结果在 `v3-audit-metadata-fetch.json`，原OID/大小可见性/后检查在 `v3-audit-git-metadata.json`。

| 审计序 | task / role | nonce | 原21:10审计中的response存在 | 本次新增原response/耗时 |
|---|---|---|---|---|
| 6 | V3-ASSET-01 / review | `945f83d0fef148e58913614015287fb5` | true | 0 / 0 |
| 15 | V3-ENCOUNTER-V2-01 / implement | `5d43d28154d340809f0f3c775d4c6cbc` | true | 0 / 0 |
| 22 | V3-ENEMY-EVIDENCE-REPAIR-01 / implement | `43bca68ad1564db984b8a51abec67bd3` | true | 0 / 0 |
| 23 | V3-ENEMY-FORMAL-01 / implement | `288b275b89fc430a8309e8687bd5db7e` | true | 0 / 0 |
| 24 | V3-FOREST-STARTUP-01 / implement | `cd2a3f3c85234ef08019f52ad379c3ea` | true | 0 / 0 |
| 26 | V3-FOREST-STARTUP-01 / implement | `e28bf88714134e2fba8d9fbf3056f94a` | true | 0 / 0 |
| 32 | V3-REAL-RECOVERY-DRILL / implement | `b58fdf0533a9492e862471ca5aea5637` | true | 0 / 0 |
| 33 | V3-REAL-RECOVERY-DRILL / review | `2413c86b7fed4b8ab362859a1a9ee21f` | true | 0 / 0 |
| 34 | V3-REAL-RECOVERY-DRILL / review | `54dd34a03d8245c7975fb68bc08f622e` | false | 0 / 0 |
| 39 | V3-SHARED-ENVIRONMENT-01 / implement | `bcea8bc185f347399887f56fbacc5419` | false | 0 / 0 |
| 40 | V3-TERRAIN-BINDING-02 / implement | `e08d05b2b0e74a69bab27e05dafea85c` | true | 0 / 0 |

原存在性审计：`docs/evidence/region_production_v3/check_preflight/budget_audit.json`，Git OID `1075ff6b0c59ab98c44c26bcedb59aa49527bc99`，SHA256 `454f02ad3a637943509b32fde5ba7720b7c218bf7406c46c602cd5c35f7401d8`。它是原存在性快照，不能代替原response字节或精确耗时。

旁边JSON列出全部211候选路径/OID、已读字节SHA、对应44请求及11缺失项，原账本copies路径/存在性标记逐项保留。允许范围与时限内已停止；未检查的大档案仍是范围限制，不作“根本不存在”的判断。
