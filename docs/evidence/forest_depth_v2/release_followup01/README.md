# 0cf失败、限定读取器迁移与后续证据

当前游戏仍是v10／Canopy-v3可玩候选，整体REVISE。这个档案保留真实失败与源码有界修复，不能签森林趣味、真人、设备或商业品质。

## 原完整CI（失败不改签）

[run39089359464](https://github.com/zhipijun1996/gunman-rush/actions/runs/39089359464)，源`0cf4aa5816c735fdd6e83bfb95d8ee0f70d129ee`，attempt1。prepare／Windows／Web成功；core 49项通过后，Guardian正式流程外层reader失败，部署／公开验证跳过。当前80路线真实通过314.664秒；既有平原删除落岸专项43.679秒通过。之后的检查未由这轮CI执行，不能把49改写成完整85或全88通过。

失败native本身25/0、836实际战斗帧、Boss32→0、玩家末HP4，正常指针领奖进入图2。真实图2为v10 Canopy，admission是`candidate_whole_boss_pending`；旧reader却要求旧Queen的`experimental_whole_boss_pending`。原完整CI ZIP（artifact12122749493，16,257,775字节）原样置于包内`ci/original-harness-gameplay.zip`，SHA256 `b786aeaf9cbfd51c92b56c75d232eec22a515cab8e813bc903a2ad44b8e225c9`，API元数据／完整日志／选取raw同时保留。不是根据本地猜测重签远端失败。

## 单文件迁移与实际定向7

读取器源提交`df3f162ac7c49f0bcdfe56c3d4093a3f49d289aa`，只改`tools/run_forest_depth_campaign_boss.py`，生产、GD驾驶、物理、输入、断言阈值和预算不变。共用版本身份helper要求新v10的完整contract/version/admission/scene/resource；旧布局显式白名单并保留旧完整合同，不接纳unknown或混版。旧raw在新reader离线接受并不重签原CI。

[独立限定审查](independent_reader/REVIEW.md)绑定上述Git blob；独立运行原CI及两历史完整case、44变造拒绝、另验实际v7/v9 Manifest与原Canopy App03。其余旧函数AST／严格错误过滤／source guard／预算保持。

原Harness在干净该提交上一次执行7项定向检查，257.517秒，全passed：Guardian App、旧Queen App、生态出返、R入口、crossbranch生命周期、Canopy黄金、Canopy App。各原生退出/原断言/source guard保持；完整report/log/artifacts在`native-targeted/`。这是targeted检查，不是完整profile或公开试玩验收。下一候选同源完整CI仍须实际终态。

## 浏览器原FAIL仍未解决

精确0cf Web构建`30d8b215ac15`：原动作预算首轮20/24、4项fan首发／二段重瞄失败，errors0；原FAIL及events保留。只做一次同产物、同40ms点击、同100ms和其余等待/断言的被动host/DOM时序诊断，24/24但未复现首败；不能据此宣称修复。另两组原消费者首次48/48、errors0。绝非72完整通过。原失败缺指针时序，因此首发迟到的根因仍未证；不据本次正常轨迹倒推陈旧block或console迟到为已证根因。[采样合同审查](sampling_contract/REVIEW.md)仅建议后续加严，不是本次改动或通过证明。

## 当前HUD正常影片与总体边界

[0cf正常60fps女王整战](current-canopy-H.mp4)：626视频帧／625物理帧，614杀，HP5→4；raw与旧02同字节。[独立HUD评审](independent_hud/REVIEW.md)只限定接受16px结2/2→1/2→剪除实景可读性。“岸”正式objective未在此standalone fixture展示，未签像素；末帧teardown不是胜利反馈。不签全速真人手感、听音或设备。

[最终范围独评](independent_scope/REVIEW.md)仍REVISE：守卫有独有夺铃因果；女王普通解保留多数追射／留剪／换岸，H独有进攻机会、高结保留收益、主路有效遭遇及跨Seed决策差异不足。技术、完整视听、趣味和商业品质分列。后续优先女王H主动进攻价值、主路生态节奏、跨Seed决策与初见试玩。

## 原件索引

`selected.tar.gz`按`members.json`逐成员SHA校验；`archive-receipt.json`记录整体SHA与大小。内含原CI全ZIP、失败原件、修复前后reader／离线负例、定向7完整原件、原浏览器FAIL和唯一诊断、当前HUD原生receipt/raw/实际抽帧。所有source元数据保持原样：0cf CI／电影、df3f读取器与定向执行分别绑定，不互相代签；压缩只为便携，不生成新结论。

本地docs原profile首检查扫描到ignored build诊断快照的缺文档链接而FAIL，原日志保留；隔离预检一次共享clone意外历史打包被停止，第二次Harness启动Git diff原30秒超时，均未执行实际检查项。没有改checker、补删旧快照或放宽预算。在输入逐文件相同且前后13205输入均不变的干净源码目录，直接运行原docs命令通过33必需文档／链接／210任务依赖；原check_quality静态检查亦通过。该定向结果不是22项docs profile通过，完整新CI仍待验。
