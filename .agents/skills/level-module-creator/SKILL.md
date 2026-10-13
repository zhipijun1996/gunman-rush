---
name: level-module-creator
description: 新增平台跳跃挑战、模块端口/时序/连接改动及模块准入。
---

# level-module-creator

## 触发与边界

新增平台跳跃挑战、模块端口/时序/连接改动及模块准入。 从仓库根目录调用 `$level-module-creator`。使用 [总门槛](../../../docs/development_quality.md)；重要内容由 game-quality-gate 建立一次任务，专业技能补充同一记录，不重复执行共用阶段。

## 输入与依赖

读取 [AGENTS](../../../AGENTS.md)、[实际状态](../../../docs/current_state.md)、[handoff](../../../docs/handoff.md)、[架构](../../../docs/architecture.md)、[验收](../../../docs/acceptance_tests.md) 和相关最新设计。输入用户目标、基线完整 SHA、任务 ID、内容版本、受影响路径、正式消费者、已知失败与前置能力。缺信息先记录 unverified，独立可逆工作继续；重大创意不可伪称用户确认。

## 阶段流程与交付物

G0：模块名称、玩法目标、必需动作、真实能力要求、进入位置/速度/资源/冷却、入出口端口、操作序列、机关时序、观察区、安全落点、失败恢复、接缝净空、敌人允许点、镜头提示、美术语义、难度收益。先读 [模块契约](../../../docs/platforming_modules.md) 和 [能力](../../../docs/ability_components.md)，不能使用未授予能力。
G1：用现有 [PlayerMotor](../../../scripts/player/player_motor.gd)、实际能力/动作次数和反冲弹体执行。正向、需要的反向、动态相位、资源能力边界、完整身体碰撞/危险扫掠、接缝、失败恢复分别验证。入口速度/冷却写在证据里，不靠传送/手改坐标或几何路径冒充成功。
G2：art-director 验证功能色、地形端头和镜头落点；涉及动作/特效调用 animation-vfx。正常游戏尺寸合屏及连续操作录像，不能为拼图改碰撞。
G3：Module Lab 只作为定位工具；在真实邻接模块、不同端口/镜像/高差和正式随机池验证连接。单模块成功不代表拼接成功。核对正式能力/资源、存档回退和恢复位置。
G4：运行真实 Motor 专项及生成回归；gameplay-reviewer 主动检查危险扫掠、不可见落点、偶然相位和不可恢复状态。禁止擅自调整 PlayerMotor 基础参数使模块过关。
G5：玩家实操可读性、手感、公平性和设备控制；有证据才允许正式池准入。原型可保持 review/blocked 并清楚列出缺项。
交付：设计卡、可玩模块、端口/相位表、邻接矩阵、真实输入轨迹、截图录像和质量报告。

## 设计要求

使用 [专用模板](../../../docs/templates/level_module_design.md) 写场景/前置、方法、可观察结果和失败条件。复用真实配置/Definition/架构，禁止重复数值默认值、无消费者框架或为通过测试改基础物理。占位仅限明确标注的原型，不能冒充最终内容。

涉及可变形状地形时，执行 [邻接与拼接契约](../../../docs/quality/terrain_tile_contract.md)：枚举局部邻接、不同分块的同图对照、薄结构与孔洞、真实 GPU 与正式合屏分开验收。不能用覆盖率代替美术品质。

地形表现接入时引用 [地形契约](../../../docs/quality/terrain_tile_contract.md)：一行平台也须覆盖长度×厚度、短端头、相邻间隙和移动相位。物理尺寸先定，素材按外露边界适配，不为图片改变已验模块。单向桥、实体台与危险的轮廓语义分开；用正式模块合屏证明落点可读。

## 自动验收

运行 harness gameplay，定位入口 [地区测试](../../../tools/run_plains_region_tests.py)、[历史专项](../../../tools/run_plains_ten_tests.py)。保留正例与必失败反例，记录 Seed/Manifest、能力、入出口状态；结构测试和 Motor 验证分栏。 记录实际命令、环境、退出码、日志和版本；计划命令不算执行。执行 [质量检查](../../../tools/quality.py)；静态检查、运行测试、实际宿主调用分别记证据。

## 人工审查

采用 [通用审查方法](../../../docs/quality/review_method.md) 的不变量与对照/变形测试，覆盖实际绘制与正式消费者；用户反馈是回归样本，不是发现问题的唯一列表。

在镜头中观察危险/落点、提示与安全空间；玩家是否学得会、失败能理解且能恢复。审查相邻组合及资源边界，不能只看蓝图。

## 准入退出与返工

按 [policy](../../../docs/quality/policy.json) 的相关 G0–G5 执行。进入一阶段前上一相关阶段通过、输入与消费者明确；退出须专用模板的可证伪判据及对应证据成立。设计失败退 G0，操作/公平失败退 G1，表现失败退 G2，接入/状态失败退 G3；修复后重跑受影响门槛并复审。保留失败原件，不删除测试/降标。依赖阻塞写 blocked，缺审查写 review，缺真机写 awaiting-device。

## 完成与证据

使用 [质量报告](../../../docs/templates/quality_gate_acceptance.md) 和 docs/quality/records/<task_id>.json，逐项记录 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance。只允许 passed/failed/unverified/not_applicable（有理由）；证据需路径、SHA256、提交/内容版本、观察和来源。技术通过不能宣称完整内容完成；所有适用条件具备才可 done。本技能文档本身不提供任何内容的 PASS 或用户认可。
