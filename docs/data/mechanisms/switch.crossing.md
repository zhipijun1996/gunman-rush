# G15 通过感应器

线段的两个端点使用局部坐标。角色碰撞中心跨过实际线段后，`once` 输出开启，`toggle` 翻转布尔输出。方向按线段从首端到末端的右法向计算。端点标出受理范围，虚线标出连到的机关。

检测沿连续物理步扫过的路径。停在线上时保留来向，完整身体脱离后才能再次触发。重新定位和闪移会按目的地重新建立侧别。门遇到占用时保留当前形态，待安全时接受信号。该件使用尝试级状态，可在全部区域实例化。

[定义与默认参数](../../../production/config/world_elements/definitions/switch.crossing.json) · [行为与端口](../../../production/config/world_elements/behaviors/WorldCrossingSensor.json) · [完整合同](../失序之钟_基本机关库.md#g15)
