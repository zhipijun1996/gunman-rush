# 荆棘森林：简短请求驱动的 S2/H 技术首阶段

任务 `level-new_region-thorn_forest-prototype`。本轮重新接收的用户输入仅为“制作荆棘森林。”。使用现有 region-generator → level-module-creator → challenge-choreographer 路由，复用已经实现且经返工的真实 H 切片，禁止无意义重写。此卡不代表完整地区制作完成。

## 权威与状态

- `docs/design/player_actions/README.md` 最新覆盖合同优先。`regions_v0.3.md` 第0.1节锁定 S2 单能力，地区矩阵第99行与第172–180行给森林 H 门槛、铃藤教学和树冠接力候选。后续W/D/U1/U2不准混入。
- H 是当前 Studio/开发初始化实际可授予的独立能力；正式森林及正式进度中的 H 奖励未开放。本切片不改进度、存档或地区注册。
- 当前装备只为 PulseLv1 一种；本技术链不射击，不声称已验证 H+R 接力。武器V0.8及最新覆盖仍约束后续生产，不能把所有分支同时当可用能力。
- `docs/world_regions.json` 的巨树、藤蔓、被吞没皇家花园及暖光→湿墨绿是候选视觉方向。本轮灰盒无美术准入，不沿用平原风铃/草丘/Boss当森林身份。

## 玩家体验与取舍

第一株铃藤的核心判断是“看见锚点与宽枝台，承诺牵引，踢跳后朝枝台修正，稳定落地，再返回树根”。观察区为宽根面；锚点先可见，无敌人抢占唯一落点；枝台宽度允许完整身体稳定支撑，落地后可从边缘自然返回下层根面。

选择现有静态锚点教学链；替代方案是移动萤虫目标与反冲接力，但它需要新的真实敌人、目标失活恢复与资源证据，本轮未实现，不以动作数量堆深度。保持现状即不重新造已经有效的基础教学，而将有界工作用于 fresh 原生证据和自动质量消费者绑定。

## 动作、空间与资源合同

真实消费者 `scripts/demo/thorn_forest_h_slice.gd`，入口 `tests/forest_h_slice_runner.gd`。它实例化正式 player.tscn、PlayerController、唯一 PlayerMotor 和 GrappleAnchor；仅开发初始 spawn 定位，之后不注入位置/速度/资源。输入来自现有 Router 的 grapple 请求与移动轴。

空间常量由消费者读取：RootLanding `(-200,600,1050,90)`，CanopyBranch `(20,405,190,24)`，锚点 `(380,470)`，初始脚下 `(100,582)`；它们是本灰盒几何，不是所有森林地图规则。入口静止，实际身体/资源/Definition配置由运行快照取得，不能复制固定最大跳跃包络。实际单次输入在初始化后的第12物理帧排队；这是可复现驾驶策略而非普通人时序容错证明。

AtomicAction → Phrase：观察/瞄准 → 请求H → hook_cast → hook_fly → hook_pull → hook_contact_kick → hook_kick → 空中横向修正 → 完整身体在枝台停稳12帧 → 行走离台/下落 → 根面停稳12帧。真实每帧唯一 Motor step、Router输入、accepted状态事件、支撑面、健康/能量/空中次数和最终状态均入轨迹。无等待相位机关；不从静态通过外推动态敌人、随机图或复杂接力。

正例必须真正完成上述连续链；资源来自 Definition/现有状态，途中无伤害/开火/补能，必须保持合法且与起始一致。无H或删去真实锚点必须实际失败。验收器另拒绝删落地/返程/accepted事件、伪输入和资源越界。可视提前展示、真人容错、手柄/触屏同时操作负荷仍未验证。

## 本轮真实验收与后续依赖

实际运行原 runner 三次原生进程（positive / missing-anchor / no-hook），保留完整 capture、日志、命令、源码清单、SHA 和退出码；positive 由原 Harness 的 region_proof 消费者严格核对，负例真实移除节点/未授予H，不伪造JSON来冒充原生失败。独立工程审查由另一个真实代理完成，本实施者不签 G4。

原 `V3-FOREST-STARTUP-01` 的两轮实际 REJECT 原样保留；其 UID 问题的独立修复与当前 fresh 证据分开，不重签旧录制。新任务为父预算明确重新分配的两个从未创建名额，不退款旧失败。

`short_request_route.json` 保留自动识别出的九个完整 production_plan 包：审计、设计、生态、Boss、资产、动画、黄金、正式集成和审查。它们均 pending。当前仅 G0/G1 技术首阶段；正式地图、活锚点/移动敌人、Boss、独立资产家族、动画/声音、正式生成与保存、整区路线、多武器、用户趣味和真机验收需要以后真实执行。production_pool=false，formal_region_opened=false，formal_H_grant=false。不得将灰盒技术成功签商业或地区完成。
