# PIXEL-LIGHT-STUDY-02：像素对齐与局部打光

用户最新要求：继续快速实验，先对齐像素；保留 Underworld 风格，只借鉴 Animal Well 的打光。此前三套全局调色不推进。本轮不跑 CI/Harness、不替换正式入口、不发布旧包或合 main。

基线 `35a9cd8e0ff1b2a6eb0b8f55e3fca9cefe3302f5`，独立分支 `art/pixel-grid-lighting-study`，root 独占新增 Lab、三个 Shader 与本任务证据。不改正式物理、生成、资源、保存、素材原图、公共配置或既有 UID。沿用 visual-director/art-director 的实机比较、原件保留和独立看图原则；依用户指令采用轻量实验。

入口：`bash tools/godot.sh --path . scenes/dev/pixel_light_study.tscn`。底部切原版 / A 仅对齐 / B 暖灯 / C 冷暖光，以及 HOME / PLAINS。仅此 Lab 消费实验，Meta 持久化禁用。继承上一实验的真实 App 构造与清理，不消费其三套调色。

像素：保留原生地形 16px / 32wu；高分辨率精灵与人物通过各自固定 2wu 采样格显示，MODEL_MATRIX 去除平移避免格子随物件位置重新选样。静态 Sprite 与人物纯表现节点吸附 2wu，最终世界输出 2px；HUD 与世界标签绕过世界采样。碰撞／Motor 不吸附。这里是运行时采样与表现规则修正，没有重画原图，细节会减少；动画、相机滚动和跨分辨率闪烁仍未验。

灯光：原始 albedo 与天空保留。现有窗户、灯笼、铜铃使用真实 PointLight2D，实际地形矩形提供 OccluderPolygon，限制亮部响应并加小范围 bloom；C 增加轻微冷色环境补光。现用 unshaded 地形边界仅在实验实例里适配受光。未声明建筑轮廓遮光、法线贴图或完整物理照明。

最终五镜头 × 四版本，20 张真实 Godot 1280×720 定位静态截图，[位置与光源回执](capture.json)、[原生退出0/完成标记](capture.log)。本目录精选家园与铜铃八张。房屋 ROI 的 GPU 2×2 同色比例：原版 1.33%，三个对齐版本均 100%；空天空 ROI 在两灯光版与仅对齐版之间像素相同，见 [测量](pixel_grid_measurements.json)。测量只证明输出格子与限定天空未调色，不证明美感、通关或性能。

独立只读代理实际看初轮六图、nativegrid 三图与三个 Shader，补读固定物件采样 Shader。判断新增物件采样格／锚点比整屏重采样完整；暖灯保留原基调且无第一轮过曝。保留小金币／脸部细节损失、平原光池弱、仅静态未验运动和真机的意见。最终收尾修复由原生重新采20图验证，不冒称独审看过连续运动。

失败原件：`build/pixel_light_study` 首轮屋顶过曝；`build/pixel_light_study_r2` 与 `final` 只有整屏网格，未达到物件自身采样目标；`build/pixel_light_study_nativegrid` 收尾 typed actor key 释放错误，日志保留 [previous_cleanup_error.log](previous_cleanup_error.log)。改 WeakRef 与释放前 busy 后，最终 `build/pixel_light_study_deliver` 原生退出0、无脚本错误。不把前轮失败签通过。

交付是20张原图、家园／铜铃两张对照板、4倍细节板与可离线打开的自包含截图查看器。查看器可切5镜头、左右原版/对齐基线与三候选，不是可玩 Web。没有 CI、全区回归、真机或最终美术认可声明。下一步先由用户判断像素颗粒和细节取舍，再决定是否细化光池、遮光轮廓与运动稳定性。
