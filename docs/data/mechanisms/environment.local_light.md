# G27 局部灯台与引路灯虫

固定灯台和移动灯虫按同一距离衰减、实体遮挡和最大值叠加规则供暗区和花盘采样。灯虫模式的灯囊固定在起点，可见圆壳对应真实射击部位。启用且待发时射击后沿局部路线前进，各路点可停留，末端可折返或停靠。停用时熄灭并保持位置与剩余停留。本条目的时钟随当前挑战推进。

固定灯使用本区灯具，发光部位与采样中心重合。引路模式中，原地灯囊指示射击位置，离巢后的灯虫指示实际光源。区域 `instrument_atlas` 的前四格依次为灯虫、合拢花盘、展开花盘和灯囊；第五格可指定独立固定灯。荆棘森林保留四格原画及金属灯座。 [区域原图与裁切](../../../art/mechanisms/regional-perception/provenance.json)

[版本与参数](../../../production/config/world_elements/definitions/environment.local_light.json) · [字段和端口](../../../production/config/world_elements/behaviors/WorldLocalLight.json) · [设计合同](../失序之钟_基本机关库.md#g27)
