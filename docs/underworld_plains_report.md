# Underworld 正式风铃平原生产结果

> 下文记录冻结F版本；用户随后提出的六项反馈正在revision2中实施。F试玩地址不包含新动作、家园与UI返工。当前工作进度见[revision2规格](evidence/underworld_plains/revision2/spec.md)，新结果将以新运行源与build另列。

任务 `UNDERWORLD-PLAINS-01`；开发基线 `8382a41cb0ccf9a8e2e56075ade9edaceb4ff67a`，最终运行源 `a44b856e1730e81ed74aa5eb1c8999e8d2bb8ff2`，Web build `4b01de439c24`。分支 `feature/underworld-plains-production`；本轮不合并main。后续证据/文档提交不冒称重新导出。

## 实际改动

普通标题入口的风铃平原两张正式地图整体接入Underworld：原生暗色岩床、薄苔亮缘、同族角色/敌人/两Boss/拾取与交互物、三张独立景层、风架/断钟拱/修理棚/溪谷远井架。原五风格与Underworld/Cavern三地区实验入口保留。不是只加一张概念图或孤立演示场。

保留原布局、碰撞、Motor、武器/资源/伤害、随机流与存档。非整格几何不吸附到网格：完全成立的内部格子使用永久TileSet/TileMapLayer，边界使用同源像素的精确并集适配。正式两图核心TileMap覆盖约39.9–48.4%实体面积，实际地形用3–5个atlas格与11–13种边界角色；完整47索引/原生画片可用，不声称现有地图已经消费全部47态，也不冒称整张地图转为完整47或dual-grid。

荆棘成为平台的表层材质：根部嵌入8wu，四向端片/中段/安全接头使用同源暗石+真实生成刺材。外侧原hurt band、damage、无敌窗与实体不变；没有新增悬浮刺台或底座。原无支撑落坑仍是落坑，不靠添加实体救画面。

## 可复用生产方式

完整操作见[Underworld Tile生产流程](underworld_tile_production.md)。5份Skills当前入口与7个Harness检查共用真实production manifest。

- 参考：保留发布页/许可/原件/SHA，先看原生16px及边/角/填充/留白，登记逐片裁切配方。Underworld为作者自定义允许使用条款，不标CC0。
- 生成：真实imagegen生成材料母版或完整物件，保留提示词、参考/原图及未知成本；裁切和nearest尺寸适配明确记录。先代表块与接口组合黄金，再完整家族，不让模型负责精确47网格。
- 关卡：先真实实体占用/语义、模块halo与端口，再统一求邻接；solid/one-way/moving分别处理。装饰独立seed，先槽位和keepout后变体。
- 背景：远/中/近三张不同原图，实际相机screen center驱动；x系数0.035/0.12/0.28、y系数0.015/0.04/0.075（屏幕像素/相机世界单位）。远层交替镜像重复，中近层同向重叠透明边；竖向限幅与覆盖独立检查。不是同一张图三次透明度。
- 装饰：近处地标有真实平台根扇与射线支撑；溪谷井架为完整石基的冷灰远建筑，无碰撞/standing_edge/物理支撑声明，整幅避让功能keepout，不混称grounded。

16区统一像素尺度、暗体/亮边语法、光向、接口和读图规则；每区分别生产材料、色域、生态与地标。后续荆棘森林制作树皮/根皮/藤蔓族，齿轮工城制作金属/铆接/齿轮族；不能把平原岩石改色当完成新地区。本轮只正式迁移平原，其余地区不冒称已开放。

## 验证与交付

