# 第一轮结果与交接

已完成有限的真实装载接入：main基点 `30e36c9abe223f26e666ceaf796e3fe9cb58e10f`；`feature/mapgen-host-v2-01`。当前可审查实现为冻结map→Provider→现有LevelPlan→专属Stage→原LevelRuntime，整套旧App没有复制；原player/services/碰撞装配和普通地图不变。

新增文件职责：

| 文件 | 唯一职责 |
| --- | --- |
| `game/world/levels/providers/runtime_map_v2_provider.gd` | 已物化选中内容准入/转换，纯数据、明确拒绝未支持内容 |
| `game/world/levels/content/runtime_map_ellipse_definition.gd` | 已有MovingPlatform Resource的源协议轨迹子类，保持原phase/精度/x_sign |
| `experiments/generation/runtime_map_frozen_source.gd` | 开发冻结JSON文件读取、六成员SHA锁；与未来算法返回Dictionary共用Provider协议 |
| `experiments/generation/runtime_map_slice_stage.gd` | 一张受控地图的原Runtime装配、伤害注入及原时钟/visited状态 |
| `experiments/generation/runtime_map_slice.gd` 和 `entries/runtime_map_v2_slice.tscn` | 独立明确标识的开发入口，组合原RunComposition/RunSession/输入/表现/音频/生命周期 |
| `resources/levels/mapgen_host_v2_01/` | 完整原map、三实例原content、选择与host-only出生绑定及输入锁 |
| `tests/runtime_map_v2_runner.gd` | 真实Motor跨接缝、平台骑乘、唯一几何/服务、恢复/取消/退出及输入负例 |
| 原Harness/impact/planner及其测试4文件 | 新专项注册和有限准确输入routing，不引入第二套CI权威 |

本轮首次官方Python生成PASS；真实Godot专项150/0、原LevelPlan146/0、RunSession61/0、架构13/0、planner49/0。命令、用时、实际源SHA和所有开发失败见[证据](../../evidence/mapgen_host_v2_01/README.md)。新增专项追加到原full171为172（parallel92+serial80），原219 check定义、预算、原顺序和历史断言保留；新增有限资源邻项未知仍full。没有声称远端完整172、Web或手机已通过。

必须保留的边界：

- 真实M16/M18/M21全部内容装入、C027/C030走过、原ellipse骑乘成功；C031仅静态核，切割边未封。不是整图可玩证明。
- 未支持非空wall/hazard/thorn/saw/hook/latch/enemy/reward/HQ及非ellipse轨迹等内容；完整地图当前会拒绝。源数据逐实例清单在证据ZIP，不靠删除内容装全图。
- 全图出生/Boss绑定与完成未解决；能力snapshot不完整，官方请求grapple不代表当前切片玩家获授grapple。
- 正式App/Stage对legacy_generated、记录和恢复的实际依赖尚未迁移。map_hash不是包含host bindings/独立content的完整重放指纹。
- 当前原生FileAccess路径没有新增到Web原始JSON include；没有Web包、浏览器、GPU/GUI、手机或发布证据。Python绝不进入游戏运行时。

第二轮按[上游要求](upstream_requirements.md)推进：先物化机制/敌人/奖励与稳定状态消费者、spawn/Boss/真实能力快照，再正式App的源专属记录与恢复；独立完成算法包运行时接口/有界调度/取消，最后才切正常出发及Web验收。接收正式参考包时按现v2替换输入，不重写协议、不在宿主复制算法。

回退锚点为本轮main基点30e36c9a，新增运行实现、fixtures、专项和4文件CI注册整体成组撤销。此次仅交付技术stage与PR，质量保持review，不自动合main、不发布，也不把局部技术通过签成完整内容或设备认可。


本地全局docs/quality/structure因稀疏缺旧归档/证据/preview返回失败，输入预检显示3777文件约3.19GB，未在低磁盘工作区强行物化；原诊断保留，不称全局门通过。本任务stage检查明确 `scope_complete=true/content_complete=false`，实际base的quality diff已通过；远端完整CI仍应据精确PR head核。工具补跑的文档漂移拒绝、任务元数据拒绝及新专项artifact路径单文件遗漏均保留，最后只作必要局部修复/复验。


最终归档修复的原Harness fresh补验：native150、planner49、Harness91及Web资源合同全部通过；实际artifact原JSON与原件SHA/长度一致。技术测试合计7个不同专项，不是full172；目录声明修复及对应断言另经非作者窄审，原候选错误和旧审查不追签。来源与命令见证据 `final-harness/report.json`、`artifact-verification.json`。
