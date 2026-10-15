# PLAINS-REDESIGN-SCENE-01：只读实施准备

2026-10-15；尚无实施租约。未改生产、文档、测试或质量记录。已读 AGENTS/current_state/handoff/visual_bible、scene-composer/art-director、整区设计合同、原构图审计及本轮基线补审。最新整区授权覆盖旧“仅小切片”，但 Motor/资源/成长/保存/RNG 不变。

## 亲自查看的实际画面与资产

本代理实际 view_image：baseline/movie_advanced_deep/frames/frame_001200.png、frame_003480.png，以及 composition_current_baseline_segment43.png 八帧contactsheet；assets/plains_v3/decor.png、plains_v4/spatial/chassis.png、plains_v3/background_layers/hills.png。未完整播放视频，未听声音，未接实体设备。补审其余截图结论是引用该只读报告，不能写本代理全部亲看。

直接观察：frame1200 左上飞敌及其发射原点在 HUD 后，右敌在空域可见；HUD 占 x12..772/y8..152。contactsheet43 连续采样中角色上升穿过HUD，右岸被小地图压住，动作链长串文字穿过玩法空域。frame3480 草顶站立边和轮敌明确，应保留；整体仍只有两条细横带与同一密细节山谷。

## 确定的真实消费者与必改点

- DemoApp._process 强制正式 HUD760×144（debug180），且资源HUD是同CanvasLayer的兄弟节点，并不在panel下面。仅缩 Panel 或改 Scenery 不能修复。
- ActorResourcesHud 子控件绝对定位到 y133，长 energy说明宽达450；主流程重复展示 jumps/air shots，导致大面板。应给正式平原明确 compact presentation，保留 HP/能量/剩余跳/射/共鸣必要信息；详细解释留 INFO/debug，资源服务原样。
- Stage _ready 每一区生成heading+整串routeclues，高奖励两处多行大字。缩略图固定(1018,180)/240×156；不是全图UI。应改观察岸短上下文提示与场景title，动作中淡出无关文字；保留起始操作教学、奖励回程和捷径操作信息。
- PlainsRegionScenery 当前只安装2个低矮landmark，所有其它身份被省略；四个语义身份要真实组织局部中景和焦点，不能沿用MAX2作为新全区限制。
- GroundSupports 已是实际collision-bearing底岩，但只针对plains_和micro_board；不能由美术偷偷扩充真实碰撞。新v10的实体地基必须由空间包验证。场景包可消费现有supports，禁止画亮草顶假落点。
- PlainsBackground 是DemoApp常驻背景CanvasLayer -100，panorama有限且漂移很轻。应保留母版色域，局部中景与遮蔽组织随真实空间身份；不必重新生成大张背景。若直接修改Background需只影响正式region的明确presentation设置，避免Home/Studio/旧demo波及。

## 四身份构图执行草案（待真实v10 Manifest修订）

1. 风车台地：优先真实宽实台地的偏左/偏右观察肩岸放一座 v3 windmill，默认原比140..180世界单位高，完整脚宽有支持。高饱和布帆只作一次局部焦点；动作方向另一侧留天。背景山体低对比，避免与远景自带风车同频复制。小平台不可承载大风车，失败明确omitted不能浮空。
2. 断钟庭院：按真实上下错层桥和中央空域，背景两侧是破损拱/残墙，不出现明亮水平草顶。v3 ruin_arch 坐真实实体边肩，不盖唯一通行门/铃；中央射线、跳跃弧和接收岸留净。钟锁本体仍唯一功能焦点，装饰chime不冒充真实互动铃。
3. 溪谷井环：读真实纵向 path/分离回程，背景竖向暗岩体/苔挂在两侧，底部透出冷青远景。stone在实际落地观察岸，ivy仅沿墙下垂，均不盖上升木台和下落口。明确无碰撞背景深度与实体岸材质区别，不用背景石台骗玩家。
4. 维修回廊：以实际camp/shop凹室为焦点，真实压缩顶板/左右口来自几何；背景低对比木架与旗帜，真实shop优先。下一出口显亮开口，离开回廊后转开阔。没有新维修资产时不能把单拱称完整精美建筑系列；记录复用的具体限制。

身份分配来自实际 semantic role/space_identity，不从随机label反推。节点名称+props数量不是验收，必须同一路线上拍到开阔→压缩→井口/垂直→回廊出口的画面差异。重复地标需按macro cluster约束，不是每个area一座风车。

## 动态UI可见区方案

先将正式HUD压成约370×100的紧凑group，所有实际controls归同presentation布局；无需修改资源行为。标题短到地区+地图，详细区域名可在到岸时短时出现。菜单按钮维持可点；缩略图可缩至约180×110且移动到空闲角，expanded map大小/雾/平移缩放/触屏合同保持。

不能承诺某个固定角永不遮敌：用真实CanvasTransform投影 player全体/当前视野敌body和攻击原点预告/下一接收岸/移动台接收范围/钟锁目标至屏幕，按预设有限候选角选择最小冲突布局；保留变化迟滞，不在触控按下时把按钮移走。不依靠隐藏所有UI、全改透明或只测静止截图。若无法找到无冲突布局必须产出unresolved记录/失败，不伪造clear。可考虑将地图收起为可展开chip（动作中），恢复到观察岸；这属于展示，不影响游戏输入或探索状态。

