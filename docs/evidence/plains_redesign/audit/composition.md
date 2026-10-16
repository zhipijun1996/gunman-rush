# PLAINS-REDESIGN-01：独立场景构图设计审计

审计角色：scene-composer + art-director，只读生产/测试/文档。基线 30f6a825712fbb30e607791c996de142c6757a79；分支 feature/plains-designed-exploration。本报告仅提出设计与覆盖要求，不是新实现的审美验收或真人签收。

## 证据和版本边界

已读 AGENTS、current_state/handoff 最新段落、两项技能、visual_bible、art_quality_target、terrain_tile_contract、content_pipeline、SceneComposition 模板。实际读消费者：PlainsRegionStage、PlainsRegionGenerator、PlainsRegionScenery、PlainsSetDressing、PlainsBackground、StageCameraRig、PlainsGroundSupports、PlainsV3Assets 及 decor/manifest/runtime_integration/style_approval。v8 石灰岩母版获用户认可；v3 style_approval 是风格输入认可，不等于任何新运行合屏已认可。

以下 PNG 均实际通过 view_image 查看：

- `docs/evidence/level_autonomy/media/navigation_after/frame_001440.png`：1280×720；两个木桥层近同高度，箱子/玩家/长捷径文字争夺同一带，stones 贴右边缘且体量很小。
- `docs/evidence/level_autonomy/media/navigation_before/frame_001560.png`：1280×720；主通路贯穿横条、上层单条，两图使用同一城堡/瀑布全景；下层文字被裁。
- `docs/evidence/level_autonomy/media/action_after/frame_003480.png`：1280×720；同样贯穿横条，轮敌读得见，但并不能凭改动作模块获得维修回廊的空间身份；上方平台接近小地图遮挡区。
- `docs/evidence/level_autonomy/media/action_before/frame_003360.png`：1280×720；荆棘和敌人可分辨，主/次层仍是平行细条；顶部角色/物件落进HUD。
- `docs/evidence/level_autonomy/final_validation/browser/region-tutorial-spawn.png`：1280×720触屏模拟；两块悬空石台+同全景，尚有清楚起跳缺口，三行教学文字太大，缩小时更弱。
- `docs/evidence/level_autonomy/final_validation/browser/region-map-open.png`、`region-map-centered.png`：实际概览界面，但迷雾只显示起点；不能用它们证明完整拓扑轮廓。此项全图空间概览仍未验证。
- `preview/plains_v3_contact_sheet.png`：资产概览；确认风车、拱、石群、藤蔓、旗杆等确为现有资产，不是虚构新画稿。非游戏合屏，不能代替正式消费者证据。

读取四组 rendered_report/capture/source-manifest；ffprobe 实际核对 after 两个 MP4：navigation 1280×720/60fps/49.25秒/2955帧；action 1280×720/60fps/62.70秒/3762帧。报告明确 synthetic InputRouter、正式相机、软件GPU、无物理设备认可；导航before来源7c981ee，after标签b6337d7；动作前后来源标签b6337d7、需冻结source manifest区分实际字节。当前基线30f6a82不能直接继承这些截图的验证。此审计未观看完整视频或听音轨，动态/音频保持UNVERIFIED。

## 诊断

**REJECT（限定：所看旧合屏与当前构图策略足以满足用户全面优化目标的说法）**。症状主要是空间轮廓、深度和焦点恒定，不是props不足：所有位置都是同一幅山谷画后，横向薄平台游离在中间。文字代替场景告诉玩家“维修”“溪谷”，区域名由随机landmark决定，实际几何相同。现有Scenery仅junction，只接受ruin_arch/stones，全图MAX_LANDMARKS=2且同ID只一次；风车/风铃/藤蔓名称通常无实物。同一身份不应由它的未实现贴图命名。

PlainsSetDressing只接GeneratedDemoStage，正式PlainsRegionStage没有消费它。单独调它或改decoration_seed无法改善正式两图。PlainsBackground正式默认continuous_panorama=true，只有一张RGB全景，.045漂移并tanh限幅，低对比处理不能产生真正分离的景深。备用v3 sky/hills/meadow虽存在分层，切回也须验证实际覆盖/透明底部，不能声称无缝循环。

