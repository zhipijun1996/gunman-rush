# SPATIAL-RHYTHM-07 独立局部构图与源码复核

2026-10-23；独立审查者density_art_review。本代理没有实施本任务landmark sequence、parallax、Shader或采集代码，只读取实际PNG、生产源码与capture记录；仅写本报告，不跑引擎/CI、不改生产文件。

## 阶段判断

**所看局部的疏密变化与主次关系，比DEPTH-FRAME-06有实质改善，可作为新方向候选。** 已从满屏并列大塔/风车，转成单组地标与真实空窗：出生点有一组风车，junction移到左侧，高点可看到钟塔，两个low窗口没有大型地标。角色周围的天空与低坡留白更多，家园焦点归还人物和暖色建筑。此结论仅签局部AI构图观察，不代签用户认为好看、不签全区或完整动态。

## 实际看图范围

实际用view_image original打开final目录11张1280×720图：home、home_east；s0_m1_spawn/low/high/junction；s0_m2_spawn/low/high；s2_m1_spawn；s2_m2_junction。此前本代理已实际看06相同Home/Plains镜头，及本任务quick_r2同名两图。final其余19张未逐图审，不把30张采集完成称30张视觉通过。

读取final/capture.json：任务SPATIAL-RHYTHM-07，30条定位静图、failures=[]、scope为real formal App positioned stills，不是human traversal/motion/device/art acceptance。记录local_landmarks与实图对应：s0_m1_spawn风车world_cell0；junction仍同一anchor=-1310、从屏中移至左侧；s0_m1_high钟塔world_cell2；两个low为空数组。另Seed的出生点仍使用风车组，但位置略不同，符合目前“路线顺序固定，Seed轻偏移”的设计，不能称每Seed有全新景观内容。

## 局部观察

- **疏密**：出生点只留一主风车组，不再用巨钟塔压在主角背后；junction与高点的地标偏向边侧。low以低草坡和旧树铃剪影为主，有真正无大地标的镜头，明显回应“中景过多喧宾夺主”。
- **Home**：最终小风车比quick上移后，风叶/主体可见；正常Home仍被右侧树与平台遮住一部分，但作为背景配角合理。东端可完整读出风车组，未重新压过出发门或人物。原quick“几乎藏地里”不当成final结果。
- **根部/边界**：所看组底被连续坡面和前层地面遮接，未见明显悬浮矩形、硬竖切边、断塔尖或切断主风叶。没有把真落差两岸连接成假道路。侧肩边缘局部有偏白雾化，但当前静图尚不构成明显硬接缝。
- **可读性**：暖红角色、敌人和金色铜铃仍优先可辨，前景侧枝存在但所看图没有直接盖住关键主体/落点/HUD。背景低坡本身纹理仍偏密，尤其low/高点下半屏；大地标减少不等于整个中景已安静精致。

## 源码连续性与UV核对

完整读取新增underworld_landmark_sequence.gd、UnderworldParallax与edge shader变更。实际查看原landmark_ridge_r2.png确认当前风车crop[0,180,660,761]、钟塔crop[700,180,440,761]保留主要叶片、塔尖与台地根肩；不以原图漂亮替代上述实机判断。

- 世界anchor由anchor_offset+index*4000及seed/index字符串hash偏移决定，位置用(anchor-center.x)*.24计算，无camera-zone透明度切换。回到相同seed/center/viewport，应得到同组与同位置；整数round最多产生1px阶步。这是确定性源码判断，尚未由实际回程影片核验。
- 视域查询nearest±5只是找候选；sprite仅在完整bounds进入viewport时显示，没有在组主体仍位于屏中时按camera分区切换opacity的明显逻辑。实际屏边进出连续性与微跳仍需运动观察。
- region_enabled使用原完整纹理，source_region按该纹理尺寸归一化。shader将UV限制在选定crop内部半texel，local_x也以crop局部坐标计算fade，避免把整张atlas的边当单组边；共享全图planes保留默认source_region=(0,0,1,1)。未发现明显Atlas UV分母或偏移错误。
- 渐隐只作用两侧肩，不是整组随相机变透明；连续meadow后绘，负责遮接底部。Home只保留index1风车，宽缩至.82，bottom_ratio单独.92；普通地标底为1.03。以上是当前实现条件，不外推所有源crop或尺寸。

## 残留与未验

