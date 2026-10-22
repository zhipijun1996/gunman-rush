# 武器 VFX 第二版只读绘制合同

用户本轮要求回旋镖高速返回应能看到刃体、激光应有离子炮特征、坍缩奇点应像黑洞，并加强爆炸。采用 animation-vfx。实现为新增 `scripts/dev/player_presentation_01/weapon_vfx_v2.gd`，不改已有图像、shared style 或旧录制绑定。父线负责接入新的 V2 消费者和 Runtime 可选 presentation 槽；没有活跃槽时旧绘制保持原消费者行为。

`PlayerWeaponVfxV2` 是实际 actor 子树中的只读叶：绑定已有 `WeaponActionRuntime` / `PlayerController` 与 `opacity`；读取实际 beam segment、phase / age、原 `_fx` 和 Definition。没有 raycast、碰撞、伤害、资源、RNG、time_scale、位移写入或新增 gameplay timer。唯一缓存是从原 `weapon_catalog.json` 读取 region2 的原回旋刃 AtlasTexture；同一纹理持续持有，避免临时 GPU 资源。每次 draw 直接生成有界图元，不创建粒子节点。

## 表现时间轴与边界

- 普攻激光：沿实际可见枪口至 accepted 物理端点，暗轮廓／青色能量通道／两像素亮芯、9枚确定性行进能量包。端部短火花只在实际端点短于射程时画；射程落空不画假命中。保留既有实际枪口，由已存在 Runtime 负责结束／取消。
- 离子炮技能：只消费原 skill beam `_fx`，持续其原0.3秒淡出，不制造额外弹道或延后命中。炮束较宽但不满屏白闪。
- 手动回旋镖返回：真实玩法仍是 accepted tick 中原 sweep / caught。新增 `return_blade` 视觉 echo 在0.14秒内沿实际 start→end 快速运动，复用原36wu刃体并旋转，附两层低透明短距刃影和最多32wu局部短尾。绝不画整段蓝线，不把视觉回程插值当成新的物理飞行。原 `_fx` 可保留0.3秒供 OFF 旧表现，但新叶在 age>=0.14 即停止画该 echo。
- 奇点蓄积：实际 `_center` 上的暗事件视界放在固定背景 CanvasItem，absolute z 为 motor.z_index-1，实际 hero 因而画在暗核之前。主叶画3条细椭圆吸积带、18枚向内旋转的确定性粒子和4段潮汐弧；大引力半径只有低透明边缘，不用大面积不透明圆盖住场景。实际发射方向标保留。
- 奇点坍缩：原 blast `_fx` 改用18枚向内碎片、3条薄椭圆透镜波和0.1秒短亮边，不复用炸弹橙色火团；不改变原伤害半径。
- 爆炸：原 blast 点／半径上画8瓣紧凑火焰、16根短余烬、8段薄冲击前沿及6团淡烟；最亮核心仅0.09秒。主要火团保持在真实半径内部，外前沿对应原半径，没有新增全屏闪光／震动。

节点生命周期为每消费者一个 presenter 加一个固定 EventHorizonBehindHero CanvasItem；没有每帧节点分配。子树遵循原暂停；隐藏／卸载后没有独立持久粒子或计时器。beam9、return3、singularity18、blast16 为各自固定图元数，原 Runtime `_fx` 生命周期仍由原玩法负责。V2 owner 清理与 OFF 恢复测试由父线验证。

## 已执行与待验

执行 `bash tools/godot.sh --headless --path . --check-only --script scripts/dev/player_presentation_01/weapon_vfx_v2.gd`，退出0，日志 `build/player_presentation_01/weapon-v2/vfx-parse-first.log`。亲自查看原 `weapon_families.png`，region2 确为原金／白／青色回旋刃，非另造武器外形。

以上只是接入接口和解析检查，不签实际GPU可读性、常速动作、事件帧同步、用户审美、听感、性能或实体设备。正式真实 Home / Plains 带声连续采证与独审由父线在统一冻结版本后执行。失败条件包括：回程只剩线条、鬼影超出实际返回段、暗核盖住 hero、束端越过实际碰撞点、切换后旧 fx 残留或任何玩法轨迹差异。
