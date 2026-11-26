# G02 可击碎障碍

整块和逐格模式复用攻击包身份与保存事务。挖掘只扣除与首个实际接触圆相交的现存格；写入成功后同时更新支撑、碰撞与裂纹。

[参数与模式合同](../失序之钟_基本机关库.md#g02) · [实例定义](../../../production/config/world_elements/definitions/terrain.breakable.json) · [行为与端口](../../../production/config/world_elements/behaviors/BreakableTerrain.json)

每块现存地形按本区材面铺设，裂隙随剩余耐久加深。损伤实际提交后，受击格冒出冲击碎屑，移除的格子扬尘。 [像素部件来源](../../../art/mechanisms/projectile-library/sources.json)

[可玩验收房](../../../production/tests/projectile_library_demo.tscn) · [Godot 回归](../../../production/tests/projectile_library.gd)
