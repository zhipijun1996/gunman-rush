# 两类 RootBell 正式实机录像与画面对照

以下为原速、1280×720、60fps 的有损分享编码（H.264 CRF26）；音轨直接复制并核对 AAC 包内容。原始大录像保留在 build，不覆盖原件。分享版不能声称与原片像素完全相同。

| 空间 | 分享录像 | 大小 | 视频帧数 | 视频时长 |
| --- | --- | ---: | ---: | ---: |
| 宽岸 | [rootbell_wide_share.mp4](rootbell_wide_share.mp4) | 42.33 MB | 6883 | 114.716667 秒 |
| 紧岸 | [rootbell_tight_share.mp4](rootbell_tight_share.mp4) | 30.13 MB | 5185 | 86.416667 秒 |

两部各含 19 个案例：17 个 Router 输入案例、1 个真实暂停回调案例、1 个显式 inactive-target 夹具。旧 raw 标签“18 input-only”不准确；每部 inactive-target 夹具均出现过 HP5→4，不能签全 19 案例无伤。它们证明限定正式遭遇，不能代表全战役、商业美术、用户体验或设备认可。

宽岸文件为 42.33 MB，略高于建议的 40 MB，但小于 GitHub 100 MB 限额。本轮只串行编码两次，没有为体积反复重编。

[完整编码、SHA、ffprobe、音轨包与耗时报告](share_report.json)。确切拍摄源码以 [完整 overlay ZIP](source_overlay/dirty_source_overlay_complete.zip) 及 [两片实际绑定](source_overlay/actual_movie_bindings_complete.json) 为准：ZIP SHA256 为 `6b66760804de72f7d6d0f990950f60052ff08295733f73d3983a366998ca21f6`；早期 `e4f3e6…` 不完整包没有用于此分享交付。原历史 receipt 未改写，稍后的 complete bindings 已绑定两片。

下面直接链接既有原始 Godot PNG，没有拼图、重绘或模拟替换。植物对照使用冻结 v11-root-bell-v2 宽岸的相同 Manifest、几何与镜头，仅切换新植物消费者；v12 实际电影与 fresh 默认运行另外验证。不能把 v11→v12 整版变化归因于美术。三窗是明确静态重置夹具；中央窗重叠姿态不代表合法完整遭遇，动态行为看上方影片。

| 实际观看窗口 | 原画面 | 新画面 |
| --- | --- | --- |
| 接近：左树与灌丛 | [baseline](../../asset_families/final_plants_ab_01/window_0_baseline.png) | [candidate](../../asset_families/final_plants_ab_01/window_0_candidate.png) |
| 预告与落点：保留 RootBell 判断带 | [baseline](../../asset_families/final_plants_ab_01/window_1_baseline.png) | [candidate](../../asset_families/final_plants_ab_01/window_1_candidate.png) |
| 回望：右侧有根树木 | [baseline](../../asset_families/final_plants_ab_01/window_2_baseline.png) | [candidate](../../asset_families/final_plants_ab_01/window_2_candidate.png) |
| 岩壁右下角实验：完整目标未达且不 shipping | [baseline](../../asset_families/combined_ab_04/window_5_baseline.png) | [candidate](../../asset_families/combined_ab_04/window_5_candidate.png) |

植物的独立静态接受仅覆盖实际有限消费者；完整自然连接岩壁家族与商业大轮廓目标仍未完成。
