# deep_high 入口：只读独立设计诊断

身份 `/root/plains_design_challenge`。这不是生产租约、最终验收或玩家试玩；没有修改源码、质量记录或host响应，没有新增production loop/agent。采用 challenge-choreographer、encounter-director、gameplay-reviewer。当前head为30f开发基线加dirty工作区，实际字节绑定provenance.json；本次没有观看任何最终场景/截图/影片或听声音，不能评价currentScenery美术、实际预告是否看得清或用户趣味。

## 结论

已经证实一个**内容编排与策略观察同时存在的缺口**：随机junction diver的巡逻身体进入高级入口第一跳的承诺空间；默认起岸受保护、首级平台又遮住枪线，脚本没有在起跳前找到侧方视线，于接触之后才在窄台尝试射击，随即因真实反冲支撑不足停止。

没有证明这里无解或所有玩家必伤。左侧真实地面存在**只在鸟巡逻左相位**才同时满足枪线/全反冲支持的候选，尚未通过实际输入完成；不能把这个候选写成替代通路已通过。更新聪明driver若能走通，也不能抹去当前随机遭遇缺少明确观察/承诺合同的问题。

## 实际证据与对照

root `level-design-v2-baseline`，map1 intro，return，当前Manifest `612b0820e0eab48011d3702aebd194529833705ddf94bd33d11e237415009cc1`。

| 实际消费者 | 结果 | 范围 |
| --- | --- | --- |
| 原after kill_from_bank_v1 `build/verification/plains-encounter/run_7q21bhnl/after/case_0/capture.json` | policy_failed，816ticks | 捕获有效，不是关卡通过 |
| 本次现有正式工具 bait_then_bypass_v1，完全同Seed/map/return/Manifest | policy_failed，1102ticks | capture进程exit0、errors=[]；路线仍失败 |
| 原before同kill策略 | reached，4711ticks | 内容不同：入口是地面charger(130,-700)，after是diver(70,-810)，不是同敌态对照 |
| 本次真实正常spawn的DemoApp physics查询 | 15组query，exit0 | 假想站位/记录敌位的静态几何；没有移动角色或证明输入通路 |

实际命令：

```sh
python3 tools/level_formal.py --seed level-design-v2-baseline --seed-count 1 --maps 1 --strategies return --encounter-policy bait_then_bypass_v1 --max-ticks 18000 --output build/plains_redesign/high_entry_diagnosis/bait_return --timeout 180
bash tools/godot.sh --headless --fixed-fps 60 --path . --script build/plains_redesign/high_entry_diagnosis/geometry_probe.gd
```

日志/exit与原件全部保留在本目录；bait wrapper1/1捕获、0目标到达。geometry probe继承了已有退出2 ObjectDB/1 resource warning，未冒称内存检查通过。没有使用注能、搬actor、直接伤害、改AI或机关时钟。

## 内容、身体与时序

Generator `_deep_loop` 在上庭base(0,-700)放第一升台：世界x20..160，顶面y−782，合法站立中心y−800；后两级继续交替上升。当前generic guard则从普通junction分支选diver，home(70,−810)、水平巡逻±40，碰撞28×32。玩家身体24×36。因此鸟的正常巡逻位置与第一升台/起跳轨迹发生真实重叠，并非刻意绘制的一张“高奖入口遭遇卡”。

kill真实序列：到junction tick781，player≈(0,−700)、grounded、51能量/5HP；tick782承诺第一跳；tick789 player(34.69,−782.94)发生bird contact扣1HP，**同一tick才第一次出现diver telegraph**；tick815落到(90,−800)，816策略报 `unsafe recoil bank before enemy shot plains/enemy/area_0_0`。不是射击资源耗尽：末帧52能量、有原合法Pulse1/一跳两发。raw在此之前对这只鸟没有accepted shot。

bait真实序列：到上庭tick767；首次接触与telegraph均775；attack811、recovery832，后续又有telegraph/attack/recovery周期，但脚本最终停在约(130,−800)，1102报 `no safe non-kill recovery/crossing within budget`。这证明另一现有策略也没有完成，但没有穷举人类可行输入。

接触与攻击预告必须分开理解：DemoContactEmitter对身体相对扫掠独立造成接触伤害，不等待telegraph；EnemyAttackBehavior `_can_engage` 又同时受45半径protected anchors、180激活距离和真实terrain射线限制。即使浮空敌人本身可见，当前raw也不能证明新玩家会从正常镜头提前读懂它与第一跳的危险关系。

