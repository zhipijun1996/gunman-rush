# 真实区域候选地形消费者：独立范围审查

审查者 `/root/independent_gameplay_audit`，只读生产源，不参与实现；只写build/verification临时探针与报告。按gameplay-reviewer的空间×状态×时间×消费者契约检查。HEAD `4f81371306f065387f0271264980a5934059d0bb` dirty并行开发；源记录 `independent-region-study-source.json`，不是冻结最终版本。

**本次初审 REJECT**：并集覆盖算法与退出flag基本合理，但有两项已实际引擎复现的分块/薄结构问题（第一项旧分块radius已修，第二项当前隔空隙仍失败）、一项分块预算反例，以及Boss破桥后的确定静态生命周期缺口。未认可素材、G2画面或正式准入。

## R1：圆角与作者分块/不相连邻体耦合（P2）

`PlainsTileComposer.build_rectangles` 的初始radius来自输入rect.size：同100×20实体，单块r2.5，拆2×20+98×20时左角r1。已反馈实现者，其改为并集occupied探针；当前独立引擎实测 whole=2.5、split=2.5，这一原反例关闭。

但新半径算法只查2*r远处端点，不验证中间连续实体，仍会越过空隙。`Rect2(0,0,1,10)`单独时左上r0.3125；加一个隔3单位的`Rect2(4,0,10,10)`后，相同第一条细墙左上r变2.5。横向(5,.001)误落入远侧实体，纵向(.001,5)落在原细墙。点(.5,.5)原不在小圆角影响区，放大后alpha近0；细墙本身没变，却受不相连邻体影响而被切去显著角区。

**实际独立运行**：`independent-region-geometry-probe.gd`调用真实生产PlainsTileComposer并读真实ShaderMaterial参数；日志`independent-region-geometry-probe.log`：Godot4.7.2，whole=2.5 split=2.5 narrow=0.3125 beside=2.5；2 checks/1 failure，引擎exit1，Python wrapper抛错。外层cat命令exit0只是显示日志，不能误写测试通过。未渲染GPU或直接测像素。

修复应依据相接并集外边界的连续长度，或暂不为任意矩形圆角；不能只用远处点占用代替连续性。

## R2：相同并集，密集作者分块被误判为几何过密（P2）

`build_rectangles`收集unique_edges时仅去掉完全同坐标段，没有合并同向共线相接段；nearby_edges预算受输入切块数量影响。单`Rect2(0,0,100,20)`可build；相同并集拆100个1×20竖条后build返回null。局部48距离内上/下边片段超过64，即使继续细分draw也不会降低附近原边段数量。

**实际独立运行**：`independent-region-partition-budget.gd`与`.log`，真实生产类输出whole_present=true、hundred_strips_present=false，引擎exit1、wrapper抛错。并集几何没有亚像素密孔，因此“unsupported subpixel density”不是这例拒绝的准确原因。回退保留基线是安全行为，仍不能宣称同几何任意分块一致。建议先将共线同向接续/重叠边段规范化，再预算；同时可供R1计算真实连续边长。

## R3：Boss第3阶段破桥后候选图像仍保留旧地面（P1，静态确定）

`PlainsTerrainStudy._ready` (`scripts/art/plains_terrain_study.gd:8–23`)只采样一次platforms/columns并建art；set_candidate只切visible与绘制flag，没有几何变化订阅或重建。

正式类 `WindkeeperArena._break_ground()` (`scripts/bosses/windkeeper_arena.gd:40–80`)第3阶段实际移除中部旧碰撞，修改module.definition.platforms（:47–48），重装ground supports（:63–73），并queue_redraw基线。新study仍画最初完整矩形，同时terrain_candidate_preview隐藏新的基线平台，造成可见“地面”下已没有地面碰撞。切回基线才恢复新破桥外观，再切候选又显示旧几何。

这不是study写坏物理，而是表现缓存未跟随真实消费者生命周期。需要在真实几何修改完成之后（_break_ground是deferred，不能只在phase_changed当时采旧几何）重建或安全退回基线，并检查阶段3恢复/重载。此项来自实际调用链与源码，**本次未独立走完整Boss实战或运行破桥探针**。

## 已核对成立的局部性质

