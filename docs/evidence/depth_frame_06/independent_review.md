# DEPTH-FRAME-06 独立实机静图与前景边界复核

日期：2026-10-23；审查者：density_art_review独立子代理。本代理未实施本任务中景、前景、Shader、生成或接入生产代码；本次只读取源码/实际图像/采集记录并写本报告，没有启动引擎、运行CI或改生产文件。按art-director / visual-director的实际像素要求审查，技术、局部AI构图判断、用户审美与设备分开。

## 有限结论

**用户要求的“更多、更大的风车钟塔”与“人物更近的氛围层”在所看局部镜头中已有实质改善，可作为方向候选继续评审。** 不签用户已觉得精美，也不签完整地图或动态遮挡。首轮mid_r2的假道路问题在最终图中改善：断桥下移，不再把出生点真实平台间隙画成一条连续可走顶面。大钟塔相位偏离主角，正常角色轮廓比首轮更独立。

前景已从05近乎看不见的计数，变成实际可见的侧枝与底部草：s0_m1_spawn左侧枝、s0_m1_high右上枝、s0_m2_low右侧枝、s2_m1_high左枝/底草和Home底草都能看见；完整根/挂点留在画外。所看静图没有直接挡住角色、主要落点、铜铃或HUD。不是只凭branch_count推导效果成立。

## 实际观察范围与对照

实际以view_image original打开final目录12张1280×720定位静图：home、home_east；s0_m1_spawn、高点、低点；s0_m2_spawn、高点、低点、bell；s2_m1_high；s2_m2_junction；forest。两张05同镜头 `docs/evidence/fine_space_05/{home,s0_m1_spawn}.png` 与首轮mid_r2同名图在本任务前一轮已实际打开，用于同位置观察方向变化。final其余18图未逐张看，不写30张全视觉通过。

读取final/capture.json，任务DEPTH-FRAME-06、30条capture、failures=[]。记录包含实际seed、map、camera、parallax源及foreground保护矩形。Home是固定场景；正常平原为level-design-v2-baseline/08，另Seed抽看包含fine-space-05/highland等当前记录值。截图是正式App定位静图，角色在high等诊断点可能和商人相交；这不证明正常行走穿模，也不证明路径可通行。

## 局部画面判断

- **体量和身份**：巨大风车、钟塔、台地石构提供了05稀疏剪影所没有的“聚落规模”。材质细节有保留，冷灰中景与暖色角色/家园窗灯仍有区分，没有用整片平涂抹掉材质。
- **中景用途**：断桥、石台地落在背景层，最终出生图没有明显跨真落差的假路。所看塔体未见云从实体石墙中穿出的明显问题；这只限采样时刻，不签所有云动画/接缝。
- **前景层次**：左右侧枝比旧暗底小草更有效，叶片从画框外伸入，局部形成近—人物—石岭的深度。Home草依然在地下暗面上，表达的是框景层而非人物脚边生态；实际可见但比平原侧枝贡献弱。
- **边界可读性**：草顶、暗solid、木质单向平台仍能区分；铜铃金色在s0_m2_bell较明确。s0_m2_low中敌人仍可辨认，但背后石纹/树丛相当密，动态风险高于静图。

## 残留问题与限制

1. **大型地标重复较强**：不同地图/Seed仍频繁遇见同一钟面、相近大风车组合，Home east与平原也共享主塔。中景“多且大”成立，不等于新的观看顺序与空间身份已经丰富；局部高频石纹与树丛偏满。后续若精修，优先用相位、遮挡和局部空气分区让主体周围喘息，保留材质，不建议再堆更多同一塔或全层洗灰。
2. **前景动态跳变未验**：实际保护是hard-hide，候选替换也按实时矩形执行；玩家/敌人/瞄准或HUD刚进入矩形时，整枝可能突然消失。静图没有证明其切换自然，也没有覆盖风动最差相位、飞弹trail与枝叶同屏、触屏或地图暂停等连续状态。
3. **森林原问题仍在**：forest图未见本轮新增前景，暗裸单向条与苔草实体根台的承载语言仍分裂，不能用平原中景改善签森林完成。本轮未把它当新成功样板。
4. 旧草沿周期、深暗矩形填充与石沿包边仍存在；家园世界标签偏小灰。用户审美与手机缩小可读性未由AI代签。

## 前景完整矩形与3wu风裕量源码复核

完整读取 `scripts/underworld_plains/underworld_foreground.gd` 与 `shaders/underworld_foreground.gdshader`。并读取foreground_build.json确认实际raw_crop/attachment，实际参考为原高分母版AtlasTexture（filter_clip=true），没有把旧小PNG直接放大充当新细源。crop按完整原矩形计算display_size，sprite centered=false，位置round后重新计算actual_anchor；拒绝任何 `bounds.grow(3)` 与保护矩形相交的候选，不仅检查可见叶片或小alpha包围盒。