- [实际截图总览](evidence/underworld_plains/overview_f_a44b.png)及原尺寸两图定位截图；位置夹具与自然操作分开。
- 运行源F注册7项Underworld fresh检查全部通过，无缓存；[原报告](evidence/underworld_plains/verification/final_f_a44b/report.json)。实际导出插件新80/0+原28/0、Python新5/原2均独立复测通过。冻结E注册9项fresh检查全部通过（6个新专项+核心5676/0+原Pixel地形2097/0+保留的风格实验），source guard稳定。[原报告](evidence/underworld_plains/verification/final_e_8653/report.json)。
- 原场景检查8条真实路线全部到达目标，59/0，正例138.157秒；10实际错误节点和12证据损坏均被拒绝，原180秒时限/断言未降。[原件](evidence/underworld_plains/verification/original_scene_e_8653/receipt.json)。这是E真实路线；E→F947个既有collector路径逐字节一致，新增1个export-only测试后集合为948项，不能称整个集合完全相同或把E路线重标F。
- 正式10rootseed×2地图，40374/0几何与Boss断地刷新；四身份20/20，77真实grounded物件/77 StaticBody根射线、17近井、20非物理远井。429/0景层与支持/keepout；281/0真实伤害接触，四方向技术夹具均有源；正式随机样本只实际出现top/left，不能称随机全向覆盖。
- [不同作者限界独审](evidence/underworld_plains/independent_review/formal_e_8653/report.json)ACCEPT，30张E原尺寸图逐张实看。C三段各8秒动作素材保持C源；相关演员/地形/危险/背景家族到E逐字节不变，不把旧片重标E，完整Boss阶段与完整听音未签。
- [试玩](https://zhipijun1996.github.io/gunman-rush/?plains=1&v=4b01de439c24)：公开F PCK **132,559,084字节**，完整SHA256 `4b01de439c241004d9148bf5958de524d14dda3ae5bc56b67c2731312856b46c` 与冻结本地完全一致，12份许可逐文件相同。Pages运行[39248153645](https://github.com/zhipijun1996/gunman-rush/actions/runs/39248153645)成功，准确运行源F、prepared `428353bb8961180d2394c31335bb1f363702bbcb`。普通标题鼠标进入、真实角色移动/原地Space起跳及回台、map2定位与保留实验入口已实际浏览器验证，无脚本/着色器/资源HTTP错误，三层原图SHA均实际非空且与源PNG一致。
- 浏览器动作按实际画面区分起跳、跨缝、落地与坠落。旧driver文件名after-landing不代签落地；定位图和像素差不代签Motor路线。E本地成功视频、E公开早跳落缝与F原件均分别保留，不能互相替代。
- 完整docs/art/gameplay/web共76项：原60秒超时保留，后续原87生产流程测试46.569秒通过、原31关卡合同51.657秒通过；[30项通过后的原wood失败](evidence/underworld_plains/verification/full_f_before_wood_adapter/report.json)保留。旧wood测试将新默认Node2D当成旧shader节点导致空引用；已仅适配测试，在两张正式地图分别检查实际默认与显式legacy replay，原shader/scale/outline/碰撞、GPU端点/平移阈值和负控保留。原wrapper headless4533/0、GPU4546/0、legacy-strip exit1/7fail、两个错误renderer guard exit1/2fail且无脚本中止；[原件与说明](evidence/underworld_plains/verification/wood_adapter/README.md)。最终完整复试另列，不能把前30项当全76通过。


原D随机独审暴露4/20修理棚缺失，保留UW-G3-04 REJECT。追加完整修理棚64/56wu合法尺寸后，新专项20cases21127/0，四身份/实际sprite/真实StaticBody射线/原whole bounds+8 keepout均实测，已挂入underworld-scenery；不是改metadata凑身份，也不是放宽净空。两条历史证据指向会变化的共享文件，已从确切Git提交恢复命中原expected SHA的不可变快照，只修路径/来源、不改原哈希或验收状态，经独审确认；原失败报告与before记录保留。

E Web包实际ctex与画面正确，但三张原PNG未被打包，诊断SHA为空；失败原件保留。F复用现有runtime_raw_export插件，仅补7个真实源PNG并保留正常导入；实际PCK7原件SHA与33ctex闭包、浏览器3非空原图SHA分别核对。F游戏、美术、玩法源码相对E逐字节未变，导出修复不冒称重新绘图。

原F身份窗口map2首次截图完成但退出有ObjectDB/资源警告，原source_binding/日志保留；同一fixture仅加--verbose独立复采8窗严格干净，原图未覆盖。两次范围分别记录，不把exit0直接当无资源问题。

后续完整回归的工作区只在 `tests/wood_platform_runner.gd` 有明确test-only适配差异，运行游戏/美术/export均逐字节为F。完整报告保留实际diff与输入摘要；E→committedF的947路径历史比较不能外推到当前测试工作区。已部署F与F媒体标签不改。

## 实际边界

技术回归与限定独审不代签用户审美、商业品质和实体设备。演员目前为状态驱动pose/叠层，不是完整逐帧手绘动画。动态证据覆盖已记录走跳/开火与Boss前段；完整所有Boss阶段/听音、手机实机可读性与性能、任意最差地形仍未验证。静态定位图明确不是自然路线通关。
