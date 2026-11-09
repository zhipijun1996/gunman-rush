# 平原当前交接

## 范围与来源

分支 `feat/plains-v07-complete`，PR142保持草稿，接续PR141。整区目标35房/43接缝，当前正式开放03→21→22→23→24→01六房，其余29内部尚未迁移。L01东行与26双吊台主路不变。

本轮WORLD-CAMERA-02基线beb8dab8。用户认可镜头其余行为，要求小型Boss场地平滑拉至尽量全场可见；普通观察在地面偏上、上升逐渐居中、下降偏下、落地轻微回升。直接更新[正式镜头规范](../../../bible/room_authoring.md#正式镜头)，仍由WorldCamera唯一计算，区解析归WorldCameraZones；[查看输入](../../../bible/controls_contract.md#手动查看)未修改。

## 当前实现

- 普通缩放1.6；Boss区显式开启合屏，入场平滑趋向场地中心，在最低1.0与普通比例之间选取能尽量容纳全场的画幅。缩放阻尼0.45秒；大场地/窄屏放不下时有限跟随，退出恢复探索比例。牧风者现有场地可完整合屏。
- 普通纵向观察沿真实运动连续变化：站地上方→上升减速时向中心移动→顶点居中→下落转向下方→落地0.24秒柔和回升。沿唯一目标与分轴阻尼计算，不新增落地震动或能力镜头模式。
- 已设计的下降段落点预读、Boss全场和安全边界优先。最初把下行区偏置统一改成上看会遮住教程落台，连续回归发现后已保留其明确构图；不能为了新效果牺牲已认可的可读性。
- 水平观察方向、前瞻、左杆上下低优先级查看、隐藏区交接、演出/震动与生命周期继续沿现行规则；角色物理、输入、309房施工合同与35场景布局相对本轮基线均未变化。数值权威仍在config/world/player.json:camera。

## 验证与交付

当前日志与短片归 `build/camera-refinement/`。新增camera_vertical.gd以实际跳跃输入验证上升/顶点/下落/落地与Boss合屏，共18项；短跳/满跳顶点相机中心距角色约3.4/6.4wu。原camera_controller 36项、camera_zones 118项、camera_motion 10项、连续教程与111项预读/恢复通过。日常CI四项、世界单测24项、文档与质量记录一致性通过。Web复验启动/移动跳跃/地图/暂停、触屏上下查看与恢复、逐房存档隔离、视频播放及下载。

13段正常速度短片全部重录新版。前两段与上一版beb8dab8比较Boss入场和跳跃节奏；其余沿原29bd6b58对照，逐片记录基线。隐藏区与P14 Boss/H是明确隔离夹具，不表示当前六房主线可达；完整原生录制和抽帧审看不等于实体设备或真人盲玩。开启夹具没有写入正式进度。旧临时源码/大型AVI在完成交付后清理，旧公开短片已替换。

公开 build `cdbd68be4e70`，导出源码 `bb9613cc4f624e4864670e6d72eb0b4c99ef9f2f`，prepared `ffc6ddbf7debb408554b8b3990c7336ac19c01ab`；部署[42566878336](https://github.com/zhipijun1996/gunman-rush/actions/runs/42566878336)成功。线上版本、46份页面/短片/ZIP/总图文件与本地一致，公开启动已复验。

- [连续试玩](https://zhipijun1996.github.io/gunman-rush/?v=cdbd68be4e70) / [六房快速入口](https://zhipijun1996.github.io/gunman-rush/replays/?v=cdbd68be4e70)。
- [13段前后对比](https://zhipijun1996.github.io/gunman-rush/camera-review/?v=cdbd68be4e70)：最前两段为本轮重点，约4秒与3秒。
- [新版短片合集，约10.1 MiB](https://zhipijun1996.github.io/gunman-rush/camera-review/camera-after-clips.zip?v=cdbd68be4e70)。
- [35房路线/职责/收集/Boss/休息站总图](https://zhipijun1996.github.io/gunman-rush/map-review/?v=cdbd68be4e70)：沿已确认的同源轮廓与连接。

## 剩余工作

本次未扩建地形。首段22完成侧回程板、24载具外观、整体材料层次，以及其余29房的能力锁/收集返回/战后分流/连续主环仍留在区域施工任务。全区玩法、美术、剧情与视听未整体终审。实体手机/手柄、完整Web流程、目标设备帧时间未验证。

正式槽原生 `fixed_world_plains04_construction.json` / Web `plains04_construction`；逐房模式只用内存。后续恢复上下文先读本交接与现行镜头规范，未决设计冲突询问用户，已明确的新规则直接落实。PR142不合并。