- subtract_rect把交集以顶/底/左/右四片差集拆除，零面积片过滤；union_pieces逐项去掉先前覆盖，正尺寸矩形并集不重叠、空域不填。当前测试对输入与输出边坐标网格中点检查“恰好一次”，比只比较总面积有效。
- study只读取静态solid平台和ground_supports，排除one-way平台；新标志只在PlatformingModule._draw跳过solid基线绘制，不改变collider、Definition、Motor、Manifest或随机流；one-way、危险物和移动平台仍走原消费者。当前模块仅平移，不支持任意旋转缩放，这与原模块契约一致。
- null回退在隐藏基线之前返回，没有先隐藏再留空。ground_supports.visible只影响Canvas绘制，不关闭碰撞。
- Gallery明确用户opt-in，经ModuleLab signal→leave_lab清输入/结束lifetime→home_requested关闭lab→start_plains；进入真实PlainsRegionStage而非虚构背景。正常入口flag默认false；start失败清flag；_run_ended最先清flag，覆盖放弃/死亡/成功，_cleanup_run连stage子树、候选art、UI一起销毁。跨stage若仍在研究run则重新构建，未见退出后把候选带进下一正常run的确定源码路径。
- 实施者`quality-region-study-engine.log`记录1014 assertions/0fail，54 solids/54pieces/setup11ms。此为实施者定向运行，不是本审查独立重跑；11ms一次初始化不证明稳定帧率/设备性能。其测试真实连接了app/lab/stage并检查Manifest、CollisionShape2D数量和退出flag，但数量不变不等于几何状态所有细节没变，且未覆盖Boss动态破桥。

## 尚未验证与后续方法

本次仅独立运行两个轻量Godot几何探针，未导出、未重跑全套、未实际观看此次非整格GPU对照或真实区域GUI/录像，未听声音。用户素材认可、完整G2、完整路线、设备性能均未验。

补足不变量时应同时改变输入分块数量、极不等长比例、负坐标、小于格尺寸、真实孔洞/不相连邻体，保持并集不变对照实际GPU。时间维度还要包含“建图后碰撞几何改变”，而不止静态切换visible与比较Manifest；至少Boss破桥前后、暂停/恢复、退出再普通入口和已破桥存档重建。验收必须绑定冻结SHA及实际构建，不用临时dirty截图替最终版本。

## 三项修复后的复核进展（保留原失败）

实现者将边界先按方向/轴/坐标分组，排序后合并共线相接或重叠段；圆角仅由接于该角的连续边长限定，禁止跨空隙端点采样。独立原探针重跑结果：whole=2.5、split=2.5、narrow=0.5、beside=0.5，2checks/0fail；whole与100strips均成功。两个实际Godot运行均正常返回，日志 `independent-region-geometry-recheck.log`。**R1/R2原反例限定 ACCEPT**，失败原件未覆盖。

R3新代码collect_solids每帧读取当前Definition与support列，与authored_solids快照相同则不重建；不同先恢复基线、释放旧art、按已提交几何重建再恢复原enabled。null时停在基线。该路径能在deferred _break_ground之后下一次_process观察到变化，初始化也读取已破桥数据；不开新物理/随机写入。不是即时同帧signal重建，正式GPU连续画面仍需验证。

独立运行仅调用现有region_art_consumer的临时脚本 `independent-region-lifecycle-recheck.gd`，第一轮被并行新石灰岩素材未导入阻塞：plains_v8/painted_limestone_material.png无loader，脚本解析失败，无成功标记。原日志 `independent-region-lifecycle-recheck.log`保留；这轮不能计通过，也暂不归为几何修复回归，等待导入完成再验证。

用户已明确拒绝旧土褐材质美感；新石灰岩是另一候选。本报告局部代码通过不推翻旧视觉拒绝、不承认新候选美术通过。视觉仍待新版本实际合屏/录像与用户审查。

## 导入完成后的独立生命周期复跑：R3限定 ACCEPT

确认v8纹理导入后，独立再次执行 `--headless --fixed-fps 60 --path . --script build/verification/independent-region-lifecycle-recheck.gd`。该脚本只调用已审阅仓库测试的region_art_consumer，未修改生产/仓库测试。**18 assertions, 0 failures；Godot及wrapper正常返回exit0**，日志 `independent-region-lifecycle-recheck-after-import.log`；前次no-loader失败日志未覆盖。实际源码绑定 `independent-region-final-recheck-source.json`，仍是4f81371上的dirty工作区。

本次实际经历开发lab→实际第一区域，4次候选/基线切换并检查Manifest及碰撞对象数；使用明确标注的`plains_campaign_fixture.second_map` outcome夹具推进到实际第二区域，再直接触发arena._phase_changed(3)，等待真实deferred破桥，检查observer更新、桥洞不在新solids内、切换不恢复旧地形、另建observer读取已经改变的几何；最后放弃退出并检查opt-in清除。**没有声称玩家通过输入打败第一Boss、自然抵达第二图或完成整场战斗**。这是实际消费者上的生命周期与状态夹具验证。

采样setup13–18ms不是帧率/设备性能证明；日志包含18 ObjectDB实例、6 resources退出清理诊断，未归因，不宣称零错误退出或无泄漏。未看新版GUI/正常速度录像，不能证明延迟重建的实际视觉帧连续性。

最终本轮局部判定：**R1圆角分块/邻体反例、R2预算按真实并集规范化、R3动态Boss几何观察与已变几何初始化，均限定 ACCEPT**。它们只关闭本报告相应确定反例，不覆盖全部任意几何/GPU、完整生命周期/性能、美术或G5。旧土褐材质被用户拒绝的状态保留，新石灰岩候选仍未获本审查或用户美术认可。原始REJECT和失败日志继续保留作为修复前证据。

