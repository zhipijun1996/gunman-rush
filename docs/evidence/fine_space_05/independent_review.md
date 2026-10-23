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


## final_r2 有界补充复核（2026-10-22）

生产checkpoint：`5ce3cd3d8771d6e44d00cc600b0a73ddb1e6b0a8`。本节补充并更新当前字节绑定；上文final图、旧v5哈希与问题记录作为原轮证据保留，不冒称仍是最新版本。

实际再次view_image打开 `build/fine_space_05/final_r2/{home.png,s0_m1_spawn.png,forest.png}` 三图；未重审其余27图。读取final_r2/capture.json，含30条capture及空failures；未凭此代签30图。Home/Plains画面主体、根接触、细密度和背景地标分离未见新增明显退化。forest单向木条现在有更明亮的树皮暖斑，比final暗条更容易辨认，但仍是独立裸细矩形，未建立与苔草实体根台一致的承载结构。结论更新为“可读性局部改善，森林空间语言仍REWORK”；不要求盲目扩产第三轮，也不签整区。Home label仍偏小灰、天空叙事偏明亮、前景贡献不足等原问题保留。

独立读取当前fine_sprite shader：vertex计算MODEL_MATRIX原点到round(origin)的位移，再经矩阵逆变换加至VERTEX，仅改变绘制顶点。它没有设置Node位置、修改交互anchor或物理状态。project.godot及UnderworldPresentation中未查到全局snap_2d配置；据此确认本次实现采用绘制层吸附，而非全项目transform吸附。源码审查不能替代运动抖动与所有变换组合的GPU验证。

### 测试改动独审

实际读取checkpoint相对其父提交的三份测试diff，并查看相关保留断言：

- `test_underworld_scenery.gd`：唯一条件替换是远层从相邻mirror交替改为两条均不mirrored，符合当前同向云重复。横向覆盖、邻条无gap、其他层原向重叠、root span支撑、真实solid top、whole-object keepout、空地拒绝漂浮、分块/顺序不变性等断言仍在。此修改确认语义迁移，不单独证明云接缝像素自然。
- `test_underworld_identity_population.gd`：从AABB底中心射线改为实际Sprite.to_global(source.foot)，在渲染根上方12wu到下方3wu寻找真实表面，适配埋根而非漂浮。较长射线受到新增0–8wu inset、碰撞surface与原逻辑foot差<.01、记录render_root等于实际变换、两端真实StaticBody支持共同约束；原keepout断言保留。没有把metadata本身当接触通过，也没有删除支撑要求。0–8wu只属本次嵌根规格，不外推全游戏。
- `test_underworld_formal.gd`：`foot.is_equal_approx(stage.merchant_position+Vector2(0,18))`完全保留，只在失败label追加actual/expected数值。后续实际StaticBody支撑射线也保留。故本次未用放宽merchant锚点阈值掩盖全局snap造成的偏移。

本代理未重跑这些测试。scenery450/0、identity21572/0及formal96/0属于生产者已记录的执行结果，本节独立签的是修改内容及原约束保留，不冒称重新执行通过。

### 当前方向/源绑定

新版v5的20条runtime_reference全部与当前字节匹配；细粒度用户原话、candidate状态和不签视觉/设备的范围仍在。fine_sprite引用已绑定新vertex实现，旧v5字节由上节原值留痕。只批准当前方向与字节重绑这一有限结论；森林、动态、前景效果和用户审美不因此获得认可。

- 当前v5 SHA256：`5c5585a275cf009ea6860371c920657e8d875955d5ddaaedb3c1cdc38527160c`。
- 当前fine_sprite SHA256：`8132707bd3baf841ceda85d1c728890f813f19c4fccfd3cb07c9fcbecc185188`。
- final_r2/capture.json SHA256：`839d1cac5863b6c34ca946aa3011fa7ee72ecc4d86e367f501561e6733587c9e`。

| 此次实际补看图 | SHA256 |
| --- | --- |
| final_r2/home.png | `638bd3f62effe970ea30e3a5dc76192e696698b7467c951fbde34de6244a254e` |
| final_r2/s0_m1_spawn.png | `85d10d29f91c2c58921dcf0282336c818672515ac9ed199528bd1a8574d80d39` |
| final_r2/forest.png | `0cf231fc055a639e3178022e9ddedf473a060b06c15c643e4ae905f326a09518` |

前景Plains.opacity≈0.0045不能验证可见效果的原结论保留；未看新版连续影片，尚未验证风动、动态遮挡、整段路线、音轨、用户及真机。


## 真Godot影片抽帧补充与报告冻结（2026-10-22）

实际以view_image的original尺寸打开 `movie_frame_06/12/14/16/20/22/24.png` 七张原图，未观看其余17张抽帧，也未直接连续播放MP4或听音轨。ffprobe确认影片为1280×720、60fps、约24.3667秒；元数据不等于已经观看全片。

读取movie_trace_r2.json，144条周期记录。scope明确前12秒是Home真实InputRouter/Motor输入，后面两个约6秒为正式map1/map2的live-world相机诊断；角色留在spawn、镜头独立移动，不是可通行路线。trace保留loading帧，且没有同输入基线电影。本代理只核读记录与上述七张实际图，不把相机诊断视为真实玩家横纵通关。

抽帧观察：

