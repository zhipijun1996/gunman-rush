# 正式风铃平原像素演员与机关表现

实施者 `/root/formal_pixel_actors`，同一共享工作树，无独立提交。使用 art-director 与 animation-vfx 的真实消费者、事件只读与证据分离要求。本页是实施/有限技术证据，不代签审美、动画连续画面、独审或真机。

## 接入

`PixelFormalActors.install(stage)` 在正式 Stage ready 后执行，设置 `pixel_formal_style` metadata；替换实际 EnemyMotor 的表现节点、给两个 Boss 和 PlainsStageVisual 显式开启像素风格、刷新已生成 ShotLatch 的附加风铃。重复调用不重复创建敌表现。根负责 Player、正式 Stage/App 接入、地形/场景/背景和宝箱/商人 Sprite 指派。

`PixelFormalActors.icon_texture(kind)` 支持 coin / heart / note（其他音符名回退）/ door / chest / merchant / bell；原创建、拾取、传送、领取、掉落、状态保存代码继续拥有玩法。无外部素材：图标由运行时代码中的像素矩阵生成，演员由原创两世界单位色簇绘制，来源哈希见 sources.json。

## 消费者与信号

- patrol / charger / hopper / sentry / fan_sentry / diver / root_bell：分别有风鸟、冲角、后腿、单/三枪口、飞翼、根铃轮廓。读取实际 Definition 尺寸、行为 state、locked_direction / attack_goal；保留预警、攻击、恢复、命中亮色、死亡及HP表示。
- root_bell：预告固定实际 attack_goal；攻击完整绘制 Definition.pulse_size 矩形包络，恢复仅在真实攻击后留短收束尾，不将被打断的预告画成脉冲。
- Bellstrider：真实位移驱动轮轴，预警弹簧与死亡消隐，核心用 encounter.core_offset，保留滚道/投铃锁点/铃波预告、核心计时与音效事件。
- Windkeeper：四足着地、真实位移步态，预告压身、分阶段塔颈过渡；核心位置直接读取 encounter，阶段2转子读取真实 blade_angle。保留核心射向/计时、符文落台、阶段落点、攻击警告、护甲/受伤反馈、死亡和音效/入场时钟。
- BossArrivalPresentation / BossProjectile / BellstriderBellProjectile / EnemyAttackProjectile / DefeatBurst / BossArenaSeal：仅在正式像素上下文绘制新色簇；保留旧 fixture 默认。原有 windblade / pier 隐形伤害采样体语义不改，实际可见警告仍由 Boss 表现拥有。
- ShotLatch：主铃、顺序第二铃、返程/附加铃、门柱、配对符文均有新绘制；1/2序号、联动目标、计时/运行/停止/开门字样、联动颜色与接受射击逻辑保持。符文颜色不取代原有文字信息。
- PlainsStageVisual：拾取与门、Boss掉落均换新图标；稳定ID、已领取、拾取飞入和门显隐继续由原代码处理。

## 实际检查及边界

`bash tools/godot.sh --headless --path . --script res://build/pixel-formal-actors/probe.gd`：实际生成 intro / advanced 两图并建立 PlainsRegionStage，110 checks / 0 failures，干净日志。检查重复安装、所有实际敌表现、两个真实Boss、拾取层；安装前后 Motor / Actor / HealthState / Definition / CollisionShape 的对象身份与 layer/mask、Manifest 均未改变。不是完整通关或动作/视觉证明。

`python3 tools/run_pixel_plains_tests.py`：原一屏实际 Motor 往返、能力、射击、暂停/重启/退出，19 checks / 0 failures；素材源检查通过。此次新绘制继续满足原 fixture 返回 WindchimeEnemyVisual 的类型合同。

`git diff --check`（上述演员/机关所有修改源）通过。最终干净 probe 及原样复现脚本在本目录；早一次并行检查遇到根线程正在编辑的 parallax parse error，失败日志保留在 build/pixel-formal-actors/probe-final.log，不能因其尾部110/0误报通过。

本实施者未采 GPU 影片或听音，不声称新Boss/敌人所有状态已经过实际像素审查、性能或玩家认可；交给根线程正式合屏和不同作者审查。

## 后续实缺修复：主角受伤/死亡反馈

根线程正式Web观察后发现：旧 PlayerVisualAdapter 已停用、PlayerFeedback 隐藏，而原 PixelPlainsActor 的基类只监听 shot，导致 accepted hurt / death 缺少像素表现。已仅在 PixelPlainsActor 接入真实 HealthState.changed（必须 APPLIED / damage / 负 amount），短闪0.18s；实际 terminal 或 controller.died 显示脚底固定倒地色簇和4个有界短粒点。菜单inactive不是死亡，真实健康重置清除死亡。没有新增声音，沿用原已有音效信号。

实际 Player 场景和 HealthState 事务 probe 12/0（player_feedback_probe.gd/log）：拒绝、回执REPLAY与回血不误闪；实际接受伤害闪、真实terminal与真实reset可辨，Motor位置/CollisionShape身份不变。无注入伪造health结果；测试直接调用真实health事务是显式consumer验证，不冒充正式受击通关。若原死亡流程同帧卸载Player，不能据此声称玩家已经看到了死亡姿势；没有延迟或更改原有死亡流程。实际GPU动态、音频、设备仍未由本实施者验收。
