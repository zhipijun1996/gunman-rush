# 平原起步区的邻房接收段

v29 在三个正式房的另一侧设置五处接收段。角色在各门台落稳后可沿同一门返回。下表使用接收段本地坐标，井口的出生点为站稳时的角色中心。

| 邻房 | 连接 | 落脚与返回 |
| --- | --- | --- |
| F08 | P01 西门 d223 | 林侧东门面 x=600，脚面 y=1140。门闩在 F08 一侧，开栅后两侧共享通行状态。 |
| P04 | P03 西上门 d003 | 旧路东门面 x=2070，脚面 y=573。 |
| P13 | P03 东门 d017 | 岩脊西门面 x=0，脚面 y=468。 |
| P16 | P02 西草径 d009 | 下落至 [495,60]，原地起跳返回。 |
| P19 | P02 东井 d330 | 下落至 [360,60]，原地起跳返回。 |

五个门台的实际地形与区域材质见[接收段文档](../../../production/rooms/world/receivers)。旧版沟谷远墙、P13 的拼接方法与原始坐标随 [v27 制作记录](https://github.com/zhipijun1996/gunman-rush/blob/24e5957206d3e966e7c7a9e98ce4982fb28c2a8b/art/rooms/plains_intro/README.md)保存。

## 林缘栅门

d223 两侧共用栅门。四根错高立木及两根横档来自平原风铃门柱，铰件与横闩取自鸣钟闸图集，苔根裁自森林倒木。开门后木桩留在原位，门扇转向侧面。[木料原图](../../../production/assets/plains_v3/windchime_gate_beam.png) · [铰件原图](../../../production/assets/mechanisms/bell_gate/bell_gate.png) · [苔根原图](../../../production/assets/world_elements/forest_stage/thorn_forest_v2_thorn_log.png)

[门桩](../../../production/rooms/world/p02_connections/forest_gate_post.png) · [门扇](../../../production/rooms/world/p02_connections/forest_gate_leaf.png) · [绘制、互动与碰撞](../../../production/rooms/world/world_shortcut_gate.gd)

## v29 实机评审

P01、P02、P03 的整图按正式世界单位逐像素输出。触控短片分别记录起身拾枪与高台宝箱、钟台与草间隐径、上下折返的真实路线。[三房成片与构图复现](v29/README.md)
