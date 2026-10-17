# 森林探索 V2：巨木内外与共享林隙实验

任务 `FOREST-DEPTH-02`。现有 `ThornForestRegionV2` 已改为实际的新实验生成实现，`layout_version=hollow-clearing-experiment-v1`，没有另造平行生成器。default/legacy_v1 仍保持 v1，`production_pool=false`；两图新宏观未获得完整 Motor、敌组合、Boss、独立内容或设备准入。

## 为什么替换 macroA

macroA 固定三个完整大场地并用长双层地面连接。独审依据实际 raw 判为 REVISE：一个 seed 的 fast/growth 逐帧同轨1692ticks、三次受伤，数条连接有4.6～5.8秒没有新动作；高奖是七跳接近再回同口，map2存在低路只开最后门就到Boss的静态反例。其18211项数据通过不代表玩法通过。

旧 generator、当时 topology runner、文档与独审六件的精确归档在 `build/forest_depth/hollow_trunk/candidate01/macroA-before-reconstruction.tar.gz`，同目录 receipt 记录全部SHA；formal02～05和旧失败保持。当前新 topology runner只验证新候选的数据合同，未修改原 baseline tests。

## 已测局部，严格限定范围

`ForestHollowTrunkGeometry` 是单一巨木的数据工厂，使用现成 PlatformingModule、PlayerMotor、Router、Policy；没有改角色/武器/资源。hollow05 同一源四例真实 normal-input：浅环下降H+R320帧、深侧环H返程零枪325帧、纯R286帧（更快）、无动作下落152帧后自然恢复到外根。四例离岸身体/速度/HP/枪数/能量相同；上程均仍使用H+R，不能称全局无H消融。深侧环是 `[120,155]`；返程零枪不是全程零枪。

唯一同源GL完整深H闭环329帧/60fps=5.483秒通过，源与runner guard一致。前四轮失败和浅H/R较慢反例保留。不同作者的独立局部审查已给CONTINUE：仅深H一整空间可按真实入口状态整体嵌入；浅H+R强制推广为REVISE。真实129～133帧存在partial脚掠缘接地并刷新H，不能写成连续空中抓停；终点两方案都会回满，未证明实际零枪资源初始局面。不得代签整区/玩家认可。hook_start 固定在request，实际12px钩头扫掠与全身体须区别中心线可见性；不能根据下落玩家中心的ray推断钩头发射源移动。

## 两图实际骨架

| 地图/family | 入口与目标 | 实际奖励跨联/恢复 |
| --- | --- | --- |
| 图1 hollow_inner_first | 树腹M先见外冠E，Boss接近在E另一端 | 外枝K连接E-R；拿奖可普通跳穿one-way接近枝继续Boss，也可从另一端落R，经下洞D回内根营地，避免为成长重复上H |
| 图1 hollow_root_first | 外根R进入，先看下洞与内根，Boss仍用真实Factory既有右侧prep端口 | K移到D-M内侧腔，并真实拆分M地板开侧腔；普通恢复路仍保留。高奖后K-M-E-R返回外根营地，不是同口退袋 |
| 图2 clearing_shared_edge | 西庭W进入，中央M可改意，营地在内根D侧 | 左/右环实际共用D-M恢复边；奖励K在外冠与外根跨联，另有直接继续Boss出口 |
| 图2 clearing_shared_node | 西庭W进入，北庭N是营地，中央M与外冠/下洞组成另一环 | 两环只共M；K连接N-D，实际北枝/侧腔平台和出入口不同。不是换camp标签或整体镜像 |

Boss入口没有为“换目标端”伪造未测镜像：当前Factory只验证从左prep进入右侧arena，因此实验两seed都把P接到真实右侧入口。它们的入口、K邻接、地板空腔、环共享和发现顺序仍真实不同。原纸面“第二seed把Boss接树腹西侧”需要新Factory方向合同，未实现，不能把图线当可用。

图1共享局部的世界偏移是 `[600,600]`：M`[600,600]`、E`[980,558]`、D`[720,802]`、R`[1020,882]`。实例id `hollow`，支持/环 id 均 `hollow__` 前缀；Manifest记录完整source_geometry、local_geometry、idmaps、derivations与SHA。root_first/shared_node的M地板真实拆分，明确不继承hollow05整场地证明。新增K、R向D、返向、北庭等也要各自fresh。

