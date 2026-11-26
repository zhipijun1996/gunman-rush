# 射击风铃

用玩家弹丸击中铃触发。命中资格、角色生命与会话仍有效时才提交信号。可配置重复切换、限时关闭与同一铃的附加射击点。

一次和限时模式从关闭开始；限时模式使用尝试级状态，激活期间沿原到期时刻运行。反复切换模式可用 `initial_active` 指定初态，期限为零。尝试级信号连接相同挑战分区，同一门的持续开关输入由单个来源驱动。

[完整合同](../失序之钟_基本机关库.md#c01) · [行为与字段合同](../../../production/config/world_elements/behaviors/WorldElementSwitch.json)。输出 active (bool)

[版本和默认参数](../../../production/config/world_elements/definitions/switch.shot.json) · [机关目录](../world_objects.md)
