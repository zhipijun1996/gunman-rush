# 多武器细节候选证据

[交接与复现](../../../worklines/PLAYER-PRESENTATION-01/weapon-handoff-05.md)说明真实消费者、范围、接口、已知失败和后续事项。工作线保持 in_progress，旧握持／run 美术问题未关闭。

- [真实同条件对照电影](weapon-comparison.mp4)：原武器表现先播放，候选后播放；各16.7667秒、1280×720、60fps、带原音轨。移动候选两边一致，9 Mode 普攻。源码 `5a1c640bdfd8c5889ae88efd9bdb10596aab00d2`，未以新UI源重标。
- [原始证据归档](weapon-v1-evidence.zip)：真实 native ON/OFF 轨迹、全部36张独审视频抽帧、15装备＋6实际攒资源技能 headless 轨迹、生命周期和旧武器专项、原始失败日志、三次浏览器报告及选定实际截图、可复现交付驱动。逐成员 SHA / CRC 已读回；清单见 [evidence-index.json](evidence-index.json)。
- [工程独审](engineering-review.json)：限域 ACCEPT。[运行及实际抽帧独审](runtime-review.json)：整体 UNVERIFIED。接触／激光端点／地雷微光偏弱，未签可读性改善、全速或听感。
- [UI专项独审](ui-review.json)：限域接受最终中文菜单／布局与记录中的本地 DOM 操作；未签整个 Web 网络或实体设备。
- [独立试玩包收据](package-final.json)：本地实际 ZIP / 原 PCK 重建和 Chromium 键鼠／DOM touch 验证；最终 build `b01ee2694450`，源 `3a8320327ba22683cd455c9c9a476cedceabaaf0`。相对电影源只有任务菜单字体／布局改变，精确 [diff](ui-only-diff.patch) 保留。大试玩包位于交接所列 build 路径，未放入源码证据归档。
- [公开电影完整下载核验](public-movie-download.json)：匿名响应完整字节 SHA 与原始电影匹配；共享站最新 Web 仍因900MiB容量拒绝，未发布新公网试玩入口。
- [版本化消费者清单](consumer-inventory-weapon-v1.json)：全部旧消费者保留；正式 Home / Plains 仅任务挂载，不是正式共享采用。

用户审美／听感／手感、实体设备、完整15装备／6技能 GPU 美术及全部受影响 Integration 未验。浏览器原 console 的未知 URL generic404 和 autoplay 提示保留，Space 后 AudioContext running 不等于听音认可。电平峰值 -4.3dB 也不签混音质量。