- 06与12：Home角色处于真实输入段，所看帧轮廓清楚，未被前景草遮住；房屋、树根与草沿接触保持，没有新的明显白块/裂缝。
- 14与20：镜头只有天空/远近景，没有角色与玩法平台；符合独立镜头诊断的范围，不能据此宣称角色消失Bug或路线可读性通过。背景在这些帧未见露底、白边或明显断接。
- 16、22、24：正式两图高低镜头下，所看实体边、底面及背景连续覆盖，未见明显白条、缺图或露底；接缝可能发生在两采样时刻之间，不能签全段无缝。重复草沿、整块暗矩形与包边的原艺术问题仍在。
- **新增采证/UI异常保留**：16帧的MENU出现在右下，24帧左侧HUD落至左下且被底边裁切；它们位于diagnostic camera段，说明当前影片不能用来签HUD在镜头运动时始终固定、完整。根因与正常相机是否同样受影响未在本次审查确定，不将诊断行为推断成真实路线故障，也不忽略可见裁切。

所看Home样本未发现关键遮挡；两个正式图诊断段角色不随镜头，缺少移动主角/枪口/敌预告与前景相交的有效反例，**动态关键遮挡、风动节奏、连续接缝、完整播放和音轨均UNVERIFIED**。不能把七张静态抽帧称完整运动验收。森林未出现在本片抽帧范围，其REWORK结论不变。

- 实际MP4 SHA256：`60a2246a496ebb679ebbf8e77c8d31364879afaf62129e30dc516d8298ba2ed1`。
- movie_trace_r2.json SHA256：`3ba45999d3608604c2c639dd9b5bc615b85d46b625a2a2c5771966c644e4e88d`。

| 实际观看原图 | SHA256 |
| --- | --- |
| movie_frame_06.png | `cef872a739a0f9493d275b08da83bcc09caf089cd1c179f49116b821a05523b3` |
| movie_frame_12.png | `a153535d0b6d556373799dbb8c28e8f2c7d5fb6be6d03c0ec250eb0a91e63766` |
| movie_frame_14.png | `1769d290e164ccba7b4c54a1ab5cdfaa535160ca330562d8914b11e8fe2b7b70` |
| movie_frame_16.png | `7227abf88f75c590673acb753ff3d7c075dc1bdb6e7d081744006adc6aa7a7ad` |
| movie_frame_20.png | `892d43933a6de24deabcd2b158c6a5d5e29d9f6a6a9415a4d6c3ec673fbe91cf` |
| movie_frame_22.png | `3dbf060932a33721b60408e08a4594684856970f424f18a87860e351bc41d70b` |
| movie_frame_24.png | `72a303d8657d2b239d963d2f51f9fecaa9d9335d7a769404628cfb6c7af07712` |

本轮报告至此冻结：限定静图/抽帧改善及字节重绑结论成立，森林材质承载语言与前景效果尚待完善，诊断HUD裁切保留为未解决采证问题；全区、连续视听、正常路线、用户审美与设备均未获本代理签字。


## HUD边界单点修复复核与最终冻结（2026-10-22）

生产source：`efd784349efa31502cb428b14bde10ea517bdd9a`。此前fine_space_05.mp4中HUD裁切失败原件与上节观察继续保留，不能追认为旧片通过。

本次实际以original尺寸打开新片23秒抽帧 `build/fine_space_05/movie_final_24.png`：左上资源HUD完整，右下MENU与MAP按钮也完整处于画面内，未见此前底边裁掉资源文字的问题。当前画面并未实际触发HUD底部位置，因此单帧只证明该时刻完整，不能单独证明原底部槽已修。

独立读DemoApp修复diff：仅在每个候选评分前，按viewport起止、真实_hud_frame.size及8px边距clamp候选位置，随后仍用原blocker/touch_regions评分。1280×720、140px高面板的底部候选由590收至572，数学边界与旧失败相符；未通过修改物理、相机或玩家坐标修HUD。现存候选、关键物体权重及保护区域判断保留。

独立读新增test_fine_hud_bounds.gd：使用实际DemoApp正式map2、实际Camera2D.zoom把5个屏幕目标换算为相机偏移，然后检查真实panel及可见的title/金币/HP/精力/射击/战斗/focus Label矩形被viewport包住；bottom_seen断言要求至少一次实际选到底部候选，避免只查默认左上。读取hud_bounds.json回执为42检查、failures=[]、bottom_seen=true。本代理没有重跑engine，确认的是源码、回执与新帧相互支持这一限定结论；该测试不覆盖全部UI控件、触屏、异形视口、所有动态转场或设备。

结论：**本次实际1280×720正式map2诊断的HUD边界修复具备针对性源码、实际底部布局回执及新帧支持，可关闭原已观察裁切这一局部缺陷。** 保留旧失败，不升级为整套HUD/全动态通过。未直接播放新24秒MP4，也未听音轨；完整动态、前景遮挡、正常路线、森林REWORK及用户/真机限制均维持原结论。

| 本次复核对象 | SHA256 |
| --- | --- |
| scripts/demo/demo_app.gd | `d1295039ba8f6e3582002844638e195f0d9c31c2bf4972009559204946f6bb43` |
| tests/underworld_plains/test_fine_hud_bounds.gd | `732a2da6a290659e028cae3b0e825d51044b393be43596d26b555ed54d4fa4dc` |
| build/fine_space_05/hud_bounds.json | `295683274efb34d8fbaa257be1e92abe8bd704783ee95144bffd92130faa041c` |
| build/fine_space_05/movie_final_24.png | `5d47f5c520e62cc00dd44c9c12c2c78843db7bec46f674075c92a2bde9236eb2` |
| build/fine_space_05/fine_space_final.mp4 | `80301f729eb1e8b33d8fb3e928fc9f7501ef11fde98945c5e8b909ec3f003b33` |

报告最终冻结；本代理仍只修改本报告，不改生产代码，不代签用户审美与设备。
