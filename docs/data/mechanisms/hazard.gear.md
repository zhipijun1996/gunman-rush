# 移动齿轮

直线模式沿中心两侧的半程移动，圆弧模式绕可见支点在两个角度之间摆动。两端可独立于移动时长停顿。齿轮通过 `drive_id` 共享运动所有者的时间，也可用自己的时钟。暂停时齿面仍按真实位置造成接触伤害。

直线轨道的两端有区域轴座，圆弧支架随齿轮绕固定支点摆动。轮毂、轨面和端部按当前房间选材，外齿采用原生磨坊齿轮贴图。

[行为与字段合同](../../../production/config/world_elements/behaviors/WorldElementGear.json)。输入 set_active (bool)

[版本和默认参数](../../../production/config/world_elements/definitions/hazard.gear.json) · [机关目录](../world_objects.md)