1. 真实“前进时不断变化”的时间体验尚未成立证据：现有间距交替8000/12000wu，相当于地标锚屏距约1920/2880px。静图证明有空窗，但不能证明正常行走速度下空窗长度舒适；仍可能出现较长的同质草坡段。需要实际旅程看片，不能用有两类地标和有空窗的计数代签节奏。
2. 地标仍只来自同一风车/钟塔母版，跨地图/Seed相近。低坡草纹/树丛密度、地标侧肩局部白雾化也需要连续镜头观察。当前应优先验证观看顺序，不建议再加满地标来掩盖这个限制。
3. 未验证实际回程的相位/边界、全屏宽高与所有纵向镜头、云/层拼接在采样之间的状态、前景hard-hide跳变、危险/射击时遮挡、真实输入路线、音轨、Web或设备表现。未看完整影片，不称完整运动通过。森林不属于本轮成功样板，不因平原减密解决原森林承载语言问题。

## 证据字节绑定

审查时HEAD：`f554e6bbea6c4f7282ed762a4880a92cae4e7918`；当前未提交源以以下完整字节为准。

| 本次源码/记录 | SHA256 |
| --- | --- |
| scripts/underworld_plains/underworld_landmark_sequence.gd | `83724df75f96fce32380f8635311c6e1b98f691afcbc5dd27d9c60dd8cfb5621` |
| scripts/underworld_plains/underworld_parallax.gd | `377da72f14dcbabdc9c35ed9eee70fbf096212e0271b47b2ae39ca24300c9853` |
| scripts/underworld_plains/underworld_parallax_edge.gdshader | `618e9e58a24e6f0b1962e092fa9b0c647f61c0ea2ee4c4eb2f3c139ef83fd251` |
| assets/underworld_plains/scenery_build.json | `305813daf77f22cfa3873daf55eb82a449c6fe956a40ac42855eac4f702705de` |
| assets/underworld_plains/backgrounds/spatial_rhythm_07/quiet_meadow.png | `b1a45ca95353cc56a533d877a1055fb6dd6a1380fc8a284a3f7dac9905c6545e` |
| assets/underworld_plains/backgrounds/depth_frame_06/landmark_ridge_r2.png | `29c0812af64de5cf1299cecb7e8810d93bfd435b099a1434bca0cd12e475fc29` |
| build/spatial_rhythm_07/final/capture.json | `a3667bfec3d0e8f84a0e3ba19eac8613859c15674f237f3a5f757e272e24f8bc` |

| 实际观看final图 | SHA256 |
| --- | --- |
| home.png | `bdb072ccedf81a826f6b895acd196dfc7cb9831b0e0acf3944bc93517cdddaae` |
| home_east.png | `a93da40c30aed64ba90bcc02c64f7ee7071e89ba0fe3e1105c7747fc238ed39c` |
| s0_m1_spawn.png | `eb0a237c3c1b376412fc72c242e69cb346322ed7db9c38eb57f0ba6962355ef6` |
| s0_m1_low.png | `c873a9468ea4af79e1e2e8a13a381f953a9d4e312bd046b1e9b8399a426fe983` |
| s0_m1_high.png | `bf1df8d5971960c89fb8197991cc17bb6800d736e3a38ad78eae03f13284e3ad` |
| s0_m1_junction.png | `dd63f4dfb311c77c1e4ee3dd109031bac63389aebb233d2907e7ee933603d7ba` |
| s0_m2_spawn.png | `c6d6b5ea7a86be3946b30cd48ecf429f08203e6a49a4031c43582310cfa4e8e7` |
| s0_m2_low.png | `530023f9285b0119878582ba7df8c4cb07bb09bf8b7f9977277d61a1e1870510` |
| s0_m2_high.png | `8470357f9ee746f36ea7707e41eb5052cf4717f0aca800c7f25b2857cdbbb363` |
| s2_m1_spawn.png | `84dce7a77f69bd30032862e3f96b4c0dad367c25ea15ff7fd518b7629a2613f1` |
| s2_m2_junction.png | `bb8132d2cefb0244ab510fd41762d3dbe4bead1b6c4a75012038e0d31d08e9f0` |

本代理的范围结论为：局部疏密/主次改善、当前裁切和UV源码未见明显错误；实际连续节奏、全区、用户及设备仍UNVERIFIED。没有运行engine，不将生产者空failures当作本代理重跑通过。
