# 平原 Boss 当前交接

本轮根据用户反馈修正牧风者转身、前扑／后跳前摇和空中姿态。保持三阶段生命配置与高跃穿身反制；动作数值唯一归 [动作资源](../../../../resources/bosses/windkeeper_storm.tres)，玩家可见行为归 [牧风者规范](../../../data/bosses/windkeeper.md)。

接续 [PR144](https://github.com/zhipijun1996/gunman-rush/pull/144)，分支 `art/plains-enemy-static-pr142`，基线 `28f4a95dda559a486fe174b178756e1daad7c178`，运行源码 `efcd167fe3688d0dad71008a256b6c21ba938873`。后续提交仅更新交接。改动为动作时长、骨骼姿态、共享投影中的牧风者分支、固定素材区域绑定、专项和录制。所有源 PNG 保持现有素材；原小腿贴图通过 Sprite2D 区域分别绑定胫骨和新增脚掌关节，未生成或重采样像素。

转身由头先转、躯干跟随和两组交错踏步组成，支撑段脚掌固定；正侧面采用单个实色朝向视图，避免半透明叠影。近远腿遮挡按正面站位调整，骨段端点与独立脚踝连接；披风等附件沿回身投影转入遮挡，不靠透明消失。头顶风车轴心跟随头部，转子不反射累计转角。

前扑与后跳分别采用后压／前压重心的蓄力和短暂停住，延长前摇及飞行。新跳跃为固定落点的抛物线，动作区分蹬地、收腿和伸足着地，后跳使用独立姿势，脚掌不随小腿大幅旋转。旧活动存档保留原轨迹标识，在原曲线上完成已承诺飞行；新轨迹标识随快照保存。

验证：CI 四项及文档检查通过；十个受影响专项共 2356 项通过：双向转身后穿身／停留对照 40、转向／后跳／踝关节等 80、连续性 506、Boss 行为 25、牧风者时钟 1198／几何 97／支撑 78／正式 App 63／奖励 139／音频 130。最后风车轴心投影调整后重跑转向 80 项通过。新增检查覆盖胫骨与脚掌连接、脚底水平、正侧面实色互斥、转子连续和转身支撑段足位固定。真实 P-R14 中出生保护结束后，双向普通地面移动仍穿身无伤，原地停留仍受真实接触伤害。

技术证据为 `build/pose-refine-ci.log`、`build/pose-refine-final-checks.log`、`build/pose-refine-turn-final.log` 和 `build/pose-refine-comparison-v2.log`。已检查蓄力／收腿／转身中间帧：脚掌不再随小腿翻转，收腿保留明显地面通道。用户对本版动作观感尚未反馈。

最新预览产物 `bfaf5f299902009db7cd23c5d7c451d50d313400`，H.264 Baseline／AAC、540p60、faststart，每段约 1.7–2.4 MB：

- [转身与扑击穿身对照](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/bfaf5f299902009db7cd23c5d7c451d50d313400/pounce.mp4)，约 16 秒，包含两个方向的转身、前摇、腾空及停留落点反例。
- [一阶段实战](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/bfaf5f299902009db7cd23c5d7c451d50d313400/keeper.mp4)，约 19 秒，包含转身、蓄力后跳与接招。
- [二阶段实战](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/bfaf5f299902009db7cd23c5d7c451d50d313400/windmill.mp4)，约 22 秒，包含风车展开、前扑、转身、吹风、后跳和踏击。

十二段视频公网 HTTP 和 SHA256 校验通过；三段新片绑定本轮源码，九段未改小怪／巡游机视频保留各自原源码。录制入口为 `tools/art/capture_plains_actor_combat.gd -- keeper,windmill` 与 `tests/windkeeper_pounce_142.gd -- capture`，捕获原片／时间线在 `build/plains_actors_142/`。初始站位、二阶段生命阈值、固定倍率宽镜头及穿身对照指定招组为明确夹具；这些证据不代表自然通关、全随机招组或手机性能。三段新片已在浏览器 1× 全程播放，56 个动作选择／12 个视频入口无脚本错误；软件解码分别丢帧 13／1／8，播放记录为 `build/plains_actors_142/browser-actions.json`。当前无运行阻塞，下一动作按用户对动作观感的反馈继续迭代。