更低风险首版是紧凑HUD+小地图移屏边+上下文文字，先跑真实投影检查；如果仍有已知CB04/CB07型交叠，再有界加入局部避让。不要先建通用UI框架。

## 原测试冲突与迁移

旧 tests/plains_autonomy_slice_runner.gd 32断言硬绑 plan.items==2、arch+stones、area_0_1/area_1_0、support精确数组、只支持2资产。旧 tests 及断言必须原样保留，在冻结v9完整runtime消费者重演positive32/0与实际Sprite上移20负例32/3；新正式v10另建更强的consumer测试。测试封装须可新checkout运行，不依赖本机worktree，隔离项目父级.gdignore避免全局类重复。可复用空间包建立的legacy runner，不重造第二档案。

原art/gameplay其余安全/资源/生命周期检查仍跑新default，不能整体搬旧版。新Scenery不应破坏旧static plan API，可明确版本化与legacy replay，而不是让旧32“适配新玩法”降低数量/位置断言。

## 新consumer专项：正例 + 实际破坏反例

统一命名 plains-redesign-scene，接原Harness profiles，不另建门槛。实际DemoApp → Stage → 新Scenery/真实HUD运行，Manifest/RNG序列前后不变，scenery无CollisionObject/Shape。测试2图/至少2Seed/四身份、显示比例、真实脚底ray/支持、投影和来源。真实敌人存活/移动预告，真实Motor通过短链和接收岸，相位至少起跳/上升顶点/落地/回程；摄像机正常。

至少八项可证伪检查：
- actor fullbody vs 真实HUD可见rect：故意新增实际不透明Panel盖actor，拒。
- enemy body/attack_origin/telegraph vsHUD：实际自然telegraph窗口；故意把HUD真实节点置其上，拒。
- 下一唯一接收岸投影 vsminimap：故意移动实际map节点盖岸，拒。
- 真实bell/射线 vs前景：故意新增实际装饰Sprite覆盖bell，拒。
- 移动ferry sweep/boarding沿途 vsforeground：实际ferry至少两个phase；故意放opaqueSprite，拒。
- 支持足宽与脚底collision：实际landmark Sprite上移20，拒；不是只改metadata。
- 世界heading/clue实际Labelrect vsactor/敌预告：故意恢复长串放到路线，拒。
- 意图/实际语义绑定和轮廓区别：真实节点texture/scale/depth身份，故意挂错身份或删掉必需局部深度节点，拒；这只能证明部署/角色，不给美感打分。

对部分投影指标必须过滤实际画面外/已死亡敌，不让不可见远处敌导致永远不可解。不能漏掉已经发出的敌弹、空中敌追击范围以及ferry真实扫掠。所有故意失败都保存actualsource/command/exit/log/截图/trace/sourceSHA，不篡改正例证据。

## 真实图片/视频与许可边界

先在最新v10真实formal 2图2身份采短片，用tools/level_visual_capture.py实际GPU软件渲染；max-ticks预算截断必须如实frame_budget_exhausted，不说route passed。正式最终录主路与高奖励往返，1280×720/60FPS/AAC48k stereo，保留所有UI；截图缩小640×360/480×270作为代理，仅可读性。媒体SHA与source snapshot绑定，source_before==after；最终全套在source冻结后。

复用v3 decor/objects、v8 limestone、v4 panorama，原图不编辑；新consumer引用母版/实际asset entry/原像素SHA。v3 styleapproval只为风格认可，非任意组合用户通过；原manifest未声明具体license的字段保留unknown，不臆造商业许可。不上外部付费模型，本轮没有新图像生成可不造AI生成记录。未完整看听/实体设备/目标性能/用户审美和趣味均unverified。

## 建议实施租约允许路径（精确到实际文件）

必需生产：scripts/art/plains_region_scenery.gd、scripts/demo/plains_region_stage.gd、scripts/demo/demo_app.gd、scripts/ui/actor_resources_hud.gd、scripts/ui/plains_region_map.gd。
可选生产：scripts/art/plains_background.gd；scripts/art/plains_scene_composition.gd及.uid（仅有正式Scenery消费者的小专用composition绘制/metadata），scripts/ui/plains_scene_readability.gd及.uid（若重复投影逻辑真有2个消费者才新增）。
不默认允许：PlayerMotor/Controller、武器/资源、enemyAI、随机流/保存、generator拓扑或GroundSupports碰撞。若需必须回报空间包复验，不能场景包偷改。
测试/工具：tests/plains_redesign_scene_runner.gd及.uid、tools/run_plains_redesign_scene_tests.py、tools/harness/profiles.json、tools/run_plains_autonomy_tests.py（若空间包尚未实现完整legacy冻结包装）、必要已有portable frozen runner工具；若实际capture缺camera/UI telemetry，只允许增加原capture的观测字段及明确消费测试，不改旧throughput/route判据。
文档/记录：docs/quality/plains_redesign_scene.md、docs/quality/records/PLAINS-REDESIGN-SCENE-01.json、docs/evidence/plains_redesign/scene/。

以上仍为待实施方案；没有填写完成、PASS、美感认可、已拍新片或已验证新v10。
