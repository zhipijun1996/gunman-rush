# 牧风者运行切片

D072现行行为以[优化运行记录](plains_optimization_runtime.md)为准，以下D071验证数值为历史证据。竞技场现为版本4；新增登场/阶段过渡、最终桥墩循环、独立HUD，暂停冻结当前Boss状态，段回退才取消攻击。

上位设计：`windkeeper_plains_iteration.md`。正式平原 Boss8 实际使用 `scenes/bosses/windkeeper.tscn`；旧 Guardian 保留固定 demo、原 Boss Lab 与旧回归。MODULE LAB 新增独立 WINDKEEPER 按钮，六姿态原画与独立转动风车接入；姿态切换、呼吸、命中闪光与旋转属于程序表现，不是完整逐帧动画。

## 分离契约与可调策略

`WindkeeperDefinition` 保存 12HP、0.67/0.34 阶段阈值、1.1秒预警、3.8秒核心窗口、225冲撞/110追逐速度、180波速和局部风速(32,-38)，均为可调 demo 值。定义拒绝非有限、逆序阈值和无效时长。`WindkeeperEncounter` 使用既有 BossEncounter 的 Health、typed projectile 信号及取消契约，独立负责三套模式和可受伤窗口。表现只读 `stage_phase/mode/core_open/core_offset/objective`；Damageable 只在真实核心 Area 暴露时接收弹体，并通过正式 FrameDamagePolicy 提交，不直接扣共享HP。

Ⅰ 真实扫掠踏地波、固定前摇后笨重冲撞、停撞后的颈侧射击窗口。Ⅱ 四片风叶全部以玩家实际矩形和12px叶片厚度作角度扫掠，最大0.035rad间隔（叶尖约4px）；每转去重一次受伤事件，局部气流通过 PlayerMotor 的有界 local velocity 接口叠加，唯一 `move_and_slide` 仍由 Motor 调用。平台和风区外的草地提供停留空间。Ⅲ 三个桥墩目标、短段有界追逐、每墩停撞暴露桥面高度风铃；80px桥断口可一跳跨越，回身射击提供下一落台反冲。

竞技场模块版本3：前两阶段连续草地、130px高桥面、三块180/180/190px木桥与两个80px断口。第三阶段撤除中段地面与支撑岩体，80px断口没有下层绕路。落桥提交真实环境伤害1HP；存活时由既有SegmentRespawn回到已安全验证的桥面段起点，保留BossHP/阶段/断桥状态。零血优先结束本局，不回退、不授奖。原地面锚点会被实际地形安全检测拒绝，桥面落地靠近锚点才推进段起点。巨羊在桥后方运行，BossMotor 使用明确Arena边界限制位移，巨羊实体不阻塞玩家/桥面；72×62接触伤害包络、核心Area与攻击都有实际消费者。不能将图可达当真实可达。

阶段切换、段回退、死亡、离场清旧攻击、core窗口与局部外力。D072暂停冻结树和Boss当前模式，恢复不重置核心窗口。段回退保留BossHP/阶段/已授奖励。正式App暂停/回退清理旧玩家弹体及开火资格；Lab奖励仍仅当次练习。胜负/金奖复用既有逐帧批次协调，玩家同帧死亡优先而不授金。RunManifest 保存/严格验证 Boss id/version/arena版本/三阶段，并继续记录版本化模块布局；伪造Boss布局拒绝。

## 实际验证范围

`timeout 120 bash tools/godot.sh --headless --path . --fixed-fps 60 --script tests/windkeeper_runner.gd`：173 assertions / 0 failures，退出0。覆盖一跳躲真实波、跳跃+反冲换侧避接触、实际130px升台与背部弹体命中、完整叶轮周期稳定台安全、叶片中部真实伤害/局部气流、80px断口一跳+回射反冲落下一桥面并打核心、取消/pause/伪造manifest拒绝、阶段III射线证明无底层地面绕路、真实落桥损血段回退、120轮真实攻击创建/销毁后引用列表有界。

完整初始12HP轨迹仅使用普通移动、按住/释放跳跃、下降穿台与实际松手弹体：经过全部三阶段，12次发射，Boss0HP、玩家1HP完成。此轨迹包含真实巨羊接触、波和风叶的FrameDamagePolicy及实际玩家死亡钩子；不重写HP/phase、不补血。分阶段测试使用明确HealthRequest fixture进入指定阶段，与完整轨迹证据分开。完整轨迹有受伤，不能称全Boss无伤；各专项无伤轨迹也不能替代真机难度/手感验收。

日志：`build/verification/d071/windkeeper/final.log`；故意失败 `-- --failure-probe` 返回1（174 assertions / 1 failure）。正式App第8关独立结果fixture（不冒称手动通完8关）另外验证实际加载羊、阶段III断桥生命周期、金奖安全站位与真实确认/领取弹窗、一次金→Home和同帧双死无金。

早期失败保留，包括core初始化、追逐碰撞停滞、旧平台遮挡核心与测试AI无法存活；未降低判定。技术测试不代表Boss趣味性、手机触控或视觉认可。
