# 砌体机关门

门闭合时提供实体碰撞。接收开启信号后隐藏门体并放开通行；关门前检查玩家是否占用门区。恢复已开启状态时保持通路畅通。

`appearance` 默认为 `inherit`，从所属区域清单的 `gate.masonry.material` 选择门体的 TileSet。实例可显式指定注册材质。未指定区域时使用磨坊砌体。开关状态、端口和碰撞尺寸由同一行为持有。

信号门由输入控制。房内单向门按左、右、上、下标出允许进入的一侧，玩家全身离开后按配置延迟关闭。对侧可连接独立开门机关。关门时使用门体与玩家实际碰撞形状检查占用。限时风铃等待可安全关闭后一起释放，允许玩家留在门中再离开。

[完整合同](../失序之钟_基本机关库.md#c02) · [行为与字段合同](../../../production/config/world_elements/behaviors/WorldElementGate.json)。输入 set_active (bool)

[版本和默认参数](../../../production/config/world_elements/definitions/gate.masonry.json) · [机关目录](../world_objects.md)
