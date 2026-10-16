# 风铃平原 D1–D3 内容返工：技术候选

状态：in_progress；D1–D3 与低拱几何返工的实施候选，G0/G1 证据按任务记录，等待不同代理只读审查。正式敌情、场景、设备与玩家认可分别验收。此文不声称平原已经好玩或美术完成。依据是独立 [设计挑战](../evidence/plains_redesign/design_challenge/report.md)，不是增加机关数量的指标任务。遵循既有 region-generator、challenge-choreographer、encounter-director、level-module-creator 与 G0–G5/十一维流程。

## 实际设计

图1先保留 well→low_arch 的同枪开门/反冲后改变按跳时长；图2第一段使用现有 remote_sequence：地面看首铃→射击开第一道门→经过遮板→跳上90高观察台→新的视线射第二铃→接收岸恢复。两个真实地面站位之间有位移与一次跳跃，不要求连续空中两发。营地前下一拍按实际动作家族换为相位轮、反冲跨越或墙面翻越等，避免只换 recipe ID 再考同一个低拱或井。高级图上一庭的单遥铃与主路双铃体现展示到换站位深化；不宣称全地图任意路径均不重复。

溪谷的第二中箱沿用总额2 medium/1 high/1 top 与原资源池，改由受控渡船旁的真实单向侧岛承载。玩家在起岸观察并启动渡船，登船后射铃停车，跳上侧岛发现原预算中箱，落回原船，重新射铃继续至接收岸，再沿已经存在的攀升支路回已知营地。主路仍可直接到营地；溪谷的绕路有专属发现与另一类操作。Manifest `creek_discovery` 与该箱 `approach` 保存实际模块、bank、entry/exit_area、camp、reward_id、观察点、回程和上岸提示目标，下一场景包消费 `hint_from=area_1_1`，不能把该字段当已完成的画面。

首次溪船仅演示单 diver，在启动岸一侧可观察，巡逻点不再位于岛上。fan 留在后期普通渡船，与旧高级 fan+diver 联合遭遇测试兼容；初次溪船不叠加两个模式。首段抬升/换射线、第一恢复岸、溪岸接收与营地不放通用随机守卫。未改变任何 AI 行为、伤害或玩家物理资源。

## 连续状态与接口

真实当前能力只有 Pulse1、一次基础跳跃、两发空中射击与原20能量花费/地面恢复/冷却；黄金入口0能量通过真实消耗设置边界，之后只靠自然恢复。未授予 H/W/D/U1/U2、命中回能或随机道具。模块转接、返程、唯一站位与动态机关由真实 PlayerMotor/碰撞/Router 输入运行。

`tests/plains_creek_discovery_motion.gd` 是黄金、默认 native 区域轨迹与后续正式观察器共用的实际 driver：

```gdscript
module.set_meta("discovery_latch", encounter.for_module(module))
await load("res://tests/plains_creek_discovery_motion.gd").traverse(
    driver, module, bank, claim_callback, forward)
```

`driver` 使用既有 branch_module_driver，tick_callback 必须运行真实场景。callback 在岛中央真实落地、船已停车且时钟/位置至少12帧不变时被 await；正式 growth 从起 dock 进入 helper，在 callback 内走原 Router interact、原 reward modal 回调并核 claimedID，然后 helper 落回同一船、真实射击重启和出 dock。不能先走 area_2_2 终点再盲直走悬空箱。旧 v9 无 approach 继续原普通箱路径。黄金 callback 只记录停稳窗口，不是正式游戏领奖证据。

## 有界真实返工与公差

保留 golden1 的132断言16失败（边缘起射造成反冲出岸）、golden2 的132断言24失败（船上侧射反冲跌入真实危险体），之后先在岸稳定，船上侧射前靠左站35并用真实方向输入对抗反冲；未改 Motor/资源或机关 clock。golden3 140/0 是接入正式生成之前的真实时间证据。

历史的5个低拱输入观测不是设备验收或“趣味分”。原7tick释放/原起点成功；5tick在±8起点、9tick在+8起点真实接触齿轮，9tick/-8通过。这提示原主路拱顶对提前释放/较近起跳的容错有限；相位/能量矩阵成功不能消除此缺口。失败轨迹和危险接触日志保留，不能据单条精确脚本宣称普通玩家流畅。若没有后续实际几何返工证据，此项仍是内容风险。

另有实际图2案例先走上庭→营地，再从右侧进入尚未开启的首段双铃：门保持未开直到该段，真实两发射击后同一身体回到起岔。它验证替代探索顺序的返程，不是对所有玩家行为的穷举。


## 低拱 Definition v2：真实操作包络返工

在明确加入必要 prefab 路径的新 lease 中，先在旧几何跑完整 `release5/7/9 × takeoffoffset-8/0/+8 × 双向`，18例中12例真实危险接触。严格runner与当时完整源码归档保留，不把原抽样3/5当全部边界。

唯一空间方案将原半径18的齿轮安装到地面槽中，中心 `(320,282)→(320,308)`，露出地面10像素；轮子、半径、低顶 `(200,160,240,18)`、地面、端口、Motor/输入/跳跃/能量全部保留，`definition_version=2`。作用是给较早释放和更近起跳留下安全高度余量，避免普通主路要求脚本精确的7帧释放。不是删除齿轮或把碰撞关闭，也没有修改身体扫掠标准。