## 正式消费者接口

核心边使用 `hollow_upper(M→E)`、`hollow_lower(E→D)`、`hollow_recovery(D→M)`，携带 geometry_instance、from_port/to_port、landing及实际landing_support_id。05实际恢复先站在原入口左侧local−180；实验split地板之后另有显式post_landing_steps跨40px洞回主站位，不让driver盲走过洞。

R→D是新的 `hollow_outer_recovery`，北庭与跨林隙是 `candidate_hook_relay`；均未物理准入，不能继承05那条从E下降的轨迹。普通边列实际takeoff/landing/support与中间路径；全身落点数据检查不能代替身体运动。

`routes.fast`/`growth`止于gate_ready`[1400,558]`，不进入Boss核心；`high_return`止于实际营地。`change_mind`先到E看到接近目标再转营地。离开cache的每条边有claim_before_edge、claim_area、claim_id，需真实modal领取及幂等，不以路径经过代签取奖。

图2Queen仍由 `BossArenaFactory.from_prep(map2)` 明确blocked；空间候选可研究，但公开generate不回落成旧Queen。两Boss机制与正式路线分别准入。

## 生态与随机

不再保留2600px完整woven floor逼出长廊。先使用实际旧Def的charger配方、sentry、lantern，脚底读取真实body，350px营地排除；未声明新獾价值。当前敌组合仍实验且密度可能不足；不凭凑8怪填满唯一接收岸。蛛线/活锚可按已验证的具体关系加入一个共享窗口，但其换地/相位/返程需fresh，不能继承旧局部生态通过。

固定八个root×两图的新数据首验已真实1693断言/0失败、11.048秒，sourceguard与全部1997原文件SHA一致。四个实际骨架、完整seed重建、共享几何派生/实际支持、奖励跨联、route连续、hash修复后的篡改拒绝均过。原件在 `build/forest_depth/snapshots/hollow_macro01/build/forest_depth/spatial/hollow_macro01/`；实际代表图1为 `forest-depth-hollow-00` 和 `forest-depth-hollow-02`，图2同两root分别为共节点和共边。它不是60条正式路线矩阵或旧18211断言的续签。先一个代表seed的实际快Boss/成长/高奖返回和中途改意，再另一seed；发现廉价绕过仍保持真实对照，不缩安全地面/加刺强迫H。

视觉先保木干/通孔/枝台/安全地面语义；镜头、可读性、完整正常速度音画、性能、设备与玩家趣味仍须各自验证。

## 当前上窗荆棘替材候选（尚未原生采证）

无危险的紧凑骨架已由正式路线作者在图1两代表root实跑fast/growth/high_return/change_mind共8条；其原始源与失败仍保留，不能代签下述新危险或后来BossFactory的公平。1693数据断言也只对应原无危险源。

当前实验 `hollow-clearing-upper-thorn-candidate-v2` 只更换上窗上沿的实际材质：原实干local `[210,-520,120,426]`削至height402，将真正移除的 `[210,-118,120,24]` 放入danger；world为 `[810,482,120,24]`。原70px安全通孔 `[810,506,120,70]`、环、收岸和下孔恢复不变。明确的 `danger_presentations[0].facing=down` 供正式绘制消费者呈现完整朝下危险，而非将刺埋在实心碰撞里。

假设是H之后用射击方向控制穿孔高度：横向反冲沿原安全轨迹出冠；向下斜射产生向上反冲，可能真实碰到可见荆棘上沿。新专项以同一正式App/Manifest/原资源比较，仅改一次真实射击方向，要求错误路线记录实际generated_spikes Policy伤害与正式Segment返回，再用正常输入重试。尚未证明这个错误一定会碰刺或可自然恢复，不能先写成成功。旧轨迹上沿身体净空最小6.482px，不等于输入舒适，需局部扰动和正常镜头可读审查。另一个待比较假设是下孔顶沿同包络替材，使等待下落再侧抓与过早向上抓产生不同风险；本轮不同时叠加。

先前“外根短荆棘带再加一次普通跳”已在采证前因不深化H判断而淘汰，候选源与拒绝收据保留于build，不进入当前Manifest。不得用危险强迫H；无H/单R替代仍保真实比较，当前上窗更不能提前宣称H必需。分层生态仍是独立后续变量，本次危险首采不混入新敌。
