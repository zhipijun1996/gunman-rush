# CLOUD-EFFICIENCY-01 实际工程证据

基线为`97c060f33192ea560874da7348c907c80d780bd1`。本轮不改核心玩法，不删除历史证据／资源、不重写Git历史。源码修复、最后PR head及merge身份以[PR103](https://github.com/zhipijun1996/gunman-rush/pull/103)和Git为准；本目录收据保留各自真实HEAD及working_files，不能把dirty候选验证改称后续干净SHA的fresh完整CI。

## 已实际验证

- [真实root初始化](real-root-summary.json)：直接初始化元数据＋只读alternates，23521索引路径／4747实际文件、父子指纹一致、父源稳定，2.448秒；新增pack与运输事件均0。此处是准备阶段指标，不据此推算整库加速比例。
- [真实partial/promisor反例](promisor-summary.json)：84项Harness测试通过。filtered promisor源含未取得冷blob且origin不可达，原clone传输正对照失败，新实现不执行clone／fetch／upload-pack。保留cone／non-cone、已物化S位、staged／普通删除、新增、intent-to-add、linked worktree、split index和私有ignore。
- [原Harness七项fresh验证](native/report.json)：jobs2，84 Harness＋21输入物化＋16选择器＋30媒体交付测试，真实Godot核心5681断言、原历史森林检查和开发入口／音频释放全部通过。使用`1cfd8aa`及收据中明确记录的working overlay；源码字节由原守门前后核对。只批准这些专项，不是完整Integration或Release。
- [隔离lane内的原历史消费者](isolated-history/receipt.json)：在真实partial-source隔离工作区内，直接运行原Harness的serial `forest-formal-combat`，exit0，27.918秒；没有修改serial标记或原检查。[原收据](isolated-history/report.json)与[原执行日志](isolated-history/forest-formal-combat.log)保留。
- [GitHub首32对象](github-first32.json)：原生lazy-fetch的noop协商和空bundleURI配置，前0／后32对象、50,319,209原字节、28.164秒、exit0；独审逐个重算Git blob SHA通过。这只签该批传输；完整docs输入与CI另按实际结果记录。
- [实际三轮物化](docs-inputs-summary.json)及[完整无损原报告](docs-inputs.json.gz)：2712文件、3,011,151,589字节、1700.562秒；只取选定缺blob并校验，未改sparse规则。28分钟包含本环境实际传输／恢复，不是普遍加速率。源码提交后的[输入ready复核](docs-inputs-postcommit.json)另记；ready不代表原检查已通过。
- [独立审查](review.json)及其[路由／CI](supplement-routing-ci.json)、[运输](supplement-provider-transport.json)、[partial源隔离](supplement-partial-source-isolation.json)增量审查，均只签相应技术范围；原[REWORK](review-v1.json)保留。

- [完整docs第二轮fresh通过](docs-v2/report.json)：33项全部通过，jobs2；source `0ca0474`及收据明确记录的quality/evidence overlay。包括115项production_loop、84项Harness、21项cloud_inputs和原portable frozen消费者。没有复用结果；不据此代签未来PR head完整Integration。
- [依赖闭包修复独审](closure-v2-review.json)与[真实补充物化](efficiency-docs-inputs-closure-v2.json)：恢复10个真实受控文件、106030原字节、3.713秒；逐个Git blob SHA复核。先前input ready只对当时预检范围有效；此次把遗漏来源与目录存在依赖纳入真实消费者闭包。

- [五个原生历史消费者fresh复验](native-fixtures-v2/report.json)：5/5通过，实际source `4950311`及明确working overlay，包含存档176断言、根铃原重放与三项平原Golden。显式`--check`覆盖profile，因此本收据只签5专项，不称docs或38项通过；docs另外运行。原未声明依赖仅补inputs，命令／断言／预算／serial／缓存属性不变。有限[原生审计](native-input-audit.json)、[Python审计](python-input-audit.txt)及[独审](native-inputs-review.json)分别保留原范围。

- [最终代码docs33 fresh通过](docs-v3/report.json)：实际source `1c0332e`及收据所列overlay，33/33 passed，无复用；包含84项Harness、115项生产循环、21项输入API、30项媒体和16项选择器。三项Python消费者补充输入由[独审](metadata-v3-review.json)核实；原profile顺序和非input字段不变。当前v2质量卡只引用本源码的本地docs与独审；旧引擎／运输收据作为各自旧源码身份的支持材料，不重标为新head运行。最终精确head Integration／Release仍以实际工作流为准。

## 原始失败

- [普通批量fetch失败](failures/provider-batch-before-noop.json.gz)：真实GitHub partial clone出现bad revision／必要对象缺失，exit非零、0件物化；不是通过。
- [首次真实隔离初始化失败](failures/partial-clone-setup-report.json.gz)、[完整父命令日志](failures/partial-clone-setup.log.gz)及[原lane setup日志](failures/partial-clone-lane-0-setup.log.gz)：`clone --shared --no-checkout`仍尝试传冷对象，interrupted、0项检查。后续新实现通过不改签该失败。
- [完整docs首次复验失败](failures/docs-closure-v1/report.json.gz)：原检查发现两个目录链接及八件资产卡嵌套来源缺失，另有本轮task／record状态不一致；[docs原日志](failures/docs-closure-v1/docs.log.gz)与[quality原日志](failures/docs-closure-v1/quality.log.gz)完整保留。补足真实预检闭包及状态后须新目录重跑，不由input ready代签。

- [闭包修复后首次production_loop失败](failures/production-loop-closure-v1.log.gz)：真实115项中24项因新依赖未恢复失败；原日志保留。实际恢复之后的[115项新运行](production-loop-preflight-after-hydration.log)通过；后续完整docs在独立运行目录再次通过。

- [精确83bbb26远端Integration失败](failures/ci83-sparse-fixture/receipt.json)：64项通过，aim-save-compat因原inputs未声明其真实历史Manifest而失败，其余未执行。[原report](failures/ci83-sparse-fixture/report.json.gz)、[检查完整log](failures/ci83-sparse-fixture/aim-save-compat.log.gz)及data阶段收据保留。补充真实依赖后必须fresh复验，不改存档断言或原预算。

Gzip保存原JSON／日志完整字节，`gzip -dc <file>`可恢复；没有截去原失败段落。完整CI、Release、用户审美／手感／趣味、实体设备均不由上述局部工程收据代签。实际公开录像和Preview仍使用[原交付源6ca72ef](../cloud_production_01/README.md)，本轮工具提交没有伪造新游戏包。

## 最终A1真实Integration与合入

精确A1在run39771696574实际146/146 fresh通过；[原报告](final-a1/report.json)、[执行计划](final-a1/execution-plan.json)、[API与完整ZIP核验](final-a1/verification-summary.json)、[独立CI审查](final-a1/independent-ci-review.json)及[源审](final-a1/independent-source-review.json)保存原身份。PR103已合main e9ab0e0，源树完全相同。原109MB归档[下载](https://github.com/zhipijun1996/gunman-rush/actions/runs/39771696574/artifacts/12426861148)需GitHub登录，2026-11-05到期；小报告在Git永久保留。前述失败与旧source证据不改签；main正式Release与玩家／设备另验。