## canonical扫描带绘制分块复审

版本仍为4f81371 dirty，绑定 `independent-canonical-source.json`。旧subtract/union helper删除，实际Polygon改由归并外边界的y区间扫描线生成。扫描中只在相邻端点y之间取中点，不跨顶点；x交点排序成对填充，洞对应中间不填区间；同x跨度的上下相接带合并。局部预算仍在最终实际pieces上检查，超预算递归二分，最低尺度仍超则整体null、保留基线，不截断face/corner数组。

独立再次跑原两探针，全部通过；另生成并实际运行 `independent-canonical-bands-probe.gd`：**348案例、16086 checks、0fail，Godot/wrapper exit0**。案例为307小形状（使用17.25×11.5非整数格、负偏移）、1环洞、40固定seed重叠矩形；变形测试每矩形25/75不等分后逆序、重复全部输入，检查实际输出piece序列相同；核对实际Polygon顶点等于piece、face<=64/corner<=32、每个输入和输出坐标区间的中点恰覆盖一次/空域不覆盖、不修改输入。原始JSON/探针/日志在 `independent-canonical-cases.json`、`independent-canonical-bands-probe.gd/.log`。这验证CPU实际消费者几何，没有冒称GPU像素或素材认可。

### R4：固定0.01边界探针导致极小空隙被填（P3，确定精度缺口）

输入`Rect2(0,0,10,10)`与`Rect2(10.005,0,10,10)`，间隙0.005；`PlainsTerrainBorders.plan`用固定0.01向外探测邻域，两侧竖直边探针越过空隙落进另一个实体，从而同时删掉面对空隙的两条外边。此前矩形差集仍能保留输入空域，但新pieces_from_edges只看剩下左右最外侧竖边，扫描成一个连续实体。

独立实际Godot调用输出 `refused=false empty_gap_painted=true`，实际Polygon的authored_piece包含空隙点(10.0025,5)；引擎exit1/wrapper抛错。证据 `independent-canonical-thin-gap.gd`、`independent-canonical-thin-gap-confirmed.log`。第一版探针在free后读取art==null使refused显示失真，原日志保留；confirmed版在free前记录refused，才是准确拒绝状态，两次painted结果相同。

该问题只已证实极小输入精度边界，**未声称正式地图存在此几何或玩家已看到可见事故**。几何保持/不填空域的通用声明在此仍不成立，R4范围 **REJECT**；支持范围内348案例可通过。可在真正不支持的精度下明确拒绝并保留基线，或改为不跨空域的精确矩形区间边界提取。之后继续保留原反例复跑。不能仅把美术像素对照门槛放宽。

新手绘material及border确由ShaderMaterial绑定，但本轮没有审查其实际GPU画面、美术协调或用户接受度；仍为开发候选，不给艺术ACCEPT。历史R1/R2/R3修复证据保留；R4是后续扫描带改变暴露的新精度边界，不推翻已验证的原反例修复。

## R4修复后独立复跑：canonical几何契约限定 ACCEPT

`PlainsTerrainBorders.occupied_side`改用符号单侧极限：负方向使用min<point<=max，正方向使用min<=point<max；外侧面与四象限占用都不再跨有限距离探测。切分段仅跳非正长度，移除了.001阈值。对正尺寸轴对齐矩形，此判断保留相接和有空隙两种情况的区别；面中点另一个方向位于分段内部，零方向使用半开区间不会跨越另一个切点。没有以低精度豁免或改变物理尺寸来通过。

独立实际重跑原极小gap、原圆角/隔空隙、100条预算及348案例扫描带探针，全部Godot/wrapper exit0；`independent-canonical-precision-recheck.log`：gap refused=false、empty_gap_painted=false；whole/split=2.5，narrow/beside=.5；100条成功；**348 cases/16086 checks/0fail**。版本绑定 `independent-canonical-precision-recheck-source.json`。旧失败与错误探针诊断原件保留，confirmed失败日志仍为修复前有效证据。

**R4原精度反例关闭，新的canonical扫描带几何及已覆盖预算/孔洞/分块不变性限定ACCEPT**。这并非任意浮点尺度穷尽证明，也没有独立执行新版GPU像素对照、正式完整路线或新素材审美验收。新手绘material/border、连续画面、美术与G5仍不在本次ACCEPT中。

## 后续绘制类迁移与GPU证据限制

Polygon2D改ColorRect后的独立几何/预算复核见 `independent-colorrect-review.md`：348案例22854checks及14组预算1884checks均0fail，旧失败反例仍通过。原Polygon探针/日志保留，新增probe以实际Control.position/size验证实体几何，未只检metadata。该代码范围局部ACCEPT。

另外，旧c74e69b1 GUI日志发现WebGL INVALID_OPERATION，而checker误标passed；归档在webgl-diagnostics-failure。**旧GUI完整通过声明无效**，CPU契约通过不覆盖渲染诊断，修复成功须另有新版实际GPU日志。本报告无整体品质或艺术通过。
