# 附着尖刺

把有朝向的危险边贴到支撑实体。设置 host_id 时会核对接触面；贴图和伤害应沿同一段 bounds。上下左右四种朝向均以同一段危险包络裁切贴图，根部只在支撑实体内绘制。

尖刺按根部接触的地形材质选择外观，局部涂层参与选择。可用 `appearance` 为实例指定已登记的样式；未登记专用样式的地形使用[外观配置](../../../production/config/surface_styles.json)中的通用岩刺。

[行为与字段合同](../../../production/config/world_elements/behaviors/array_spike_strips.json)

[版本和默认参数](../../../production/config/world_elements/definitions/hazard.spikes.json) · [机关目录](../world_objects.md)