PlainsGroundSupports.plan过滤plains_或micro_board，region_junction等不会自动产生地面支撑；不要扩大这过滤来用碰撞填空迁就厚地形视觉。厚块/壁/孔洞由新正式几何合同设计并验证，艺术仅如实画该几何。

## 四个与地形同步的身份（设计候选）

相机默认zoom1.95，1280×720实际世界视域约656×369；单个关键构图应在此尺度读出。每个空间有一个主焦点，一个明确的开放方向；身份选择跟拓扑/连接语义，不能随机抽素材后改标签。候选体量以下皆为世界单位，只约束表现比例，不修改既有碰撞。

| 身份 | 地形空间与玩法可见区 | 前景/玩法/中景/远景 | 地标和引导 |
| --- | --- | --- | --- |
| 风车台地 | 宽重台地边+单侧上升，天空负空间；横向缺口或可观察动作段占中部。台地厚度必须来自真实新增/已验实体 | 前景小苔草仅地形内部；中景偏左或偏右单风车；远景hills保持天空留白，不在每个台地再放第二风车 | 复用v3 windmill，身高130–160，脚底锚点；起跳侧先看到风车+下一落点。风车无交互语义，无真实叶片动画时明确静态遗构 |
| 断钟庭院 | 两侧不对称厚壁/台地+中部真正孔洞，桥交错且主落点清楚；横向开口与下方绕行形成环 | 玩法桥保持现有单向木材语义；一座ruin_arch放非落点背景侧，拱中负空间框下一段；藤蔓只墙内部 | 复用v3 ruin_arch，90–120高，低对比；装饰拱不可伪装可进入的门，尤其不与真实射铃闸门同屏靠近。真正闸门为主焦点时拱撤下 |
| 溪谷井环 | 贯屏竖井+左右不等高落台；一侧下落一侧攀回，低处看见返回入口；不是三条平行高速公路 | 左右岩壁真实厚度/孔洞；stone群只稳固观察岸上；远景更淡，中景峡口由真实岩体轮廓形成。当前veil按world_y变深可复用但不压暗危险 | 复用stones 32–45高+ivy墙内；地标是井口与井底的不对称轮廓。下落入口提前看到安全着陆台；不能新增假水面/瀑布作为可站面 |
| 维修回廊/营地 | 低矮横向空间后接开阔出口；厚壁凹室容纳商店或真正安全观察台。上方层避HUD，压缩不靠调相机掩盖路线 | 玩法商店是功能焦点；背景banner/ivy落在侧墙或下表面，不能覆盖商品/交互提示；出口透出低对比远山 | 复用实际shop/chest与v3 banner，旗高65–85；维修语义依赖营地/休息/回程位置，不装饰死敌假装可搜索物。不要把高亮黄铜散在背景以抢商店 |

接受“同一素材可服务不同几何”的设计方法；四卡仍为proposed。最小黄金组合宜先风车台地+溪谷井环，各一段，证明开阔横向/深竖向确实不同；随后断钟庭院+维修回廊扩展。用户已授权全面空间优化，但尚无新合屏审美认可。

## 正式修改落点（供实施，审计没有修改）

