# PLAINS-REDESIGN-EXPERIENCE-01 R2 独立复审：ACCEPT，限G0/G1技术切片

真实审查身份 `/root/plains_design_challenge`；实施者 `/root/plains_spatial_worker`。实际R2 lease nonce `405064e7fa3b4710ba48124fc229aa86`、request_hash `236c1f449a085bc88f2ded350df54d3a60b5d8477d9093e4f958934c2b6cc006`。已核R2目标、前轮REJECT、作者实际响应及controller本轮6项fresh检查。只写ignored本审查目录及约定host_response，未改任何生产、测试、文档、质量记录或先前审查证据。新租约提交时未到期。

## 结论

**EXPERIENCE-R1 已解决，本包 G0/G1 ACCEPT。** 接受的是D1–D3与低拱输入包络的技术候选、当前证据验收器的一般化因果修复；不是正式奖励/敌情/美术完成，更不是用户已经觉得平原好玩的证明。全区目标仍需后续正式App、正常速度画面、敌态、同条件对照与设计验收。

## 本次独立实际执行

1. `python3 tools/run_plains_experience_golden_tests.py` fresh实际退出0；原件 `build/plains_redesign/experience/run_a2xt6tq6/`。真实255断言0失败，16个remote/creek双向×0/100精力×两相位、18个release5/7/9×offset−8/0/+8双向角落保留；真实删除侧岛产生8断言2失败/exit1并正确拒绝；原15+新增27，共42个永久反例全部拒绝。命令日志与退出码见 fresh_experience.log/.exit。
2. 独立脚本 `recheck_causality.py` 使用**不可变的R1诚实原件** `build/plains_redesign/experience/run_igiwoygr/positive.json` 和精确旧checker；原R1变异函数直接导入，没有执行其main或覆盖R1结果。旧与新checker均接受同一诚实原件，原5个坏变异旧全接受、新全拒绝，证明不是换schema或粗拒旧证据。
3. 同脚本另外核旧4个邻近控制（缺callback、缺整段返程、停车clock篡改、错出口）继续拒绝；**另13个本次独立构造**的错位/缺失jump输入、landing支持、返船floor切换、callback同位置错帧、drop同位置错帧、damage错误operation、impact晚于damage、缺首impact、restart早于返船、容错landing缺失、容错jump错位、消费错帧、恢复时非grounded，全部拒绝。5+4+13共22项，命令实际exit0。逐例数据见 causal_recheck.json/.log/.exit。
4. 独立核170个portable的压缩SHA、解压SHA与原字节数，全部匹配；当前runtime archive624源成员逐项SHA与清单一致，与当前工作区624项也一致；相对于R1被拒源，运行源差异**仅** `tools/run_plains_experience_golden_tests.py`。旧checker SHA与R1源快照精确一致。当前review source guard与request.source_hash相符。见 provenance_checks.json。
5. 原REJECT的22个可归集原件与portable index raw SHA逐一仍相符；原拒绝报告、原变异程序、原exit1/原生raw没有重标或覆盖，见 previous_reject_preserved.json。

本次没有重新跑空间/64/完整15。R1本人已独立fresh跑过空间1073/0+350与原64 3105/0；本轮唯一运行源变化是离线验收器，作者和原controller本轮均实际fresh空间/64/15，controller六项状态/退出码在本R2 host_request.feedback。没有将这些当作本人新执行，也没有将中间源完整31替代最终源31。

## 一般化修复核查

检查了 `actor_causality`、`encounter_causality`、`valid` 和永久反例消费者，代码不依赖本次case名字，不硬编码R1事件ticks。

- 每个事件绑定对应真实前/后帧位置；落地信号恰好对应air→ground，jump/drop恰好覆盖ground→air；跳跃对应Router请求/上推/used_jumps，落地核全身支撑/动作恢复。
- 每帧实际精力余额与按序交易相等，射击成本、ID、接受事件、请求方向、反冲与impact相位相连。自然恢复依据真实配置每帧恢复上限与grounded，不靠固定补满。
- remote：首shot/impact→sequence0→1→跳上观察台/落地→二shot→impact/同packet health damage/门状态切换→drop落回；缺final health或impact都拒绝。
- creek：启动→登原船→停车→跳岛/落地→停稳visit/callback同帧前状态→真实drop→原船支撑→shot重启/motion切换→离船落dock；完整停车区间时钟/位置冻结。callback仅有个数或发生在岸上不再能通过。
- 18个低拱角落与空间对照也使用真实floor/event因果，保留原危险和顶棚；没有为修证据再降内容难度或改Motor。

## 设计价值及保留边界

R1已独立确认的具体内容改善仍成立，R2没有改其几何/敌人/奖励：图1稳定井铃→低顶教学；图2两次真实站位/射线的双铃推进；下一拍按动作家族变化；溪谷原预算中箱与停车/登岛/回船动作组成一个目的明确的可选绕行；首次单diver与后期fan编排分开；原低拱18格12次接触→当前18格全部无接触而走路仍碰轮/长按仍碰顶。

这是有证据的设计改进，尚不足以宣布整个平原达到用户品质目标。**本包callback只证明真实停稳领奖窗口；helper忽略callback返值的问题尚不能作为正式领取成功，后续正式growth必须核原modal回调与claimedID，失败应停止该策略。** 下方线索实际可见、唯一落点/攻击预告、alive/moving-away/dead/inactive与正常kill/bait策略、正式音画/镜头HUD、美术构图、全源31/全Harness与前后公平cohort、实体手机/手柄/真人趣味仍需后续实证，不在本ACCEPT中签passed。D4高奖组合是否足够精巧，保留到完整实机影片与独立设计审查，不为了填动作数强加障碍。

最终结论：本次有界生产包已经完成“独立发现→真实内容制作/低拱返工→真实运行→独立REJECT→因果修复→独立复验”的技术闭环；继续制作/审查整区体验，不能用这一阶段通过代替全区完成。
