# 地形与材质系统

- task_id：TERRAIN-MATERIAL-01。授权：分析用户提供的TileSet设计，融入现行文档并实施；用户追加要求旧房尽量迁移到新实现。本次交付主游戏统一实现与44房迁移，不包含独立编辑器仓库的专用笔刷UI或公开部署。
- 基线：`4f2bb5e41573e930603789c64b52a0c15a6a3dc4`；分支：`codex/terrain-material-system`。源码身份以该分支提交／PR为准；本机完整PCK内容版本 `1660bb0eba5b83e3c32bab3311406c3afa29dc66f5b799dc2e91973c1a025fff`。负责人：Codex；无外部依赖PR。
- 写集：地形表现、44房外观协议及旧手工接缝清理、材质配置／重打包素材、编辑目录与发行校验、相关回归、现行文档和本交接。物理／伤害／进度规则及原关卡几何未修改。

## 分析与取舍

原设计方向合理：实体拓扑、主体材质、外露表面、内部接缝和危险权威分开。现有UnderworldTerrain已经具备47核心、矩形并集及多边形适配；主要缺口是草土／砌体分开求轮廓、区域换材分散、手工过渡依赖坐标、整层上移在混材时错缝。16区原生47素材已存在，无需重画整套。

采用共享几何＋材质分区；明确覆盖优先级及稳定ID、未知输入拒绝、未登记配对的确定硬接缝、危险条的唯一权威与旧房兼容。原文九个模块是职责划分，不机械新增九个管理器：复用Blob47Rules、UnderworldTerrain和原危险绘制，新增真实消费者所需的配置、合成和解析组件。

长期约束集中到[地形与材质](../../../bible/terrain_materials.md)，Visual Bible只引用并保留视觉／场所标准；字段及编辑事务归[编辑协议](../../../data/world/editor_protocol.md)，边界归架构，真实入口与命令归模块导航。未将“有素材”“导入成功”“用户认可”混为同一状态。

## 实际实现与迁移

- 全部44个已编写房间显式使用 `terrain_paint.version=1`，正式静态地形统一由TerrainComposer装配。旧砌体标记、masonry_region和区域默认经同一桥接解释；保留旧实体ID与碰撞数组，便于现有编辑草稿继续往返。
- 16区＋mill_masonry共17个材质注册；原平原像素不重画，其余15区按原生RGBA机械重打包，来源与SHA写入现有区域清单。
- 47邻接只看占用；所有材质共享实体边与洞口。安全完整格仍用TileMapLayer，非整格及多边形用精确适配。视觉TileMap碰撞关闭，避免重复物理。
- 材质区域覆盖与四向裸露／材质表面，按priority和稳定ID裁剪。地刺条根平面推导裸露区，原WorldSpikeArt负责四向首中尾；不复制危险数据。顶饰在外露边采样及有限覆盖，不再整体挪动材质分区。
- 草土／砌体竖向接触复用现有过渡像素并裁到两侧真实材质范围；其它配对／方向用明确硬接缝。P02、P18、P27、P33共5条手工接缝删除。退役无消费者的PlainsMaterialTransition、RegionThresholdMaterial和专用砌体换皮器，独立机关／隐藏遮罩改用注册表，仍保留自身生命周期。
- `replace_paint`复用共享几何及未变材质分区节点，相同输入不重建，错误输入保持旧结果；当前粒度是材质分区，尚非空间分块增量。更换几何重建并集。风材质引用改为弱引用，防止连续编辑保留已替换资源。

## 共享接口

生产者：schema2房间root.properties的可选terrain_paint、旧工作台草稿；消费者：WorldRoomDocument／WorldRoomDraft、FixedWorldRoom、组件目录导出、正式及隔离运行包。单写者为本任务。版本1支持整数seed、矩形regions和四向surfaces；未知版本／字段／材质／重复ID／非法区间拒绝。编辑副本校验成功后才提交，取消不写源。独立编辑器可保留完整属性并通过同版运行包预览，专用笔刷UI未在该仓库实施。

发行包明确携带新注册表。原生拒绝清单此前误拒已成为运行权威的房间JSON，现仅放行清单选中的确切正式房间，仍拒绝世界设计源、V-R12及未知房间。P01入口测试改为比较解析后的Rect2，修复JSON数值类型导致的错误失败，未改变其坐标或标准。

## 检查与观察

以下命令均退出0；运行引擎为项目锁定的4.7.2 gunman-sd1，不使用环境预装4.6.3代替。

- `python3 tools/ci.py`：project／import／smoke／contracts四项通过。
- `python3 tools/run_terrain_material_tests.py`：538断言、44房；覆盖256→47、共享异材质边、非整格／多边形面积、四向表面、拒绝输入、数据往返、相同输入无重建、未变分区保留及几何／危险不变。仅合成计时约几十至数百毫秒，不作为目标设备帧时间。
- `tools/world/export_editor_documents.gd`：44房完整往返；`export_editor_project.py`：309房／409连接；`tests/world/editor_documents.gd`：186断言及真实正式入口／编辑预览；`tests/test_editor_protocol.py`：3项通过。
- `tests/world/station_exit_art.gd`：入口砌体、同源编解码、真实下穿及安全落地通过；`tests/underworld_plains/test_underworld_terrain.gd`：239900项原精确几何覆盖通过。
- `python3 tools/art/bake_region_thresholds.py --verify`：15区重打包像素与SHA通过；`tests/test_native_release.py`：4项，含严格拒绝世界源／非发行房间。
- 实际发行PCK：核对1378资源／149原始数据，空目录 `native_pack_probe.gd` 装载43正式房，0失败；未发布该包。
- `python3 tools/check_docs.py` 与 `git diff --check`：通过。

真实Godot窗口检查P05、P18、P33、F01同机位前后，草尖、材质体量与区域灯光保持可辨；另看诊断图中的三格地刺、混材接触、洞口／薄柱、非整格斜坡、上下分层和16区样片。初次发现草尖裁平后补回外露覆盖并重拍。诊断图是技术拼装，不冒充完成房间或用户美术认可。6秒原速镜头横移检查覆盖稳定；未声明完整战斗、连续全图通关或实体设备性能。

临时证据位于 `build/terrain-materials/`：before／after四房截图、diagnostic.png、motion.mp4、contracts.log、ci.log、pack.log及本机game.pck。媒体未入Git；可用 `tests/world/plains_capture.gd` 和 `tests/world/terrain_materials_preview.gd`（加`--motion`）在真实显示环境重建，打包命令沿现有发行工具。工程与诊断入口随源码保留，不能把会话临时文件声称为长期在线媒体。

## 已知边界与下一动作

本轮完成主游戏系统与旧房迁移，尚未制作独立苔藓／冰刺／腐化等全套覆盖素材，未登记方向采用硬接缝；四向覆盖不支持任意斜边专用饰面。多边形房间沿精确适配而非完整格全面批处理；增量更新当前按材质分区，空间分块优化需结合实际设备测量。独立编辑器笔刷UI和运行包同步发布应在相应仓库／发行任务继续，不把仅主游戏协议导出称为已部署。

下一动作：审阅本分支PR；需要扩充表面资源时先登记素材与来源，再用同一诊断及代表房复验；需要正式试玩时以本提交重新导出并按发布授权执行。无需重做44房几何。
