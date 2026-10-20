# UNDERWORLD-R3 Boss连续战斗合同

用户第11条覆盖正式两Boss旧的仅弱点时窗/方向/符文可伤规则。历史D077/D078/D081窗口资源从0fab13f原字节保留为resources/bosses/legacy，原断言不删除。

正式Boss存活、已启动且非intro时，真实身体/铃芯均可提交同一Health/FrameDamagePolicy；phase_transition仍可伤。core_open继续表示攻击后的恢复姿势/低攻击压力，不再决定攻击权限。身体/铃芯共享actor/epoch/event去重，不独立扣血。

Bellstrider：固定roll→rings→lob顺序，低于半血rings/lob各增加独立延迟的第二击；roll锁方向且有限行程，蓄力标记覆盖完整行程，躲过可在冷却期追击。可射击体140×144 offset(0,-6)，接触危险为独立真实128×110底盘offset(0,10)，高处悬铃不是底盘接触体。

Windkeeper：I地波/冲撞交替，II旋叶/锁定风籽与平台，III断桥三墩按相邻顺序往返。正式过渡预告1.4s后进入下一模式，III从最近已有墩开始真实移动；不再长时间返岸或无限等待玩家上台造成无风险木桩。旧窗口fixture仍3.2s并等待安全。阶段取消旧弹体、风场与符文记录，桥坍塌/安全锚点仍由既有WindkeeperArena消费。完整可射击体150×190 offset(0,-30)，脚底保持motor+65。大Boss整体不是要求基础跳越过的低车，而有明确预警和三平台避让。

公平测试失败保留：连续战斗third/fourth各96项中95通过，Bell整hurt体/起跳时机分别无法避开。真实逐帧定位后采用分离底盘及提前4tick跳跃，未调Player物理/HP/资源/伤害。roll_diagnostic_timing68实测8/0，原地不躲受伤，真正Router满跳+反向移动跨过roll不受伤。

每Boss完整驾驶使用capture_underworld_r3_boss_fight.gd：实际DemoApp启动，唯开场房间定位setup；不改HP/phase、不停AI、不注入资源、不使用中途传送，真正Router/Motor/弹体/资源/封门和奖励。headless不是GPU/玩家趣味验收。完整金奖、同帧死亡、旧token与迟到弹体另测，不能以单场胜利代替反例。
