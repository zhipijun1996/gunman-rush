# FINE-SPACE-05 独立静态视觉复核

审查者：独立子代理 density_art_review；日期：2026-10-22。职责依据仓库 art-director / visual-director 的实际像素审查要求。本代理没有参与生产实现，仅修改本报告，不运行CI、不修改生产代码。

结论：**局部改善成立，视觉整体仍为 REWORK / UNVERIFIED，不代签用户。** 家园根基、平原细密度和背景分层有所改善；森林单向平台读图与前景效果证据仍有缺口。本报告不把文件数、source hash或层数据当作美感通过。

## 实际观察范围

以 view_image 实际打开 final 目录12张1280×720定位静图：home、home_east、home_upper；s0_m1_spawn/high/low/junction；s0_m2_high/low/bell；s2_m1_high；forest。此前本轮已实际打开基线 `/workspace/gunman-space-before/build/space_before/{home,plains,forest}.png`，此次据这些原件对照。其余18张final图未逐张看，不能写30张全部独审通过。读取最终 capture.json：含30条capture、failures=[]、seed/map/camera/viewport、parallax及presentation/foreground记录；该记录的技术状态由采集者负责，不由本次看图重新证明。

静图不是正常行走：home_upper及high点角色与屋/商人重叠属于诊断定位，不能据此断言真实路线穿模，也不能凭这些图确认落脚、通行或交互。尚未查看连续电影、音轨、真实输入轨迹、全地图和目标设备。

## 改善

- 相比quick_r2，上部天空更暗、更灰，人物后面的风车已在出生点移开；背景地标不再直接贴住主角轮廓。平原远山、聚落剪影与近丘有明度/细节差，静图纵深比基线更清楚。
- 家园建筑底部与树根被草沿接住，未见基线式明显悬空边；home_east的门柱、树根和草地接触可信。人物、屋顶、门窗细节保持细粒度，未见白块或缺图。
- 平原单向平台已有可见厚度及端部，明显比quick_r2的亮细线更容易识别为实体承载物；solid保持草顶、暗填充和石断面，和木桥有基本语义区别。
- 森林保留树皮/根枝和绿灰空气色域，去掉侧壁荧绿框后较克制；角色暖红仍能从绿灰背景分离。没有把平原石材简单换成绿色冒称森林。

## 优先阻断与剩余问题

1. **森林可走面仍需REWORK。** forest图中上方、右侧及角色右侧单向平台是接近背景明度的裸暗木条，主体苔草根台与单向条的材质语言分裂。正常尺寸下更难第一眼判断下一落点，较高平台还容易并入背景树枝。增加微小厚度没有解决承载结构与可读性；需要沿真实宿主补足受光边/根枝关系，而非加亮全屏。该图不足以签“森林空间统一完成”。
2. **前景只证明存在，未充分证明空间贡献。** home图底部左草可见，右草更淡；对主体无明显遮挡，但暗底上存在感很弱。s2_m1_high记录branch_count=1，其实际visible项opacity=0.0045802746899426，正常尺寸几乎不可见；不能用计数称该图前景框景已成立。s0_m1_spawn/low均为0，forest保护矩形几乎全屏且前景为0。有意留白本身不算错误，但目前这些样本不能签动态遮挡保护或前景纵深效果。
3. **光色与焦点仍保留审美风险。** 最终天空较WIP克制，但仍是明亮蓝灰上空+大片金色地平线，明显区别基线深蓝暮色；暖窗/灯在家园不再具有原来的唯一亮点优势。home标签仍小且灰，和云及天空对比不足。s0_m1_low/s0_m2_low中大近丘树铃剪影有较强高频轮廓，局部接近角色和敌人；当前能分辨，不等于运动时始终避让。

其他剩余：草沿规律重复、长solid侧壁呈石沿包边、内部大面积纯暗，尚缺局部体积变化；细分辨率本身没有自动带来“特色/高级感”。平原木桥规则长条仍保留设计感较强的几何轮廓，森林矩形悬台也未因新纹理变成真实宽根结构。选细粒度不等于用户已选择这次天空叙事或所有新素材。

## 共享方向 v5 的独立重绑审阅

v5明确保留用户细粒度选择原话：

> 细粒度好看。确定使用细粒度，之后所有都统一，不统一的都修改。然后我发现家园的房子或者树和地面不贴合，需要修复

该引用由root从会话人工留存，文件已注明不是API导出；本代理确认引用存在及其作用范围，不冒充另有独立原始消息导出。它足以说明此次由16px/32wu转向32px/32wu与世界1wu采样属于明确方向重绑，而不是用新SHA追认旧美术通过。v5保留Underworld家族、47邻接/精确边界、区域材料差异和技术/视觉/用户/设备分开的限制，状态为candidate_not_user_art_acceptance，合理。

核对20条runtime_reference文件：当前字节全部与v5完整SHA一致。实际 UnderworldTerrain 的BUILD_PATH读取fine_32/terrain_build.json，加载formal_fine_boundary/formal_fine_lit；该build指向fine_32/source.png和terrain.tres，tres引用fine_32/terrain.png。因此不是只改文字而仍绑定旧16px源。terrain_build的selected_master_sha256也与实际authored母版匹配。此项仅确认引用/来源方向，**未重验构建算法、47mask完整像素、全消费者或美术质量**。

v4当前SHA与v5.supersedes记录匹配；v4及两份原Bible相对当前Git HEAD的暂存/未暂存diff均为空。本代理没有修改它们。基线截图工作区没有这些Bible文件，故不声称已与那个目录逐字对照。旧Bible保留、v5替代密度方向的边界成立；视觉、动态与跨区全量认可仍未验证。