所有附件锚在原crop内部。Shader两项正弦振幅之和为1.25+.35=1.6，除source_to_world后再随Sprite等比scale回到屏幕位移；线性剪切围绕挂点固定，source轴到挂点的归一化距离不超过1。因此当前实现的顶点最大位移约1.6屏幕wu，3wu矩形裕量在该变换假设下覆盖风移。此为源码数值推导，未重新GPU测最大风相位，不能推广至旋转/非等比或未来增幅。

保护每次refresh重建：实际静态地形边界/机关/通路；玩家、真实枪口与瞄准线；当前钩索引导和绳段；实际可见Control/触屏按钮；实际碰撞形状；活敌人与预告；弹体以及真实trail点；Boss场、未领取奖励。来源为实际节点及状态，不是只看seed的预制安全区。超过64保护矩形或可见敌人telegraph/attack会隐藏全部前景，保护优先于出图。CanvasLayer1、无创建物理体；源码没有修改角色物理、碰撞或能力。

候选附着点依据世界格与seed生成，近景parallax大于1；枝挂点至少在左右屏外12wu，草根在屏底外12wu；opacity低于.65、有效可见面积/长度不足者拒绝，至多1枝2草。故当前解决了05“有计数却opacity≈.0045”的问题，但也存在整枝即时拒绝的动态取舍。

对30条capture记录另做只读数学核对（不是全图观察、不是引擎测试）：21条有前景，共23个visible记录；未发现记录内opacity<.65、附着点不满足屏外12wu，或完整bounds+3wu与记录保护矩形相交。此项只说明输出记录自洽，不证明保护inventory完备、实际GPU采样、运动安全或美感。

## 字节与范围绑定

审查时工作树HEAD：`4a41fd729ed06e6806826bf97ded3be5c9c817ed`。生成/source与截图字节以下列完整SHA为准，HEAD不代替未提交内容闭包。

| 对象 | SHA256 |
| --- | --- |
| build/depth_frame_06/final/capture.json | `aff1abf39c9a7ea98cac4f59d83e650f41dee35d68f6cc8236427c93b21ccd42` |
| scripts/underworld_plains/underworld_foreground.gd | `7677a81e3c810b3101e018c08aa6871887aab0e18c9d702b115165fdcfc370ac` |
| shaders/underworld_foreground.gdshader | `0f31bf6cf7b4d092eac5686ff0d429f9602e4b4f4a991d6fbafc4b02970e11b6` |
| assets/underworld_plains/foreground_fine_05/foreground_build.json | `e4dd9755ff6d5b62550311e5261d3be0513bd108d977e42f485a788891f60c41` |
| assets/underworld_plains/foreground_fine_05/master_original.png | `e3218e05c4a6e6386bd546beaf0310184adaf94c5087b20af2267e1763c18a99` |
| assets/underworld_plains/backgrounds/depth_frame_06/landmark_ridge_r2.png | `29c0812af64de5cf1299cecb7e8810d93bfd435b099a1434bca0cd12e475fc29` |

| 实际观看final图 | SHA256 |
| --- | --- |
| home.png | `e7c41563fdba4a6e26bd8de425313f0c04c2a2137ef998bb85381a08e6251535` |
| home_east.png | `ddd75156a2aed37fd926336ca80376131611cd1c0cb7f4e54a308af37abc893b` |
| s0_m1_spawn.png | `265e53181ccdb6824630e902c54ed968e095f796bcd6127faba96103ac3987d7` |
| s0_m2_spawn.png | `48fcde39125b9894218bb88a5df3e1e4a1d656fe7cf93171a6011dc068f4f9da` |
| s0_m1_high.png | `9a7f97a3214ddee6b1771891ccd9cb8849092993984caafac349fb70b95de3e8` |
| s0_m1_low.png | `45fdf19489b798e2cbbd8672d93f9dc8da45bf837109eaad2fa532a936f1ce30` |
| s0_m2_high.png | `33a3dc35f58e7b65657d1311428777843c469f048d02b94f73c78a19dd38afcb` |
| s0_m2_low.png | `fa5b7e7339bdc5b7d8a9a68042b9743d796a5bd8f7103007f1b662ff35edecf1` |
| s0_m2_bell.png | `4c0a1a1309154245074ddb24f6efabba7e5a02c70fca15eae0d166c9f26b4e94` |
| s2_m1_high.png | `197eac636d28fe71b735bce3d7111a0174a92de7725fa73508585bc4864c354d` |
| s2_m2_junction.png | `9d30d357d00c16b2438aa91b2c2535ad4cc45f23433dae4c268006bb2a89a3d0` |
| forest.png | `3fab44667e1b81ce4eb6cc5c44c1c461492c6b5c56a168fdee4bae033e5d7373` |

阶段判断：指定局部构图较05有实质进步，前景保护代码与记录在上述范围内自洽；仅准入方向候选，不签商业精美、用户认可、全区、全片、音轨、正常路线、Web/设备或完整动态。未跑引擎/CI，不把生产者空failures记录当本代理执行通过。
