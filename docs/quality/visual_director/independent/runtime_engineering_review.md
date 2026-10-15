# 实际场景工程只读审查：限定认可，黄金与最终电影未验

审查者 `/root/visual_pipeline_engineer`，2026-10-15。源码基线 `2c2904172045017037e4110323c1097f9d24c5ad` 加当前未提交工作树；必须结合同名 provenance JSON 的逐文件 SHA。本代理没有修改生产文件、启动引擎、运行测试或处理媒体；没有查看新画面像素，因此不签审美或电影可读性。本人实现的 `tools/visual_director.py` 不属于本次独立认可范围，13项该工具单测日志仅作已执行记录核查。

结论：**当前实际消费者的限定工程方向可保留；没有发现本范围内需要立即回滚的核心规则改动。黄金品质、完整覆盖与第二场景准入仍 UNVERIFIED。** 写报告时 v2 `visual_capture.json` 仍 running，虽已存在完整原生数据3951ticks/route_target_reached与33个实际观测样本，也不把未终态媒体生产者当成功。v1电影已captured，但独立像素审查明确REJECT可见画面改进；其拒绝不能被技术断言覆盖。

## 实际审阅来源

- `scripts/art/plains_visual_space.gd` SHA `a8547ade27b2691dd3f2a369f79cf667024beb6e1dff3e713b4f5f92f2f9a6b5`。
- `scripts/art/plains_region_composition.gd` SHA `a56ba99a3b3f6af93c2d57b30616d245c09de587fd5ef774540f7363976575b3`。
- family manifest SHA `e0c49ddf959f0f88cb0ad78a67038f01f111a3548277fec92718b6bd4b697b12`。
- 原v1与当前v2原生capture/raw/receipt、`space_tests/run_v89gmk6m`六次真实子进程记录、原v1独立像素REJECT记录。所有对应SHA见provenance，未使用文件名代替像素评价。

## 已核验工程事实

实际消费者是 `PlainsRegionStage → PlainsRegionScenery → PlainsRegionComposition → PlainsVisualSpace`，根据真实Manifest的 `creek_discovery.module` 找实际 assembler module、固定语义 `plains_bell_ferry_control` 和真实Platform0。仅加Node2D/Sprite2D并省去所选维修营地不合用途的背景小屋；不添加碰撞、相机、输入或奖励服务。代码没有Motor调用、资源补给、随机流消费、保存更改或玩法Manifest写操作。baseline/v1/v2原生policy basis的 **133 core及19 driver逐字节一致**。

两个正式候选PNG原字节SHA、尺寸和family声明一致。PIL重新测得alpha>=128 bbox分别为 `[18,17,988,1500]`、`[7,6,1524,998]`，与manifest一致；这是源alpha测量，不能证明GPU接缝、主体是否美观、商业许可或真正空间围合。新asset承壁用途为承壁、后壁用途为远处水工围合，没有把小石簇放大成岩壁。许可和模型仍unknown而非编造。v1承壁被旧岸遮挡的像素失败已经记录，v2将其设为不可见，并仅保存为 `inactive_nodes`；**当前raw的active nodes只有far后壁和gameplay真实dock，未把隐藏承壁算middle层或景深成功。**

当前远壁实际采用世界空间 `base + (camera_center - reference) * .12`，相机由正式viewport只读获取，造成不同于玩法层的真实相对滚动；并未移动相机。raw中相机x从−1790到5495，远壁位置随其变化，33个样本字段可复算；这不是已经证明整张随机图/任意纵向镜头覆盖。单幅后壁只局部服务溪井，本轮仍只有一个新环境深度职责，不满足完整多层黄金本身。

默认没有observer文件写出；**默认仍有读取family JSON和加载纹理的正常资产I/O**，不得写成“零文件I/O”。仅显式观察参数才收集/退出写raw，采样读取真实Node变换、RectangleShape2D、相机和纹理SHA；语义/layer/alpha bbox来源是声明，与实测世界bounds有区分。最后样本为engine physics frame3842，native3951，**不是精确terminal tick或完整逐tick观测**。

## 非阻塞修正建议与准入缺口

1. **可见后壁的根基/裁边/移镜头覆盖尚未由新反例验证。** `actual_issues()` 里前三种root/channel/attachment断言主要检查当前隐藏的旧承壁。v2新增真实 `far_wrong_scale`、`far_wrong_depth` 反例有效，但不能用前三项成功证明可见后壁基座可信或大图镜头无裁边。责任scene-composer；先看实际v2连续镜头，再只针对看见的缺陷补可证伪检查，不能添加假平台。
2. **当前wall坐标赋值依赖原点父链。** `plains_visual_space.gd:68` 在 `add_child(wall)` 前设置global_position，随后加入非原点父节点时该位置会被重新解释为local坐标。当前正式父链原点及实际anchor断言通过；wall现不可见，因此不影响当前far画面。未来启用承壁或推广到有变换父链前，应该在加入父树后设置global_position，并用真实平移父链反例验证，不能宣称跨场景坐标鲁棒。
3. **保护区观测尚不完整。** `protected_bounds()` 当前含两岸、真实船、RectangleShape2D玩家；未收集风铃/奖励箱/敌人/弹道预告或全部替代落点。far层在玩法之后可降低遮挡风险，但不能据此签这些对象的像素可读性或完整视觉覆盖。
4. **诊断输出路径只作prefix判断。** `:232` 未canonicalize `res://build/../...`，手工直接给Godot诊断参数时可逃出build前缀。当前新tool生成固定新目录路径，没有实际越界证据；普通游玩默认不写盘。后续有写窗口时可规范化并限制真实build根，不应在冻结录片期间修改。
5. **观测是采样而非全帧。** `_process` 每累计约120个engine physicsframes采样，退出复制最后样本；真实电影可能暴露两样本之间的遮挡/接缝。连续影片独审不可由33条AABB替代。省略镜像场景也有明确omission_reason，不能当所有Seed都已视觉升级。

## 既有真实反例记录核查

`build/visual_director/space_tests/run_v89gmk6m/report.json` 真实六次子进程：正例exit0、11断言0失败；detached_root/channel_intrusion/wrong_attachment/far_wrong_scale/far_wrong_depth各exit1、11断言1失败，并含对应实际issue。修改的是实际消费者Node/实际支撑引用，不是单纯编造JSON；wrapper同时检查退出码、失败数、结束标记、目标issue及无脚本错误，未通过删除原断言放行。wrapper本身不保存完整源前后快照，因此其报告单独不能认证任意未来源码；本次仅结合冻结源SHA、原生电影源inventory与实际日志理解。原四例历史报告仍保留。

当前不批准第二类空间扩展。需要当前v2终态媒体、实际像素与连续镜头独立复审，以及原质量记录中有据的G2结果；后续全适用回归、真机/性能/用户认可另列。该工程审查不构成商业美术、美感或最终任务完成声明。
