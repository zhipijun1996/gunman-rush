# ITEM-V5-01 证据索引

本目录保留附件原件、实现过程、真实运行与失败记录。下列影片和界面证据有各自准确源码版本；**它们不证明后续 Manifest 修复或最终整合已经通过**。本历史归档建立时尚未创建 PR／合入 main，最终状态由交付更新与实际 PR 决定。

| 证据 | 实际来源与结果 | 证明范围 |
| --- | --- | --- |
| [原表与全表快照](source/) | 用户附件 SHA256 `222d7dd49918ab613d5430a03fcc07f45bce1fbaa89ba6ea072c5a21174b545f` | 72 有效、21 删除、16 成长；03 表 H 当前建议参数由用户确认 |
| [主游戏操作片 MP4](movie-dbf3a154/movie.mp4) | `dbf3a1543d007b4b62b5bad10812d55e7bcc6783`；93 断言／0 失败，原生退出 0，运行期间源码稳定 | 真实标题→可操作 Home→正式平原→宝箱／背包／装备与卸下→射击积攒共鸣→双向飞轮及三台巡游机 |
| [影片像素独审](movie-dbf3a154/pixel-review/review_report.json) | 同一 MP4，独立抽取并实际查看 n1848／1860／1880／1895 及 n1514 | 观察到双侧飞轮向外再返回、三台机械伴随物及攻击线；交叉核实际伤害收据 |
| [小屏原生触控](touch-ui-fbcfed72/capture-manifest.json) | 运行源 `fbcfed72a5c6c266228c3f8f32eaf56a1739fa0d`；Godot 4.7.2 软件 GL，196 断言／0 失败 | 1280×720／960×540 实际绘制；齿轮形状负荷、背包滚动；960 详情实际拖动后，完整装备按钮可见并可点击 |
| [K2 整合 REJECT](integration-dbf3a154-REJECT/review_report_REJECT.json) | 同一 `dbf3a154…`，原 Harness 选定 29 项，26 通过、森林流程失败／180 秒原预算超时、2 未运行 | 保留 IV5-R06：新版商店条件误包地图 Manifest 输出；原检查失败不可重签为通过 |
| [守门独审](guard-review.md) | 独立审核旧命令、输入、预算、拒绝规则及测试迁移 | 工程守门范围，不代表逐件玩法／设备／玩家 G5 |
| [较早开发诊断](development/) | 各收据内原始版本／命令／结果 | 开发证据，不代替最终冻结源码验证 |

影片为 34.883333 秒、1280×720、H.264 60fps／AAC 48kHz 双声道，12,098,296 字节；MP4 SHA256 `18c2d2473a28046551c29994a2f3f87fe928818a20e743d4f5901633a1ee004a`。原始 2083 个轨迹帧与 2093 个媒体帧含收尾的计数口径不同，完整原始[轨迹](movie-dbf3a154/trace.json.gz)、[捕获收据](movie-dbf3a154/receipt.json.gz)与[引擎日志](movie-dbf3a154/capture.log)均保留。这里的相对 MP4 链接指向仓库文件；公网下载可用性须在推送后另行验证，不把尚未发布的路径写成已上线试玩。

影片明示一次宝箱位置 fixture、B33／P24／G15／P14 的已知道具 RewardService fixture、训练平台／镜头／高血靶子；B33 在战斗前卸下。装备通过实际鼠标界面，5 次实际主武器命中自然积攒 35 共鸣，R 产生真实双向飞轮；没有注入玩家生命、金币或共鸣。它证明正式游戏入口与道具运行接线，不是自然完整路线／Boss 通关，也不是 72 件全部自然获取录像。没有匹配的 before 影片。

原命名截图 `opposite_flywheels.png` 抽早了，实际尚未显示飞轮；保留原件与问题，不拿它证明运动。独审从**同一未经修改的 MP4**另取连续阶段的实际帧，映射与 SHA 在 [selected_frames.json](movie-dbf3a154/pixel-review/selected_frames.json)。独审只做已列画面／轨迹观察，没有连续正常速度观看全片或实际听音；音轨存在不等于听感认可。

触控使用外部[控制器原件](touch-ui-fbcfed72/controller/ui_detail_touch_capture.gd)，SHA256 `b7e43629df44472a089b1451f4c8f0a9a95038eef3ec2c038cb8c8f323d86b74`，继承冻结测试，仅增加真实 `ScreenTouch`／`ScreenDrag` 输入及截图观察，不改产品源代码。两次 960 触控分别产生一次 `equipment_requested`，修订 71／会话 19；这是 GUI 可达性与请求证据，没有执行 BuildState 提交。72 道具菜单是明确 fixture。控制器附带 README 的 “Prepared only, not run” 是执行前原件，实际后续执行以 [native.log](touch-ui-fbcfed72/native.log) 和 [输入轨迹](touch-ui-fbcfed72/external-touch-control-trace.json) 为准。

软件 GL／原生触控代理不代签实体安卓、实体手柄、低端 GPU 性能、玩家趣味或艺术验收。P17 基础蓄力移动与表参数冲突、G19 Boss 计精英候选及未实现设计边界以权威规则和最终交付记录为准。

[historical-capture-index.json](historical-capture-index.json) 列每个原始来源、归档路径、字节数及 SHA256。`.gz` 是原始日志／JSON 的无损压缩，已逐项解压与源 SHA 对照；保留原绝对路径作为溯源，不假设接收者本地存在该工作区。原 220MB AVI 不入库，完整可播放 MP4 保留。
