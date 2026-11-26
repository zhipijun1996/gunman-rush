# 环境区域

在矩形内实例化环境效果，mode 决定气体、暗区、水等表现及响应。需要服务、真实控制器和伤害策略作为宿主参数。

C10 风场在角色腾空、可自由位移时按物理步向 PlayerMotor 累加独立风速，`wind_speed_cap` 限制风速分量。定向模式沿归一化的 `wind_direction` 加速；涡旋模式采用正方形内切圆，在圆内按 `vortex_direction` 的切向加速，圆心无风。脚底支撑、W 附墙或 H 挂载时清空该风速，离开风场后按现有运动衰减。

[行为与字段合同](../../../production/config/world_elements/behaviors/array_environment_zones.json)

[版本和默认参数](../../../production/config/world_elements/definitions/zone.environment.json) · [机关目录](../world_objects.md)
