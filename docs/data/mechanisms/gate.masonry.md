# 砌体机关门

门闭合时提供实体碰撞。接收开启信号后隐藏门体并放开通行；关门前检查玩家是否占用门区。恢复已开启状态时保持通路畅通。

`appearance` 默认为 `inherit`，从所属区域清单的 `gate.masonry.material` 选择门体的 TileSet。实例可显式指定注册材质。未指定区域时使用磨坊砌体。开关状态、端口和碰撞尺寸由同一行为持有。

[行为与字段合同](../../../production/config/world_elements/behaviors/WorldElementGate.json)。输入 set_active (bool)

[版本和默认参数](../../../production/config/world_elements/definitions/gate.masonry.json) · [机关目录](../world_objects.md)
