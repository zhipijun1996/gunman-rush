# D070 正式平原风铃

用户指出正式游玩看不到风铃并明确要求直接接入。本轮授权见[连续平原设计](plains_living_routes.md)，替代D069仅允许固定Lab的阶段边界；固定Lab自身仍是独立回归入口，不把它的整张场景塞进正式池。

## 可见的教学与组合

标准一跳角色的正式第1小关，公共路第二模块是480×360的安全风铃教学台。出生与第一个地面不动，玩家实际走到安全站位，再向黄铜风铃松手射击；SHOOT BELL变为OPEN，铃短暂摆动/亮环，连接门向上撤去。敲击后的一次deferred提交立即撤门实体，0.35秒表现不决定碰撞或伤害；当前没有敲击音，不伪造音频完成。

第3关起，非服务房的挑战分支首模块是640×420风铃井：100px浅井中的铃，向下发射子弹开门，同时反冲向上；也允许岸边斜向下先开门再单跳过井，不锁定精确帧操作。普通分支保持原稳妥路线。挑战收益复用已有版本化branch_profiles金币/音符预算和领取账本，不新设可重复领取的风铃奖励。非Boss不要求清敌，正式8关与Boss8保持。

教学台整块安全地面；井与门前后有独立安全锚点。敌人编排保护风铃模块，地基保留井和危险包络。角色一跳、260速度、地面0.55反冲与空中爆发不变；不额外给枪、空中次数、无敌或慢时资源。能力不足的同类型兼容布局和服务房不被强迫装挑战井。首关有界空间fallback仍保留地面教学，不能因换保底就悄悄消失。

## 数据与生命周期

唯一布局配置：config/plains_shot_latches.json。新模块为plains_windchime_lesson与plains_windchime_well。PlainsBranchLayout v7 / blueprint v5、PlainsStageGenerator v8-visible-windchime-recoil记录shot_latch_plan，含配置版本、模块/node归属、精确局部铃/门矩形、玩法种类、提示和颜色。布局完全确定，无额外抽样影响地图/奖励流；同Seed及当前版本重放一致。镜像通过实际Definition反射铃/门；正式本轮不把新模块加入随机镜像白名单，候选镜像另有真实物理证据。

GeneratedShotLatchEncounter是实际消费者，安装器由GeneratedDemoStage和完整路线物理测试共用。每个铃复用原ShotLatch的真实PlayerProjectile扫掠命中、HealthState、Damageable和逐发session/Actor/Health/lifetime校验，不用距离或几何连通冒充射击。门实际阻挡、铃layer8不成为额外落脚点。

段回退保留同一个铃/门、开门计数、地图和领取账本；取消旧弹体、待命中和deferred请求。暂停、出口确认和恢复清理动作边界；切关、RunEnd、死亡与离开永久取消该房旧消费者。RunManifest同时验证generated_layout中的plan和shot_latch_layout输出；篡改位置、配置版本或另存输出，即使重算hash也拒绝。

## 证据范围

正式专项tests/plains_shot_latch_runner.gd：295项、0失败。27个动作房候选覆盖3个Seed×第1/3/7关×战斗/金币/道具，记录重放/错误拒绝、常规分支不要求风铃、服务/Boss空计划，后期井后恢复落脚与真实必需反冲升阶。实际DemoApp从默认正式入口生成首铃，真实Motor走到安全站位、真实松手弹体开门，HP未减少；环境伤害保留状态并扣血，暂停/退出取消，完整RunManifest拒绝伪造。

实际路径证据另由generated_latch_trajectory_runner及plains_exit_routes_runner记录：两镜像、两种井解法、小角度偏差和48条完整旧路线都需真实Motor/弹体，无瞬移/删危险/改无损标准。最终计数、构建和公开网页以handoff及验收记录为准，单个专项不能代表全部回归。

手机命中难度、地面反冲学习位置、整体场景趣味性与美术品质仍待用户实际试玩；技术通过不自动代替体验认可。

风铃井保留预先开门后普通跳过井的宽容解法；在原有反冲升阶能力条件满足时，挑战分支仍按“风铃井 → 安全落脚板 → plains_recoil_step”保留真正需要反冲的高度挑战。井不是升阶挑战的替代品。严格校验器检查该顺序，压力链、最多两次反冲模块及40节点预算保持原上限。

升阶保留修复的最终实跑：`tests/plains_ten_generation_runner.gd` 5014项/0失败；48完整路线12359项/0失败；18风铃镜像、两种解法与±0.05rad瞄准扰动轨迹277项/0失败。日志分别为build/verification/d070/generation-recoil-472.log、build/verification/generated-latch-trajectories/full-routes-v7.log、build/verification/generated-latch-trajectories/angles-v7.log。正式风铃专项日志为build/verification/d070/windchime/formal-recoil-472.log（295/0）。这些为实际Godot 4.7.2无界面物理验证，不代替真机手感与性能验收。
