# G30 可控水位

布尔真请求高水位，假请求低水位。水面从实际位置按设定速度趋近最新目标。绘制和正式 water 危险体积在同次物理步更新。多个浮台可同时引用同一水源，载台顶夹会留下可见高度差，畅通后按相同速度逐步追上。

水尺和两岸以本区材料固定在盆地上。浮标指向当前实际水面。水纹、泡沫、分区光色的反射与进入水中的浮台湿线同步升降，两个档位共用一套表现。

[定义与可配参数](../../../production/config/world_elements/definitions/zone.water_level.json) · [行为合同](../../../production/config/world_elements/behaviors/WorldWaterLevel.json) · [设计定稿](../失序之钟_基本机关库.md#g30) · [真实角色验证](../../../production/tests/carrier_library.gd)