1. `scripts/generation/plains_region_generator.gd::_candidate`：在拓扑已确定之后赋composition_id/语义焦点，取代119–121的随机landmark命名；junction的400×32薄板不能为四身份提供轮廓。新真实几何与端口按region/level-module流程验证，再交艺术。
2. `::_fill_edge`、`::_deep_loop`：设计横向开阔→压缩→竖向→观察的序列，回程从不同高度看到同一主地标；动作段先画净空/轨迹，再确定外轮廓。不要每条连接重复完整小关。
3. `scripts/art/plains_region_scenery.gd::plan`：由composition_id生成每区分层布局。去掉全图只ruin_arch/stones的身份折叠，以每个明确构图的主/次焦点约束替代MAX_LANDMARKS计数；继续记录foot/support/display_bounds/omitted，保留现有禁区而扩动态覆盖。根z=-10不是不遮挡保证，背景仍会造成轮廓/颜色混淆。
4. `::protection`：补真实跳跃/反冲轨迹、发射/机关预告范围、巡逻至攻击全过程；已有anchor72×78矩形只是点保护。落地前预览和HUD投影是屏幕空间检查。
5. `scripts/demo/plains_region_stage.gd::_ready`的_sign调用：同屏仅保留当前动作必须信息；主/次导航箭头靠观察平台，长路线字符串进入地图/INFO或在接近时显示。真实互动结果仍必须可见。area_label使用真实身份，禁止标签替代造型。
6. `scripts/art/plains_background.gd::_ready/_update_panels/landscape_rect`：先复用sky/hills/meadow，有限全景不循环；区域深度可改变中景遮罩/远景权重，但不在边界突然换图。不要逐房创建背景导致地平线重置。
7. `scripts/generation/stage_camera_rig.gd::advance_follow`：保护正式相机角色可见、moving support稳定、左右反向；先用几何让起跳与落点落入世界视域，再考虑有真实消费者的局部观察focus。现有route_focus由Boss更新，不能擅自复用而与Boss抢控制，也不能相机越界显示空白。
8. `scripts/art/plains_set_dressing.gd`仅列为另一个消费者的回归项；无需为了正式两图修改它。`PlainsTileComposer`/v8 shader与单向木桥表现保留实体语义与并集边界合同。

## 不遮挡矩阵（每身份×两图×左右返回）

| 对象/相位 | 当前保护 | 新合屏必须证明 | 失败反例 |
| --- | --- | --- | --- |
| 起跳/跳顶/反冲/唯一落点 | anchor附近72×78，缺整段轨迹 | 起跳前与飞行全程能分辨身体、站立线和唯一落点；地标alpha/粒子不能抹轮廓 | 将windmill/arch插到落点投影；HUD挡上层台，必须检测并拒绝 |
| 单向桥/实体壁/孔洞 | 排除one-way作地标支撑 | 木桥可穿透语义明确，实体边四向一致；洞口不被中景伪填，极短木桥不重复端头 | 站立线下装饰画出假岩墙，或透明拱表现成真门 |
| ferry起/中/末+乘坐/跳离 | envelope.grow36 | 全扫掠净空，地标底部不能似固定接岸；运动时纹理跟身体，camera不滑 | 中途经过旗帜/藤蔓遮挡接岸或平台边 |
| saw/敌巡逻→预告→攻击→死亡 | world_dangers与patrol/dive近似 | 实际预告、攻势轮廓、动态轨迹与命中结果连续可见，背景不抢红橙/青 | 地标与危险同明度，粒子遮刀轮；仅idle截图不通过 |
| 铃/门/捷径开关开关态 | bell/gate保护已有 | 目标、关/开、通路、射线连续可读，装饰windchime不造第二目标 | ruin_arch放真门后或背景风铃使用同高亮 |
| chest/shop/奖励领取 | 奖励和商店矩形已有 | 观察→接近→交互→已领取全程；短提示不盖角色/下落口 | 长文本+toast+HUD同时覆盖关键落点 |
| 高井/反向回程/重生/破桥 | world bounds与实体层重建 | 上下不同视点仍有真实轮廓，无背景竖向复制；破桥后不存在装饰假落点 | 回程朝向切换后新地标挡视线；地形消失但装饰留悬空 |
| HUD/小地图/触屏/INFO | Scenery只世界空间保护 | 1280×720投影与缩小代理逐帧检查，核心危险/落点不在opaque面板下 | action_before3360顶部遮挡作为回归样本 |

所有测试还要涵盖长/短/薄/厚/内外角/孔洞、左右镜像、实体同并集换分块、同结构不同seed；不允许改碰撞迁就贴图。

## 资产复用与确切缺口

现有原图SHA：v8材质 `f8ecfd384a1b5182273c9b0237511dd4f9252fcad0360b04dda9e2a17f465289`，1536×1024 RGB；decor `04daac451742b124d0cb40dc0682363ba5cac28adc380ddfd6ea215b04e2749d`，1536×1024 RGBA；panorama `990603b0c11db4948b4b1428f61ae87de12053d55bb63bc85a4f412ed4a99fa9`，1672×941 RGB。PlainsV3Assets实际body裁切：windmill476×590、ruin_arch416×523、stones380×243、ivy162×374、banner250×546。表现均等比，以裁切后底中心为foot，不以源atlas透明padding当底。风车160世界高→312屏像素；从590px源下采样可用，不需拉伸。ruin120高→234屏像素；stones42高→82屏像素。禁止把以上decor伪作可碰撞平台。

