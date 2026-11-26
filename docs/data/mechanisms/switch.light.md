# G33 感光花盘

花盘读取所选灯台、灯虫和装备灯的照度。连续达标后输出开启，连续失光超过保持时间后输出关闭。中心亮度表示当前照度，花瓣表示受光进度，外圈提示目标仍在等待。灯源的整条潜在路线和可控实体遮挡参与控制环路校验。装备灯须在正式休息站装配，其范围取自[灯光配置](../../../production/config/equipment_lamp.json)。

闭合花苞与展开花盘共用一个根部锚点。花芯亮度随采样照度变化；花脚的金、蓝镶片分别标记局部灯和装备灯，等待下游受理时花头保留琥珀色弧光。区域可替换 `instrument_atlas`。区域图集保持同一采样中心和根部位置，冰镜以冰晶片旋展，工城以阀盘部件开合。 [区域原图与裁切](../../../art/mechanisms/regional-perception/provenance.json)

[版本与参数](../../../production/config/world_elements/definitions/switch.light.json) · [字段和端口](../../../production/config/world_elements/behaviors/WorldLightFlower.json) · [设计合同](../失序之钟_基本机关库.md#g33)
