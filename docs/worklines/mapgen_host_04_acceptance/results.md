# map-gen 0.4阶段A工程收口

基线PR129/46eb3960，原受验代码d37b37075144c7a7550ad0fe9d3bd7118d6dae1d。远端c9416f16是不同commit身份，但完整tree逐字节/模式等于d37的fecc23d4860a08ad5c3d49df7de503f13578c68c；原两提交另由a402祖先中的Git bundle保全。最终交付head的完整CI在提交后生成，见后续PR的实际Actions，本文不提前签结果。

本批仅阶段A。SDK仍0.4.0原18GD，module1.1.0仍5ad5…；算法/物理/经济/RNG/永久保存不变。未开展阶段B、0.4.1、主出发替换、合并或部署。

## 实际修复

- 已验ModuleArchive按module SHA/version和SDK implementation/algorithm/version/archive/release/source身份进程内复用。仅原PreloadJob完整PASS后发布，源JSON递归只读；每个GenerationJob仍有独立输入快照、PreparedLibrary、RNG、取消和结果。离图取消自己的job，保留已验DATA；全新浏览器context仍冷启动。
- 删除宿主传给只读Provider前的冗余深拷贝；新增窄output_summary/request_abilities接口，原完整诊断getter仍复制。真实BUDGET_EXHAUSTED的map=null摘要反例已修。进度只保原host-tick采样，SDK源码与90秒限制、8ms软目标、默认128cap不变。
- Provider键归一/来源验证/身份摘要，job预载/advance/帧间隙/结果快照/选择，Stage装配/物理准入/提交/收据各自计时。诊断meta不参与map/host恢复身份。
- 原规划MD保留为同字节md.txt，原JSON/72eca724…证据指纹不刷新；当前MD只修可移植导航。父CI的坏/tmp链接在新源修复。原Foundry36短句/18连续路线重验后56JSON仅326个basis/hash/manifest_hash叶变化，无几何改动。

## 验证身份与真实失败

| 范围 | 实际结果 | 可复核边界 |
| --- | --- | --- |
| 父46eb CI41614301960 | 85PASS/1FAIL/92未执行/0reuse | 原85 serial成功；parallel首docs双/tmp坏链；affected正确拒绝，原phaseZIP与日志已重新核API SHA |
| d37原12相关fresh | 当时全部通过；Harness墙钟197.859秒 | 原本地raw随环境替换丢失，现仅历史见证；不能称本轮重新跑12 |
| d37恢复后的gears原native | 69/0、check48.182秒、严格退出clean | 当前原69报告/日志/四件实际数据与压缩归档俱在 |
| d37默认双fresh/原300 | 当时自动209.255767秒PASS；六图真实独审/严格join PASS，离线213.163965秒另计 | 原图/report/PCK512c丢失；按用户要求源码身份相同承接，不补造、不重跑；这是历史见证，不是新default |
| 新Web导出 | f547fc7974fdf8c643c48863f782271e367861ee08ff65ecd87d7f1855390481，218926492B；原bundle检查通过 | 与历史512c不同包，不能混写；原18SDK/JSON/唯一模块ZIP精确读回，无Python/测试参考ZIP/证据入包 |
| 新包gears原manual300 | FAILED300.489秒 | WAIT3 Title确认超时；前两ACK真实，第三迟到未消费，normalafterguards未运行；完整失败/7图/迟到说明保留 |
| 新包gears自动300 | 完整通过：自动157.962516秒/原300，真实新七图独立离线审查114.815539秒，严格join通过 | 新7图全部实际view；21样本跨10.000源钟秒/10.021墙钟秒，两船/锯轮确有运动；所有正常guards完成；不以旧7图或历史default代签 |

原manual的capture→ACK1/2合计161.184秒是模型/工具/审阅墙钟，不能归为算法CPU。v2保原76个非审图断言、七capture、原运动观察/动作/失败/300与所有afterguards；两个人工审阅门改为明确自动顺序和离线全图门，不再让模型往返阻塞游戏执行。自动pending不以PASSED开头，未图审或漏guard不能通过。

## 耗时口径

下表默认数据是旧d37真实读回的历史见证，原raw已丢；不是本次重新测量。当前恢复69的完整分项见[宿主报告](../../evidence/mapgen_host_04_acceptance/host-report-recovered.md)。

| 阶段 | 同线程执行elapsed | 阶段/流程墙钟 |
| --- | --- | --- |
| 默认冷预载 | 原advance11.098秒 | 26.048秒 |
| 默认生成 | 原advance30.538秒 | 68.498秒 |
| Provider / 其中摘要 | 0.119秒 / 0.058秒 | 单主线程无让帧 |
| 装配 / 含物理交还 | 0.113秒 | 0.369秒 |
| 六图截图 / report保存 / 来源guards | 4.177 / 3.078 / 3.908秒 | 验证工具开销，不能计入算法 |

elapsed不是OS独占CPU；墙钟差含让帧、调用者、系统和渲染调度。历史Chromium观测PID CPU含SwiftShader多线程/renderer且覆盖不全，非算法或硬件GPU归因。DOMContentLoaded0.222秒不等于完整启动/PCK；完整PCK/WASM下载、解码、编译的独占CPU与精确boot分段未分离。8ms只是软目标，冷冻结/验证/装配仍有长段，手机/硬帧预算未验。详细上游要求见[本批接口反馈](upstream_contract.md)。

## 范围与继续方式

完整地图、未支持机制/敌人/奖励/Boss、普通controller请求可通全图、手机/硬帧/玩家认可未验。本批不新增内容支持，coverage旧表不刷新成新物理通过。未来正式出发复用现RunSession/StageFlow，不能嵌套实验Root另建服务。

回退以46eb运行源为基点，整套撤回宿主job/cache/narrow API/诊断与配套Foundry来源，保留真实证据与可移植文档修复；不要只退SDK或bindings制造混版本。原0.3/PR128完整178基线保持不动。阶段B需后续独立授权与提交，本轮明确不启动。
