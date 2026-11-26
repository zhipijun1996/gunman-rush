# G23 滞弹雾

矩形边界决定弹体中心的进出。在一步内按边界重算剩余时间，重叠区域取最低倍率。角色与弹体寿命使用各自时钟。

[参数与模式合同](../失序之钟_基本机关库.md#g23) · [实例定义](../../../production/config/world_elements/definitions/zone.projectile_drag.json) · [行为与端口](../../../production/config/world_elements/behaviors/ProjectileDrag.json)

两侧区域基座上的光学喷口标记雾带下沿；分层流动的冷色雾丝沿房间给出的矩形铺展。 [像素部件来源](../../../art/mechanisms/projectile-library/sources.json)

[可玩验收房](../../../production/tests/projectile_library_demo.tscn) · [Godot 回归](../../../production/tests/projectile_library.gd)
