# PLAYER-PRESENTATION-01 当前交接

目标：正式主角苏醒、贴墙和上下查看补帧，以及短暂停住后逐渐加速的贴墙下滑。

当前分支`fix/stargate-contact-route`，沿已授权工作台分支`feat/world-review-stargate`接续；没有修改房间布局、基础跳跃或反冲参数。进度由[任务表](../../tasks.md)维护。

## 当前实现

- 同一Underworld主角母版新增18张真实姿势：苏醒8帧、抓墙／攀附／下滑4帧、上看／下看各3帧。源图、请求、锚点与像素哈希在[素材目录](../../../../assets/player_presentation_01/wake_wall/README.md)，现有旋转站姿苏醒已删除。
- WorldIntroSequence拥有苏醒流程，PlayerAuthoredPoses只绘制。暂停冻结、角色epoch变化／受伤／死亡／回退取消旧姿态，脚底保持同一地面。默认角色与classic配置共同消费。
- TraversalDefinition配置0.18秒停顿及2秒二次曲线加速，原75wu/s上限保留。上升动量保留，开始下落时计停顿；同墙射击取消不刷新停顿，离墙或换墙沿原接触收据重置。PlayerMotor仍为唯一运动执行者，补弹及D/H/Q规则不变。
- 查看动作读取WorldCamera已接受方向，沿现有左杆／键盘输入优先级与区域许可，不因向上瞄准误播。站立进入与保持有专用补帧，松开短暂归位，其他动作优先。

## 检查与边界

`tests/player_wake_wall.gd`使用正式P03与真实Motor碰撞，覆盖苏醒关键帧、对白／拾枪前禁射、暂停、epoch取消、上下查看及瞄准反例、左右贴墙停顿和加速、同墙取消不重置、墙跳响应。`tests/traversal_resource_refill.gd`验证17项原能力恢复规则。正常Godot窗口检查P03地面接触、上下查看与V12两侧墙面局部动作。

发布版本与手机入口归[工作台交接](../mobile_level_workbench_01/scope.md)。素材与局部控制器检查不代表安卓真机、所有角色动作或全主线已经终审；新手段正常游戏不开W，贴墙在已有W的隔离V12夹具验证。

## 后续

在同一工作台版本按P03检查苏醒与查看，按V12/HWDQ检查贴墙下滑。具体调整写回既有[能力合同](../../../data/abilities.md)和配置，不保留并行参数方案。
