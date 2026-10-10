# 十六场景画风审核 v1

本轮只制作待审核画风示意，用户确认前不将图片作为批准风格输入，不扩展正式素材生产。统一精细gouache手绘钟械童话；上部场景含平台，下部展示材质/平台族概念。固定十六个候选区与世界锚点一致，不开放运行地区。

审核画册：[浏览器样板](../preview/biome_style_review.html)。HTTP打开，点图查看原图；可逐项记录意见并导出JSON。仅本地浏览器草稿，不自动更新仓库。

| 编号 | 场景 | 核心特色 | 原图 |
| --- | --- | --- | --- |
| 01 | 风铃平原 | 嫩绿草甸、木桥、风车、风铃花与柔和阳光 | [查看](../assets/biome_style_review/windchime_plains.png) |
| 02 | 荆棘森林 | 巨树、藤蔓、被吞没的皇家花园 | [查看](../assets/biome_style_review/thorn_forest.png) |
| 03 | 萤雾沼泽 | 蓝绿薄雾、荷叶、木桩与漂流灯笼 | [查看](../assets/biome_style_review/firefly_marsh.png) |
| 04 | 风蚀峡谷 | 暖色砂岩、吊桥、散落商队货物 | [查看](../assets/biome_style_review/windswept_canyon.png) |
| 05 | 蕈灯地穴 | 蓝紫发光菌群、柔软地下洞穴 | [查看](../assets/biome_style_review/mushroom_caverns.png) |
| 06 | 沉水遗迹 | 青蓝水体、苔藓石柱与旧符号 | [查看](../assets/biome_style_review/sunken_ruins.png) |
| 07 | 齿轮工城 | 黄铜、管道、齿轮与无人车间 | [查看](../assets/biome_style_review/gear_city.png) |
| 08 | 月冠古堡 | 蓝紫月光、破损阳台、吊灯与空王座 | [查看](../assets/biome_style_review/moon_crown_castle.png) |
| 09 | 月影墓园 | 冷色月光、墓碑、幽灵与柔雾 | [查看](../assets/biome_style_review/moonshadow_cemetery.png) |
| 10 | 霜镜冰川 | 冰蓝悬崖、极光与冻结城镇 | [查看](../assets/biome_style_review/frostmirror_glacier.png) |
| 11 | 熔火腹地 | 橙红熔岩、玄武岩与失控熔炉 | [查看](../assets/biome_style_review/ember_depths.png) |
| 12 | 破碎浮岛 | 云海、紫蓝天空、残存空中花园 | [查看](../assets/biome_style_review/shattered_isles.png) |
| 13 | 根脉圣殿 | 巨型树根、生命光点与自然祭坛 | [查看](../assets/biome_style_review/root_sanctuary.png) |
| 14 | 逆时钟塔 | 钟针、摆锤、巨大齿轮与时间残影 | [查看](../assets/biome_style_review/reverse_clocktower.png) |
| 15 | 星桥天门 | 星空、悬桥、天文环与光路 | [查看](../assets/biome_style_review/starbridge_gate.png) |
| 16 | 世界钟心 | 巨钟内部与本局经过地区的残影 | [查看](../assets/biome_style_review/world_clockheart.png) |

## 审核标准与未来输入

每区审核：配色/光线、笔触精美度、核心地标辨识度、平台落脚边可读性。可用“01认可、02森林更茂密、11火山再冷暗一些”反馈。默认全部pending_user_review；manifest中approved_as_generation_input=false。

认可后才记录具体图像SHA/版本/用户意见，再以统一母风格+对应地区批准图作为image_gen参考。局部修改生成v2，保留v1原图和来源；不能让重新生成的图自动继承批准。批准画风不等于批准机制、剧情身份、路线数量或最终瓦片。

随机地图后续素材拆分：背景远中近层、平台左端/可重复中段/右端、支撑填充、转角与独立机制。统一连接高度、笔触密度、材质比例；碰撞/端口/相位由代码契约定义。当前样本的接缝、透明边、尺寸和物理可达性未验证，不能从示意图直接提取碰撞或声称无缝拼接。

源PNG原样保存；generation.json含完整提示词与来源，manifest含尺寸/hash/审核状态。样板截图为浏览器排版展示；不改源图像素。参考家园画作只代表当前候选手绘质量，不视为此前已获用户批准。
