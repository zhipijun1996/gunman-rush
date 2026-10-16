# PR68 → V3 正式路线：事实对照包

本页继承原build事实报告。可直接下载版本见同目录README.md：两份原MP4单独提供，原记录/PNG另装original_records_and_png.zip；下文original_evidence.zip是保留在build的历史完整归档，未重复提交。新包装完整性见portable_packaging_receipt.json。

本包只读现有正式记录，不运行 Godot，不改生产源、历史 guard 或原图。作者实现过 ivy，故本包不是 ivy 的独立视觉验收，也不签美术/商业品质通过。全部对照依据 actual pixels 与原始 capture；未使用素材 metadata 替代看图。

## 可比条件与不能越过的边界

三侧均是 literal root seed `level-design-v2-baseline`、map2、fast、phase_wait_ticks0、同一个实际 postdraw 协议，3063 物理帧 /3067 视频帧 /27张抽帧；均到达 route_target_reached。独立 map2 入口，不代表 map1→map2 campaign、Boss 通关或手机输入验证。三侧每次捕获自身 source_before/source_after 稳定；本包重新计算全部3份 native capture、MP4 与81张原抽帧 SHA，均与其原始记录相符。

PR68 capture_commit ed0623000c61287282f89e6b0463937b0afe0aca；V3 before-ivy 21e27bda8031d1b7122257c900479647f1cfbf31；当前 V3 1d1ccadc2649b145b58c1489a439ffc687b5877c。记录内 source_commit 不是完整版本指纹：每侧实际 source_before 全清单保留在 index.json 和 ZIP 原 visual_capture.json。

严格 PR68 art-only 比较仍是 blocked：driver_sources、manifest、formal_run_manifest_initial 不同。未移除字段、未改 guard、未将 diagnostic 比较伪称严格 PASS。PR68 内容基底 overlay 的 exact_overlay.diff 和真实记录在 ZIP：这也是为何不是未经修改的 PR68 原始运行器对照。

## 精确相同和真实差异

PR68→V3：3063个同 tick 的 position、velocity、axis、displacement、grounded、health、energy、shots、cooldown、jumps、controller tick、recovery、session/resource epoch 全部精确一致。最大位置与速度差均0；7段 edges、初末 capability 精确一致。碰撞数据2365帧不同，但完整 deepdiff 说明差异全部在 collider 实例路径（5629个 leaf）；无碰撞法线、位置或数组长度差异。事件43帧不同，完整 leaf 差异为 owner_id/event_id/source 实例标识；input_requests47帧的差异为真实单调钟 timestamp。input_timing3063帧差异为实际 physics signal 时间与47次排队时间/age。原始差异全部保留，未从 capture 中剥除。

camera 初末 position、screen_center、zoom、viewport、follow_trace 精确相同。但逐 tick capture 没有 camera 字段，所以不能声称逐帧 camera trace 已验证、全程像素配准或视频 frame index 等于物理 tick。JPG用相同 video frame index/60秒作为观看对照，明确不是同 physics tick 的截图。

当前地图 Manifest 仅3处实际差异：version `plains-region-v10`→`plains-region-v11-root-bell-v2`；新增 root_bell_admission（此 seed `no_physically_qualified_lane` /replaced0）；manifest_hash。两份 formal_run_manifest_initial 的10个 leaf 差异对应两个 stage 的版本/入选说明/hash。此 seed 不包含新 Root Bell 正式遭遇，因此本对照不能证明新敌人体验。

capture_source_hashes 六项中只有 scenery 不同，五个实际 capture/trace 协议 SHA 一致；policy_basis.driver_sources 另有 tools/level_design.py 版本差异，正是严格 guard 拒绝条件之一。runtime source inventory 还包含真实 generator、DemoApp、敌人和视觉源变更，均逐项保留，不能由这条路线位置一致倒推这些修改全游戏等价。

V3 before-ivy→current：原同 v11 严格 art-only 比较为 comparable_for_review，原结果原样收录；新增事实 deepdiff仍保留3419个 raw leaf差异（实例标识/真实时间/源码指纹等），全部3063帧 position/velocity/resources/collision一致。该结果只允许进入像素审查，不代表 ivy 已获独立审美认可。

## 实际看图选择与覆盖

实际看过 PR68/V3 各27帧 contact，以及600、840、1320、3000当前全尺寸与600、1320旧全尺寸，用来选择而非仅凭区域名判断。6份三联 JPG 上中下分别 PR68、V3 before-ivy、V3 current；原始 PNG 原字节存 ZIP。

- video600/10s：主路线风车高地，旧画面主要是远方山谷，新画面右侧有近处大风车与石基；可用于观察地标/空间密度改变。
- video840/14s：主路机关/平台处的岩壁围合，比较大形体与交互物可见关系。这不是下层 creek_well 节点到达证明。
- video1320/22s：实际 REPAIR CAMP 标识与帐篷旁，新版完整维修建筑与原前景地形共同可见。
- video1440/24s：营地离开窗口，保留相邻区域衔接，而非只选新增建筑最满的镜头。
- video1800/30s：实际从 area_3_1 向 area_3_2 下降的垂直窗口；该路线随后在 lower creek 带行进。
- video3000/50s：area_4_2→area_4_1 的回升窗口，保留镜头随动作变化、边界与落点关系。此帧仅作为真实比较材料；作者不独审自己 ivy。

本路线未进入上层 clock_court、隐藏大师路或 Boss 战场，不能为它们提供该 seed 对照，不能用视觉职责标签虚增覆盖范围。下层后半程仍有大量开阔背景/重复地形；是否满足画质目标由不同审查者实际看正常速度录像与这些原图决定。

## 文件和复现

- `pr68__v3_current.summary.json` / `v3_before_ivy__v3_current.summary.json`：逐字段数量、全部关键输入差异、camera/trajectory事实。
- `*.raw_deepdiff.jsonl.gz`：全部原始 leaf 差异，含路径、before、after，不只是精选样本。
- `index.json`：原路径、归档member、逐文件SHA/大小、3侧完整源码指纹、6个选帧、原严格结果。
- `original_evidence.zip`：两份原始正常速度 MP4（PR68/current）、三侧 capture/visual记录与日志、18张原始PNG、overlay/严格比较原件；ZIP CRC与每个member解出字节SHA全部强验。before-ivy完整MP4不重复归档，原路径及SHA保留在 index；原件未删除或改写。
- `actual_hash_reverification.json`：本轮独立重算已有三套全部媒体记录的校验结果。
- `package_facts.py`：实际生成/验证脚本，仅写本证据目录；不得当作新 Harness 或生产准入器。

本目录实际约116 MB，低于120 MB预算。没有新增 host/model 调用，没有 Godot执行、没有修改任何生产/旧记录。尚需不同人员审查实际像素与连续录像；本包不替代真人试玩、移动设备或商业美术验收。
