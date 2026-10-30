# 全怪物程序整体重构

最新冻结源`596a2eee230eb1b9d23dc2ff878c1ff3259cf293`：原生733断言／40case和docs33全部fresh通过。完整166 CI40860669611已通过（91＋75、0复用，affected合流成功），森林原80为404.511／600秒；旧5b串行超时原件保留。3bc本地原80在505.552／600秒内通过，来源分别记账。[性能事实](performance.md)。

普通14物种、2开发候选及8Boss场景／9配置的共同程序边界已实现；[PR114](https://github.com/zhipijun1996/gunman-rush/pull/114)保持草稿，不合main。此为工程结构交付，旧成品美术品质拒绝仍有效。

- [逐怪程序入口索引](runtime-map.md)：25条目对应当前工厂、Definition、行为与实际结构case。
- [架构与后续维护](architecture.md)：创建、策略、只读状态、身体绑定、表现生命周期与恢复。
- [运行证据与历史失败](../../evidence/enemy_structure_01/README.md)：保各自实跑源，[完整CI原收据](../../evidence/enemy_structure_01/ci-40860669611/RESULT.md)确认166／166技术通过。
- [精确596a源闭包独审](../../evidence/enemy_structure_01/review/enemy_structure_596a_source_appendix.md)：限定代码与测试迁移，成品／设备另验。
- [原资料素材盘点](../enemy_asset_audit_01/README.md)：原图与未用动作格、已证错配及待验证问题；未采用流程草案。

本轮修复创建时外部生命配置共享、未知身体绑定静默接受、特殊盾反馈释放后仍回调；保存和终态继续按原物种政策。冷terminal首次绑定直接settled属于明确生命周期修正，fresh lethal继续原演出。Lab／Studio候选参数差异显式保留。没有新图、音频或技能流程采用。
