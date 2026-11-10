# 主角苏醒与贴墙动作

同一Underworld主角母版补绘，原始生成图与完整请求保存在generated/；不是旋转、缩放站姿伪造动作。图集前八帧为趴地、抬头、双手撑地、收膝、跪起、蹲起与站稳，后四帧为抓墙、屈臂承重、攀附与下滑。

`python3 tools/build_player_wake_wall.py`只执行完整分格、统一nearest缩放与整数锚点对齐；原始像素不重绘。build.json记录源哈希、切片、位移及各帧像素哈希。运行图集80×64/帧，站姿46源像素映射44wu；落地基线y58，贴墙最右手脚对齐人物碰撞侧12wu。姿态本身的高度差保留。

正式消费者为PlayerAuthoredPoses，由UnderworldPlayer及其当前默认子类共同绘制。开场时序由WorldIntroSequence拥有；贴墙读取TraversalAbility，不写物理或资源。旧整图旋转苏醒已删除。运动停顿和加速仅由TraversalDefinition与PlayerMotor执行。

正常Godot窗口核对P03苏醒与V12两侧墙面局部动作；专项见tests/player_wake_wall.gd。素材补齐及技术检查不代表安卓真机或整个角色动作集已终审。

上看／下看另有六帧look.png，来源look-source.png及look-request.json。统一1/8 nearest采样，清除生成图alpha<128的外部雾晕，未改不透明RGB；脚底按各帧原图接触点登记。WorldCamera公开已接受查看方向，表现不重新判定输入或移动镜头。进入0.12秒、保持两帧呼吸、松开0.10秒归位；跳跃、移动、瞄准、射击及受伤直接让出姿态。
