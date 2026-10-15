# PLAINS-REDESIGN-EXPERIENCE-01 第一轮独立审查：REJECT（G1证据因果缺口）

审查身份 `/root/plains_design_challenge`，不同于实施者 `/root/plains_spatial_worker`。真实当前 review lease nonce `2a3051e2c9624e82ae8bb4bf2c708ad6`，request_hash `7f5db0dbe1c325922eebdad859d928705bb75913280833a3a248aaabf8fd751d`。未修改生产/测试/文档/任务质量记录；只写 ignored build 审查证据及约定host_response。此结论只涉及本包G0/G1，不是全区G5，也不代签用户/设备。

## 独立实际执行及来源

- `python3 tools/run_plains_experience_golden_tests.py`：fresh255断言0失败，16个remote/creek（双向×0/100精力×0/.5相位）与18个低拱输入角落通过；真实删侧岛8断言2失败、exit1按预期拒绝；原15种伪证均拒绝。原件 `build/plains_redesign/experience/run_igiwoygr/`，命令日志/exit在本目录。
- `python3 tools/run_plains_redesign_spatial_tests.py`：fresh1073/0，实际20图/10零能量、最差两图完整替代路线、高奖返程；350图语义712/0与四直接反例，真实删除接收岸反例按预期拒绝。原件 `build/plains_redesign/spatial/run_ae7wiy7l/`。
- `python3 tools/run_plains_redesign_golden_tests.py`：fresh3105/0，64个原连续组合矩阵和物理删除接收岸拒绝。原件 `build/plains_redesign/golden/run__aq59lh0/`。
- 独立逐项检查portable109件，压缩/解压SHA与原字节数全部相符；当前runtime archive624源成员与清单全部相符，且624项与工作区一致。review source guard与request.source_hash相符；详见portable_index_check.json/archive_check.json。
- 本人未再次跑完整15/31；controller当前15通过是其真实独立命令证据，31中间源只按中间源记录，未外推最终31。未观察正常速度图像/音频、未操作真人/手机/手柄。

## 内容设计的实际进展（AI设计判断，非真人认可）

D1已真实改变：10个intro均well_arch，10个advanced均remote_sequence；intro下一边5recoil_crossing/3thorn_wall/2gear_timing，advanced3recoil_crossing/2low_arch/5gear_timing。由动作家族约束消除原前半相邻低拱重考，并将图2改成两次真实择位射击。独立remote实例首枪tick25位置(99.58,281.93)、跳跃132、抬升落地166位置(520,191.98)、二枪172、真实铃伤害与开门173；是实际射线/站位变化，非配方改名。

D2已真实新增玩法：20图中箱medium_1均在当前岛上，预算仍两个medium。独立creek实例已实际登船、三发启停重启、跳岛、岛上停稳窗口、drop回原船及出口；它让奖励绕行有独立的操作目的，不是把箱子移远。正式App modal领取和下方可见引导仍未验证，hint_from字段不能证明画面发现成立。

D3当前20图初溪船均仅一个diver；generic guard避让恢复/溪岸关键位置，旧后期fan和高级fan/diver仍由原回归覆盖。是内容编排改善；其正式alive/dead/bait/inactive公平性需要后续包真实输入证据，不能从无敌人本包签收。

低拱空间修复可证：原18输入格12次危险接触→当前18/18无接触，原半径18/低顶160/地面/端口/输入/资源不改，只轮心282→308、definition2；实际走路仍会碰轮，长按仍实际碰顶（长按也可能完成，不能伪称强制失败）。这说明容错的具体进步，而非趣味评分。新拱下diver派生已显式排除，本人确认当前源，未假装中间31就是最终源31。

## EXPERIENCE-R1：关键事件/领奖窗口因果被删除或移位仍接受（高，G1）

位置 `tools/run_plains_experience_golden_tests.py::valid`。当前native raw是真实的；但自动验收承诺的不伪造因果条件没有成立。独立对fresh positive.json逐项单独变异，五项 `valid()` **全部仍True**：

1. 所有remote/creek observations删除accepted_jump；
2. 删除accepted_landing；
3. 删除Router drop_through请求（实际侧岛返船所需输入）；
4. grounded_island_callback保留个数，却改为tick0、位置(0,282)（起岸，不在岛上）；
5. remote删除最终latch_health_commit伤害提交。

程序与原件SHA、每个变异函数、预期/实际结果都在 `reproduce_validator_gaps.py`、`reproduced_validator_gaps.json/.log/.exit`；执行命令当前exit1，因为必拒五例全部漏过。额外四个邻近控制：缺整段返程、无callback、破坏停车clock、错出口均正确拒绝，详见validator_challenges.json。可见这里不是泛化“所有validator都不可信”，是具体漏检。

原真实creek forward/phase0/full：岛上visit frame702，callback703，drop707，船上落地720，restart shot729→commit740；只计callback个数无法核其在真实claim窗口。原remote跳132→落166→第二shot172→damage/open173，删除这些核心事件不应靠终点grounded与open标记蒙混。

**最小返工**：在当前validator核事件与帧、真实站位/支撑、运动切换/因果时序；岛上callback与visit/停车区间绑定；drop输入与岛后空中/同船再支撑绑定；关键跳/落地与相应阶段绑定；remote最终真实damage receipt与shot/门切换绑定。不要只加入五个名称的特判、硬编码当前ticks，或修改Motor/挑战难度。保留当前成功raw与本轮拒绝，真实修复再重跑原生、删除反例与新增邻近删证/移位反例。

## 结论边界

本包有真实可观察的设计改进与物理返工，不应因证据漏洞否定所有内容进展。但新自动准入工具未满足明确的“删关键事件/claimwindow必须拒”合同，因此当前G1 **REJECT**，等待有界下一轮修复与独立复验。正式modal领奖、四种敌态、正常画面与声画、视觉线索/唯一落点/触屏容错、真人趣味仍unverified；D4高奖节奏判断保留至完整实机影片，不为了凑难度增加模块。