四身份的首轮技术构图无需新资产。若目标明确要求近中景维修建筑/破风车动态细节，现有资产确有缺口，具体候选：

- `plains_workshop_mid_v1`：RGBA 1024×1024、底中心锚点、目标160×160世界、4px/world或更高源密度；低饱和、无门光/无可站突边，实际商店独立露出；单张透明建筑轮廓即可，不作为地形。
- `plains_mill_mechanism_v1`：分离底座/叶轮两层各1024×1024 RGBA、统一轴心、底座foot；目标底座130–160世界高；若动叶轮必须单独animation-vfx定义，不画烘焙朝向阴影，不暗示新机关能力。
- 需要近中景断壁时：`plains_ruin_mid_v1` 左/右各1024×1024 RGBA、bottom足点及连接口明确、世界目标128×192；任何站立边只由v8实体表现，装饰断壁弱化为不能站的景深层。

上述资产尚未生成、没有原图/hash/许可/导入/用户认可；本只读审计不能声称完成。任何新图引用已认可v8+真实角色+现背景合屏作为母版，记录工具/模型/提示词/参考许可（未知仍unknown）、原图/派生hash；首套合屏后才扩产。无需新画风。

## 1280×720与手机缩小代理验证方案（未执行的新方案）

保留固定种子 `level-design-v2-baseline` map1和 `level-design-v2-baseline/02` map2，对新源冻结；新旧都用正式loader/角色/HUD/敌人/相机，不用概念图。四身份每个采起跳前、跳顶、反冲、落地、回程、机关最危险相位；额外12秒正常速度连续片段看镜头运动。全地图概览要求实际正式地图已探索或有准确标注的Godot几何overview辅助图，当前迷雾起点截图不足。

真实现存CLI可运行：

```
python3 tools/level_visual_capture.py --seed level-design-v2-baseline --map-index 1 --strategy deep --max-ticks 18000 --output build/plains_redesign/media/map1_deep
python3 tools/level_visual_capture.py --seed level-design-v2-baseline/02 --map-index 2 --strategy deep --max-ticks 18000 --output build/plains_redesign/media/map2_deep
python3 tools/level_formal.py --seed level-design-v2-baseline --seed-count 10 --maps 1 2 --strategies fast growth deep return --phase-wait-ticks 0 --output build/plains_redesign/corpus --jobs 4
```

阶段相位另跑wait0/60/120/180并按实际失败保留；10seed不是所有seed证明。capture进程成功只证明完整性，route/death结果需逐项读。录制1280×720/60fps带声；report留source snapshot/Manifest/Seed/能力/装备/相位/输入/截帧SHA/日志及退出码。检查GPU/Shader/资源ERROR与真实生命周期。适用docs/art/gameplay及正式两图验证由实施承担。

代理图从实际完整截图缩到640×360与480×270，保持HUD/触屏，不重新排版、不把裁掉UI的清洁图当代理。逐幅实际view_image：能否不用文字区分四身份；角色朝向、枪口、唯一站立边、移动岸、危险预告、闸门状态可读；地标是否改变空间注意力。代理只能发现可读性失败，不能签Android/iPhone性能/触感或真人审美。实体设备/用户最终体验仍awaiting-device/unverified。

## 独立结论范围

- ACCEPT：本审计中的消费者定位、旧图症状、母版复用边界和不改碰撞的设计原则；四身份作为可实施候选设计。
- REJECT：以随机地标名称、props数量、种子/Hash变化、只改SetDressing或动作路径替换证明全面视觉改良；以旧图替当前新源验证。
- UNVERIFIED：新实现画面、全图真实概览、新资产、动态遮挡、连续音画审美、性能、目标设备、玩家认可。此次只读审计不运行新游戏、不代签真人审美。
