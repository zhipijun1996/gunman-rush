# C15 风铃与机关门

一次放置会生成 `bell`、`gate` 两个子实例和一条布尔连线。默认 `once` 永久开路。`timed` 由风铃掌握到期时刻，门内有人时延迟关闭，通路清空后恢复，下一次射击可再次开门。

从作者 API 指定预组原点和创建参数。下面的配置生成一个三秒窗口，门的局部边界随成员偏移只平移一次。

```gdscript
var placed := WorldElementCatalog.instantiate_definition(
    "assembly.bell_gate", "shutter", Vector2(368,360), "gear_city",
    {"mode":"timed", "member_offsets":{"gate":[96,-104]}}
)
```

`mode` 推导两个成员的状态寿命。`bell.duration` 可覆盖限时时长，`gate.bounds` 可指定局部矩形，`section_id` 绑定房内挑战分区。房间保存展开的实际值、稳定 ID、连线及来源版本。已经放置的第一版保留原来的 `switch` 子 ID 和布局；新版新放置的铃使用 `bell`。

[定义及开放参数](../../../production/config/world_elements/definitions/assembly.bell_gate.json) · [射击风铃](switch.shot.md) · [砌体门](gate.masonry.md) · [限时试玩](../../../production/tests/bell_gate_demo.tscn)

铃与门共享黄铜受光色。中弹后的摆铃和声纹对应开门，洞口右侧的六格灯显示限时门剩余时间。角色留在洞口时，灯熄后空门框继续表示可通行。 [美术来源](../../../art/mechanisms/bell_gate/sources.json)

预组继承铃和门所在房间的区域外观。两地相同的射击位置、通道宽度和倒计时中，挂架、门体与受力方式可以不同。