## 证据字节绑定

- capture.json SHA256：`dd44661ed6fdc6139b1a3ccc0f8a908333ca07510d5f4c9c63f38cf40cdbd333`。范围声明为real formal App positioned stills，不是human traversal/motion/device/art acceptance。
- v5 SHA256：`cf41b733df35af561acfc30e94fd6cfba51c790f9056c23d6df7d15931e10ca3`。
- v4 SHA256：`a6f817bb762a53d99e45185444f11889246866a8baa5d29e5efaee994e7f3ae9`。
- authored master SHA256：`51333d751d910966bee1cc23184206f075b79fa7c6634bbe0cea51f8f4c31ad9`（与fine_32 build记录匹配；此轮不重新审母版艺术）。

| 实际源/消费者 | SHA256 | 本次字节核对 |
| --- | --- | --- |
| assets/underworld_plains/terrain/fine_32/terrain_build.json | `d613c8730f1fbc202a80824794ab0ca79a4a9372235c042f63cae43e55125410` | 匹配 |
| assets/underworld_plains/terrain/fine_32/terrain.tres | `bb2b0b8bbb967144f338f06852817c25088cb4697a3719898de168fef28f34b9` | 匹配 |
| assets/underworld_plains/terrain/fine_32/terrain.png | `267ba0fa45ec8c909d245d3d7a7b74aa98f464e9e6ac8bc1d671d180e35dd5de` | 匹配 |
| assets/underworld_plains/terrain/fine_32/source.png | `d08218cddd5b463a0ff033e3e5b1a260ed1280691d0b93d4565421c2f0f71431` | 匹配 |
| shaders/formal_fine_boundary.gdshader | `34ce7ad20f890e3b3d437b334e0dc9dd515a45a7ba7477390ce4ea9e4d7737f2` | 匹配 |
| scripts/underworld_plains/underworld_presentation.gd | `f12f7687ff971ae054396f4ad76afc8878f36e9d8d19ceae005fd8a503a7b367` | 匹配 |
| shaders/underworld_fine_sprite.gdshader | `fbe15e2b6e4df27cb0a6eadeacd71bd2defafc70ca4c9dc290394539f2ed86b6` | 匹配 |
| assets/authored_terrain_study/provenance.json | `f33c9590a6fe3b3997722752ab10cf2f72896dcb4e49749f3ab6c57ab4d4ac0a` | 匹配 |

capture记录的三张parallax纹理也与实际字节匹配：morning_sky `4af64f48f9e91400f080432d490fe2490faf7fb24afdf5b6501ef6e023e45ad7`；ridge_landmarks `3d0723275b127b360c74ac749ff89aa9a69179f9bfaaef5e0b0594603b9af041`；near `32ea3038c8388b4df3898e0803d02ca7ad76634d5745019cbde3057d66c6ccf2`。哈希确认是相同源，不证明其空间用途成立。

| 实际观看图 | SHA256 |
| --- | --- |
| final/home.png | `628cff1f04b5b13560406302a8147547b7db1f5504549e6328b35f1a56aaa036` |
| final/home_east.png | `c86abb317efdae7353784ddf718d9fc0eda6d4abad4b4dc0cb66491aadc7cba3` |
| final/home_upper.png | `d01ecc1fa8c6db809c4913afb394b351266b5893afff15bc2ee192fa8defc5ed` |
| final/s0_m1_spawn.png | `e712afb0e90165dbb04a6506e3c60992b9156462231f47d698ee6f2741915514` |
| final/s0_m1_high.png | `cf8d46bc20eae628196ea21484523afbea338cb0e2a93980105d212e525b653c` |
| final/s0_m1_low.png | `2d380a0c8659c62554eefdf71a0ff57e24ddbd0ef1665dc0368deac401b087b5` |
| final/s0_m1_junction.png | `b0814f3935f23c2993a2449b109ec48241f1073708c05508d69a36a1047327fe` |
| final/s0_m2_high.png | `5c47119bf442a7d2eb731185961fb16acc3ef31dc7af84ed3371ab75d5125752` |
| final/s0_m2_low.png | `b04d257ba5cc89b62b749e1a08e64b9c7aa97b51968b436c6cc190c4e388c899` |
| final/s0_m2_bell.png | `384d2d3c11bb68a48dc0ba2ed01a21a728859d48e7b6ff01cc50366e22ebc0e8` |
| final/s2_m1_high.png | `c9704b50bd9e544d90bd03598d9ead0969427c9dfe706b2ba88be256dec0a18f` |
| final/forest.png | `0803584de58b18bb121ae8b4dac42041c42c81b77cf77ef6b9a8152f72196db3` |
| 基线 space_before/home.png | `e0c0ebeb9ef598842bbe8570a039e91b6862634ba59f1c9bda0d967cf8c8a977` |
| 基线 space_before/plains.png | `c2a2a1f3e5b84356fe33425bf0b5fa1abc8dfbd812fe83f1f26973633f941cb0` |
| 基线 space_before/forest.png | `38f990b59a64044e32e025a754500f3b4de82894f7d9fff79308b3c08ef0a85f` |

本报告仅接受“指定局部静图有上述改善、方向重绑与当前源字节一致”的有限结论。森林落点可读性、前景可见贡献需继续返工；连续运动、视差接缝、风动/遮挡保护、正常路线、全Seed全区、Web实际渲染、用户审美与真机性能均未由本代理验收。
