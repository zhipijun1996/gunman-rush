# 四个实际地区身份：三处实体支撑地标与一处局部远背景

这是源C后三身份缺口的有界返工；旧C影片/证据不升级成D。主代理绑定最终D整游戏源，本目录只绑定自有组件字节。生产、测试、资源已冻结。

实际新增1次image_gen调用，以本轮已选Underworld props为参考，获得完整井/水轮、断钟拱、修理棚三件同源图。原PNG、完整prompt、实际图集regions/source/reference hash在`assets/underworld_plains/decor/identity_generation.json`。没有改源像素；用实际alpha≥2主体包围盒与8px采样边提取完整region，原始alpha1噪声保留原图。原严格8%等分边距没有完全满足（中间断钟接近cell边），不伪称模板通过；实际完整对象region单独验证。实体地标仅将原根锚以下埋藏尾部排除在显示region外，使真实纹理box底边与实际根线一致，不能以透明尾巴在solid内部起ray。

实际两张正式地图都放置了不同的风架、断钟拱和修理棚。每个真正的Sprite有对应`landmark` metadata与`presentation_manifest.items`，真实display bounds对应实际node；两图各三次原bottom-center射线全命中StaticBody2D。metadata不会给未放置物登记identity。

井在creek区的11个真实静态bank候选上，即使缩至64world高，完整根扇+8边距与whole-object功能keepout仍无法同时满足。固定33点扫描的漏窄口风险也改成精确keepout边界候选，原whole规则不放宽；原失败与实际areas/solids/protected数据保留`final/identity_geometry_probe.json`。实际grounded well继续omitted。

主代理据原PlainsRegionComposition既有语义明确授权井作为局部远背景建筑。`UnderworldLocalComposition`是真实子消费者，既有slot名`PlainsRegionComposition`及实际`compositions`数组供原collector观测；没有把背景改叫物理地标。井只在creek_well区域附近放置，完整source中的石基/水轮/苇草构成painted base；`physical_support=false`、`collision=false`、`standing_edge=false`，不设landmark metadata。冷灰蓝luma映射、负z与亮度边界来自同一真实spec `scenery_build.decor.local_composition`。整bounds+8保留功能keepout，整bounds+2不得与任何foreground solid相交，因此屋木架、水轮和完整石基均可见，不靠遮掉失败部分过关。它是局部背景建筑，不计作第四张独立主远景。

429项headless组件检查/0失败，新增真实node正反例覆盖：无solid时grounded well仍拒绝；背景真实存在且位置/材质/无物理语义正确；冒设landmark、移到foreground、把highlight改亮绿均被拒；全功能keepout下背景也不得出现。两张正式map各8个实际GPU定位窗全部成功，原三grounded射线/局部井实际issues均正常，日志无script/shader/error/leak。定位控制器与相机cut均明确是美术fixture，不能宣称自然抵达/无伤/通关；map2定位过程中真实受伤保留，不重写资源。

已亲看两map的井/水轮/石基、断钟拱、修理棚与风架实际图。`final/golden_local_creek_well.png`和`final/golden_map2_local_creek_well.png`中井完整可见、低对比冷灰；最终审美、自然路线读图和设备仍交独审/用户/真机分别确认。主代理保持原八路、四身份集合与全部counterexamples；原observer只认识PlainsRegionScenery的问题通过显式观测新实际消费者修复，不删四身份断言。

一次初始兼容继承probe证明Variant覆写语法合法，但最终遵主代理选择保持独立Node2D。`inheritance_leak/`保留当时原退出警告；后续`--verbose`实证资源为land.ogg/OggPlayback，而非已证继承泄漏，完整输出在`final/identity_exit_verbose.log`。自有定位capture在app.free后等待4个process_frame排空音频，最终两图均干净退出；生产音频代码未改。
