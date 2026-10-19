# Underworld 第二轮：六项试玩反馈

游戏运行源为 `c65a111015d032211bb8c54aaae9b322401349d4`（G），Web build为 `6b3093b929c0`。试玩：[标题页](https://zhipijun1996.github.io/gunman-rush/?v=6b3093b929c0)，可进入风铃平原和家园。H `8dfef50ee902f7c0726764d41d0480f2df46ea18` 只补真实输入录像的左跑采样长度与Home录影时限；后续 `8972f92f` 只更新扩展审计的Harness时限与依赖。这两个提交的全部游戏代码、场景、配置、资源、图片、着色器及导出设置与G逐字节相同。影片仍保留H生产者标签。

| 用户反馈 | 实际修改 | 可查看的结果 |
| --- | --- | --- |
| 动作帧不足、没有左走 | 20个真实生成身体关键帧；跑动8帧，待机/起跳/下落/落地/受伤/死亡各2帧；左右镜像，身体与瞄准分层 | [正式关卡真实键鼠影片](actual_input_h/formal/movie.mp4)、[真实轨迹](actual_input_h/formal/trace.json) |
| 移动平台画风不统一 | 同族暗石、旧木、苔绿和黄铜材质，端头与长宽独立拼接；纹理持续持有，修复GPU纯白块 | [原生材质目录](mechanisms_g/material_catalog.png)、[实际接受射击/移动状态](mechanisms_g/feedback_gpu_runtime.json) |
| 商人大小 | 与人物共享44世界单位的实际站姿身高，保持源宽高比 | [地图1同岸比较](formal_g/map1_merchant_standing_comparison.png)、[地图2同岸比较](formal_g/map2_merchant_standing_comparison.png)、[14项实际比较](formal_g/merchant_standing_comparison.json) |
| 风铃机关画风 | 主铃、序列第二铃、返程铃复用同族图；接受事件驱动摆动、短闪与局部反馈 | [103帧原始反馈记录](mechanisms_g/feedback_frames.json)、[来源绑定](mechanisms_gpu_G_binding.json) |
| 家园重设计 | 同族Tile与三层景深的3520wu安全聚落；四个原入口、八个明确预留站位；修复新旧身体叠画 | [完整十二站往返影片](actual_input_h/home/movie.mp4)、[十二站/四服务轨迹](actual_input_h/home/trace.json) |
| UI与菜单 | 共用原生Theme、声明的Underworld Tile九宫框、18个真实生成物品图标；覆盖标题/设置/HUD/地图/暂停/商店/奖励/触屏等 | [标题](ui_g/title.png)、[商店类样板](ui_g/shop.png)、[地图实际入口](ui_g/actual_fog_map.png)、[消费者清单](ui_g/ui_inventory.json) |

[四窗实机对照](overview.png) · [公开包与GUI交付](../delivery/source_G_c65a/README.md) · [独立限定审查](independent_review/final_g_h_limited_review.json)

## 验证范围

正式关卡H影片540条post-draw观察、546个实际电影帧、9.1秒、18/0；Home1961条观察、1967帧、32.783秒、52/0。真实InputEventKey/Mouse经原适配器、Router和Motor，不改玩家位置或注入资源；Home十二站东西往返、四原ID各一次、八预留无业务请求。两片所有1057来源文件前后相同、生命保持5、枪口与原权威节点一致。MP4正常播放60fps；本机软件录影仅约15–17%实时速度，不能据此签设备帧率。MovieMaker音轨有非零混音，Dummy输出不代听音/实体声卡验收。

G两图20张定位图、追加两图商人同岸比较14/0、Home四窗101/0、新机制GPU1254/0均有实际输出。定位检查明确不是自然通关，商人初始定位图两身体重叠不适合比较，追加图才是站姿尺寸依据。UI原命令隔离复试265/0、22图干净；前一次地图点击失败并出现canvas空引用，原失败保留，原因未验证。G的公开完整PCK为139,618,488字节，SHA256 `6b3093b929c062222e5f7b3b9313974fe79d03e4114a42bc6f26e41c5e19392a`；12份公开许可与源相同。最新[12项fresh报告](verification/targeted_12_I/report.json)全部通过（source I，380.153秒、无缓存）。[原HomeApp/HomeUI复核](verification/revision2_original_home_final.log)：19/0干净；27/0功能通过但退出197资源/285对象泄漏，strict FAIL。实际本地7项/公开8项GUI通过，Pages39263060977/1成功；不把包校验当操作或审美验收。

## 已保留的问题

- 原独立 `home_ui_tests.gd` 的27条功能断言通过，但严格退出资源守门失败。正常App的Home专项、连续往返和UI返回检查可干净退出；不能互相代替。所有无完整修复证据的运行时/测试探针均已撤回，旧测试断言未删。受控旧Home代码在当前其他依赖下也有资源告警；这不是精确全F基线，不能据此宣称已证明旧版本同因。
- UI地图点击曾间歇失败，隔离同命令通过；并发、生命状态和动态命中仅是待证假设。完整CI的generated-consumers失败使自动Pages跳过，新预览使用既有prepared流程与严格包闭包验证；不宣称完整回归全绿。
- `viewport_720x1280` 是请求窗口，实际Godot逻辑视口保持1280×720、截图720×405，未通过纵屏重排或手机实机验收。完整Boss阶段、全部状态×朝向画面、目标设备性能、用户对本版最终审美与手感均未签。

## 生产方式与证据

[Tile生产流程](../../../underworld_tile_production.md)包含许可/参考、母版与裁切、真实TileSet/TileMap、三层不同相机速率、装饰根基、融合伤害、人物/NPC比例、Home与UI的共享合同。新增四个原生Harness检查与原七项并存；来源/组装审计扩为869检查，107测试保留原55反例并新增52反例，时限根据实际63.4秒扩为180秒。

[来源别名表](artifact_aliases.json)映射原build路径与这里的逐字节副本。原始回执中的路径和源标签不改；原AVI仍在build，正常速度MP4、轨迹和选帧保存在这里。G短左跑采样失败、白块材质失败、UI地图失败与退出资源探针均保留；原F许可/截图/审查不重标本轮。16区仍共享画法/接口、分别生产色域与材料；本轮未开放森林、工城或其他新区域。


## 最终文档与审计收口

`docs --release --jobs 1` 实际22/22项通过，整体状态 `passed`，见[原始报告](verification/docs_profile_serial_I/report.json)。执行时冻结工作文件的SHA保留在报告中；后续仅追加文档/证据封装。188项资产源Hash与元数据检查通过。最初并行文档运行在创建临时Git克隆时失败，0检查执行：partial clone历史缺少promisor对象；原件见[克隆失败](verification/docs_profile_parallel_clone_failure/report.json)。串行走原Harness入口，不改检查合同。

[差异审计](verification/revision2_quality_diff_after.log)仍失败：旧`plains_connected_landscape.gd`引用目录 `res://assets/production_repair/`，现审计缺有限目录适配；该行在开发基线8382a41已经存在。已补本轮准确affected_paths与逐文件源/运行/处理记录，剩余此审计阻塞未豁免。不把技术专项通过写为全部发布守门通过。
