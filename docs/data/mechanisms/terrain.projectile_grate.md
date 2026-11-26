# G28 可射穿栅栏

角色、货箱和喷流使用同一个实体矩形；普通飞行弹跳过此栅栏，保留随后最近的真实接触。

[参数与模式合同](../失序之钟_基本机关库.md#g28) · [实例定义](../../../production/config/world_elements/definitions/terrain.projectile_grate.json) · [行为与端口](../../../production/config/world_elements/behaviors/ProjectileGrate.json)

锻铁栅条保留两端的尖饰与接缝；区域横梁和铆座连接栅条，杆件数量及分隔随实例宽高调整。 [像素部件来源](../../../art/mechanisms/projectile-library/sources.json)

[可玩验收房](../../../production/tests/projectile_library_demo.tscn) · [Godot 回归](../../../production/tests/projectile_library.gd)
