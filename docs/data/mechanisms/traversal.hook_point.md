# 固定钩索点

放置共享钩点的便捷定义。一个房间可放置多个独立位置；移动点位后应复验射向、到达的落脚面和离钩恢复。

固定点实例化可悬挂的[钩索锚点](traversal.hook.md)，共用所在区域的悬挂贴图。

C07 固定为停留型，与 C06 共用离钩冷却、初始资格、复明预告及挑战恢复。普通房 JSON 和 PackedScene 均保留实例字段；历史位置数组沿原索引装配。新房间使用独立实例 ID 配置位置与冷却。

[行为与字段合同](../../../production/config/world_elements/behaviors/array_hook_points.json)

[版本和默认参数](../../../production/config/world_elements/definitions/traversal.hook_point.json) · [机关目录](../world_objects.md)
