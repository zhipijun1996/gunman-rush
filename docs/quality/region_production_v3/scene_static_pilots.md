# V3 独立空间静态 pilot

任务 `V3-SCENE-01`，作者 `/root/v3_scene_engineer`，基线 `ebcf348312b2e128e51b8c5b684e402b3a565de0`。状态为可运行候选，独立像素/动态/设备/用户认可未验。采用 scene-composer、visual-director、art-director、animation-vfx、region-generator；保留 PlayerMotor、正式路线、碰撞、相机、资源、能力成长、RNG 与保存。

`PlainsRegionStage → PlainsRegionScenery → PlainsRegionComposition → PlainsSemanticLandscape` 已直接消费两件独立原始图。旧 `PlainsVisualSpace` 与其原 `nodes`/断言保留；其采集 raw/samples 新增 `semantic_landscape` 字段，测量真实 Sprite、全局 bounds、有效 z、原图 SHA、支撑成员、根与相机。没有借文件名/层数宣称可见体量。

## 构图与用途

| 代表位 | 实际大形与观看用途 | 原始约束与本轮使用 |
| --- | --- | --- |
| meadow area_1_1 左侧主路观察岸 | 低斜石灰岩后崖；保留旧小风车作次导航，轮廓不靠新增小花数量 | 岩肩源1862×845，原近岸宽高规格失败；仅620世界宽后崖，完整原图、depth0、禁止镜像，不作190高近岸接合件 |
| repair area_2_1 左侧真实接收岸 | 完整屋檐、塔翼、墙与基础，归来时可见营地建筑；商人仍是既有前景交互 | 建筑源1536×1024；canonical500记录不改，本轮完整等比330世界宽；不裁基础，不把整屋旋转作风车翼 |
| clock/其余 creek/教程/Boss/高奖 | 保留基线画面，明确尚无新家族覆盖 | 不用旧拱门/石簇放大补缺；旧失败溪谷不阻塞上述独立族 |

地图1实测建筑根 `(2671.667,21)`，实体支撑并集 `[2520,18,320,32]`；地图2根 `(2391.667,21)`，并集 `[2140,18,420,32]`。营地本体实际是单向平台，因此首380宽建筑试验被真实支持筛选拒绝（失败保留）。当前330宽的保守基脚约305.98世界单位，落在营地左侧真正相接的静态石岸，而非在单向桥下画假岩根。屋檐可出挑，基础完整。

岩肩地图1根 `(1245.830,21)`、地图2根 `(865.830,21)`；对应980宽真实静态并集。是否被地形遮蔽、是否形成假可踏斜边，必须看正式像素；Node.visible=true不等于画面改善。

## 支撑、景层、保护与生命周期

- 读取实际 module RectangleShape2D；跳过 one_way 与 floating_solid_indices。只合并同高且真正相接/重叠的实体，不跨空隙；记录每个成员真实 NodePath/bounds。故意移动实际支撑实体会触发诊断。
- 两族每图各最多1个实例。Scenery(-10)+Composition(-5)+Landscape(8) => effective z=-7，位于正式地形(-1)和角色之后。完整源图 RGB 可作低饱和退远，源 alpha/轮廓不变。
- grounded 根均depth0；相机移动不带走地基。代码的相机响应/测量由真实 consumer 执行，尚无新远层视差素材准入，不能称本轮已完成多层动态景深。
- 输入原 Scenery.protection 的危险、落点、船扫掠、门铃、奖励、敌人、商人保护区，所有中景 AABB 相交保留为像素审查候选；near 相交候选拒绝。AABB不是实际alpha遮挡结论。
- 仅实际创建成功的区域替换旧 Composition 道具；营地旧小石堆不再作为地标，草甸小风车仍作次焦点。缺图/错SHA/无支撑则省略该族并保留旧画面。
- 素材及家族记录只读；不消费 RNG，不修改 Manifest，不写保存，没有粒子/音频/计时回调。实例随 stage 释放，process继承PAUSABLE；当前仅同步锚点，不新增风场空框架。
- 动态仍未准入：原图风车翼烘焙在整屋内，不能摇整屋冒动画；未来需正确分离翼、草/布/藤真实根或挂点，静态独审后才能接局部共享风相位。音频没有新增来源，保持未验。

## 已实际执行的技术证据

全部引擎通过 `GODOT_BIN=/workspace/gunman-rush/build/region_production_v3/godot_locked.sh LP_NUM_THREADS=1`，未加外层同锁。

| 检查 | 结果与限制 |
| --- | --- |
| editor import | 两次实际完成，无脚本/Shader解析错误；第二次包含冻结的新原图 |
| 新正式两图消费者 | 71断言0失败；故意guard反例72断言1失败且exit1，wrapper正确拒绝；718份runtime/driver来源前后相同 |
| 新实际节点反例 | 每族移动根、非等比拉伸、前景错误层、错贴图、移动真实支撑，均被诊断；恢复后干净；平移父节点不改变世界锚 |
| 原 visual-director-space | 原12组正反/平移例及实际独立GPU shader probe通过，旧断言未删改 |
| 原 terrain-production | 240断言0失败，正式地形与相机/碰撞路径未改 |
| Python编译/whitespace | 通过 |

首个新消费者报告 `build/directed-space-7cldrrgn/`、补充支持邻域失败 `build/directed-space-ewjki1pr/`保留，不追认成成功。最终新套件 `build/directed-space-a4fja60a/`；原完整space `build/visual_director/space_tests/run_ehgi1xkr/`；terrain日志在原implement租约目录。

退出有 ObjectDB/resource 警告：新两图套件8 ObjectDB/4 resource，terrain12/4，尚未归因；保留原日志，不签生命周期/性能通过。完整来源与便携技术原件见 `docs/evidence/region_production_v3/scene/technical/`。正常速度正式影片、三观看窗口、halo/遮蔽/假落点/UI/预告像素与独立审美由父宿主排队采集、不同作者审查，本作者不签自己的美术验收。

## 准入与返工条件

静态三个观看窗口必须实际看见可识别体量、完整基脚和可信层次，同时下一落点、敌预告、船/门/奖励/HUD可读。若岩肩被旧地形完全盖住则拒绝该用途；若建筑脚悬空/半透明背景明显则回资产或锚点；不能靠调色反复冒称补大形。单族失败不删除别族进展，连续两次无实质进展停止该方向。当前只提供两图各一pilot的有限技术集成证据，不外推全区/三家族/整局/动态/真机完成。
