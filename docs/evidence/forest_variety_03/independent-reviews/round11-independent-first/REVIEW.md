# Round11 六条实际路线独立审查

结论：**限定接受六条实际路线的通行/指定领奖返回证据**。不签美术、丰富随机地图、八种新趣味、全组合路径或发布。第二轮实际画面仍 ART_REWORK；附林保持候选，不发布。

原件 `/tmp/gunman-forest-variety-03/round11`，receipt 原 exit0、117.829s，90/240s 上限。独立重建 **3665 = 38 条 ZIP changed + 3627 条 baseline** 全源 SHA，全部匹配且 before/after 相同。审查没有开引擎、改 Git、改生产或改原收据。完整复核脚本/日志/机器结果在本目录 `verify.py`、`verification.log`、`review.json`。

## 六条的真实范围

| 原件 | 实际帧/完成段 | 可以确认 |
| --- | --- | --- |
| old-HH | 401 / 6 | 从原 spawn 走原入口 HH，到旧 innerbough；新165wu湾没有阻断这条原设计。 |
| old-skill | 223 / 1 | 从原 spawn 完整 root_spiral 旧技巧线到原 crown；新湾没有挡住此线。 |
| L-coin | 1991 / 42 | **明确的局部初始spawn fixture** 从 observation 起步，上窗→下窗内根→L领奖，实得4金币/0音符，低出口→挂果跳→内根→盆地→RH回上窗。 |
| L-note | 2275 / 50 | 同一局部fixture实得0金币/1音符，且实际到远出口后回L低口，再挂果跳返回。远出口证据在这条局部路线，不能写成所有正常spawn的全组合都验证。 |
| map1-annex | 4560 / 66 | 原 spawn→原设计→东附林观察岸→上窗/连接枝→原F05根→旧weaver下窗→旧核心camp `[1230,882]`。 |
| map2-L-journey | 6475 / 106 | 原 spawn→附林→L实际4金币→低口/挂果跳/盆地/RH→旧F05根→旧核心north camp `[200,450]`。 |

共 **15925个实际连续Motor帧、271段**，逐段末12帧独立核对真实支持实体、完整24wu脚宽、站地及原目标规则（横≤7/纵≤2），全部通过；按12×18半体积扩张静态危险矩形扫相邻帧，交集0。没有手动 Motor、途中位置注入或资源覆写；六条均原 H-only（D/W关闭）、初末配置SHA相同。两条 L fixture 的初始位置覆写是显式且发生在首Motor之前，仅此局部作用域，不冒充原spawn。

**不是全程无伤**：map1-annex 在 tick4461 被旧 `hollow_route__outer_lift_lantern_contact` 扣1HP，真实帧降至4，tick4531 回5；同一actor/stage epoch。原manifest在 `[1195,877]` 有1HP camp_heart，回5位置 `[1150.011,881.925]` 距该心约45.26wu，符合未改 App 的 `<46wu` 自然拾取/治疗路径。原件无独立拾取事件，因此这个因果由原实体、未改代码和实际健康变化支持，不声称看到额外领取事件。其余五条帧HP均5。

## 领奖和挂果跳不是文案声明

三条领奖轨迹都在真实L receiver约 `[4649.982,1835.925]` 停留；每次5个 modal采样均 paused、同位置且 motion_steps不变。两条实际鼠标按下/释放选择可见按钮；初次和重复 `interact` 都有真实Router queued包。钱包/音符选择为OR：金币路线 +4/0，音符路线 +0/+1，items未多给；重复交互前后 claim/wallet/notes 完全相同。map2完整路线的claim使用map2命名空间。

L返回三条均真实接到同一 `varied_l_return_fruit`，观察到 hook_hang，随后从该状态真实 jumped。L-coin tick1261 hang→1262 hook_kick，L-note1545→1546，map2 4022→4023；起跳vy约 `-556.067`，不是直接把人移到内根。随后真实到达内根且末12帧完整落脚，再继续盆地回路。此证据仅签实际这条固定果实返回，不外推Z返回或别的地形。

两条完整路线在去程 tick1899 已实际观察到旧 weaver 死亡，之后返回通过的是这同一敌人已死的下窗；这不证明新增“逆向岸边再射杀活weaver”的驱动分支已执行，也不证明活敌逆行无伤。没有把旧实体关闭或将旧体当透明。原静态危险扫掠不包含动态敌人，故明确保留上述受伤事实。

## 保留旧设计与随机性的边界

20个实际生成JSON样本中，旧 retained platforms/anchors/enemies/rewards/instances/dangers 全条目与当前manifest仍精确相同，0缺失/改动；v15 producer源码SHA还与已恢复公开旧版 bbf5b24 的该文件一致。原HH/root_spiral本轮又在165wu湾下真走，补上 round07 的旧线限定缺口。此处不等于完整旧版所有路线/所有seed全重跑。

独立重新按新增 `varied_*` 实体核对，**每map新增平台rect/one_way集合只有1种**；新增实际anchor坐标/个数有2种。旧runner报 map1=2/map2=4 的 physical_signature 混入整个geometry_instance的ID、动作程序等metadata，不能称为2/4种平台地图。真实有限变化是 HH/RH 的果实位置/B果有无，以及window cache内/外口；附林地形骨架和整体拓扑没变。这仍未满足用户要的多样模块与随机地图。

父代理已决定把平台实体签名、anchor位置、端口/奖励去向拆开，并让当前新增平台轮廓不足的检查真实失败；保留本轮native实际通过，不追改原失败，不靠尺寸微调凑数。该新guard待独审/真运行，不能用尚未出现的新收据替换本轮scope。详细样本核对见 `world-review.json`。
