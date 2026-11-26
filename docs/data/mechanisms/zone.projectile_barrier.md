# G24 消弹薄幕

布尔输入切换弹幕拦截。角色可穿行；匹配阵营的弹体在有限薄幕的表面消散，边界、两端与内部生成共用扫掠几何。

[参数与模式合同](../失序之钟_基本机关库.md#g24) · [实例定义](../../../production/config/world_elements/definitions/zone.projectile_barrier.json) · [行为与端口](../../../production/config/world_elements/behaviors/ProjectileBarrier.json)

两端区域构件承托相向的发射头，亮起的帘束沿整条有效线段展开。停用时镜头熄暗，弹体消散只在真实接触点闪光。 [像素部件来源](../../../art/mechanisms/projectile-library/sources.json)

[可玩验收房](../../../production/tests/projectile_library_demo.tscn) · [Godot 回归](../../../production/tests/projectile_library.gd)
