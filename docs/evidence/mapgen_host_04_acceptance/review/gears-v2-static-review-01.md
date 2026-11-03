# Gears v2自动捕获＋离线审图：独立静审

结论：冻结工具可进入root已授权的新单case原300秒实测；没有发现具体工具源阻断。这里只签工具/新staging，不签尚未执行的浏览器或新图。审者未启动Godot/browser、未跑测试、未改所审源码。旧manual300.489FAILED及迟到ACK3未消费事实均保留。

读取 `browser-tools-v2/freeze.json` 全部列出的SHA，实际文件完全相符。自动driver `eeab037bb93b67caa453206aeadbcd1da69876a2c2acda8f04499cfa5b65f82e`、offline helper `7e5734d628ea37dbdc542f3c502e5c12a8e2344a2bb5abfe783a4ade5f66345b`、stager `fcd351ed3a5e6d038dd8e5e9011fdf4ea1472ae3ab34cfc931a90f9aca13dd29`。

我独立按有限checkpoint/status/key逆替换，**整个源文件逐字还原**至原112c6244 SHA，不只依赖作者audit。另行AST Counter核查原78条中两条人工审核相关断言显式迁移，其余76条全部原AST保留，新共79条。原checkpoint ACK的action/passed检查变为固定seq/action/捕获数检查；motion批次的人工reviewed_files集合检查变为实际capture_files集合检查。未生成operator_visual_review或自动passed认可。完整7图真正审查移至独立离线join。

原单fresh context、真实930007生成/出生/输出/身份检查、所有两ferry/saw/静态contact字段与共享时钟检查、实际至少10 source秒及wall秒观察循环、motion位移/样本、原7图、ESC、清理先于Title、Title OCR、错误处理和全部source/PCK/producer/served HTTP guards保持。旧实测10.5source秒不是另造的新硬编码阈值。原300及timeout路径不变，不能逐阶段重开预算。新自动状态为非PASSED前缀 `AUTOMATED_COMPLETE_VISUAL_PENDING`；最终正常guard断言体保留，只按该精确新状态判断。

Offline helper要求正常完整自动状态、有限非负≤300耗时、before/after source gzip实际原raw SHA及JSON一致、非空producer与served before/after相同、正常关闭、正确结果/初始出生/cleanup/Title、原序7capture SHA和3声明批次。独立审者身份与实际functions.exec/tools.view_image方法有明确字段；旧迟到ACK文件、空/错误方法、缺图/错SHA/失败决定、非法时间/预算、修改report、输出覆盖等不能join。它不能程序证明某模型真的看了图，故新7图必须由审者实际工具调用并写真实观察，不能复用旧manual7图。

作者 `pure-final.log` 实际7方法/0.912秒/OK，含fake执行正例与多负例（timeout、source/finalguard错误、page、错误出生、Title缺失、cleanup、latecommit、阶段/图片缺失、离线缺图/占位/错SHA/NaN/旧ACK/覆盖/错误reviewer）。我读了代码与原log，未独立重跑；这些都是合成工具测试，不是Godot、PCK实际加载或真实图审。

新stager只复用已核原9f392准备，保存原argv，然后替换为自动driver并增加冻结工具/cache的producer。当前新immutable staging `gears-auto-01` 已独立快核：source d37、新fresh69原log实际SHA8d9a4100与expected/持久native receipt一致，expected48062f46；PCK f547fc79/218926492，明确不是旧512c包；新URL8832、新actual路径、eeab driver、6f1host/c652map/474974出生一致。Prepare本身的source参数不独立attest日志，本次由实际native log SHA与root持久rescue receipt完成外部绑定，不把它包装成通用日志来源认证器。

Root恢复缺失docs/cloud_inputs是原字节物化；新source inventory可比native69时更完整，不能硬等丢失旧fullvector。必须保实际code/ref、关键源SHA/SDK锁与native69 log绑定及本次真实normal before/after。远端c941与本地d37已另审完整tree等价但commitID不同，当前PCK/native元数据仍d37，不能混称同commit。

仅工具准入。新自动部分要在原300内完整完成全部guards，之后再实际查看其新7图并严格join。旧manualFAILED和历史default原件丢失边界不变；不重跑default，不签B/0.4.1、完整地图、手机/FPS、路线/骑乘或用户认可。