同18例实测全部通过；新的专项把全部18格作为必通过合同，不能少跑角落或只留原控制轨迹。逐帧核版本/真实危险体原点与半径、动作请求/已接受跳跃、释放时间、实际起点、同一身体、连续性、真实支撑和接收端。额外真实行走反例仍碰轮，长按跳跃仍碰低顶，而7帧短按有净空。长按碰顶后也可能完成，不伪称所有长按都失败；短按的价值是减少碰顶、保持节奏。局部±2帧/±8坐标通过不能外推真人、触屏或全速度范围。

原64相位/能量/方向矩阵、完整20图往返/10零能量/350语义、原接收岸物理删除、真实岛删除、上庭优先再反走未开双铃、原15默认消费者在当前源完整复验；31共享消费者在同一个 prefab v2 的中间源完整实跑。之后联合设计审查发现：轮心下移让旧的敌人 patrol/低顶碰撞过滤失效，隐式增加拱下 diver。当前生成器显式保留低拱观察净空，其他 gear/ferry/bell 联合遭遇原标准不变；此定点后当前20/350、原15、经验黄金与64矩阵重新真实运行。31中直接启动 RegionGenerator 的 HomeApp19/0也重新跑当前源；完整31中间源证据没有换指纹冒充最终同源，最终root整轮full仍需当前源31。准确结果和源码指纹在 `geometry_repair/`，旧189/0和原阻塞保留为历史，不覆盖成255/0。原黄金包已封账5/6未用1次重分配，体验总预算旧1+续4，五包仍28次；不抹旧blocked或新建无限重试。

## 自动入口与不可伪造条件

```sh
python3 tools/run_plains_experience_golden_tests.py
python3 tools/run_plains_redesign_spatial_tests.py
python3 tools/run_plains_region_tests.py
```

黄金逐帧核连续身体/session、真实资源消费与 accepted shot/Router 请求，双铃第二次真实高台站位/新射线、门序，侧岛前实际登船→停车→停稳 callback→再登船→射击重启→出口。真实删除岛碰撞必须失败；删停车/重启/岛访问/换位/返程、伪造岛位置、传送、篡改操作边界必须被拒绝。新20图首段按图号检查1/2发，并限定首段时间窗，禁止拿后半程射击顶替。原20主路往返/10零能量、350语义/4反例、缺接收岸物理负例、原15套/冻结v9矩阵标准继续保留。

完整证据以 [索引](../evidence/plains_redesign/experience/index.json) 与任务质量记录为准。历史空间候选1029/712和原独审拒绝源保留在空间 evidence；本包不覆盖其 raw 或重标历史状态。当前 committed base 30f 不是本工作区候选已提交的证明，具体字节由各 receipt/source archive 绑定。

## EXPERIENCE-R1：证据因果返工

第一轮不同代理真实复审 REJECT：native255/0本身真实，但旧 `valid()` 在删除跳跃、落地、drop输入、remote最终health提交，或把岛上callback搬到起岸后，仍接受报告。原review/script/五项漏过结果、source和fresh原件保留；原PASS计数不冒充其验收合同已经成立。

本轮只修当前验收器，未改变关卡、Motor、资源、敌人或输入策略。所有actor事件绑定其真实生产帧/位置：输入与accepted jump对真实grounded→air切换，accepted landing对air→ground与全身支撑一一对应；drop请求必须产生下落并落回同一暂停船。出程按实际登船→停车→起跳登岛/落地→稳定visit与callback→drop→返船支撑→重启→出dock跳/落完整编舞核对，不能只看出口标签。

callback按现有记录约定绑定其前帧的实际visit，位置/支撑/稳定速度/岛上区间和真实暂停clock均须一致；不硬编码本次帧号。每个shot核Router请求、实际消耗、同帧自然恢复与逐帧余额、原生反冲、对应弹体impact与门/运动计数切换。remote第一弹必须改变sequence，抬升跳与落台后第二弹的真实health receipt eventID必须匹配actor/session/shot，随后才出现实体门切换和实际drop落地。低拱18格也使用同样actor/frame与能量核对。

独审原fresh原件仍被新验证器接受，五个原始漏检变异现在分别被拒；原review文件未被执行脚本覆盖。另复验其四个邻近场景，27个新增删/移位/重复动作、callback、health、impact、资源、motion反例已永久加入原15个，总42个。当前真实新源结果与拒绝均在 `causal_repair/`；这只是G1实施修复，最终独立复审仍由另一代理进行。正式App modal领奖仍属后续实际流程，不能从此callback测试签收。

## 尚未验收

独立设计审查；正式 App 原 modal 领取；敌人 alive/moving-away/dead/inactive 的合法输入对照；最终同源两边多 Seed 敌情策略；地标与下方奖励实际可见性、镜头/HUD遮挡；正式尺寸美术/音效/录像；手柄、触屏、真人操作；性能与既有退出 ObjectDB/resource 警告。技术切片成功不等于正式池或整体品质准入。