## 真实静态几何查询（不是替代通关）

在同Manifest实际Godot场景里查询。使用原 `bank_supported` 全脚宽与全反冲路径、玩家真实3半径弹体layer9 sweep和enemy layer1 sightline；没有设置任何actor位置。enemy centre是raw记录附近及其home/右相位的假想查询点，不能当作三次实际敌态复现。

| 假想站立中心 | 对左巡逻位(30.23,−809.14) | 对home(70,−810)/右位(110,−810) |
| --- | --- | --- |
| (0,−700) | 原地及反冲有支撑；枪线被首级Platform1挡 | 同样被挡 |
| (−60,−700) | 全反冲支持，弹体和视线均清晰 | 首级仍挡 |
| (−90,−700) | 全反冲支持，弹体和视线均清晰 | 首级仍挡 |
| (−120,−700) | 对左相位可行 | 向home/右位连全反冲支持也不足 |
| (90,−800)首级中心 | 枪线清晰；84.7反冲全路径缺支撑 | 同样缺支撑 |

起点(0,−700)与实际protected anchor重合；所以“在junction等它先俯冲”本身未必能触发AI。左移60/90后远离保护圈，但对home70的距离也变大；必须联测激活距离/视线/巡逻相位，不能简单说左移90就总有解。查询从角色中心做实际弹体圆扫掠，未操纵角色姿态/枪口；真正替代还必须经过原ShootAbility包含body→muzzle短扫掠的真实发射与伤害receipt。

## 策略缺口（工程事实）

`prepare_threats` 对clear_shot=false而距离≥75的活敌直接continue；不会主动寻找真实有支撑的侧方观察/射击位。它在deep_trial前虽正确恢复新上升目标，却仍从(0,−700)进入第一跳。`kill_from_bank` 的侧向找位只在当前射击反冲银行不足时执行；它不解决被首级遮挡的起岸视线，而且窄台上的候选不能穿过活敌身体当“安全移位”。`bait_then_bypass` 对距home>125先返回继续移动，之后的非击杀跨越针对同高度takeoff/receiver；此处是带垂直上升的入口，窄台/鸟近身造成这条策略失败并不等于所有合法非击杀方案不存在。

## 两个可控内容候选（都未实施/输入验证）

1. **推荐：把高级入口的准备/首级平台变成明确观察与恢复空间。** 将generic守卫排除在入口第一落点/首跳扫掠区域；同一敌人预算可重分到已有宽安全岸之后的可观察单一窗口，或取代另一个普通generic位置，避免叠到已有bell/ferry敌人上。保留高奖内部原连续模块与高回报，不靠减少整条挑战掩盖问题。玩家先在真实稳定岸看清下一段，再选择承诺。这是在编排层明确“哪里观察、哪里受压”，不改AI/Motor/资源。
2. **若希望保留此处敌人与上升地形的互动：把侧窥/择时做成经过设计的解法。** 利用当前左岸候选，先明确可见观察点和第一台上方鸟的空间关系；如实际三枪/引诱窗口过窄，再在明确黄金样板中调整准备岸或首级遮挡几何，为有效枪线、真实84.7反冲和撤回留下包络。玩家能选择等鸟到左相位射击、或观察锁向后走另一上升站位。不能只写路标、凭坐标保证，不能要求只有一个精确巡逻tick才可执行。需要真实kill与非kill输入各跑成，然后看正常镜头是否读得懂。

第一项通常更小、更符合“高奖连续技巧从可读准备区开始”；第二项保留更强的联合遭遇设计，但成本/相位公平性更高。二者都不新增核心能力、敌人HP/伤害或经济奖励，也不靠堆更多机关。

## 必要回归与尚未证明

同root/map/phase分别正常alive、真实击杀dead、真实bait走离、未激活，原0/低资源/冷却/失败重新接近；额外覆盖鸟巡逻左/中/右、先走上庭和高奖返回、两图/代表Seed。真实扫描body、弹体/枪口短扫掠、landing/恢复、伤害与命中回能receipt、唯一落点和撤回；保留当前816/1102失败，不能换Seed消失。若换策略，冻结old内容也同字节复采。原15/31、20/350/64与高奖完整出返程不降，适用质量层按实际改动重跑。

当前没有证明无伤替代通行、强制受伤或整区不可玩；也没有证明正常镜头已能看见安全侧站位。最终currentScenery、主观公平/趣味、真人手机/手柄与玩家认可均未验。本报告是给下一次有界内容编排/可读性返工的具体证据，不是生产状态PASS/REJECT。
