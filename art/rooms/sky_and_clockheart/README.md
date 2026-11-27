# 碎空群岛、天门与世界钟心

下文记录 v27 的关卡构图与验证。请在[冻结版本](https://github.com/zhipijun1996/gunman-rush/tree/24e5957206d3e966e7c7a9e98ce4982fb28c2a8b)复现旧房；区域像素母库和角色、机关素材继续供重做使用。

A01–A11、V01–V13、Z01–Z11 的舞台使用对应区域的原生背景、地标与独立附件。来源位于 [16 区像素原包](../../world-art-v2/assets/pixel) 和 [区域扩包](../../world-art-v2/assets/pixel/v2)。每房数据里的 scenery.pieces 给出贴地锚点，terrain.polygon 给出实际地面，platform.one_way 的上沿与可穿越碰撞一致。悬岛截面、星桥桁架和钟心撑梁各有一张透明像素件，按承重面宽度拼接。

- [碎空群岛运行素材](../../../production/assets/scenery/shattered_isles)与[东风巢台](https://github.com/zhipijun1996/gunman-rush/blob/24e5957206d3e966e7c7a9e98ce4982fb28c2a8b/production/rooms/world/A11.json)
- [天门运行素材](../../../production/assets/scenery/starbridge_gate)与[星轨校时庭](https://github.com/zhipijun1996/gunman-rush/blob/24e5957206d3e966e7c7a9e98ce4982fb28c2a8b/production/rooms/world/V08.json)
- [世界钟心运行素材](../../../production/assets/scenery/clockheart)与[校时机组房](https://github.com/zhipijun1996/gunman-rush/blob/24e5957206d3e966e7c7a9e98ce4982fb28c2a8b/production/rooms/world/Z06.json)

巡风鸟和星轨守门者使用独立机身、警示轨迹和可反击的停顿。[首领图](../../../production/assets/bosses/sky) · [两间正式战场的回归](https://github.com/zhipijun1996/gunman-rush/blob/24e5957206d3e966e7c7a9e98ce4982fb28c2a8b/production/tests/sky_world_trials.gd)
