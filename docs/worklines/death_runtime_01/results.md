# 保留死亡动画的运行成本优化

基点5d3303b7，原运行源b5c7bf65、公开build9dd3a9a2ecd8。用户确认死亡瞬间和播放期间均卡。本批不改动画画面、时长、轨迹、网格密度、物理、判定、奖励、随机、存档、原图或声音；不合main。

## 实际修改

- Ground的Patrol／Charger／Hopper在死亡时复用该rig最后绘制的冻结活体顶点。姿态或air、kind、bounds、texture、点／UV内容、canonical anatomy身份改变时，沿原函数重算。死亡目标、最终Vector2.lerp、地板钳制和landing保持原运算顺序，不能直接用终态代替lerp。
- Hopper腿部IK、Sentry叶／脚关节和Fan死亡曲线／关节，在每个prepared draw只准备一次；相关尺寸／进度／Fan时钟改变会失效。Root及原静尸缓存不另造一套。
- PlainsStageVisual持有一个无uniform掉落材质，各Sprite仍独立持有纹理／颜色／透明度；死亡不逐枚分配相同ShaderMaterial。现有两个Skin测试override同步optional参数，真实App掉落和重载检查新增四项断言。

缓存仅保存本rig的值，不持有Actor／Stage；沿原canonical anatomy只读约定，不宣称支持同一个Weights对象mask原地编辑。原调用不传新optional参数时保持原计算路径。

## 已验证

| 检查 | 结果 | 范围 |
| --- | --- | --- |
| 原2ce4ffa6冻结顶点Oracle及新增失效／实际draw | 7899断言／0失败；442442顶点逐字节一致 | 六物种，原边界／任意点，Ground live→dead、air切换、恢复未完成与绑定变化 |
| 原正式motion／loot wrapper | 603／0 | 真实App致死、逐枚奖励、第二次死亡、重载和共享材质释放 |
| 原支撑／尸体保存／snapshot wrapper | 145／0、156／0、129／0 | 支撑、终态、保存与场景释放 |
| 原共享core | 5686／0 | 原完整core与预算，不代表full171 |
| 原生掉落GL对照 | 三组固定time1.25 PNG逐字相同，材质3→1、8→1 | RGBA独立、弱引用释放；软件GL，不是真机 |
| 实际draw A/A和A/B | 各1836对／3672计时draw；全部上传字节和625／0上传数合同通过 | 对称嵌套类、3轮、六物种，原mesh更新与材质参数保留 |

所有上述最终原生运行退出0，未见脚本／shader／原生ERROR、ObjectDB泄漏或退出残留资源。原断言、冻结fixture和预算均保留。原生专项在外部同字节候选上运行，core在主工作树同字节运行；不是Git-clean CI声明。

实际draw对照中，死亡持续阶段平均CPU耗时：Patrol6368→3200μs（约50%），Charger6581→2976μs（55%），Hopper7393→2853μs（61%），Sentry3813→3412μs（约10%），Fan6012→4783μs（20%）。这是含可见性、准备、缓存、顶点分配、mesh更新命令和材质参数的本机GDScript路径；测试副本仅移除最后draw_mesh，并增加对称观测。排除实际GPU绘制／AI／音频／掉落处理／浏览器／手机。

首次死亡绘制样本为death=0且命中已冻结前缀，三种Ground约降低75–78%；不等于实际致死事务整体耗时。活体约2–5%的组间差异落在A/A约±8%噪声内，不签活体收益或回归。Root未改、静尸缓存已存在，不将其计时噪声当优化。原始每样本计时与数量／字节反证见[证据](../../evidence/death_runtime_01/development/draw-bench/summary.json)。

## 保留的失败与边界

早期全Ground死亡几何缓存对便宜种类无稳定收益，已弃用，保留原微基准；只采用Hopper几何准备和后续真实消费者前缀缓存。首次基准外部类解析、自对照类名Skin冲突、原生掉落未固定时刻等失败均保留，未放宽预算或重写旧PASS。

原Web baseline首掉落确有LOOT lit／unlit编译并绘制。但两次浏览器诊断受worker观测阻塞／120秒预算限制，candidate和第二次spawn未运行。额外预热没有采用；不据此归因全部死亡卡顿，也不宣称首掉落编译已消失。完整原件及[独审](../../evidence/death_runtime_01/development/loot-shared-review.md)可审。

手机Chrome实机帧时和用户手感仍待验证。不把CPU局部收益当整帧FPS或“全部卡顿解决”。回退源码与技术绑定须整体回到5d3303b7；公开旧prepared2f0b308952145b4f8f522b10925782e4ae21f3ac／build9dd3a9a2ecd8保持可恢复。


## 本批发布

冻结运行源 `10dcd39abd8dd8be57cf838167989dd0ca93502b`（生产修改d8c9686c，后续仅文档／证据）。style34／creative37仅五GD技术重绑；current46／history52／creative31及两binder通过，旧94＋30方法／断言／预算和失败保留。另有docs／structure／quality／architecture四项fresh通过；非新full171／Windows。原修改已分区非作者独审。

由于本批改变Foundry现行basis，实际执行原`foundry.py build --count24 --promote`：36开发短句及18连续itineraries通过，随后原export stamp／Web导出／闭包／完整重建均通过，未手改basis或复用过期池。导出前SourceRoot按精确F clean核验；导出后明确56个新验证派生输入，其余全部Git源字节保持，每个派生输入又对实际PCK核SHA。不是CI API ZIP或Git-clean导出后声明。

- build `58ef14b41f57`，PCK216399188字节；完整SHA `58ef14b41f5740d32ed5ffe8d07f29a147cf1cb58af9ce239e4d6b860f456f86`。
- prepared `29a4edd5f7851b689effdf481d9006e238f3e585`；Pages[41453285376](https://github.com/zhipijun1996/gunman-rush/actions/runs/41453285376)成功。
- 原公开验证器及独立完整64位SHA流式核验通过，metadata前后稳定；空目录实际PCK原13项通过，严格ERROR／泄漏守门。
- [公开试玩](https://zhipijun1996.github.io/gunman-rush/?v=58ef14b41f57)真实Title→Home→出发门→BEGIN→正式Plains→D200ms输入通过，204.287秒／原300秒。13张截图逐张核验，最后仍在初始地面；无观察器／状态注入／FPS04，browser已关闭。favicon404与Emscripten提示保留。这只签入口／输入，不签新死亡性能或手机FPS。

最终运行源与八个已测GD的Git匹配证明、原失败、逐样本CPU数据和公开身份见[开发证据](../../evidence/death_runtime_01/development/README.md)、[公开GUI](../../evidence/death_runtime_01/gui/public01/summary.json)和[完整公开SHA](../../evidence/death_runtime_01/build/public-full-sha.json)。下次先收手机Chrome的首次死亡／连续击杀反馈或帧时，再决定是否针对首次LOOT程序编译／实际GPU提交补证；不继续凭猜测改网格、声音或规则。Root未改、Sentry首次death=0计时约慢9%的样本保留，不宣称所有物种每一帧均加速。

本机导入缓存仅复用已核的`/tmp/gunman-first-use-web-source/.godot/imported`，主树`.godot/imported`为ignored局部软链接，避免再复制355MB。运行/发布没有源码或素材软链接。旧9dd PCK另以hardlink保存在`/tmp/death-runtime-01/baseline/`，全SHA已核；诊断PCK删除前逐一精确重建核SHA，原日志／输入保留。公开回退仍为前述2f0b3089，源码须成组回退5d3303b7。
